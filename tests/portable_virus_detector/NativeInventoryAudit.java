import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.Lua.LuaManager;
import zombie.ZomboidFileSystem;
import zombie.core.random.RandLua;
import zombie.core.random.RandStandard;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.AlarmClockClothing;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoWorld;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;

public final class NativeInventoryAudit {
    private static int checks;

    private static void check(boolean condition, String label) {
        if (!condition) throw new AssertionError(label);
        checks++;
        System.out.println("PASS " + label);
    }

    private static Item template(Path path, String moduleName, String name) throws Exception {
        String source = Files.readString(path);
        var definition = Pattern.compile("(?m)^\\h*item\\h+" + Pattern.quote(name) + "\\h*\\R").matcher(source);
        if (!definition.find()) throw new IllegalArgumentException("Missing item " + name);
        int end = source.indexOf('}', definition.end());
        var module = new ScriptModule();
        module.name = moduleName;
        var item = new Item();
        item.setModule(module);
        item.Load(name, source.substring(definition.start(), end + 1)
            .replaceAll("(?m)^\\s*Researchablerecipes\\s*=.*$", ""));
        item.setDisplayName(name);
        return item;
    }

    private static void run(String code) throws Exception {
        var function = LuaCompiler.loadstring(code, "NativeInventoryAudit", LuaManager.env);
        var result = LuaManager.thread.pcall(function, new Object[0]);
        check(Boolean.TRUE.equals(result[0]), java.util.Arrays.toString(result));
    }

    public static void main(String[] args) throws Exception {
        Path game = Path.of(args[0]);
        Path itemScripts = game.resolve("media/scripts/generated/items");
        Path watchScript = itemScripts.resolve("alarmclockclothing.txt");
        ZomboidFileSystem.instance.setCacheDir(System.getProperty("user.home"));
        ZomboidFileSystem.instance.init();
        RandStandard.INSTANCE.init();
        RandLua.INSTANCE.init();
        LuaManager.init();
        LuaManager.thread.debugOwnerThread = Thread.currentThread();

        Item left = template(watchScript, "Base", "WristWatch_Left_DigitalBlack");
        Item right = template(watchScript, "Base", "WristWatch_Right_DigitalBlack");
        InventoryItem watch = left.InstanceItem(null);
        InventoryItem detector = template(Path.of(args[1]), "Gunpart", "HeartbeatSensorPlus").InstanceItem(null);
        InventoryItem screwdriver = template(itemScripts.resolve("weapon.txt"), "Base", "Screwdriver").InstanceItem(null);
        ItemContainer inventory = new ItemContainer();
        InventoryContainer bag = (InventoryContainer) template(itemScripts.resolve("container.txt"),
            "Base", "Bag_Schoolbag").InstanceItem(null);
        bag.setID(100);
        watch.setID(101);
        screwdriver.setID(102);
        detector.setID(103);
        inventory.AddItem(bag);
        inventory.AddItem(watch);
        inventory.AddItem(screwdriver);
        bag.getInventory().AddItem(detector);
        check(detector.getContainer() == bag.getInventory() && inventory.contains(detector, true),
            "fixtures place the MFS part in a carried bag");
        LuaManager.env.rawset("Inventory", inventory);
        LuaManager.env.rawset("Watch", watch);
        LuaManager.env.rawset("Detector", detector);
        LuaManager.env.rawset("Tool", screwdriver);
        var core = LuaCompiler.loadstring(Files.readString(Path.of(args[2])), "Core", LuaManager.env);
        Object[] coreResult = LuaManager.thread.pcall(core, new Object[0]);
        check(Boolean.TRUE.equals(coreResult[0]), "runtime module loads into native Lua");
        LuaManager.env.rawset("Core", coreResult[1]);
        run("""
            Character = { getInventory = function() return Inventory end }
            assert(Core.isWatch(Watch), 'digital wristwatch shape')
            assert(Detector:getContainer():contains(Detector), 'direct bag lookup from Lua')
            assert(Inventory:contains(Detector, true), 'recursive root lookup from Lua')
            assert(Core.isCarried(Character, Detector), 'Lua ownership check')
            local detector, tool = Core.findParts(Character)
            assert(detector == Detector and tool == Tool, 'find both exact supplies')
            assert(Core.install(Character, Watch, detector, tool))
            assert(Core.isInstalled(Watch))
            return 'native Lua installation'
            """);
        check(watch.getContainer() == inventory && screwdriver.getContainer() == inventory,
            "original watch and screwdriver remain in the native container");
        check(detector.getContainer() == null && !bag.getInventory().contains(detector),
            "native nested container removed exactly the detector");

        var alarm = (AlarmClockClothing) watch;
        alarm.setHour(16);
        alarm.setMinute(40);
        var data = ByteBuffer.allocate(8192);
        watch.save(data, false);
        data.flip();
        data.position(3);
        var reloaded = (AlarmClockClothing) left.InstanceItem(null);
        reloaded.load(data, IsoWorld.WorldVersion);
        check(!data.hasRemaining() && reloaded.getHour() == 16 && reloaded.getMinute() == 40,
            "native save round trip retains watch alarm fields");
        LuaManager.env.rawset("Reloaded", reloaded);
        run("assert(Core.isInstalled(Reloaded)); return 'installation survives native load'");

        InventoryItem changedWrist = right.InstanceItem(null);
        changedWrist.copyModData(reloaded.getModData());
        LuaManager.env.rawset("ChangedWrist", changedWrist);
        run("assert(Core.isInstalled(ChangedWrist)); return 'native clothing replacement mod-data copy'");
        System.out.println("NATIVE_PORTABLE_VIRUS_DETECTOR PASS " + checks);
    }
}
