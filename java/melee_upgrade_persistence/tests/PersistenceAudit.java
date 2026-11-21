import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.lang.reflect.Field;
import java.util.Set;
import me.zed_0xff.zombie_buddy.PatchEngine;
import me.zed_0xff.zombie_buddy.ZombieBuddy;
import se.krka.kahlua.vm.KahluaTable;
import suqingmeleeupgrade.PatchPersistenceLoad;
import suqingmeleeupgrade.PatchPersistenceSave;
import suqingmeleeupgrade.PatchWeight;
import suqingmeleeupgrade.WeaponPersistence;
import suqingmeleeupgrade.WearPatch;
import zombie.Lua.LuaManager;
import zombie.ZomboidFileSystem;
import zombie.core.random.RandLua;
import zombie.core.random.RandStandard;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.ItemContainer;
import zombie.iso.IsoWorld;
import zombie.network.GameClient;
import zombie.scripting.ScriptBucketCollection;
import zombie.scripting.ScriptManager;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;
import zombie.world.DictionaryData;
import zombie.world.DictionaryInfo;
import zombie.world.ItemInfo;
import zombie.world.WorldDictionary;

public final class PersistenceAudit {
    private static int assertions;

    private static void check(boolean success, String label) {
        if (!success) throw new AssertionError(label);
        assertions++;
        System.out.println("PASS " + label);
    }

    private static Item template(String weaponName, Path game) throws Exception {
        String scripts = Files.readString(game.resolve("media/scripts/generated/items/weapon.txt"));
        int start = scripts.indexOf("    item " + weaponName + System.lineSeparator());
        if (start < 0) start = scripts.indexOf("    item " + weaponName + "\n");
        if (start < 0) start = scripts.indexOf("    item " + weaponName + "\r\n");
        int end = scripts.indexOf("\n    }", start) + "\n    }".length();
        var module = new ScriptModule();
        module.name = "Base";
        var item = new Item();
        item.setModule(module);
        item.Load(weaponName, scripts.substring(start, end).replaceAll("(?m)^\\s*Researchablerecipes\\s*=.*$", ""));
        item.setDisplayName(weaponName);
        return item;
    }

    private static HandWeapon create(Item template) {
        return (HandWeapon) template.InstanceItem(null);
    }

    private static KahluaTable mark(HandWeapon weapon, int level) {
        var state = LuaManager.platform.newTable();
        state.rawset("version", 1.0);
        state.rawset("level", (double) level);
        state.rawset("fullType", weapon.getFullType());
        state.rawset("baseMaxCondition", (double) weapon.getConditionMax());
        state.rawset("baseMinDamage", (double) weapon.getScriptItem().getMinDamage());
        state.rawset("baseMaxDamage", (double) weapon.getScriptItem().getMaxDamage());
        if (weapon.hasHeadCondition()) state.rawset("baseHeadMax", (double) weapon.getHeadConditionMax());
        weapon.getModData().rawset(WeaponPersistence.STATE_KEY, state);
        return state;
    }

    private static HandWeapon roundTrip(HandWeapon original) throws Exception {
        var buffer = ByteBuffer.allocate(8192);
        original.save(buffer, false);
        buffer.flip();
        buffer.position(3);
        HandWeapon restored = create(original.getScriptItem());
        restored.load(buffer, IsoWorld.WorldVersion);
        check(!buffer.hasRemaining(), original.getFullType() + " native serialized payload fully consumed");
        return restored;
    }

    private static void condition(HandWeapon item, int value, int maximum, String label) {
        check(item.getCondition() == value && item.getConditionMax() == maximum,
            label + ": " + item.getCondition() + "/" + item.getConditionMax());
    }

    private static void near(double actual, double expected, String label) {
        check(Math.abs(actual - expected) < 0.00002, label + ": " + actual);
    }

    private static Field field(Class<?> owner, String name) throws ReflectiveOperationException {
        Field field = owner.getDeclaredField(name);
        field.setAccessible(true);
        return field;
    }

    private static final class FixtureDictionary extends DictionaryData {
        void register(Item item, short id) throws ReflectiveOperationException {
            var info = new ItemInfo();
            field(DictionaryInfo.class, "isLoaded").setBoolean(info, true);
            field(DictionaryInfo.class, "fullType").set(info, item.getFullName());
            field(DictionaryInfo.class, "registryId").setShort(info, id);
            item.setRegistry_id(id);
            itemIdToInfoMap.put(id, info);
            itemTypeToInfoMap.put(item.getFullName(), info);
        }
    }

