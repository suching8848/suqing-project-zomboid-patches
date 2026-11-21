package suqingmeleeupgrade;

import java.util.ArrayList;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.entity.components.attributes.Attribute;
import zombie.entity.components.attributes.AttributeInstance;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.HandWeapon;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.scripting.objects.ItemTag;

public final class Upgrade {
    static final String STATE_KEY = "SuQingMeleeUpgrade";
    static final int STATE_VERSION = 1;
    private static final String LOG = "[SuQingMeleeUpgrade] ";
    private static final List<Cost> COST = List.of(
        new Cost("Base.Nails", 2),
        new Cost("Base.SmallSheetMetal", 1),
        new Cost("Base.RippedSheets", 1)
    );
    static final int MAX_LEVEL = 3;
    static final int MAX_HEAD_CONDITION = 1000;
    private static final float WEIGHT_MULTIPLIER = 0.5f;

    private Upgrade() {}

    public static boolean supports(InventoryItem item) {
        return item instanceof HandWeapon weapon && weapon.isMelee() && !weapon.isRanged()
            && !weapon.isBareHands() && blank(weapon.getPhysicsObject());
    }

    public static boolean isAvailable() {
        return !GameClient.client && !GameServer.server && Main.ready();
    }

    private static boolean blank(String value) {
        return value == null || value.isEmpty();
    }

    private static boolean close(float first, float second) {
        return Math.abs(first - second)
            <= 0.00001f * Math.max(1, Math.max(Math.abs(first), Math.abs(second)));
    }

    private static Stats stats(HandWeapon weapon) {
        int condition = weapon.getCondition();
        int conditionMax = weapon.getConditionMax();
        int headCondition = weapon.hasHeadCondition() ? weapon.getHeadCondition() : 0;
        int headMax = weapon.hasHeadCondition() ? weapon.getHeadConditionMax() : 0;
        float sharpness = weapon.hasSharpness() ? weapon.getSharpness() : -1;
        float minDamage = weapon.getMinDamage();
        float maxDamage = weapon.getMaxDamage();
        if (sharpness >= 0 && maxDamage > minDamage) {
            // getMaxDamage applies sharpness to the interval above minimum damage.
            maxDamage = minDamage + (maxDamage - minDamage) / weapon.getSharpnessMultiplier();
        }
        return new Stats(condition, conditionMax, headCondition, headMax, sharpness, minDamage, maxDamage,
            weapon.getActualWeight());
    }

    private static Base base(HandWeapon weapon, Stats current) {
        Object saved = weapon.hasModData() ? weapon.getModData().rawget(STATE_KEY) : null;
        if (saved == null) {
            return new Base(0, current.conditionMax, current.headMax, current.minDamage, current.maxDamage);
        }
        if (!(saved instanceof KahluaTable state)) {
            return null;
        }
        int level = WeaponPersistence.validLevel(weapon);
        if (level == 0) {
            return null;
        }

        int body = ((Number) state.rawget("baseMaxCondition")).intValue();
        Object headValue = state.rawget("baseHeadMax");
        int head = headValue instanceof Number value ? value.intValue() : 0;
        float minDamage = ((Number) state.rawget("baseMinDamage")).floatValue();
        float maxDamage = ((Number) state.rawget("baseMaxDamage")).floatValue();
        int multiplier = multiplier(level);
        int bodyMaximum = WeaponPersistence.bodyMaximum(body, level);
        if (current.conditionMax != bodyMaximum
            || current.headMax != headMaximum(weapon, head, bodyMaximum, multiplier)
            || !close(current.minDamage, minDamage * multiplier)
            || !close(current.maxDamage, maxDamage * multiplier)) {
            return null;
        }
        return new Base(level, body, head, minDamage, maxDamage);
    }

    static int multiplier(int level) {
        return 1 << level;
    }

    public static float adjustedWeight(HandWeapon weapon, float original) {
        return weapon.hasModData() && WeaponPersistence.isSupported()
            && WeaponPersistence.validLevel(weapon) == MAX_LEVEL ? original * WEIGHT_MULTIPLIER : original;
    }

    private static AttributeInstance explicitHeadCap(HandWeapon weapon) {
        var attributes = weapon.getAttributes();
        return attributes == null ? null : attributes.getAttribute(Attribute.HeadConditionMax);
    }

