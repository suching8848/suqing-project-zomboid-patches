package suqingviewpointaim;

import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Random;
import java.util.zip.ZipFile;

import me.zed_0xff.zombie_buddy.Loader;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import sun.misc.Unsafe;
import zombie.ZomboidFileSystem;
import zombie.characters.IsoPlayer;
import zombie.core.Core;
import zombie.core.random.RandStandard;
import zombie.gameStates.ChooseGameInfo;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.HandWeapon;
import zombie.network.GameClient;

public final class NativeAimAudit {
    private static Instrumentation instrumentation;
    private static int assertions;

    public static void premain(String args, Instrumentation value) {
        instrumentation = value;
    }

    public static void main(String[] args) throws Throwable {
        Path candidate = Path.of(args[0]);
        Path profile = Path.of(args[1]);
        Path viewJar = Path.of(args[2]);
        Path viewMod = viewJar.getParent().getParent().getParent().getParent().getParent();
        Path buddyMod = Path.of(args[3]);
        var fs = ZomboidFileSystem.instance;
        fs.setCacheDir(profile.resolve("Zomboid").toString());
        fs.init();
        RandStandard.INSTANCE.init();
        check(Main.GAME.equals(Core.getInstance().getGameAndBuildVersion()), "exact game build");
        check(Main.BUDDY_HASH.equals(Main.hash(Main.source(Loader.class))), "real ZombieBuddy JAR pin");

        var info = ChooseGameInfo.readModInfo(candidate.toString());
        check(info != null && info.isAvailableSelf(), "native candidate eligibility");
        check(Main.ID.equals(info.getId()) && "0.1.0".equals(info.getModVersion()), "native metadata");
        check(Path.of(info.getVersionDir()).equals(candidate.resolve("42")), "native 42 branch");
        check(info.getRequire().equals(List.of("Viewpoint", "ZombieBuddy")), "native dependencies");
        Path lua = candidate.resolve("42/media/lua/client/SuQingViewpointAimEnhancement.lua");
        try (var reader = Files.newBufferedReader(lua)) {
            check(LuaCompiler.loadis(reader, lua.toString(), new J2SEPlatform().newTable()) != null,
                "Kahlua compiles the lifecycle bridge");
        }
        check(instrumentation != null && instrumentation.isRetransformClassesSupported(), "native JVM retransformation");
        field(Loader.class, "g_instrumentation").set(null, instrumentation);
        field(ZomboidFileSystem.class, "modFolders").set(fs,
            List.of(viewMod.toString(), buddyMod.toString(), candidate.toString()));

        TestPlayer player = allocate(TestPlayer.class);
        HandWeapon weapon = firearm();
        player.aiming = true;
        player.held = weapon;
        IsoPlayer.players[0] = player;
        var mods = fs.getModIDs();
        mods.clear();
        mods.addAll(List.of("Viewpoint", "ZombieBuddy", Main.ID));
        check(ChooseGameInfo.getModDetails("Viewpoint") != null, "Viewpoint resolves by native Mod ID");

        if (args[4].equals("reject")) {
            check(!Main.World.enter(), "different Viewpoint JAR fails closed");
            check(!Main.VIEWPOINT_HASH.equals(Main.hash(viewJar)), "wrong-source fixture differs");
            finish();
            return;
        }

        check(Main.VIEWPOINT_HASH.equals(Main.hash(viewJar)), "real Viewpoint JAR pin");
        GameClient.client = true;
        check(!Main.World.enter(), "client cannot activate");
        GameClient.client = false;
        mods.add("ShootToThrill");
        check(!Main.World.enter(), "STT conflict cannot activate");
        mods.remove("ShootToThrill");
        mods.remove(Main.ID);
        check(!Main.World.enter(), "disabled mod cannot activate");
        mods.add(Main.ID);
        Main.main(new String[0]);
        check(Main.World.enter(), "real Java entry and world activation");

        var gunplay = Class.forName("viewpoint.gunplay.Gunplay", false, NativeAimAudit.class.getClassLoader());
        check(instrumentation.isModifiableClass(gunplay), "real Gunplay can be retransformed");
        try (var jar = new ZipFile(viewJar.toFile())) {
            byte[] original = jar.getInputStream(jar.getEntry(AimTransform.TARGET + ".class")).readAllBytes();
            byte[] transformed = AimTransform.rewrite(original);
            check(transformed.length > original.length, "real Gunplay call sites found");
            boolean rejected = false;
            try {
                AimTransform.rewrite(transformed);
            } catch (IllegalStateException expected) {
                rejected = true;
            }
            check(rejected, "partial or repeated call-site rewrites are rejected");
        }

        Class<?> focusType = Class.forName("viewpoint.gunplay.Focus");
        var advance = method(focusType, "advance", double.class, int.class, boolean.class);
        var level = method(focusType, "level");
        var reset = method(focusType, "reset");
        Object nativeFocus = create(focusType);
        Object enhancedFocus = create(focusType);
        for (int skill : new int[] {0, 5, 10}) {
            AimControl.setPlayer(player);
            reset.invoke(nativeFocus);
            for (int step = 0; step < 160; step++) {
                advance.invoke(nativeFocus, 0.05, skill, true);
                AimControl.advance(enhancedFocus, 0.025, skill, false, player, weapon);
                near((double) level.invoke(nativeFocus), (double) level.invoke(enhancedFocus), "2x focus while moving");
            }
            near(1.0, (double) level.invoke(enhancedFocus), "reaches full focus");
        }

        AimControl.setPlayer(player);
        double prior = 0.30;
        for (int step = 0; step < 100; step++) {
            AimControl.advance(enhancedFocus, 0.025, 5, false, player, weapon);
            double ring = AimControl.tighten(enhancedFocus, step == 0 ? 0.30 : 0.75, 0.05, player, weapon);
            check(ring <= prior + 1e-10 && ring >= 0.05 - 1e-10,
                "changes of target do not interrupt shrinkage");
            prior = ring;
        }
        near(0.05, prior, "minimum radius");
        for (int shot = 0; shot < 12; shot++) {
            AimControl.reset(enhancedFocus, player, weapon);
            AimControl.advance(enhancedFocus, 0.025, 5, false, player, weapon);
            near(0.05, AimControl.tighten(enhancedFocus, 0.3 + shot, 0.15, player, weapon),
                "shooting, movement and target changes preserve the latched radius");
        }

        Class<?> swayType = Class.forName("viewpoint.gunplay.Sway");
        Object sway = create(swayType);
        method(swayType, "start", Random.class, double.class).invoke(sway, new Random(23), 0.3);
        AimControl.sway(sway, 0.02, 0.05, 1.0, player, weapon);
        near(0.05, (double) method(swayType, "radius").invoke(sway), "native sway uses exact latched radius");
        double right = (double) method(swayType, "right").invoke(sway);
        double up = (double) method(swayType, "up").invoke(sway);
        check(Math.hypot(right, up) <= 0.05, "real native sway stays within the aim ring");
        near(0.01, field(swayType, "time").getDouble(sway), "native sway phase uses real elapsed time");

        var gameFocus = field(gunplay, "focus").get(null);
        var shotStarting = method(gunplay, "shotStarting", zombie.characters.IsoGameCharacter.class, HandWeapon.class);
        field(Class.forName("viewpoint.core.View"), "enabled").setBoolean(null, true);
        field(Class.forName("viewpoint.input.CrosshairAim"), "on").setBoolean(null, true);
        // Exercise the transformed shot entry and snapshot without resolving a shot or loading a world.
        AimControl.advance(gameFocus, 1.0, 10, false, player, weapon);
        shotStarting.invoke(null, player, weapon);
        near(1.0, (double) level.invoke(gameFocus), "real shot entry preserves full focus");
        near(1.0, field(Class.forName("viewpoint.gunplay.Shot"), "focus").getDouble(null),
            "real shot uses the accumulated focus");
        method(gunplay, "shotEnded").invoke(null);
        player.aiming = false;
        method(gunplay, "snapshot").invoke(null);
        near(0.0, (double) level.invoke(gameFocus), "real snapshot resets focus on aim release");

        player.aiming = true;
        AimControl.advance(enhancedFocus, 0.01, 5, false, player, weapon);
        check((double) level.invoke(enhancedFocus) < 0.1, "second aim cycle begins fresh");
        AimControl.advance(enhancedFocus, 2.0, 10, false, player, weapon);
        HandWeapon second = firearm();
        player.held = second;
        AimControl.advance(enhancedFocus, 0.01, 5, false, player, second);
        check((double) level.invoke(enhancedFocus) < 0.1, "new weapon resets focus");
        check(AimControl.tighten(enhancedFocus, 0.4, 0.1, player, second) > 0.35,
            "new weapon establishes a new minimum");
        GameClient.client = true;
        AimControl.advance(enhancedFocus, 0.05, 5, false, player, second);
        near(0.0, (double) level.invoke(enhancedFocus), "client mode falls back to native unsettled behavior");
        GameClient.client = false;
        Main.World.leave();
        advance.invoke(gameFocus, 1.0, 10, true);
        check((double) level.invoke(gameFocus) > 0.0, "native focus can accumulate with the patch inactive");
        shotStarting.invoke(null, player, second);
        near(0.0, (double) level.invoke(gameFocus), "unmodified shot penalty after leaving the world");
        method(gunplay, "shotEnded").invoke(null);
        AimControl.advance(enhancedFocus, 0.05, 5, false, player, second);
        near(0.0, (double) level.invoke(enhancedFocus), "leave disables enhancement");
        check(Main.World.enter(), "world can re-enter with existing transform");
        Main.World.leave();
        finish();
    }