    @SuppressWarnings("unchecked")
    private static void containerAudit(Item knifeTemplate) throws Exception {
        var dictionary = new FixtureDictionary();
        dictionary.register(knifeTemplate, (short) 11);
        field(WorldDictionary.class, "data").set(null, dictionary);
        var scriptedItems = (ScriptBucketCollection<Item>) field(ScriptManager.class, "items").get(ScriptManager.instance);
        scriptedItems.getFullTypeToScriptMap().put(knifeTemplate.getFullName(), knifeTemplate);

        var container = new ItemContainer();
        for (int id = 100; id < 103; id++) {
            HandWeapon knife = create(knifeTemplate);
            mark(knife, 2);
            knife.setConditionMax(127);
            knife.setConditionWhileLoading(id == 102 ? 126 : 125);
            knife.setID(id);
            container.getItems().add(knife);
            knife.setContainer(container);
        }
        var bytes = ByteBuffer.allocate(16384);
        container.save(bytes);
        bytes.flip();
        var reloaded = new ItemContainer();
        reloaded.load(bytes, IsoWorld.WorldVersion);
        check(!bytes.hasRemaining() && reloaded.getItems().size() == 3, "compressed container streaming preserves all items");
        for (var item : reloaded.getItems()) {
            int expected = item.getID() == 102 ? 126 : 125;
            condition((HandWeapon) item, expected, 127, "streamed item retains its own durability for ID " + item.getID());
        }
        check(reloaded.getItems().stream().map(item -> item.getID()).collect(java.util.stream.Collectors.toSet())
            .equals(Set.of(100, 101, 102)), "streamed identical weapons keep distinct item IDs");
    }

    private static void cappedCondition(Item knifeTemplate, int base, int condition) throws Exception {
        knifeTemplate.setConditionMax(base);
        HandWeapon knife = create(knifeTemplate);
        mark(knife, 2);
        int cap = WeaponPersistence.bodyMaximum(base, 2);
        knife.setConditionMax(cap);
        knife.setConditionWhileLoading(condition);
        var buffer = ByteBuffer.allocate(8192);
        knife.save(buffer, false);
        buffer.flip();
        int header = Byte.toUnsignedInt(buffer.get(7));
        if (condition < cap) {
            int offset = (header & 1) != 0 ? 12 : 8;
            check((header & 4) != 0 && buffer.get(offset) == condition,
                "capped condition uses the native signed-byte payload for " + condition + "/" + cap);
        } else {
            check((header & 4) == 0, "native full-condition byte remains omitted for " + condition + "/" + cap);
        }
        condition(roundTrip(knife), condition, cap, "full native capped round trip");
    }