    private static int headMaximum(HandWeapon weapon, int base, int bodyMaximum, int multiplier) {
        if (base == 0) return 0;
        return explicitHeadCap(weapon) == null ? bodyMaximum
            : Math.min(MAX_HEAD_CONDITION, base * multiplier);
    }

    private static int scaleCondition(int condition, int oldMax, int newMax, float sharpness) {
        int scaled = (int) Math.round((double) condition * newMax / oldMax);
        // A single integer rounding step must not dull the weapon as it is upgraded.
        if (sharpness > scaled / (double) newMax + 1e-7) {
            scaled = (int) Math.ceil(sharpness * newMax - 1e-7);
        }
        return Math.min(newMax, scaled);
    }

    private static Assessment assess(HandWeapon weapon) {
        if (!supports(weapon)) {
            return Assessment.blocked("Unsupported");
        }
        Stats current = stats(weapon);
        if (weapon.isBroken() || current.condition < 1 || current.conditionMax < current.condition
            || (weapon.hasHeadCondition() && (current.headCondition < 1 || current.headMax < current.headCondition))) {
            return Assessment.blocked("Ineligible");
        }
        if (!Float.isFinite(current.minDamage) || !Float.isFinite(current.maxDamage)
            || current.minDamage < 0 || current.maxDamage <= 0 || current.maxDamage < current.minDamage) {
            return Assessment.blocked("Unsupported");
        }
        Base base = base(weapon, current);
        if (base == null) {
            return Assessment.blocked("Changed");
        }
        if (base.level == MAX_LEVEL) {
            return Assessment.blocked("MaxLevel");
        }
        int level = base.level + 1;
        int maxCondition = WeaponPersistence.bodyMaximum(base.conditionMax, level);
        int multiplier = multiplier(level);
        int maxHeadCondition = headMaximum(weapon, base.headMax, maxCondition, multiplier);
        float minDamage = base.minDamage * multiplier;
        float maxDamage = base.maxDamage * multiplier;
        boolean reduceWeight = level == MAX_LEVEL;
        if (maxCondition == 0 || !Float.isFinite(maxDamage) || (reduceWeight
            && (!Float.isFinite(current.actualWeight) || current.actualWeight < 0))) {
            return Assessment.blocked("Unsupported");
        }

        int condition = scaleCondition(current.condition, current.conditionMax, maxCondition,
            maxHeadCondition == 0 ? current.sharpness : -1);
        int headCondition = maxHeadCondition == 0 ? 0
            : scaleCondition(current.headCondition, current.headMax, maxHeadCondition, current.sharpness);
        float actualWeight = reduceWeight ? current.actualWeight * WEIGHT_MULTIPLIER : current.actualWeight;
        Stats after = new Stats(condition, maxCondition, headCondition, maxHeadCondition,
            current.sharpness, minDamage, maxDamage, actualWeight);
        return new Assessment(new Quote(weapon, base, current, after, level, multiplier), null);
    }

    public static Quote preview(HandWeapon weapon) {
        return assess(weapon).quote;
    }

    public static String blocker(HandWeapon weapon) {
        return assess(weapon).reason;
    }

    private static ItemContainer ownedContainer(ItemContainer inventory, InventoryItem item) {
        if (inventory == null || item == null) {
            return null;
        }
        ItemContainer container = item.getContainer();
        return container != null && container.contains(item) && inventory.contains(item, true)
            ? container : null;
    }

    private static boolean usableHammer(InventoryItem item, HandWeapon weapon) {
        return item != null && item != weapon && item.hasTag(ItemTag.HAMMER) && !item.isBroken();
    }

    private static SupplySearch findSupplies(ItemContainer inventory, HandWeapon weapon) {
        if (ownedContainer(inventory, weapon) == null) {
            return SupplySearch.blocked("InvalidMaterials");
        }

        InventoryItem hammer = null;
        for (InventoryItem item : inventory.getAllTagRecurse(ItemTag.HAMMER, new ArrayList<>())) {
            if (usableHammer(item, weapon) && ownedContainer(inventory, item) != null) {
                hammer = item;
                break;
            }
        }
        if (hammer == null) {
            return SupplySearch.blocked("MissingHammer");
        }

        Set<InventoryItem> used = Collections.newSetFromMap(new IdentityHashMap<>());
        used.add(weapon);
        used.add(hammer);
        List<InventoryItem> items = new ArrayList<>(4);
        for (Cost cost : COST) {
            int remaining = cost.count;
            for (InventoryItem item : inventory.getAllTypeRecurse(cost.fullType)) {
                if (cost.fullType.equals(item.getFullType()) && ownedContainer(inventory, item) != null
                    && used.add(item)) {
                    items.add(item);
                    if (--remaining == 0) {
                        break;
                    }
                }
            }
            if (remaining != 0) {
                return SupplySearch.blocked("MissingMaterials");
            }
        }
        return new SupplySearch(new Supplies(hammer, List.copyOf(items)), null);
    }

