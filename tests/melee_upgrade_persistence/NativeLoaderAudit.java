import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import me.zed_0xff.zombie_buddy.ZombieBuddy;
import zombie.ZomboidFileSystem;
import zombie.core.Core;
import zombie.core.random.RandStandard;
import zombie.gameStates.ChooseGameInfo;

public final class NativeLoaderAudit {
    private static final String MOD = "SuQingMeleeUpgrade_4222";
    private static final String ENTRY = "suqingmeleeupgrade.Main";

    private static void check(boolean value, String label) {
        if (!value) throw new AssertionError(label);
        System.out.println("PASS " + label);
    }

    public static void main(String[] args) throws Exception {
        Path game = Path.of(args[0]);
        Path profile = Path.of(args[1]);
        boolean approved = Boolean.parseBoolean(args[2]);
        check("2.3.4".equals(ZombieBuddy.getVersion()), "actual installed ZombieBuddy version");
        check("42.22.2".equals(Core.getInstance().getGameAndBuildVersion()), "actual build");
        try {
            Class.forName(ENTRY, false, ClassLoader.getSystemClassLoader());
            throw new AssertionError("Test classpath bypasses normal loader");
        } catch (ClassNotFoundException expected) {
            System.out.println("PASS JAR absent from test classpath before native approval");
        }
        ZomboidFileSystem fileSystem = ZomboidFileSystem.instance;
        fileSystem.setCacheDir(profile.resolve("cache").toString());
        fileSystem.setModFoldersOrder("mods");
        fileSystem.init();
        check(ChooseGameInfo.getAvailableModDetails(MOD) != null, "native mod metadata discovered");
        RandStandard.INSTANCE.init();
        Core.optionModsEnabled = true;
        fileSystem.loadMods("default");
        Class<?> main = null;
        try {
            main = Class.forName(ENTRY, false, ClassLoader.getSystemClassLoader());
        } catch (ClassNotFoundException expected) {
            if (approved) throw expected;
        }
        check((main != null) == approved, "approved JAR activates only for the exact allowed hash");
        if (approved) {
            Path actual = Path.of(main.getProtectionDomain().getCodeSource().getLocation().toURI());
            check(Files.isSameFile(actual, profile.resolve("cache/mods").resolve(MOD)
                .resolve("42/media/java/client/SuQingMeleeUpgrade.jar")), "actual approved JAR source");
            check(fileSystem.getModIDs().containsAll(List.of("ZombieBuddy", MOD)), "native mod list includes loaded dependency and mod");
            Class.forName("suqingmeleeupgrade.NativeUpgradeAudit").getMethod("run", Path.class).invoke(null, game);
        }
        System.out.println("NATIVE_MELEE_LOADER PASS approved=" + approved);
    }
}