    public static void main(String[] args) throws Exception {
        ZomboidFileSystem.instance.setCacheDir(System.getProperty("user.home"));
        ZomboidFileSystem.instance.init();
        RandStandard.INSTANCE.init();
        RandLua.INSTANCE.init();
        LuaManager.init();
        check("2.3.4".equals(ZombieBuddy.getVersion()), "reviewed ZombieBuddy 2.3.4");
        check(WeaponPersistence.isSupported(), "exact game version, git revision and native class hashes");
        var knifeTemplate = template("HuntingKnife", Path.of(args[0]));
        HandWeapon knife = create(knifeTemplate);
        condition(knife, 10, 10, "unmodified native item starts with original cap");
        var state = mark(knife, 1);
        knife.setConditionMax(20);
        knife.setConditionWhileLoading(18);
        condition(roundTrip(knife), 10, 10, "unpatched baseline clamps 18/20 to 10/10");
        check(!WeaponPersistence.verifyInstalledBridge(), "readiness probe fails closed without loader transform");

        var loader = WeaponPersistence.class.getClassLoader();
        if (args.length == 2) {
            Class<?> peer = Class.forName("suqinglunchboxweight.PatchAttachedWeight", false, loader);
            check(Path.of(peer.getProtectionDomain().getCodeSource().getLocation().toURI()).equals(Path.of(args[1])),
                "current lunchbox InventoryItem advice loaded from the provided JAR");
            PatchEngine.applyPatches("suqinglunchboxweight", loader);
        }
        check(Set.copyOf(PatchEngine.collectPatches("suqingmeleeupgrade", loader))
            .equals(Set.of(PatchPersistenceSave.class, PatchPersistenceLoad.class, PatchWeight.class)),
            "persistence and weight patches discovered");
        PatchEngine.applyPatches("suqingmeleeupgrade", loader);
        check(WeaponPersistence.verifyInstalledBridge() && WeaponPersistence.isReady(),
            "actual patched +1, +2 and +3 condition and weight probes");
        check(WearPatch.install() && WearPatch.isActive(), "native InventoryItem transformer active");
        check(WeaponPersistence.validLevel(knife) == 1, "valid level read through actual instance modData");
        knife.setMinDamage(1.2f);
        knife.setMaxDamage(2.4f);
        knife.setSharpness(0.4f);
        HandWeapon restored = roundTrip(knife);
        condition(restored, 18, 20, "damaged enhanced item keeps actual condition and bonus cap");
        near(restored.getSharpness(), 0.4, "native sharpness value survives bridge");
        near(restored.getMinDamage(), knife.getMinDamage(), "native minimum damage unchanged");
        near(restored.getMaxDamage(), knife.getMaxDamage(), "native maximum damage unchanged");
        check(Double.valueOf(18).equals(state.rawget("bodyConditionAtSave")), "actual condition captured inside save path");

        knife.setConditionWhileLoading(20);
        condition(roundTrip(knife), 20, 20, "full bonus condition survives omitted native condition byte");
        knife.setConditionWhileLoading(6);
        condition(roundTrip(knife), 6, 20, "low condition survives exactly");
        knife.setConditionWhileLoading(0);
        restored = roundTrip(knife);
        condition(restored, 0, 20, "broken bonus item remains broken");
        check(restored.isBroken(), "original broken flag maintained");

        HandWeapon plain = create(knifeTemplate);
        plain.setConditionWhileLoading(9);
        plain.getModData().rawset("UnrelatedFixture", "original");
        restored = roundTrip(plain);
        condition(restored, 9, 10, "unmarked item remains unchanged through native round trip");
        check(plain.getModData().rawget(WeaponPersistence.STATE_KEY) == null
                && restored.getModData().rawget(WeaponPersistence.STATE_KEY) == null
                && "original".equals(restored.getModData().rawget("UnrelatedFixture")),
            "unmarked item's existing native data is left alone and no upgrade marker added");
        knife.setConditionWhileLoading(18);
        state.rawset("version", 9.0);
        condition(roundTrip(knife), 10, 10, "unknown schema ignores snapshot");
        state.rawset("version", 1.0);
        state.rawset("fullType", "Base.Crowbar");
        condition(roundTrip(knife), 10, 10, "wrong full type ignores snapshot");
        state.rawset("fullType", knife.getFullType());
        state.rawset("level", 2.5);
        condition(roundTrip(knife), 10, 10, "fractional level ignores snapshot");
        state.rawset("level", 1.0);
        state.rawset("baseMaxDamage", Double.NaN);
        condition(roundTrip(knife), 10, 10, "nonfinite base damage ignores snapshot");
        state.rawset("baseMaxDamage", 1.5);
        knife.setConditionMax(22);
        condition(roundTrip(knife), 10, 10, "mismatched current cap cannot resurrect older snapshot");
        check(state.rawget("bodyConditionAtSave") == null, "stale snapshot removed on mismatched cap");

        HandWeapon axe = create(template("Axe", Path.of(args[0])));
        mark(axe, 1);
        int baseCap = axe.getConditionMax();
        int cap = WeaponPersistence.bodyMaximum(baseCap, 1);
        check(baseCap == 13 && cap == 26, "level one doubles the native axe cap");
        axe.setConditionMax(cap);
        axe.setConditionWhileLoading(19);
        var head = zombie.entity.components.attributes.Attribute.HeadConditionMax;
        axe.getAttributes().put(head, 26);
        axe.setHeadCondition(17);
        restored = roundTrip(axe);
        condition(restored, 19, 26, "axe body stays independent of native head");
        check(restored.getHeadCondition() == 17 && restored.getHeadConditionMax() == 26,
            "native independent head condition and cap retained");
        check(WeaponPersistence.bodyMaximum(31, 2) == 124 && WeaponPersistence.bodyMaximum(32, 2) == 127,
            "cap saturates at the native signed-byte boundary");
        check(WeaponPersistence.bodyMaximum(70, 1) == 127 && WeaponPersistence.bodyMaximum(127, 2) == 127
                && WeaponPersistence.bodyMaximum(128, 2) == 0,
            "valid high native bases saturate, out-of-range native base is ineligible");
        cappedCondition(knifeTemplate, 32, 125);
        cappedCondition(knifeTemplate, 32, 127);
        cappedCondition(knifeTemplate, 70, 120);
        cappedCondition(knifeTemplate, 110, 126);
        cappedCondition(knifeTemplate, 110, 127);
        containerAudit(knifeTemplate);

        GameClient.client = true;
        try {
            check(!WeaponPersistence.isReady(), "multiplayer client disables persistence entry point");
            condition(roundTrip(axe), 13, 13, "multiplayer leaves native cap behavior unchanged");
        } finally {
            GameClient.client = false;
        }
        System.out.println("NATIVE_MELEE_PERSISTENCE assertions=" + assertions + " PASS");
    }
}
