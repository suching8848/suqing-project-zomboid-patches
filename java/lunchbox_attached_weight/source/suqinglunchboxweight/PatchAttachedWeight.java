package suqinglunchboxweight;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.inventory.InventoryItem;

@Patch(className = "zombie.inventory.InventoryItem", methodName = "getHotbarEquippedWeight", strictMatch = true)
public final class PatchAttachedWeight {
    private PatchAttachedWeight() {}

    @Patch.OnExit
    public static void exit(@Patch.This InventoryItem item, @Patch.Return(readOnly = false) float result) {
        result = AttachedWeight.adjust(item, result);
    }
}
