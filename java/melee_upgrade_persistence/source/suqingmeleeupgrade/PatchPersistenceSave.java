package suqingmeleeupgrade;

import java.nio.ByteBuffer;
import me.zed_0xff.zombie_buddy.Patch;
import zombie.inventory.types.HandWeapon;

@Patch(className = "zombie.inventory.types.HandWeapon", methodName = "save", strictMatch = true)
public final class PatchPersistenceSave {
    private PatchPersistenceSave() {}

    @Patch.OnEnter
    public static void enter(@Patch.This HandWeapon weapon, @Patch.Argument(0) ByteBuffer output,
                             @Patch.Argument(1) boolean net) {
        WeaponPersistence.beforeSave(weapon);
    }
}
