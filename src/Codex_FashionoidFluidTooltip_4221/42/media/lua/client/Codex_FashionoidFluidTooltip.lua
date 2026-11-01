-- Fashionoid also sees fluid/resource tooltips through ISToolTipInv.
-- Such objects need not provide the inventory/script item type method.
require "TransmogCore"

if TransmogCore and type(TransmogCore.canBeTransmogged) == "function" then
    local original = TransmogCore.canBeTransmogged
    TransmogCore.canBeTransmogged = function(item, ...)
        if item and not item.isItemType then
            return false
        end
        return original(item, ...)
    end
    print("[FashionoidFluidTooltip] Compatibility guard installed")
else
    print("[FashionoidFluidTooltip] WARNING: Fashionoid eligibility function missing; guard not installed")
end
