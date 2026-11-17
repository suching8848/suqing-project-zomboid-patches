package suqingknoxwaveaudiofix;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.AccessibleObject;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.CodeSource;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.util.HexFormat;
import se.krka.kahlua.vm.JavaFunction;
import zombie.Lua.LuaManager;
import zombie.core.Core;

public final class Main {
    private static final String LOG = "[SuQingKnoxwaveAudioFix] ";
    private static final String GAME_VERSION = "42.22.2";
    private static final String GAME_REVISION = "3d39148846";
    private static final String KNOXWAVE_SHA256 =
        "834336060ed8cc0e89ba7bde969395f5fa05e5f276012b0a35cd719e34edb10a";
    private static final String OPTION_GETTER = "knoxwaveGetOption";
    private static final String OPTION_SETTER = "knoxwaveSetOption";

    private Main() {}

    public static void main(String[] args) {
        Path jar;
        try {
            jar = installAudioFix();
            System.out.println(LOG + "KNOXWAVE 0.15.34 volume and sound-name access ready");
        } catch (Exception | LinkageError failure) {
            System.err.println(LOG + "inactive: " + failure);
            return;
        }

        try {
            exposeOptions(jar);
        } catch (Exception | LinkageError failure) {
            System.err.println(LOG + "settings bridge unavailable: " + failure);
        }
    }

    private static Path installAudioFix() throws Exception {
        Core core = Core.getInstance();
        if (!GAME_VERSION.equals(core.getGameAndBuildVersion()) || !GAME_REVISION.equals(core.getGitSha())) {
            throw new IllegalStateException("requires Project Zomboid " + GAME_VERSION + " " + GAME_REVISION);
        }

        ClassLoader loader = Main.class.getClassLoader();
        Class<?> fileSoundDsp = Class.forName("pzacoustics.FileSoundDsp", false, loader);
        Class<?> soundVolumePatch = Class.forName("pzacoustics.SoundVolumePatch", false, loader);
        Path jar = source(fileSoundDsp);
        if (!jar.equals(source(soundVolumePatch)) || !KNOXWAVE_SHA256.equals(sha256(jar))) {
            throw new IllegalStateException("requires the verified KNOXWAVE 0.15.34 JAR");
        }

        Class<?> sound = Class.forName("fmod.fmod.FMODSoundEmitter$Sound", false, loader);
        Method volume = sound.getDeclaredMethod("getVolume");
        Field name = sound.getDeclaredField("name");
        if (volume.getReturnType() != float.class || Modifier.isStatic(volume.getModifiers())
                || name.getType() != String.class || Modifier.isStatic(name.getModifiers())) {
            throw new IllegalStateException("unexpected FMOD sound members");
        }
        allowAccess(volume);
        allowAccess(name);

        // Supply the same lookups Knoxwave caches, with access to their package-private owner.
        // The original sound calculations and FMOD callbacks continue to use these caches.
        Field volumeCache = cacheField(fileSoundDsp, "volumeMethod", Method.class);
        Field nameCache = cacheField(soundVolumePatch, "nameField", Field.class);
        Object oldVolume = volumeCache.get(null);
        nameCache.get(null); // Initialise both holders before changing either cache.
        volumeCache.set(null, volume);
        try {
            nameCache.set(null, name);
        } catch (IllegalAccessException | RuntimeException failure) {
            volumeCache.set(null, oldVolume);
            throw failure;
        }
        return jar;
    }

    private static void exposeOptions(Path jar) throws Exception {
        var exposer = LuaManager.exposer;
        var env = LuaManager.env;
        if (exposer == null || env == null) {
            return; // ZombieBuddy discovers the original annotated globals for the first Lua initialization.
        }
        Object getter = env.rawget(OPTION_GETTER);
        Object setter = env.rawget(OPTION_SETTER);
        if (getter instanceof JavaFunction && setter instanceof JavaFunction) {
            return;
        }
        if (getter != null || setter != null) {
            throw new IllegalStateException("KNOXWAVE option names are already in use");
        }

        Class<?> settings = Class.forName("pzacoustics.Settings", false, Main.class.getClassLoader());
        if (!jar.equals(source(settings))) {
            throw new IllegalStateException("KNOXWAVE settings class comes from a different JAR");
        }
        var constructor = settings.getDeclaredConstructor();
        allowAccess(constructor);
        // A save-only load can happen after exposeAll. Bind the original annotations to the
        // current environment now. ZombieBuddy keeps the class registered for later Lua resets.
        try {
            exposer.exposeGlobalFunctions(constructor.newInstance());
            if (!(env.rawget(OPTION_GETTER) instanceof JavaFunction)
                    || !(env.rawget(OPTION_SETTER) instanceof JavaFunction)) {
                throw new IllegalStateException("KNOXWAVE option methods were not exported");
            }
        } catch (Exception | LinkageError failure) {
            env.rawset(OPTION_GETTER, null);
            env.rawset(OPTION_SETTER, null);
            throw failure;
        }
        System.out.println(LOG + "KNOXWAVE settings exported to current Lua environment");
    }

    private static Field cacheField(Class<?> holder, String member, Class<?> type) throws ReflectiveOperationException {
        Field field = holder.getDeclaredField(member);
        int flags = field.getModifiers();
        if (field.getType() != type || !Modifier.isStatic(flags) || Modifier.isFinal(flags)) {
            throw new IllegalStateException("unexpected cache field " + holder.getName() + "." + member);
        }
        allowAccess(field);
        return field;
    }

    private static void allowAccess(AccessibleObject member) throws IllegalAccessException {
        if (!member.trySetAccessible()) {
            throw new IllegalAccessException(member.toString());
        }
    }

    private static Path source(Class<?> type) throws IOException, URISyntaxException {
        CodeSource code = type.getProtectionDomain().getCodeSource();
        if (code == null || !"file".equals(code.getLocation().getProtocol())) {
            throw new IOException("cannot verify code source for " + type.getName());
        }
        return Path.of(code.getLocation().toURI()).toRealPath();
    }

    private static String sha256(Path path) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream input = new DigestInputStream(Files.newInputStream(path), digest)) {
            input.transferTo(OutputStream.nullOutputStream());
        }
        return HexFormat.of().formatHex(digest.digest());
    }
}
