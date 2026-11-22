require "ISUI/ISInventoryPane"
require "ISUI/ISToolTip"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "Gun_Vars/EFK_Part_Stat_Set"

local Core = require "SuQingMFSFirearmUpgrade/Core"
Core.installCriticalHook()
local Action = ISBaseTimedAction:derive("SuQingMFSFirearmUpgradeAction")
local prefix = "UI_SuQingMFSFirearmUpgrade_"
local jobs = { upgrade = "Working", maomao = "MaoMaoWorking", reset = "Resetting", maintenance = "Wiping" }

local function sayError(character, reason)
    character:Say(getText(reason or prefix .. "Error_Failed"))
end

function Action:isValid()
    local ok, reason
    if self.maintenance then
        ok, reason = Core.checkMaintenance(self.character, self.weapon, self.maintenance)
    else
        ok, reason = Core.checkTarget(self.character, self.weapon, self.mode, self.expectedLevel)
    end
    self.invalidReason = reason
    return ok
end

function Action:start()
    self:setActionAnim("Craft")
    self.weapon:setJobType(getText(prefix .. jobs[self.mode]))
    self.weapon:setJobDelta(0)
end

function Action:update()
    self.weapon:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.UsingTools)
end

function Action:stop()
    self.weapon:setJobDelta(0)
    if self.invalidReason then sayError(self.character, self.invalidReason) end
    ISBaseTimedAction.stop(self)
end

function Action:perform()
    self.weapon:setJobDelta(0)
    ISBaseTimedAction.perform(self)
end

function Action:complete()
    local ok, reason
    if self.maintenance then
        ok, reason = Core.maintain(self.character, self.weapon, self.maintenance)
    else
        ok, reason = Core.commit(self.character, self.weapon, self.mode, self.expectedLevel)
    end
    if not ok then
        sayError(self.character, reason)
        return false
    end
    local container = self.weapon:getContainer()
    if container then container:setDrawDirty(true) end
    if self.maintenance then
        self.character:Say(getText(prefix .. "Maintained", tostring(self.weapon:getCondition()), tostring(self.weapon:getConditionMax())))
    elseif self.mode == "upgrade" then
        self.character:Say(getText(prefix .. "Upgraded", tostring(self.expectedLevel + 1)))
    elseif self.mode == "maomao" then
        self.character:Say(getText(prefix .. "MaoMaoDone"))
    else
        self.character:Say(getText(prefix .. "ResetDone"))
    end
    return true
end

function Action:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return (self.mode == "upgrade" or self.mode == "maomao") and 90 or 45
end

function Action:new(character, weapon, mode, expectedLevel, maintenance)
    local action = ISBaseTimedAction.new(self, character)
    action.weapon = weapon
    action.mode = mode
    action.expectedLevel = expectedLevel
    action.maintenance = maintenance
    action.maxTime = action:getDuration()
    return action
end

local function queueAction(weapon, character, mode, expectedLevel)
    local ok, reason = Core.checkTarget(character, weapon, mode, expectedLevel)
    if not ok then
        sayError(character, reason)
        return
    end
    ISTimedActionQueue.add(Action:new(character, weapon, mode, expectedLevel))
end

local function queueMaintenance(weapon, character, quote)
    local ok, reason = Core.checkMaintenance(character, weapon, quote)
    if not ok then
        sayError(character, reason)
        return
    end
    ISTimedActionQueue.add(Action:new(character, weapon, "maintenance", nil, quote))
end

local function damageRange(minDamage, maxDamage)
    return string.format("%.2f–%.2f", minDamage, maxDamage)
end

local function criticalValues(chance, multiplier)
    return string.format("%.1f%%", chance), string.format("×%.2f", multiplier)
end

local function addRequirement(lines, name, have, needed)
    local colour = have < needed and "<RGB:1,0.45,0.45> " or ""
    local line = getText(prefix .. "Requirement", name, tostring(have), tostring(needed))
    table.insert(lines, colour .. line .. " <RGB:1,1,1>")
end

local function wearChance(roll)
    if roll <= 0 then return "—" end
    return string.format("1/%d", roll)
end

