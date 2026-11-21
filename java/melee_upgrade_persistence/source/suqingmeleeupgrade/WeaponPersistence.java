package suqingmeleeupgrade;

import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.core.Core;
import zombie.inventory.types.HandWeapon;
import zombie.iso.IsoWorld;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.WeaponCategory;

public final class WeaponPersistence {
    public static final String STATE_KEY = "SuQingMeleeUpgrade";
    private static final String CONDITION_KEY = "bodyConditionAtSave";
    private static final String LOG = "[SuQingMeleeUpgrade] ";
    private static final int MAX_NATIVE_CONDITION_BYTE = Byte.MAX_VALUE;
    private static volatile boolean verifiedBridge;

    private WeaponPersistence() {}

    private static final class VerifiedBuild {
        private static final boolean SUPPORTED = verifyBuild();
    }

    public static boolean isSupported() {
        return !GameClient.client && !GameServer.server && VerifiedBuild.SUPPORTED;
    }

    public static int bodyMaximum(int base, int level) {
        if (base < 1 || base > MAX_NATIVE_CONDITION_BYTE || level < 1 || level > Upgrade.MAX_LEVEL) return 0;
        return Math.min(MAX_NATIVE_CONDITION_BYTE, base * Upgrade.multiplier(level));
    }

    public static int validLevel(HandWeapon weapon) {
        KahluaTable state = markedState(weapon);
        int level = level(weapon, state);
        if (level == 0 || weapon.getConditionMax() != bodyMaximum(integer(state.rawget("baseMaxCondition")), level)) {
            return 0;
        }
        return level;
    }

    public static void beforeSave(HandWeapon weapon) {
        if (!isSupported()) return;
        KahluaTable state = markedState(weapon);
        int level = level(weapon, state);
        if (level == 0) return;

        int maximum = bodyMaximum(integer(state.rawget("baseMaxCondition")), level);
        int condition = weapon.getCondition();
        if (weapon.getConditionMax() != maximum || condition < 0 || condition > maximum) {
            state.rawset(CONDITION_KEY, null);
            return;
        }
        state.rawset(CONDITION_KEY, Double.valueOf(condition));
    }

    public static void afterLoad(HandWeapon weapon) {
        if (!isSupported()) return;
        KahluaTable state = markedState(weapon);
        int level = level(weapon, state);
        if (level == 0) return;

        int maximum = bodyMaximum(integer(state.rawget("baseMaxCondition")), level);
        int condition = integer(state.rawget(CONDITION_KEY));
        int loadedMaximum = weapon.getConditionMax();
        int loadedCondition = weapon.getCondition();
        if (condition < 0 || condition > maximum || loadedMaximum < 1 || loadedCondition < 0) return;

        // B42.22.2 writes no current-condition byte at full condition. Otherwise load clamps
        // the byte against the template cap. Decline a snapshot inconsistent with that payload.
        int originalPayload = condition == maximum ? loadedMaximum : Math.min(condition, loadedMaximum);
        if (loadedCondition != originalPayload) return;
        weapon.setConditionMax(maximum);
        weapon.setConditionWhileLoading(condition);
    }

    public static boolean isReady() {
        return verifiedBridge && isSupported();
    }

    public static synchronized boolean verifyInstalledBridge() {
        if (isReady()) return true;
        if (!isSupported() || LuaManager.platform == null) return false;
        try {
            verifiedBridge = verifyRoundTrip(10, 1, 18)
                && verifyRoundTrip(40, 2, 125) && verifyRoundTrip(40, 2, MAX_NATIVE_CONDITION_BYTE)
                && verifyRoundTrip(26, 3, 119);
        } catch (IOException | RuntimeException | LinkageError failure) {
            System.err.println(LOG + "native persistence probe failed: " + failure);
        }
        return verifiedBridge;
    }

