import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import me.zed_0xff.zombie_buddy.PatchEngine;
import me.zed_0xff.zombie_buddy.ZombieBuddy;
import net.bytebuddy.asm.Advice;
import suqinglunchboxweight.Compatibility;
import suqinglunchboxweight.PatchAttachedWeight;
import sun.misc.Unsafe;
import zombie.ZomboidFileSystem;
import zombie.ZomboidGlobals;
import zombie.Lua.LuaManager;
import zombie.characters.AttachedItems.AttachedItems;
import zombie.characters.AttachedItems.AttachedLocationGroup;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.WornItems.BodyLocationGroup;
import zombie.characters.WornItems.WornItems;
import zombie.core.random.RandLua;
import zombie.core.random.RandStandard;
import zombie.gameStates.ChooseGameInfo;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoWorld;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.scripting.objects.Item;

public final class NativeWeightAudit {
    private static final String TARGET = "SuQingFreshnessLunchbox.FreshnessLunchbox";
    private static final String[] SLOTS = {"BedrollBottom", "BedrollBottomBig", "BedrollBottomALICE"};
    private static final String[] LOCATIONS = {"Bedroll Bottom", "Bedroll Bottom Big", "Bedroll Bottom ALICE"};
    private static Unsafe unsafe;
    private static int assertions;

    private static final class CountingItems extends ArrayList<InventoryItem> {
        int reads;

        @Override
        public InventoryItem get(int index) {
            reads++;
            return super.get(index);
        }
    }

    private static void check(boolean condition, String description) {
        assertions++;
        if (!condition) throw new AssertionError(description);
    }

    private static void near(float actual, float expected, String description) {
        check(Math.abs(actual - expected) < 0.00002f,
            description + " expected=" + expected + " actual=" + actual);
    }

    private static void set(Object target, Class<?> owner, String name, Object value) throws Exception {
        Field field = owner.getDeclaredField(name);
        field.setAccessible(true);
        field.set(target, value);
    }

    private static void initialize(InventoryItem item, String fullType, float weight) throws Exception {
        String[] parts = fullType.split("\\.", 2);
        set(item, InventoryItem.class, "module", parts[0]);
        set(item, InventoryItem.class, "type", parts[1]);
        set(item, InventoryItem.class, "fullType", fullType);
        set(item, InventoryItem.class, "name", "Weight fixture");
        set(item, InventoryItem.class, "originalName", "Weight fixture");
        set(item, InventoryItem.class, "scriptItem", new Item());
        item.setActualWeight(weight);
        item.setCustomWeight(true);
        item.setAttachedSlot(-1);
    }

    private static InventoryContainer box(String type, ItemContainer owner, int reduction, float contents) throws Exception {
        InventoryContainer box = (InventoryContainer) unsafe.allocateInstance(InventoryContainer.class);
        initialize(box, type, 1.0f);
        ItemContainer inside = new ItemContainer();
        inside.containingItem = box;
        set(inside, ItemContainer.class, "items", new CountingItems());
        box.setItemContainer(inside);
        box.setWeightReduction(reduction);
        if (contents > 0) {
            Food food = (Food) unsafe.allocateInstance(Food.class);
            initialize(food, "Base.Apple", contents);
            food.setContainer(inside);
            inside.getItems().add(food);
        }
        box.setContainer(owner);
        return box;
    }

    private static void attach(IsoPlayer player, InventoryItem item, int slot) {
        player.getAttachedItems().remove(item);
        player.getAttachedItems().setItem(LOCATIONS[slot], item);
        item.setAttachedSlot(slot);
        item.setAttachedSlotType(SLOTS[slot]);
    }

    private static void verifyMod(Path root) throws Exception {
        ChooseGameInfo.Mod info = ChooseGameInfo.readModInfo(root.toString());
        check(info != null && info.isAvailableSelf(), "game accepts exact version and branch");
        check("SuQingLunchboxAttachedWeight_4222".equals(info.getId()), "stable package ID");
        check(info.getRequire().equals(List.of("SuQingFreshnessLunchbox", "ZombieBuddy")),
            "game parses the two required dependencies " + info.getRequire());
        Path branch = Path.of(info.getVersionDir());
        check(branch.equals(root.resolve("42")), "native selected 42 branch");
        Class<?> javaModInfo = Class.forName("me.zed_0xff.zombie_buddy.JavaModInfo");
        Method parse = javaModInfo.getDeclaredMethod("parse", Path.class);
        parse.setAccessible(true);
        check(parse.invoke(null, branch) != null, "ZombieBuddy reads the exact candidate");
        Path loadedJar = Path.of(PatchAttachedWeight.class.getProtectionDomain().getCodeSource().getLocation().toURI());
        check(loadedJar.equals(branch.resolve("media/java/client/SuQingLunchboxAttachedWeight.jar")),
            "class runs from the delivered JAR");
    }