    private static final class TestPlayer extends IsoPlayer {
        boolean aiming;
        HandWeapon held;

        private TestPlayer() {
            super(null);
        }

        @Override
        public boolean isAiming() {
            return aiming;
        }

        @Override
        public InventoryItem getPrimaryHandItem() {
            return held;
        }
    }

    private static HandWeapon firearm() throws Exception {
        HandWeapon weapon = allocate(HandWeapon.class);
        field(HandWeapon.class, "isAimedFirearm").setBoolean(weapon, true);
        return weapon;
    }

    private static <T> T allocate(Class<T> type) throws Exception {
        Unsafe unsafe = (Unsafe) field(Unsafe.class, "theUnsafe").get(null);
        return type.cast(unsafe.allocateInstance(type));
    }

    private static Object create(Class<?> type) throws Exception {
        var constructor = type.getDeclaredConstructor();
        constructor.setAccessible(true);
        return constructor.newInstance();
    }

    private static Field field(Class<?> type, String name) throws Exception {
        var result = type.getDeclaredField(name);
        result.setAccessible(true);
        return result;
    }

    private static Method method(Class<?> type, String name, Class<?>... parameters) throws Exception {
        var result = type.getDeclaredMethod(name, parameters);
        result.setAccessible(true);
        return result;
    }

    private static void near(double expected, double actual, String detail) {
        check(Math.abs(expected - actual) < 1e-10, detail + " expected " + expected + ", got " + actual);
    }

    private static void check(boolean condition, String detail) {
        if (!condition) throw new AssertionError(detail);
        assertions++;
    }

    private static void finish() {
        System.out.println("NATIVE_VIEWPOINT_AIM PASS assertions=" + assertions);
    }
}