    public static Supplies supplies(IsoPlayer player, HandWeapon weapon) {
        return supplies(player == null ? null : player.getInventory(), weapon);
    }

    static Supplies supplies(ItemContainer inventory, HandWeapon weapon) {
        return findSupplies(inventory, weapon).supplies;
    }

    public static String supplyBlocker(IsoPlayer player, HandWeapon weapon) {
        return findSupplies(player == null ? null : player.getInventory(), weapon).reason;
    }

    private static String checkedDebits(ItemContainer inventory, HandWeapon weapon, Supplies supplies, List<Debit> debits) {
        if (ownedContainer(inventory, weapon) == null || supplies == null || supplies.items.size() != 4) {
            return "InvalidMaterials";
        }
        if (!usableHammer(supplies.hammer, weapon) || ownedContainer(inventory, supplies.hammer) == null) {
            return "MissingHammer";
        }

        Set<InventoryItem> used = Collections.newSetFromMap(new IdentityHashMap<>());
        used.add(weapon);
        used.add(supplies.hammer);
        int index = 0;
        for (Cost cost : COST) {
            for (int i = 0; i < cost.count; i++) {
                InventoryItem item = supplies.items.get(index++);
                ItemContainer container = ownedContainer(inventory, item);
                if (container == null || !cost.fullType.equals(item.getFullType()) || !used.add(item)) {
                    return "InvalidMaterials";
                }
                debits.add(new Debit(item, container));
            }
        }
        return null;
    }

    private static String checkQuote(HandWeapon weapon, Quote quote) {
        if (!isAvailable()) {
            return "Unavailable";
        }
        Assessment current = assess(weapon);
        if (current.quote == null) {
            return current.reason;
        }
        return current.quote.equals(quote) ? null : "Changed";
    }

    public static String check(IsoPlayer player, HandWeapon weapon, Quote quote, Supplies supplies) {
        String blocker = checkQuote(weapon, quote);
        return blocker == null ? checkedDebits(player == null ? null : player.getInventory(),
            weapon, supplies, new ArrayList<>(4)) : blocker;
    }

    private static void returnMaterials(List<Debit> debits, int attempted) {
        for (int index = attempted - 1; index >= 0; index--) {
            Debit debit = debits.get(index);
            try {
                if (debit.container.contains(debit.item)) {
                    continue;
                }
                ItemContainer actual = debit.item.getContainer();
                if (actual != null && actual != debit.container) {
                    throw new IllegalStateException("material changed containers");
                }
                debit.container.AddItem(debit.item);
                if (debit.item.getContainer() != debit.container || !debit.container.contains(debit.item)) {
                    throw new IllegalStateException("material did not return to its container");
                }
            } catch (RuntimeException failure) {
                System.err.println(LOG + "material rollback failed: " + failure);
            }
        }
    }

    public static String commit(IsoPlayer player, HandWeapon weapon, Quote quote, Supplies supplies) {
        return commit(player == null ? null : player.getInventory(), weapon, quote, supplies);
    }

