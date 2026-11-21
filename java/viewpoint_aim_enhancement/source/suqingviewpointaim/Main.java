package suqingviewpointaim;

import java.lang.instrument.Instrumentation;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;

import me.zed_0xff.zombie_buddy.Exposer;
import me.zed_0xff.zombie_buddy.Loader;
import me.zed_0xff.zombie_buddy.ZombieBuddy;
import zombie.ZomboidFileSystem;
import zombie.characters.IsoPlayer;
import zombie.core.Core;
import zombie.gameStates.ChooseGameInfo;
import zombie.network.GameClient;
import zombie.network.GameServer;

public final class Main {
    static final String ID = "SuQingViewpointAimEnhancement_4222";
    static final String LOG = "[" + ID + "] ";
    static final String GAME = "42.22.2";
    static final String VIEWPOINT_HASH = "8d0d5a73227d3ba0724cab076f621435ebaed8ed2c73bfaf7d32a90b0a249e1f";
    static final String BUDDY_HASH = "eb79b9876332010733a8e0d7ce4fe0377846059a9e28859029e2a0fb449f6cf2";
    private static AimTransform transformer;

    private Main() {}

    public static void main(String[] args) {
        Exposer.exposeClass(World.class, "SuQingViewpointAimEnhancementBridge");
    }

    public static final class World {
        private World() {}

        public static void leave() {
            AimControl.setPlayer(null);
        }

        public static synchronized boolean enter() {
            leave();
            try {
                IsoPlayer player = IsoPlayer.players[0];
                var mods = ZomboidFileSystem.instance.getModIDs();
                if (!singlePlayer() || player == null || !compatibleMods(mods)) return false;
                if (!GAME.equals(Core.getInstance().getGameAndBuildVersion())) {
                    throw new IllegalStateException("Requires game build " + GAME);
                }

                if (!"2.3.4".equals(ZombieBuddy.getVersion()) || !BUDDY_HASH.equals(hash(source(Loader.class)))) {
                    throw new IllegalStateException("Unsupported ZombieBuddy source");
                }
                var field = Loader.class.getDeclaredField("g_instrumentation");
                if (!field.trySetAccessible() || !(field.get(null) instanceof Instrumentation instrumentation)) {
                    throw new IllegalStateException("ZombieBuddy instrumentation unavailable");
                }
                if (hasLoadedAimReplacement(instrumentation)) {
                    throw new IllegalStateException("Another aim replacement is loaded in this process");
                }

                if (transformer == null) {
                    Class<?> gunplay = Class.forName("viewpoint.gunplay.Gunplay", false, Main.class.getClassLoader());
                    verifyViewpoint(gunplay);
                    transformer = AimTransform.install(instrumentation, gunplay);
                }
                if (!transformer.applied()) return false;
                AimControl.setPlayer(player);
                System.out.println(LOG + "0.1.0 active: 2x focus and minimum aim radius lock");
                return true;
            } catch (Exception | LinkageError failure) {
                System.err.println(LOG + "inactive: " + failure);
                return false;
            }
        }
    }

    static boolean singlePlayer() {
        return !GameClient.client && !GameServer.server;
    }

    static boolean compatibleMods(List<String> mods) {
        return mods.contains(ID) && mods.contains("Viewpoint")
            && !mods.contains("ShootToThrill") && !mods.contains("ShootToThrillMultiplayer")
            && !mods.contains("SuQingSTTRenderCompat_4222") && !mods.contains("ViewpointArsenal")
            && !mods.contains("ViewpointThirdPersonAimFix");
    }

    private static boolean hasLoadedAimReplacement(Instrumentation instrumentation) {
        for (Class<?> type : instrumentation.getAllLoadedClasses()) {
            String name = type.getName();
            if (name.startsWith("iseethem.") || name.startsWith("vptp.") || name.startsWith("viewpointcombined.")) return true;
        }
        return false;
    }

    private static void verifyViewpoint(Class<?> gunplay) throws Exception {
        var mod = ChooseGameInfo.getModDetails("Viewpoint");
        if (mod == null || !"0.1.7".equals(mod.getModVersion()) || mod.getVersionDir() == null) {
            throw new IllegalStateException("Requires Viewpoint 0.1.7");
        }
        Path location = source(gunplay);
        Path expected = Path.of(mod.getVersionDir(), "media/java/client/Viewpoint.jar");
        if (!Files.isSameFile(expected, location) || !VIEWPOINT_HASH.equals(hash(location))) {
            throw new IllegalStateException("Unsupported Viewpoint source");
        }
    }

    static Path source(Class<?> type) throws Exception {
        return Path.of(type.getProtectionDomain().getCodeSource().getLocation().toURI());
    }

    static String hash(Path path) throws Exception {
        try (var input = Files.newInputStream(path);
             var digest = new java.security.DigestInputStream(input, MessageDigest.getInstance("SHA-256"))) {
            digest.transferTo(java.io.OutputStream.nullOutputStream());
            return HexFormat.of().formatHex(digest.getMessageDigest().digest());
        }
    }
}
