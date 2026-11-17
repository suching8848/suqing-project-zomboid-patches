require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicOutputProgress"

local widget = ISWidgetCraftLogicOutputProgress
local originalCreate = widget.createDynamicChildren

function widget:createDynamicChildren()
    originalCreate(self)
    local speed = SuQingLeatherRackSpeed
    if not self.progressItems or not speed.isPatched(self.recipe) then
        return
    end

    local originalTooltip = self.progressItems.drawTooltip
    local entity = self.entity
    self.progressItems.drawTooltip = function(slot, tooltip)
        originalTooltip(slot, tooltip)
        local data = slot.craftRecipeData
        if not data or not speed.isPatched(data:getRecipe()) then
            return
        end

        local font = UIFont.Small
        local textManager = getTextManager()
        local rate = string.format("%.1f", speed.getDryingRate(entity))
        local line = getText("IGUI_SuQingLeatherRackSpeed_EffectiveRate", rate)
        local padding = 5
        local y = tooltip:getHeight()
        tooltip:setWidth(math.max(tooltip:getWidth(), textManager:MeasureStringX(font, line) + padding * 2))
        tooltip:setHeight(y + textManager:getFontHeight(font) + padding)
        tooltip:DrawText(font, line, padding, y, 1, 1, 0.8, 1)
    end
    for _, slot in ipairs(self.progressItems:getItemSlots()) do
        if slot.drawTooltip == originalTooltip then
            slot.drawTooltip = self.progressItems.drawTooltip
        end
    end
end