    private static void weave() {
        check("2.3.4".equals(ZombieBuddy.getVersion()), "reviewed ZombieBuddy version");
        var loader = PatchAttachedWeight.class.getClassLoader();
        check(PatchEngine.collectPatches("suqinglunchboxweight", loader).equals(List.of(PatchAttachedWeight.class)),
            "ZombieBuddy discovers exactly one patch class");
        PatchEngine.applyPatches("suqinglunchboxweight", loader);
        check(PatchAttachedWeight.class.getDeclaredMethods()[0].isAnnotationPresent(Advice.OnMethodExit.class),
            "actual ZombieBuddy converter supplies exit advice");
    }

    public static void main(String[] args) throws Exception {
        Field access = Unsafe.class.getDeclaredField("theUnsafe");
        access.setAccessible(true);
        unsafe = (Unsafe) access.get(null);
        ZomboidFileSystem.instance.init();
        RandStandard.INSTANCE.init();
        RandLua.INSTANCE.init();
        LuaManager.init();
        verifyMod(Path.of(args[0]));
        ZomboidGlobals.equippedOrWornEncumbranceMultiplier = 0.3;

        IsoPlayer player = (IsoPlayer) unsafe.allocateInstance(IsoPlayer.class);
        ItemContainer carried = new ItemContainer();
        player.setInventory(carried);
        set(player, IsoGameCharacter.class, "wornItems", new WornItems(new BodyLocationGroup("weight fixture")));
        AttachedLocationGroup attachments = new AttachedLocationGroup("weight fixture");
        for (String location : LOCATIONS) attachments.getOrCreateLocation(location);
        player.setAttachedItems(new AttachedItems(attachments));

        InventoryContainer lunchbox = box(TARGET, carried, 99, 13.7f);
        CountingItems food = (CountingItems) lunchbox.getInventory().getItems();
        carried.getItems().add(lunchbox);
        attach(player, lunchbox, 0);
        near(lunchbox.getUnequippedWeight(), 14.7f, "screenshot full weight");
        near(lunchbox.getHotbarEquippedWeight(), 10.29f, "screenshot stock attached weight");
        near(player.getInventoryWeight(), 10.29f, "stock role carry weight uses the same method");

        check(Compatibility.isSupported(), "reviewed B42.22.2 class resources");
        weave();
        for (int index = 0; index < SLOTS.length; index++) {
            attach(player, lunchbox, index);
            food.reads = 0;
            near(lunchbox.getHotbarEquippedWeight(), 0.837f, "native attached weight " + SLOTS[index]);
            check(food.reads == 1, "one native contents read");
            near(player.getInventoryWeight(), 0.837f, "actual actor encumbrance " + SLOTS[index]);
        }
        int[] reductions = {0, 50, 90, 93, 95, 97, 99, 100};
        for (int reduction : reductions) {
            lunchbox.setWeightReduction(reduction);
            near(player.getInventoryWeight(), 0.7f + 13.7f * (100 - reduction) / 100,
                "live reduction " + reduction);
        }
        lunchbox.setWeightReduction(99);
        near(lunchbox.getUnequippedWeight(), 14.7f, "raw weight and container capacity input");
        near(lunchbox.getEquippedWeight(), 0.437f, "held weight");
        set(player, IsoGameCharacter.class, "primaryHandItem", lunchbox);
        near(player.getInventoryWeight(), 0.437f, "actual character weight while holding");
        set(player, IsoGameCharacter.class, "primaryHandItem", null);
        GameClient.client = true;
        near(lunchbox.getHotbarEquippedWeight(), 10.29f, "multiplayer client retains native value");
        GameClient.client = false;
        GameServer.server = true;
        near(lunchbox.getHotbarEquippedWeight(), 10.29f, "server retains native value");
        GameServer.server = false;
        player.getAttachedItems().remove(lunchbox);
        near(lunchbox.getHotbarEquippedWeight(), 10.29f, "stale slot metadata cannot grant discount");
        lunchbox.setAttachedSlot(-1);
        near(player.getInventoryWeight(), 14.7f, "detached carry weight");
        attach(player, lunchbox, 0);
        lunchbox.setContainer(new ItemContainer());
        near(lunchbox.getHotbarEquippedWeight(), 10.29f, "container moved away from character");

        InventoryContainer ordinary = box("Base.Lunchbox", carried, 99, 13.7f);
        attach(player, ordinary, 0);
        near(ordinary.getHotbarEquippedWeight(), 10.29f, "unrelated container");
        InventoryContainer empty = box(TARGET, carried, 99, 0);
        attach(player, empty, 0);
        near(empty.getHotbarEquippedWeight(), 0.7f, "empty attached box");
        check(IsoWorld.instance == null || IsoWorld.instance.getCell() == null, "no world cell loaded");
        System.out.println("NATIVE_LUNCHBOX_WEIGHT assertions=" + assertions + " PASS");
    }
}
