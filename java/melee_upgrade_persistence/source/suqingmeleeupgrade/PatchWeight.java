package suqingmeleeupgrade;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.inventory.types.HandWeapon;

@Patch(className = "zombie.inventory.types.HandWeapon", methodName = "getActualWeight", strictMatch = true)
public final class PatchWeight {
    private PatchWeight() {}

    @Patch.OnExit
    public static void exit(@Patch.This HandWeapon weapon, @Patch.Return(readOnly = false) float result) {
        result = Upgrade.adjustedWeight(weapon, result);
    }
}
