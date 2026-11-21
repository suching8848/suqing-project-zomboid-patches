package suqingmeleeupgrade;

import java.io.InputStream;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.ZomboidFileSystem;
import zombie.core.random.Rand;
import zombie.core.random.RandLua;
import zombie.core.random.RandStandard;
import zombie.entity.ComponentFactory;
import zombie.entity.GameEntityFactory;
import zombie.entity.components.attributes.Attribute;
import zombie.entity.components.attributes.AttributeContainer;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.HandWeapon;
import zombie.iso.IsoWorld;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.WeaponCategory;

public final class NativeWearAudit {
    private static final int SAMPLES = 20_000;
    private static final ComponentFactory COMPONENTS = new ComponentFactory();
    private static int assertions;

    private enum Path { BODY, HEAD, DULL_BODY, DULL_HEAD, SHARP }

    private static HandWeapon newWeapon(int level, Path path) {
        Item script = new Item();
        HandWeapon weapon = new HandWeapon("SuQingMeleeUpgrade", "Wear probe", "WearProbe", script);
        weapon.setWeaponCategories(Set.of(WeaponCategory.SMALL_BLADE));
        weapon.setScriptItem(script);
        int maximum = level == 0 ? 10 : WeaponPersistence.bodyMaximum(10, level);
        weapon.setConditionMax(maximum);
        weapon.setConditionWhileLoading(maximum);
        weapon.setConditionLowerChance(0);
        if (path != Path.BODY) {
            AttributeContainer attributes = COMPONENTS.alloc(AttributeContainer.class);
            GameEntityFactory.AddComponent(weapon, attributes);
            if (path == Path.HEAD || path == Path.DULL_HEAD) {
                attributes.put(Attribute.HeadConditionMax, maximum);
                attributes.put(Attribute.HeadCondition, maximum);
            }
            if (path == Path.DULL_BODY || path == Path.DULL_HEAD || path == Path.SHARP) {
                attributes.put(Attribute.Sharpness, 0.0f);
            }
        }
        if (level != 0) {
            KahluaTable state = LuaManager.platform.newTable();
            state.rawset("version", 1.0);
            state.rawset("level", (double) level);
            state.rawset("fullType", weapon.getFullType());
            state.rawset("baseMaxCondition", 10.0);
            state.rawset("baseMinDamage", 0.5);
            state.rawset("baseMaxDamage", 1.5);
            if (weapon.hasHeadCondition()) state.rawset("baseHeadMax", 10.0);
            weapon.getModData().rawset(WeaponPersistence.STATE_KEY, state);
        }
        return weapon;
    }

    private static void check(boolean condition, String description) {
        assertions++;
        if (!condition) throw new AssertionError(description);
    }

    private static boolean run(HandWeapon weapon, Path path) {
        weapon.setConditionWhileLoading(weapon.getConditionMax());
        if (weapon.hasHeadCondition()) weapon.setHeadCondition(weapon.getHeadConditionMax());
        if (weapon.hasSharpness()) weapon.setSharpness(path == Path.SHARP ? 0.75f : 0.0f);
        return switch (path) {
            case BODY -> weapon.damageCheck(0, 1.0f, false, false, null);
            case HEAD -> weapon.headConditionCheck(0, 1.0f, false, false);
            case DULL_BODY, DULL_HEAD, SHARP -> weapon.sharpnessCheck(0, 1.0f, false, false);
        };
    }

