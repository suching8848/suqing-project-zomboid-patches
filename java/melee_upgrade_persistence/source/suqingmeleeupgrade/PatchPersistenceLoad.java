package suqingmeleeupgrade;

import java.nio.ByteBuffer;
import me.zed_0xff.zombie_buddy.Patch;
import zombie.inventory.types.HandWeapon;

@Patch(className = "zombie.inventory.types.HandWeapon", methodName = "load", strictMatch = true)
public final class PatchPersistenceLoad {
    private PatchPersistenceLoad() {}

    @Patch.OnExit
    public static void exit(@Patch.This HandWeapon weapon, @Patch.Argument(0) ByteBuffer input,
                            @Patch.Argument(1) int worldVersion) {
        WeaponPersistence.afterLoad(weapon);
    }
}
