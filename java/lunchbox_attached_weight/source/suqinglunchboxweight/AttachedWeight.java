package suqinglunchboxweight;

import zombie.ZomboidGlobals;
import zombie.characters.IsoGameCharacter;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.InventoryContainer;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.scripting.objects.ItemTag;

public final class AttachedWeight {
    private static final String TYPE = "SuQingFreshnessLunchbox.FreshnessLunchbox";

    private AttachedWeight() {}

    public static float adjust(InventoryItem item, float original) {
        if (!(item instanceof InventoryContainer box) || !TYPE.equals(box.getFullType())
            || box.getAttachedSlot() < 0 || GameClient.client || GameServer.server
            || !Compatibility.isSupported()) return original;

        ItemContainer owner = box.getContainer();
        if (owner == null || !(owner.getParent() instanceof IsoGameCharacter character)
            || character.getInventory() != owner || character.isEquipped(box)
            || character.getAttachedItems() == null) return original;

        String location = character.getAttachedItems().getLocation(box);
        String slot = box.getAttachedSlotType();
        boolean bottom = "BedrollBottom".equals(slot) && "Bedroll Bottom".equals(location)
            || "BedrollBottomBig".equals(slot) && "Bedroll Bottom Big".equals(location)
            || "BedrollBottomALICE".equals(slot) && "Bedroll Bottom ALICE".equals(location);
        if (!bottom) return original;

        float multiplier = box.hasTag(ItemTag.LIGHT_WHEN_ATTACHED)
            ? (float) ZomboidGlobals.equippedOrWornEncumbranceMultiplier : 0.7f;
        float shell = box.getActualWeight();
        if (!Float.isFinite(original) || !Float.isFinite(shell) || shell < 0
            || !Float.isFinite(multiplier) || multiplier <= 0) return original;

        // The reviewed native method has already summed the contents once.
        // Recover that sum from its result instead of traversing the food again.
        float contents = original / multiplier - shell;
        if (!Float.isFinite(contents) || contents < -0.0001f) return original;
        int reduction = Math.clamp(box.getWeightReduction(), 0, 100);
        return shell * multiplier + Math.max(0, contents) * ((100 - reduction) / 100.0f);
    }
}