    static String commit(ItemContainer inventory, HandWeapon weapon, Quote quote, Supplies supplies) {
        String blocker = checkQuote(weapon, quote);
        if (blocker != null) {
            return blocker;
        }
        List<Debit> debits = new ArrayList<>(4);
        blocker = checkedDebits(inventory, weapon, supplies, debits);
        if (blocker != null) {
            return blocker;
        }

        int attempted = 0;
        boolean committed = false;
        try {
            for (Debit debit : debits) {
                if (ownedContainer(inventory, debit.item) != debit.container) {
                    return "InvalidMaterials";
                }
                attempted++;
                debit.container.Remove(debit.item);
                if (debit.item.getContainer() != null || debit.container.contains(debit.item)) {
                    return "Failed";
                }
            }
            if (ownedContainer(inventory, weapon) == null) {
                return "InvalidMaterials";
            }
            if (!usableHammer(supplies.hammer, weapon) || ownedContainer(inventory, supplies.hammer) == null) {
                return "MissingHammer";
            }
            blocker = checkQuote(weapon, quote);
            if (blocker != null) {
                return blocker;
            }
            committed = apply(quote);
            return committed ? null : "Failed";
        } catch (RuntimeException failure) {
            System.err.println(LOG + "upgrade transaction failed: " + failure);
            return "Failed";
        } finally {
            if (!committed) {
                returnMaterials(debits, attempted);
            }
        }
    }

    static boolean apply(Quote quote) {
        HandWeapon weapon = quote.weapon;
        KahluaTable state = LuaManager.platform.newTable();
        state.rawset("version", (double) STATE_VERSION);
        state.rawset("level", (double) quote.level);
        state.rawset("fullType", weapon.getFullType());
        state.rawset("baseMaxCondition", (double) quote.base.conditionMax);
        if (quote.base.headMax > 0) {
            state.rawset("baseHeadMax", (double) quote.base.headMax);
        }
        state.rawset("baseMinDamage", (double) quote.base.minDamage);
        state.rawset("baseMaxDamage", (double) quote.base.maxDamage);
        KahluaTable modData = weapon.getModData();
        Object previousState = modData.rawget(STATE_KEY);
        try {
            writeStats(weapon, quote.after);
            modData.rawset(STATE_KEY, state);
            Stats actual = stats(weapon);
            if (!actual.matches(quote.after)) {
                throw new IllegalStateException("weapon did not accept the quoted statistics");
            }
            return true;
        } catch (RuntimeException failure) {
            try {
                modData.rawset(STATE_KEY, previousState);
                writeStats(weapon, quote.before);
            } catch (RuntimeException rollback) {
                failure.addSuppressed(rollback);
            }
            System.err.println(LOG + "upgrade rolled back: " + failure);
            return false;
        }
    }

    private static void writeStats(HandWeapon weapon, Stats stats) {
        weapon.setConditionMax(stats.conditionMax);
        weapon.setConditionWhileLoading(stats.condition);
        if (stats.headMax > 0) {
            AttributeInstance attribute = explicitHeadCap(weapon);
            if (attribute != null && !attribute.setValueFromScriptString(Integer.toString(stats.headMax))) {
                throw new IllegalStateException("could not set head condition maximum");
            }
            weapon.setHeadCondition(stats.headCondition);
        }
        if (stats.sharpness >= 0) {
            weapon.setSharpness(stats.sharpness);
        }
        weapon.setMinDamage(stats.minDamage);
        weapon.setMaxDamage(stats.maxDamage);
    }

    public record Quote(HandWeapon weapon, Base base, Stats before, Stats after, int level, int multiplier) {
        public int conditionMax() { return after.conditionMax; }
        public int headMax() { return after.headMax; }
        public int currentConditionMax() { return before.conditionMax; }
        public int currentHeadMax() { return before.headMax; }
        public float currentWeight() { return before.actualWeight; }
        public float weight() { return after.actualWeight; }
    }

    public record Supplies(InventoryItem hammer, List<InventoryItem> items) {}

    private record Base(int level, int conditionMax, int headMax, float minDamage, float maxDamage) {}
    private record Stats(int condition, int conditionMax, int headCondition, int headMax,
                         float sharpness, float minDamage, float maxDamage, float actualWeight) {
        private boolean matches(Stats other) {
            return condition == other.condition && conditionMax == other.conditionMax
                && headCondition == other.headCondition && headMax == other.headMax
                && close(sharpness, other.sharpness) && close(minDamage, other.minDamage)
                && close(maxDamage, other.maxDamage)
                && Float.compare(actualWeight, other.actualWeight) == 0;
        }
    }

    private record Cost(String fullType, int count) {}
    private record Debit(InventoryItem item, ItemContainer container) {}
    private record Assessment(Quote quote, String reason) {
        private static Assessment blocked(String reason) { return new Assessment(null, reason); }
    }

    private record SupplySearch(Supplies supplies, String reason) {
        private static SupplySearch blocked(String reason) { return new SupplySearch(null, reason); }
    }
}
