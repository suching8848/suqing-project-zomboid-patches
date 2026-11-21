require "ISUI/ISInventoryPane"
require "ISUI/ISToolTip"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

local Core = require "SuQingMeleeWeaponWipe/Core"
local Action = ISBaseTimedAction:derive("SuQingMeleeWeaponWipeAction")
local TEXT = "UI_SuQingMeleeWeaponWipe_"

function Action:isValid()
    local valid, reason = Core.check(self.character, self.weapon, self.quote)
    self.invalidReason = reason
    return valid
end

function Action:start()
    self:setActionAnim("Craft")
    self.weapon:setJobType(getText(TEXT .. "Wiping"))
    self.weapon:setJobDelta(0)
end

function Action:update()
    self.weapon:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.UsingTools)
end

function Action:stop()
    self.weapon:setJobDelta(0)
    if self.invalidReason then self.character:Say(getText(TEXT .. self.invalidReason)) end
    ISBaseTimedAction.stop(self)
end

function Action:perform()
    self.weapon:setJobDelta(0)
    ISBaseTimedAction.perform(self)
end

function Action:complete()
    local ok, reason = Core.wipe(self.character, self.weapon, self.quote)
    if not ok then
        self.character:Say(getText(TEXT .. reason))
        return false
    end
    local container = self.weapon:getContainer()
    if container then container:setDrawDirty(true) end
    if self.quote.firearm then
        self.character:Say(getText(TEXT .. "FirearmMaintained", tostring(self.weapon:getCondition()),
            tostring(self.weapon:getConditionMax())))
    end
    return true
end

function Action:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 45
end

function Action:new(character, weapon, quote)
    local action = ISBaseTimedAction.new(self, character)
    action.weapon = weapon
    action.quote = quote
    action.maxTime = action:getDuration()
    return action
end

local function queueWipe(weapon, character, quote)
    local valid, reason = Core.check(character, weapon, quote)
    if not valid then
        character:Say(getText(TEXT .. reason))
        return
    end
    ISTimedActionQueue.add(Action:new(character, weapon, quote))
end

local function percent(value)
    return string.format("%.1f%%", value * 100)
end

local function preview(quote)
    local lines = {
        getText(TEXT .. "Condition", tostring(quote.condition), tostring(quote.nextCondition),
            tostring(quote.conditionMax)),
    }
    if quote.headCondition then
        lines[#lines + 1] = getText(TEXT .. "HeadCondition", tostring(quote.headCondition),
            tostring(quote.nextHeadCondition), tostring(quote.headConditionMax))
    end
    if quote.sharpness then
        lines[#lines + 1] = getText(TEXT .. "Sharpness", percent(quote.sharpness), percent(quote.nextSharpness))
    end
    lines[#lines + 1] = getText(TEXT .. "Material", quote.cloth:getDisplayName())
    lines[#lines + 1] = getText(TEXT .. "ClothUses", tostring(quote.uses), tostring(quote.uses - 1))
    if quote.uses == 1 and quote.material.replacement then
        lines[#lines + 1] = getText(TEXT .. "Replacement", getItemNameFromFullType(quote.material.replacement))
    end
    return table.concat(lines, " <LINE> ")
end

local function addWipeOption(context, name, weapon, character, quote, reason)
    local option = context:addOption(name, weapon, queueWipe, character, quote)
    option.notAvailable = quote == nil
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = quote and preview(quote) or getText(TEXT .. reason)
    option.toolTip = tooltip
end

local function fillInventoryMenu(playerNum, context, items)
    if isClient() or isServer() then return end
    local selected = ISInventoryPane.getActualItems(items)
    if #selected ~= 1 or not Core.isSupported(selected[1]) then return end

    local character = getSpecificPlayer(playerNum)
    if not character then return end
    local weapon = selected[1]
    local quote, reason, quotes = Core.getQuote(character, weapon)
    if reason == "NotCarried" then return end

    local title = getText(TEXT .. "Menu")
    if not quote or #quotes == 1 then
        addWipeOption(context, title, weapon, character, quote, reason)
        return
    end
    local option = context:addOption(title, weapon, nil)
    local materials = context:getNew(context)
    context:addSubMenu(option, materials)
    for _, choice in ipairs(quotes) do
        addWipeOption(materials, choice.cloth:getDisplayName(), weapon, character, choice)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(fillInventoryMenu)
SuQingWipeRepairMenu = { handlesFirearm = Core.isSupportedFirearm }