    private static void sample(Path path, int level, double expected, int samples) {
        HandWeapon weapon = newWeapon(level, path);
        int returnedWear = 0;
        int bodyLosses = 0;
        int headLosses = 0;
        int sharpnessLosses = 0;
        for (int i = 0; i < samples; i++) {
            if (run(weapon, path)) returnedWear++;
            bodyLosses += weapon.getConditionMax() - weapon.getCondition();
            if (weapon.hasHeadCondition()) headLosses += weapon.getHeadConditionMax() - weapon.getHeadCondition();
            if (path == Path.SHARP && weapon.getSharpness() < 0.75f) sharpnessLosses++;
        }
        String label = path + " +" + level;
        int selectedLosses = switch (path) {
            case BODY, DULL_BODY -> bodyLosses;
            case HEAD, DULL_HEAD -> headLosses;
            case SHARP -> sharpnessLosses;
        };
        check(selectedLosses == bodyLosses + headLosses + sharpnessLosses,
            label + " only the intended field was changed");
        check(returnedWear == selectedLosses, label + " return agrees with actual wear");
        double observed = selectedLosses / (double) samples;
        check(expected == 1.0 ? observed == expected : Math.abs(observed - expected) < 0.025,
            label + " expected wear " + expected + ", observed " + observed);
        if (path == Path.SHARP) check(Math.abs(weapon.getSharpness() - (0.75f - 1.0f / weapon.getConditionMax())) < 0.0001f,
            label + " native sharpness decrement at the effective body maximum");
        System.out.println(label + " wear=" + selectedLosses + "/" + samples);
    }

    public static void main(String[] args) throws Exception {
        byte[] original;
        try (InputStream source = InventoryItem.class.getResourceAsStream("InventoryItem.class")) {
            original = source.readAllBytes();
        }
        byte[] transformed = WearPatch.rewrite(original);
        check(transformed.length > original.length, "exact wear checks are rewritten");
        boolean rejected = false;
        try {
            WearPatch.rewrite(transformed);
        } catch (IllegalStateException expected) {
            rejected = true;
        }
        check(rejected, "changed shape is rejected without installing a second set of gates");

        ZomboidFileSystem.instance.init();
        RandStandard.INSTANCE.init();
        RandLua.INSTANCE.init();
        LuaManager.init();
        check(WeaponPersistence.isSupported(), "audited game build");
        check(Rand.NextBool(0) && Rand.NextBool(1), "fixtures force native wear rolls to pass");
        for (Path path : Path.values()) sample(path, 2, 1.0, 16);
        check(WearPatch.install() && WearPatch.isActive(), "verified native retransformer installed");
        check(WearPatch.install(), "repeat installation is idempotent");
        for (Path path : Path.values()) {
            sample(path, 0, 1.0, 128);
            sample(path, 1, path == Path.SHARP ? 1.0 : 0.5, SAMPLES);
            sample(path, 2, path == Path.SHARP ? 1.0 : 0.25, SAMPLES);
            sample(path, 3, path == Path.SHARP ? 1.0 : 0.125, SAMPLES);
        }

        HandWeapon capped = newWeapon(3, Path.HEAD);
        KahluaTable cappedMarker = (KahluaTable) capped.getModData().rawget(WeaponPersistence.STATE_KEY);
        cappedMarker.rawset("baseMaxCondition", 100.0);
        cappedMarker.rawset("baseHeadMax", 150.0);
        capped.setConditionMax(WeaponPersistence.bodyMaximum(100, 3));
        capped.getAttributes().getAttribute(Attribute.HeadConditionMax).setValueFromScriptString("1000");
        check(capped.getConditionMax() == 127 && capped.getHeadConditionMax() == 1000
            && WeaponPersistence.validLevel(capped) == 3, "rank three wear applies at both native condition caps");

        HandWeapon malformed = newWeapon(2, Path.BODY);
        KahluaTable state = (KahluaTable) malformed.getModData().rawget(WeaponPersistence.STATE_KEY);
        state.rawset("fullType", "Other.Weapon");
        int malformedPasses = 0;
        for (int i = 0; i < 128; i++) if (run(malformed, Path.BODY)) malformedPasses++;
        check(malformedPasses == 128, "invalid upgrade data has no wear advantage");
        check(!WearPatch.permitWear(false, newWeapon(2, Path.BODY)), "failed native body/head roll remains failed");
        check(!WearPatch.permitSharpnessCheck(false, newWeapon(2, Path.SHARP)), "failed native sharpness roll remains failed");
        GameClient.client = true;
        sample(Path.BODY, 2, 1.0, 128);
        GameClient.client = false;
        GameServer.server = true;
        sample(Path.DULL_HEAD, 2, 1.0, 128);
        GameServer.server = false;
        check(IsoWorld.instance == null || IsoWorld.instance.getCell() == null, "no game world loaded");
        System.out.println("NATIVE_MELEE_WEAR assertions=" + assertions + " PASS");
    }
}