    private static boolean verifyRoundTrip(int base, int level, int condition) throws IOException {
        HandWeapon original = newProbe(base);
        float expectedWeight = level == Upgrade.MAX_LEVEL ? 1.0f : 2.0f;
        int maximum = bodyMaximum(base, level);
        original.setConditionMax(maximum);
        original.setConditionWhileLoading(condition);
        KahluaTable state = LuaManager.platform.newTable();
        state.rawset("version", (double) Upgrade.STATE_VERSION);
        state.rawset("level", (double) level);
        state.rawset("fullType", original.getFullType());
        state.rawset("baseMaxCondition", (double) base);
        state.rawset("baseMinDamage", 0.4);
        state.rawset("baseMaxDamage", 1.5);
        original.getModData().rawset(STATE_KEY, state);

        ByteBuffer data = ByteBuffer.allocate(1024);
        original.save(data, false);
        data.flip();
        data.position(3); // Registry ID and native item save marker precede InventoryItem.load.
        HandWeapon reloaded = newProbe(base);
        reloaded.load(data, IsoWorld.WorldVersion);
        return !data.hasRemaining() && reloaded.getConditionMax() == maximum
            && reloaded.getCondition() == condition && reloaded.getActualWeight() == expectedWeight;
    }

    private static HandWeapon newProbe(int base) {
        Item script = new Item();
        script.setConditionMax(base);
        script.setActualWeight(2.0f);
        HandWeapon weapon = new HandWeapon("SuQingMeleeUpgrade", "Persistence probe", "Probe", script);
        weapon.setWeaponCategories(Set.of(WeaponCategory.SMALL_BLADE));
        weapon.setScriptItem(script);
        weapon.setConditionMax(base);
        return weapon;
    }

    private static KahluaTable markedState(HandWeapon weapon) {
        if (!weapon.hasModData()) return null;
        return weapon.getModData().rawget(STATE_KEY) instanceof KahluaTable state ? state : null;
    }

    private static int level(HandWeapon weapon, KahluaTable state) {
        if (state == null || !weapon.isMelee() || weapon.isRanged()
            || weapon.isBareHands() || weapon.getPhysicsObject() != null && !weapon.getPhysicsObject().isEmpty()
            || integer(state.rawget("version")) != Upgrade.STATE_VERSION
            || !weapon.getFullType().equals(state.rawget("fullType"))) return 0;
        int level = integer(state.rawget("level"));
        if (bodyMaximum(integer(state.rawget("baseMaxCondition")), level) == 0) return 0;
        Object head = state.rawget("baseHeadMax");
        if (weapon.hasHeadCondition()) {
            if (integer(head) < 1) return 0;
        } else if (head != null) {
            return 0;
        }
        double min = finiteNumber(state.rawget("baseMinDamage"));
        double max = finiteNumber(state.rawget("baseMaxDamage"));
        return min >= 0 && max >= min && max <= Float.MAX_VALUE / Upgrade.multiplier(level) ? level : 0;
    }

    private static double finiteNumber(Object value) {
        if (!(value instanceof Number number)) return Double.NaN;
        double result = number.doubleValue();
        return Double.isFinite(result) ? result : Double.NaN;
    }

    private static int integer(Object value) {
        double number = finiteNumber(value);
        return number >= 0 && number <= Upgrade.MAX_HEAD_CONDITION && number == Math.floor(number) ? (int) number : -1;
    }

    private static boolean verifyBuild() {
        Core core = Core.getInstance();
        return "42.22.2".equals(core.getGameAndBuildVersion()) && "3d39148846".equals(core.getGitSha())
            && matches("zombie/inventory/types/HandWeapon.class",
                "db86fba1c10ba18c1100fdc54f982f1fb5e0d04dcc765680fa1489563b28ce85")
            && matches("zombie/inventory/InventoryItem.class",
                "b45d4438636509d992aaa7b7505ef8323cd898947efc27bf1f7e762951d6643d");
    }

    private static boolean matches(String name, String expected) {
        try (InputStream input = WeaponPersistence.class.getClassLoader().getResourceAsStream(name)) {
            if (input == null) return false;
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(input.readAllBytes());
            return expected.equals(HexFormat.of().formatHex(digest));
        } catch (IOException | NoSuchAlgorithmException error) {
            System.err.println(LOG + "class verification failed: " + name + " " + error);
            return false;
        }
    }
}
