package suqingviewpointsimulation;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Field;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.util.HexFormat;
import me.zed_0xff.zombie_buddy.Exposer;
import viewpoint.platform.LiveSettings.Choice;
import viewpoint.platform.LiveSettings.Toggle;
import zombie.ZomboidFileSystem;
import zombie.core.Core;

public final class Main {
    private static final String LOG = "[SuQingViewpointSimulation] ";
    private static final String BUILD = "42.22.2";
    private static final String VIEWPOINT_SHA256 =
        "8d0d5a73227d3ba0724cab076f621435ebaed8ed2c73bfaf7d32a90b0a249e1f";
    private static final String OPTION_ROW = "combobox|SuQingViewpointSimulation_4222|mode|";
    private static final Mode DEFAULT_MODE = Mode.HZ_60;
    private static volatile Controller controller;
    private static volatile Mode current = DEFAULT_MODE;

    private Main() {}

    public static synchronized void main(String[] args) {
        if (controller != null) {
            return;
        }

        try {
            if (!BUILD.equals(Core.getInstance().getGameAndBuildVersion())) {
                throw new IllegalStateException("requires Project Zomboid " + BUILD);
            }
            Controller matched = Controller.open();
            Exposer.exposeClass(Options.class, "SuQingViewpointSimulationBridge");
            current = readMode(Path.of(ZomboidFileSystem.instance.getCacheDir(), "Lua", "ModOptions.ini"));
            matched.apply(current);
            controller = matched;
            System.out.println(LOG + "0.1.0, mode " + current.label);
        } catch (Exception | LinkageError failure) {
            System.err.println(LOG + "inactive: " + failure);
        }
    }

    static Mode readMode(Path file) {
        if (Files.notExists(file)) {
            return DEFAULT_MODE;
        }
        Mode mode = DEFAULT_MODE;
        try (BufferedReader reader = Files.newBufferedReader(file)) {
            for (String line; (line = reader.readLine()) != null;) {
                if (!line.startsWith(OPTION_ROW)) {
                    continue;
                }
                Mode saved = Mode.read(line.substring(OPTION_ROW.length()));
                mode = saved == null ? DEFAULT_MODE : saved;
            }
        } catch (IOException failure) {
            System.err.println(LOG + "unable to read ModOptions.ini; using 60 Hz: " + failure);
            return DEFAULT_MODE;
        }
        return mode;
    }

    public static final class Options {
        private Options() {}

        public static boolean available() {
            return controller != null;
        }

        public static int currentMode() {
            return current.option;
        }

        public static boolean apply(double option) {
            synchronized (Main.class) {
                if (option != 1 && option != 2 && option != 3) {
                    return false;
                }
                return change(Mode.values()[(int) option - 1]);
            }
        }

        private static boolean change(Mode mode) {
            Controller active = controller;
            if (active == null) {
                return false;
            }
            if (current != mode) {
                active.apply(mode);
                current = mode;
                System.out.println(LOG + "mode " + mode.label);
            }
            return true;
        }
    }

    enum Mode {
        HZ_30(1, 0, "30 Hz"),
        HZ_60(2, 3, "60 Hz"),
        OFF(3, -1, "off");

        final int option;
        final int rateIndex;
        final String label;

        Mode(int option, int rateIndex, String label) {
            this.option = option;
            this.rateIndex = rateIndex;
            this.label = label;
        }

        static Mode read(String saved) {
            return switch (saved.trim()) {
                case "1" -> HZ_30;
                case "2" -> HZ_60;
                case "3" -> OFF;
                default -> null;
            };
        }
    }

    record Controller(Toggle fixed, Choice rate) {
        static Controller open() throws Exception {
            Class<?> type = Class.forName("viewpoint.game.FixedTick", false, Main.class.getClassLoader());
            var source = type.getProtectionDomain().getCodeSource();
            if (source == null) {
                throw new IllegalStateException("Viewpoint origin could not be verified");
            }
            URI location = source.getLocation().toURI();
            if (!"file".equals(location.getScheme()) || !verifiedJar(Path.of(location))) {
                throw new IllegalStateException("requires the verified Viewpoint 0.1.7 Workshop hotfix");
            }
            Field rate = type.getDeclaredField("RATE");
            if (!rate.trySetAccessible()) {
                throw new IllegalStateException("Viewpoint tick-rate field is inaccessible");
            }
            return new Controller((Toggle) type.getField("ON").get(null), (Choice) rate.get(null));
        }

        void apply(Mode mode) {
            if (mode == Mode.OFF) {
                fixed.set(false);
                return;
            }
            rate.set(mode.rateIndex);
            fixed.set(true);
        }
    }

    static boolean verifiedJar(Path path) throws Exception {
        if (!Files.isRegularFile(path)) {
            return false;
        }
        var hash = MessageDigest.getInstance("SHA-256");
        try (InputStream bytes = Files.newInputStream(path);
             var streamed = new DigestInputStream(bytes, hash)) {
            streamed.transferTo(OutputStream.nullOutputStream());
        }
        return VIEWPOINT_SHA256.equals(HexFormat.of().formatHex(hash.digest()));
    }
}
