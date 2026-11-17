package suqingviewpointsimulation;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.function.LongPredicate;
import viewpoint.game.FixedTick;
import viewpoint.game.FrameCaps;
import viewpoint.game.TickClock;
import zombie.GameWindow;
import zombie.ZomboidFileSystem;
import zombie.characters.IsoPlayer;
import zombie.core.random.RandStandard;
import zombie.gameStates.GameStateMachine;
import zombie.gameStates.IngameState;
import zombie.network.GameClient;

public final class NativeRateAudit {
    private static final String ROW = "combobox|SuQingViewpointSimulation_4222|mode|";
    private static final LongPredicate NO_STEP = time -> false;
    private static int assertions;

    public static void main(String[] args) throws Exception {
        Path output = Path.of(args[0]);
        ZomboidFileSystem.instance.setCacheDir(output.resolve("Zomboid").toString());
        Path options = output.resolve("Zomboid/Lua/ModOptions.ini");
        Files.createDirectories(options.getParent());
        if (args.length == 4) {
            String scenario = args[3];
            if (scenario.equals("reject")) {
                Main.main(new String[0]);
                require(!Main.Options.available() && !Main.Options.apply(2), "different Viewpoint JAR fails closed");
            } else {
                Files.writeString(options, ROW + scenario + "\r\n");
                Main.main(new String[0]);
                require(Main.Options.available(), "persisted native choice initialized");
                require(Main.Options.currentMode() == Integer.parseInt(scenario), "persisted mode restored at boot");
                require(FixedTick.ON.get() == !scenario.equals("3"), "persisted fixed tick state applied at boot");
            }
            System.out.println("NATIVE_VIEWPOINT_SIMULATION PASS assertions=" + assertions);
            return;
        }
        require(Main.readMode(options) == Main.Mode.HZ_60, "missing preferences choose 60");
        Files.writeString(options, "combobox|Unrelated|mode|3\r\n" + ROW + "1\r\n");
        require(Main.readMode(options) == Main.Mode.HZ_30, "reads native 30 choice");
        Files.writeString(options, ROW + "3\r\n");
        require(Main.readMode(options) == Main.Mode.OFF, "reads native off choice");
        Files.writeString(options, ROW + "0\r\n");
        require(Main.readMode(options) == Main.Mode.HZ_60, "invalid preference uses 60");
        Files.delete(options);

        require(!Main.verifiedJar(output), "dir does not match the JAR pin");
        require(!Main.verifiedJar(Path.of(args[1])), "unrelated JAR does not match the pin");
        require(Main.verifiedJar(Path.of(args[2])), "verified upstream jar");

        RandStandard.INSTANCE.init();
        IngameState.instance = new IngameState();
        GameWindow.states.current = IngameState.instance;
        IsoPlayer.numPlayers = 1;
        setCap(240);
        require(!Main.Options.available(), "options unavailable before initializer");
        Main.main(new String[0]);
        require(Main.Options.available(), "entry binds native controls");
        require(Main.Options.currentMode() == 2 && FixedTick.ON.get(), "default mode is 60");
        Field rate = FixedTick.class.getDeclaredField("RATE");
        rate.setAccessible(true);
        Method get = rate.getType().getMethod("get");
        require((int) get.invoke(rate.get(null)) == 3, "verified native 60 index");

        Method follow = FixedTick.class.getDeclaredMethod("follow", long.class, boolean.class);
        follow.setAccessible(true);
        long now = 1_000_000_000L;
        require((boolean) follow.invoke(null, now, true), "native fixed simulation enters in 3D");
        require(FrameCaps.lockNow(240) == 60, "native game-thread override is 60");
        require(TickClock.class.isInstance(FixedTick.CLOCK), "native tick clock retained");

        require(Main.Options.apply(1) && Main.Options.currentMode() == 1, "live 30 selection");
        require((boolean) follow.invoke(null, now + 1, true), "native fixed simulation remains active");
        require(FrameCaps.lockNow(240) == 30, "native override changed to 30");
        require(Main.Options.apply(3) && Main.Options.currentMode() == 3, "live off selection");
        require(!(boolean) follow.invoke(null, now + 2, true), "native fixed simulation exits");
        require(!FixedTick.ON.get() && FrameCaps.lockNow(240) == 240, "off restores game cap");

        require(Main.Options.apply(2), "live 60 selection");
        require(!(boolean) follow.invoke(null, now + 3, false), "isometric predicate keeps normal cap");
        require(FrameCaps.lockNow(240) == 240, "isometric keeps normal cap");
        GameClient.client = true;
        require(!(boolean) follow.invoke(null, now + 4, true), "multiplayer predicate keeps normal cap");
        require(FrameCaps.lockNow(240) == 240, "multiplayer keeps normal cap");
        GameClient.client = false;
        IsoPlayer.numPlayers = 2;
        require(!(boolean) follow.invoke(null, now + 5, true), "split-screen predicate keeps normal cap");
        IsoPlayer.numPlayers = 1;
        require(!Main.Options.apply(2.5) && !Main.Options.apply(0) && !Main.Options.apply(Double.NaN),
                "invalid Lua selections rejected");
        require(Main.Options.currentMode() == 2, "invalid input preserves current selection");
        Main.main(new String[0]);
        require(Main.Options.currentMode() == 2, "initializer idempotent");
        System.out.println("NATIVE_VIEWPOINT_SIMULATION PASS assertions=" + assertions);
    }

    private static void setCap(int cap) throws Exception {
        Class<?> caps = Class.forName("viewpoint.game.FrameCaps$Caps");
        var constructor = caps.getDeclaredConstructor(int.class, int.class, boolean.class);
        constructor.setAccessible(true);
        var field = FrameCaps.class.getDeclaredField("caps");
        field.setAccessible(true);
        field.set(null, constructor.newInstance(cap, 60, true));
    }

    private static void require(boolean okay, String description) {
        if (!okay) {
            throw new AssertionError(description);
        }
        assertions++;
    }
}