local function setTooltip(option, weapon, quote, mode, reason)
    local currentMinDamage = quote and quote.currentMinDamage or weapon:getMinDamage()
    local currentMaxDamage = quote and quote.currentMaxDamage or weapon:getMaxDamage()
    local currentMaxRange = quote and quote.currentMaxRange or weapon:getMaxRange()
    local currentWear = quote and quote.currentWearRoll or weapon:getConditionLowerChance()
    local currentChance, currentMultiplier
    if quote then
        currentChance, currentMultiplier = quote.currentCritChance, quote.currentCritMultiplier
    else
        currentChance, currentMultiplier = Core.getCriticalStats(weapon)
    end
    local chanceText, multiplierText = criticalValues(currentChance, currentMultiplier)
    local currentDamage = damageRange(currentMinDamage, currentMaxDamage)
    local showRange = quote and quote.minRange ~= nil
    local rangeText = showRange and damageRange(quote.currentMinRange, currentMaxRange) or string.format("%.2f", currentMaxRange)
    local lines = {
        getText(prefix .. (showRange and "CurrentDamageAndRange" or "CurrentDamage"), currentDamage, rangeText),
        getText(prefix .. "CurrentCritical", chanceText, multiplierText),
    }
    local minBonus, maxBonus = Core.getDamageBonus(weapon)
    if minBonus then
        table.insert(lines, getText(prefix .. "CurrentDamageBonus", damageRange(minBonus, maxBonus)))
    end
    if quote then
        table.insert(lines, getText(prefix .. "WearPreview", wearChance(currentWear), wearChance(quote.wearRoll)))
    else
        table.insert(lines, getText(prefix .. "CurrentWear", wearChance(currentWear)))
    end
    if quote and quote.currentNoiseRadius then
        table.insert(lines, getText(prefix .. "NoiseRadiusPreview", tostring(quote.currentNoiseRadius),
            string.format("%d%%", quote.currentNoiseRadiusPercent), tostring(quote.noiseRadius),
            string.format("%d%%", quote.noiseRadiusPercent)))
        table.insert(lines, getText(prefix .. "PlayerShotVolumePreview",
            string.format("%d%%", 100 - 2 * quote.level), string.format("%d%%", 100 - 2 * quote.nextLevel)))
    elseif not quote then
        local radius, percent = Core.getNoiseRadius(weapon)
        if radius then
            table.insert(lines, getText(prefix .. "CurrentNoiseRadius", tostring(radius), string.format("%d%%", percent)))
            local level = Core.getState(weapon)
            table.insert(lines, getText(prefix .. "CurrentPlayerShotVolume", string.format("%d%%", 100 - 2 * level)))
        end
    end
    if quote then
        local after = damageRange(quote.minDamage, quote.maxDamage)
        local nextChance, nextMultiplier = criticalValues(quote.critChance, quote.critMultiplier)
        local projectedRange = showRange and damageRange(quote.minRange, quote.maxRange) or string.format("%.2f", quote.maxRange)
        local damageKey = showRange and "ProjectedDamageAndRange" or "ProjectedDamage"
        table.insert(lines, getText(prefix .. damageKey, after, projectedRange))
        table.insert(lines, getText(prefix .. "ProjectedCritical", nextChance, nextMultiplier))
        if quote.hitChance ~= nil then
            table.insert(lines, getText(prefix .. "HitChanceChange",
                string.format("%d%%", quote.currentHitChance), string.format("%d%%", quote.hitChance)))
        end
        if mode ~= "reset" then
            table.insert(lines, getText(prefix .. "Components"))
            for _, material in ipairs(quote.materials) do
                local name = getItemNameFromFullType(material.type)
                addRequirement(lines, name, #material.items, material.count)
            end
            table.insert(lines, getText(prefix .. "Tools"))
            addRequirement(lines, getItemNameFromFullType("Base.Screwdriver"), quote.tools.screwdriver and 1 or 0, 1)
            addRequirement(lines, getItemNameFromFullType("Base.Hammer"), quote.tools.hammer and 1 or 0, 1)
        else
            table.insert(lines, getText(prefix .. "ResetDetails"))
        end
    end
    if reason then
        table.insert(lines, "<RGB:1,0.45,0.45> " .. getText(reason))
    end
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = table.concat(lines, " <LINE> ")
    option.toolTip = tooltip
end

local function addAction(subMenu, character, weapon, mode, level)
    local quote, reason = Core.getQuote(character, weapon, mode)
    local label = getText(prefix .. "Reset")
    if mode == "upgrade" then
        if level == Core.MAX_LEVEL then
            label = getText(prefix .. "AtMaxLevel")
        else
            label = getText(prefix .. "Upgrade", tostring(level + 1))
        end
    elseif mode == "maomao" then
        label = getText(prefix .. "MaoMao")
    end
    local option = subMenu:addOption(label, weapon, queueAction, character, mode, level)
    option.notAvailable = reason ~= nil or quote == nil
    setTooltip(option, weapon, quote, mode, reason or (not quote and prefix .. "Error_Failed"))
end

local function addWipeOption(context, name, character, weapon, quote, reason)
    local option = context:addOption(name, weapon, queueMaintenance, character, quote)
    option.notAvailable = quote == nil
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    if quote then
        local condition = getText(prefix .. "ConditionPreview",
            tostring(quote.condition), tostring(quote.condition + 1), tostring(quote.maxCondition))
        local lines = {
            condition,
            getText(prefix .. "MaterialPreview", quote.towel:getDisplayName()),
            getText(prefix .. "TowelPreview", tostring(quote.uses), tostring(quote.uses - 1)),
        }
        if quote.uses == 1 and quote.material.replacement then
            lines[#lines + 1] = getText(prefix .. "MaterialAfterUse", getItemNameFromFullType(quote.material.replacement))
        end
        tooltip.description = table.concat(lines, " <LINE> ")
    else
        tooltip.description = getText(reason)
    end
    option.toolTip = tooltip
end

local function addMaintenance(context, character, weapon)
    local quote, reason, quotes = Core.getMaintenanceQuote(character, weapon)
    local name = getText(prefix .. "Maintain")
    if not quote or #quotes == 1 then
        addWipeOption(context, name, character, weapon, quote, reason)
        return
    end
    local option = context:addOption(name, weapon, nil)
    local materials = context:getNew(context)
    context:addSubMenu(option, materials)
    for _, choice in ipairs(quotes) do
        addWipeOption(materials, choice.towel:getDisplayName(), character, weapon, choice)
    end
end

local function fillInventoryMenu(playerNum, context, items)
    if isClient() or isServer() then return end
    local selected = ISInventoryPane.getActualItems(items)
    if #selected ~= 1 then return end
    local weapon = selected[1]
    local character = getSpecificPlayer(playerNum)
    if not character or not instanceof(weapon, "HandWeapon") then return end

    local level, reason = Core.getState(weapon)
    local supported = Core.isSupported(weapon)
    if not supported and (level == nil or level == 0) then return end
    local handlesFirearm = SuQingWipeRepairMenu and SuQingWipeRepairMenu.handlesFirearm
    if supported and (type(handlesFirearm) ~= "function" or not handlesFirearm(weapon)) then
        addMaintenance(context, character, weapon)
    end
    if level == nil then
        local option = context:addOption(getText(prefix .. "Menu"), weapon, nil)
        option.notAvailable = true
        setTooltip(option, weapon, nil, nil, reason or prefix .. "Error_Failed")
        return
    end

    local name = getText(prefix .. "MenuWithLevel", tostring(level), tostring(Core.MAX_LEVEL))
    local option = context:addOption(name, weapon, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    if supported then
        addAction(subMenu, character, weapon, "upgrade", level)
        if level == Core.MAX_LEVEL and Core.isMaoMaoRifle(weapon) then
            addAction(subMenu, character, weapon, "maomao", level)
        end
    end
    if level > 0 then addAction(subMenu, character, weapon, "reset", level) end
end

Events.OnFillInventoryObjectContextMenu.Add(fillInventoryMenu)
if not isClient() and not isServer() then
    Events.OnPlayerUpdate.Add(Core.updateActiveSight)
    Events.OnEquipPrimary.Add(Core.updateActiveSight)
    Events.OnPlayerDeath.Add(Core.updateActiveSight)
end
