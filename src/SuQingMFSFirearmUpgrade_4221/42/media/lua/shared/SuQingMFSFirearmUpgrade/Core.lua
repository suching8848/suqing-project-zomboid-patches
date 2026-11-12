local Core = {}

local STATE_KEY = "SuQingMFSFirearmUpgrade"
local STATE_VERSION = 2
local ERROR_PREFIX = "UI_SuQingMFSFirearmUpgrade_Error_"
local DAMAGE_SANDBOX_ID = "ModernFirearmsSystemDamageSandbox"
local METAL_PARTS = "Base.part2_cat"
local POLYMER_PARTS = "Base.part3_cat"
local DRY_TOWEL = "Base.BathTowel"

local tiers = {
    { multiplier = 0.10, critPoints = 20, critMultiplier = 1.10, metal = 2, polymer = 1 },
    { multiplier = 0.20, critPoints = 35, critMultiplier = 1.20, metal = 4, polymer = 2 },
    { multiplier = 0.30, critPoints = 50, critMultiplier = 1.50, metal = 6, polymer = 4 },
    { multiplier = 0.40, critPoints = 75, critMultiplier = 1.75, metal = 8, polymer = 6 },
    { multiplier = 0.50, critPoints = 100, critMultiplier = 2.00, metal = 10, polymer = 8 },
}

local criticalHookReady = false

Core.MAX_LEVEL = #tiers

local specialAmmo = {
    ["base.capguncap"] = true,
    ["base.crossbowbolt"] = true,
    ["base.grenadeammo"] = true,
    ["flamethrower.flamefuel"] = true,
}

local specialWeapons = {
    ["Base.MTL30_cat"] = true,
    ["Base.MFS_MTL30_cat"] = true,
    ["Flamethrower.Flamethrower"] = true,
}

local function isHandWeapon(weapon)
    return weapon ~= nil and instanceof(weapon, "HandWeapon")
end

function Core.isSupported(weapon)
    if not isHandWeapon(weapon) or not weapon:isRanged() or not weapon:isAimedFirearm() then
        return false
    end
    local ammo = weapon:getAmmoType()
    local itemKey = ammo and ammo:getItemKey()
    return type(itemKey) == "string" and itemKey ~= ""
        and not specialAmmo[string.lower(itemKey)] and not specialWeapons[weapon:getFullType()]
end

local function validNumber(value)
    return type(value) == "number" and value >= 0 and value < math.huge
end

local function validDamage(minDamage, maxDamage)
    return validNumber(minDamage) and validNumber(maxDamage)
        and maxDamage > 0 and minDamage <= maxDamage
end

local function validBaseRange(range)
    return validNumber(range) and range > 0
end

local function readBaseRange(script)
    local range = script and script:getMaxRange()
    if validBaseRange(range) then return range end
end

local function rangeBonus(state, tier)
    return state and state.baseMaxRange and state.baseMaxRange * tier.multiplier or 0
end

local function readState(weapon)
    if not isHandWeapon(weapon) then
        return nil, nil, ERROR_PREFIX .. "Unsupported"
    end
    if not weapon:hasModData() then
        return 0
    end
    local state = weapon:getModData()[STATE_KEY]
    if state == nil then
        return 0
    end
    local tier = type(state) == "table" and type(state.level) == "number" and tiers[state.level]
    if not tier or state.version ~= STATE_VERSION or state.fullType ~= weapon:getFullType()
        or not validDamage(state.baseMinDamage, state.baseMaxDamage)
        or (state.baseMaxRange ~= nil and not validBaseRange(state.baseMaxRange))
        or state.minDelta ~= state.baseMinDamage * tier.multiplier
        or state.maxDelta ~= state.baseMaxDamage * tier.multiplier then
        return nil, nil, ERROR_PREFIX .. "InvalidState"
    end
    return state.level, state
end

function Core.getState(weapon)
    local level, _, errorKey = readState(weapon)
    return level, errorKey
end

local function modeError(weapon, mode, level)
    if mode == "upgrade" and Core.isSupported(weapon) then
        if level == Core.MAX_LEVEL then
            return ERROR_PREFIX .. "MaxLevel"
        end
        return nil
    end
    if mode == "reset" then
        if level == 0 then
            return ERROR_PREFIX .. "NoUpgrade"
        end
        return nil
    end
    return ERROR_PREFIX .. "Unsupported"
end

local function damageSandboxActive()
    local active = getActivatedMods()
    return (active and active:contains(DAMAGE_SANDBOX_ID))
        or (type(MFSDamageSandbox) == "table" and type(MFSDamageSandbox.Apply) == "function")
end

local function readCriticalBase(weapon)
    local origin = instanceItem(weapon:getFullType())
    if not origin then return nil end

    local chance = origin:getCriticalChance()
    local multiplier = origin:getCriticalDamageMultiplier()
    local partMultiplier = 0
    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local bonus = AWCWF_GetPartStatBonus(parts:get(i))
        if bonus then
            chance = chance + (bonus.CriticalChance or 0)
            partMultiplier = partMultiplier + (bonus.CritDmgMultiplier or 0)
        end
    end
    if not validNumber(chance) or not validNumber(multiplier) or not validNumber(multiplier + partMultiplier) then
        return nil
    end
    return { chance = chance, multiplier = multiplier, partMultiplier = partMultiplier }
end

local function criticalStats(base, tier)
    if not tier then return base.chance, base.multiplier + base.partMultiplier end
    return base.chance + tier.critPoints, base.multiplier * tier.critMultiplier + base.partMultiplier
end

function Core.getCriticalStats(weapon)
    local level = Core.getState(weapon)
    local base = level and criticalHookReady and readCriticalBase(weapon)
    if base then return criticalStats(base, tiers[level]) end
    return weapon:getCriticalChance(), weapon:getCriticalDamageMultiplier()
end

local function wearRollFor(weapon, tier)
    local script = weapon:getScriptItem()
    local baseRoll = script and script:getConditionLowerChance()
    if not baseRoll or baseRoll <= 0 then return weapon:getConditionLowerChance() end
    if not tier then return baseRoll end
    -- A wear roll of 1/N becomes approximately (1 - reduction)/N.
    return math.min(2147483647, math.floor(baseRoll / (1 - tier.multiplier) + 0.5))
end

local function applyExistingRange(weapon, state, tier)
    -- Earlier v2 records already contain damage, but have no range bonus yet.
    if state.baseMaxRange ~= nil then return end
    local baseRange = readBaseRange(weapon:getScriptItem())
    local currentRange = weapon:getMaxRange()
    if not baseRange or not validNumber(currentRange) then return end
    local maxRange = currentRange + baseRange * tier.multiplier
    if not validNumber(maxRange) then return end
    weapon:setMaxRange(maxRange)
    state.baseMaxRange = baseRange
end

function Core.installCriticalHook()
    if criticalHookReady then return end
    local applyPartStats = AWCWF_ApplyPartStats
    if type(applyPartStats) ~= "function" or type(AWCWF_GetPartStatBonus) ~= "function" then return end

    AWCWF_ApplyPartStats = function(player, weapon)
        applyPartStats(player, weapon)
        if isClient() or isServer() or not Core.isSupported(weapon) then return end
        local level, state = readState(weapon)
        local tier = level and tiers[level]
        if not tier or damageSandboxActive() then return end
        applyExistingRange(weapon, state, tier)
        -- The wear denominator is rebuilt from the script on load, like crit.
        weapon:setConditionLowerChance(wearRollFor(weapon, tier))
        -- The engine reloads raw crit fields and MFS overwrites them when syncing.
        -- Rebuild from the bare gun and current parts so repeated syncs are idempotent.
        local base = readCriticalBase(weapon)
        if not base then return end
        local chance, multiplier = criticalStats(base, tier)
        weapon:setCriticalChance(chance)
        weapon:setCriticalDamageMultiplier(multiplier)
    end
    criticalHookReady = true
end

local function workError(inventory, weapon, requireWorkingGun)
    if not inventory or not weapon:getContainer() or not inventory:contains(weapon, true) then
        return ERROR_PREFIX .. "NotOwned"
    end
    if requireWorkingGun and weapon:isBroken() then
        return ERROR_PREFIX .. "Broken"
    end
    if weapon:isRoundChambered() or weapon:isSpentRoundChambered()
        or weapon:getCurrentAmmoCount() ~= 0 or weapon:isContainsClip() then
        return ERROR_PREFIX .. "Unload"
    end
end

local function targetError(inventory, weapon, mode)
    if isClient() or isServer() then
        return ERROR_PREFIX .. "Multiplayer"
    end
    if damageSandboxActive() then
        return ERROR_PREFIX .. "DamageSandbox"
    end
    if not criticalHookReady then
        return ERROR_PREFIX .. "CriticalIntegration"
    end
    return workError(inventory, weapon, mode == "upgrade")
end

local function maintenanceError(inventory, weapon)
    if isClient() or isServer() then return ERROR_PREFIX .. "Multiplayer" end
    if not Core.isSupported(weapon) then return ERROR_PREFIX .. "Unsupported" end

    local errorKey = workError(inventory, weapon, true)
    if errorKey then return errorKey end
    local condition = weapon:getCondition()
    if condition <= 0 then return ERROR_PREFIX .. "Broken" end
    if condition >= weapon:getConditionMax() then return ERROR_PREFIX .. "FullCondition" end
end

local function usableTowel(item)
    return item and item:getFullType() == DRY_TOWEL and instanceof(item, "DrainableComboItem")
        and not item:isWet() and item:getCurrentUses() > 0
end

function Core.getMaintenanceQuote(character, weapon)
    local inventory = character and character:getInventory()
    local errorKey = maintenanceError(inventory, weapon)
    if errorKey then return nil, errorKey end

    local towel = inventory:getFirstTypeEvalRecurse(DRY_TOWEL, usableTowel)
    if not towel then return nil, ERROR_PREFIX .. "DryTowel" end
    return {
        condition = weapon:getCondition(),
        maxCondition = weapon:getConditionMax(),
        towel = towel,
        uses = towel:getCurrentUses(),
    }
end

function Core.checkMaintenance(character, weapon, quote)
    local inventory = character and character:getInventory()
    local errorKey = maintenanceError(inventory, weapon)
    if errorKey then return false, errorKey end
    if not quote or weapon:getCondition() ~= quote.condition or weapon:getConditionMax() ~= quote.maxCondition then
        return false, ERROR_PREFIX .. "Stale"
    end
    local towel = quote.towel
    if not usableTowel(towel) or not towel:getContainer() or not inventory:contains(towel, true) then
        return false, ERROR_PREFIX .. "DryTowel"
    end
    if towel:getCurrentUses() ~= quote.uses then return false, ERROR_PREFIX .. "Stale" end
    return true
end

function Core.maintain(character, weapon, quote)
    local allowed, errorKey = Core.checkMaintenance(character, weapon, quote)
    if not allowed then return false, errorKey end

    local nextCondition = quote.condition + 1
    local towel = quote.towel
    local ok, reason = pcall(function()
        weapon:setCondition(nextCondition)
        if weapon:getCondition() ~= nextCondition then error("condition did not increase") end
        -- Use the native charge and wet-towel replacement, including the final use.
        towel:Use()
    end)
    local remaining = towel:getCurrentUses()
    local consumed = remaining == quote.uses - 1 and (remaining > 0 or not towel:getContainer())
    if weapon:getCondition() == nextCondition and consumed then
        if not ok then print("[SuQingMFSFirearmUpgrade] maintenance completed with error: " .. tostring(reason)) end
        return true
    end

    -- If the game could not create the wet towel, the depleted dry towel remains.
    if remaining ~= quote.uses and towel:getContainer() then
        towel:setCurrentUses(quote.uses)
    end
    if weapon:getCondition() ~= quote.condition then
        weapon:setConditionWhileLoading(quote.condition)
    end
    print("[SuQingMFSFirearmUpgrade] maintenance failed: " .. tostring(reason or "towel use did not register"))
    return false, ERROR_PREFIX .. "Failed"
end

function Core.checkTarget(character, weapon, mode, expectedLevel)
    local level, _, errorKey = readState(weapon)
    if errorKey then
        return false, errorKey
    end
    if expectedLevel ~= level then
        return false, ERROR_PREFIX .. "Stale"
    end
    errorKey = modeError(weapon, mode, level) or targetError(character and character:getInventory(), weapon, mode)
    return errorKey == nil, errorKey
end

local function materialQuote(inventory, fullType, count)
    local items = {}
    if inventory then
        local found = inventory:getAllTypeRecurse(fullType)
        for i = 0, found:size() - 1 do
            local item = found:get(i)
            if item:getFullType() == fullType then
                items[#items + 1] = item
                if #items == count then
                    break
                end
            end
        end
    end
    return { type = fullType, count = count, items = items }
end

local function notBroken(item)
    return not item:isBroken()
end

local function makeQuote(character, weapon, mode)
    local level, state, errorKey = readState(weapon)
    if errorKey then
        return nil, errorKey
    end
    errorKey = modeError(weapon, mode, level)
    if errorKey then
        return nil, errorKey
    end

    local currentMinDamage = weapon:getMinDamage()
    local currentMaxDamage = weapon:getMaxDamage()
    local currentMaxRange = weapon:getMaxRange()
    local minDelta = state and state.minDelta or 0
    local maxDelta = state and state.maxDelta or 0
    local nextLevel = 0
    local nextState
    local tier

    if mode == "upgrade" then
        nextLevel = level + 1
        tier = tiers[nextLevel]
        local script = weapon:getScriptItem()
        local baseMinDamage = state and state.baseMinDamage or script and script:getMinDamage()
        local baseMaxDamage = state and state.baseMaxDamage or script and script:getMaxDamage()
        local baseMaxRange = state and state.baseMaxRange or readBaseRange(script)
        if not validDamage(baseMinDamage, baseMaxDamage) or not baseMaxRange then
            return nil, ERROR_PREFIX .. "InvalidState"
        end
        nextState = {
            version = STATE_VERSION,
            fullType = weapon:getFullType(),
            level = nextLevel,
            baseMinDamage = baseMinDamage,
            baseMaxDamage = baseMaxDamage,
            baseMaxRange = baseMaxRange,
            minDelta = baseMinDamage * tier.multiplier,
            maxDelta = baseMaxDamage * tier.multiplier,
        }
    end

    -- Subtract only our previous delta, keeping the gun's current attachment bonuses.
    local minDamage = currentMinDamage - minDelta + (nextState and nextState.minDelta or 0)
    local maxDamage = currentMaxDamage - maxDelta + (nextState and nextState.maxDelta or 0)
    local maxRange = currentMaxRange - rangeBonus(state, tiers[level]) + rangeBonus(nextState, tier)
    if not validDamage(currentMinDamage, currentMaxDamage) or not validDamage(minDamage, maxDamage)
        or not validNumber(currentMaxRange) or not validNumber(maxRange) then
        return nil, ERROR_PREFIX .. "InvalidState"
    end

    local inventory = character and character:getInventory()
    errorKey = targetError(inventory, weapon, mode)
    if not criticalHookReady then return nil, errorKey end
    local criticalBase = readCriticalBase(weapon)
    if not criticalBase then return nil, errorKey or ERROR_PREFIX .. "InvalidState" end
    local currentCritChance, currentCritMultiplier = criticalStats(criticalBase, tiers[level])
    local critChance, critMultiplier = criticalStats(criticalBase, tier)
    local quote = {
        level = level,
        nextLevel = nextLevel,
        currentMinDamage = currentMinDamage,
        currentMaxDamage = currentMaxDamage,
        minDamage = minDamage,
        maxDamage = maxDamage,
        currentMaxRange = currentMaxRange,
        maxRange = maxRange,
        currentWearRoll = weapon:getConditionLowerChance(),
        wearRoll = wearRollFor(weapon, tier),
        currentCritChance = currentCritChance,
        currentCritMultiplier = currentCritMultiplier,
        critChance = critChance,
        critMultiplier = critMultiplier,
        materials = {},
        tools = {},
    }

    if tier then
        quote.materials = {
            materialQuote(inventory, METAL_PARTS, tier.metal),
            materialQuote(inventory, POLYMER_PARTS, tier.polymer),
        }
        if inventory then
            quote.tools.screwdriver = inventory:getFirstTagEvalRecurse(ItemTag.SCREWDRIVER, notBroken)
            quote.tools.hammer = inventory:getFirstTagEvalRecurse(ItemTag.HAMMER, notBroken)
        end
        if not errorKey then
            if not quote.tools.screwdriver then
                errorKey = ERROR_PREFIX .. "Screwdriver"
            elseif not quote.tools.hammer then
                errorKey = ERROR_PREFIX .. "Hammer"
            elseif #quote.materials[1].items < tier.metal or #quote.materials[2].items < tier.polymer then
                errorKey = ERROR_PREFIX .. "Materials"
            end
        end
    end

    return quote, errorKey, state, nextState
end

function Core.getQuote(character, weapon, mode)
    local quote, errorKey = makeQuote(character, weapon, mode)
    return quote, errorKey
end

function Core.commit(character, weapon, mode, expectedLevel)
    local ok, targetBlocker = Core.checkTarget(character, weapon, mode, expectedLevel)
    if not ok then
        return false, targetBlocker
    end
    local quote, errorKey, state, nextState = makeQuote(character, weapon, mode)
    if errorKey then
        return false, errorKey
    end

    local inventory = character:getInventory()
    local debits = {}
    for _, group in ipairs(quote.materials) do
        for _, item in ipairs(group.items) do
            local container = item:getContainer()
            if not container or not container:contains(item) or not inventory:contains(item, true) then
                return false, ERROR_PREFIX .. "Materials"
            end
            debits[#debits + 1] = { container = container, item = item }
        end
    end

    local modData = weapon:getModData()
    local previousCritChance = weapon:getCriticalChance()
    local previousCritMultiplier = weapon:getCriticalDamageMultiplier()
    local attemptedDebits = 0
    local attemptedStats = false
    local committed, reason = pcall(function()
        for index, debit in ipairs(debits) do
            if not debit.container:contains(debit.item) then
                error("material moved before debit")
            end
            attemptedDebits = index
            debit.container:Remove(debit.item)
            if debit.container:contains(debit.item) or debit.item:getContainer() ~= nil then
                error("material was not removed")
            end
        end

        if not Core.checkTarget(character, weapon, mode, expectedLevel)
            or modData[STATE_KEY] ~= state
            or weapon:getMinDamage() ~= quote.currentMinDamage
            or weapon:getMaxDamage() ~= quote.currentMaxDamage
            or weapon:getMaxRange() ~= quote.currentMaxRange
            or weapon:getConditionLowerChance() ~= quote.currentWearRoll
            or weapon:getCriticalChance() ~= previousCritChance
            or weapon:getCriticalDamageMultiplier() ~= previousCritMultiplier then
            error("weapon changed before applying the upgrade")
        end

        attemptedStats = true
        weapon:setMinDamage(quote.minDamage)
        weapon:setMaxDamage(quote.maxDamage)
        weapon:setMaxRange(quote.maxRange)
        weapon:setCriticalChance(quote.critChance)
        weapon:setCriticalDamageMultiplier(quote.critMultiplier)
        weapon:setConditionLowerChance(quote.wearRoll)
        modData[STATE_KEY] = nextState
    end)
    if committed then
        return true
    end

    local function restore(callback)
        local restored, restoreError = pcall(callback)
        if not restored then
            print("[SuQingMFSFirearmUpgrade] rollback failed: " .. tostring(restoreError))
        end
    end
    if attemptedStats then
        restore(function() weapon:setMinDamage(quote.currentMinDamage) end)
        restore(function() weapon:setMaxDamage(quote.currentMaxDamage) end)
        restore(function() weapon:setMaxRange(quote.currentMaxRange) end)
        restore(function() weapon:setCriticalChance(previousCritChance) end)
        restore(function() weapon:setCriticalDamageMultiplier(previousCritMultiplier) end)
        restore(function() weapon:setConditionLowerChance(quote.currentWearRoll) end)
        restore(function() modData[STATE_KEY] = state end)
    end
    for i = attemptedDebits, 1, -1 do
        local debit = debits[i]
        restore(function()
            if not debit.container:contains(debit.item) then
                debit.container:AddItem(debit.item)
                if not debit.container:contains(debit.item) then
                    error("material was not restored")
                end
            end
        end)
    end
    print("[SuQingMFSFirearmUpgrade] transaction failed: " .. tostring(reason))
    return false, ERROR_PREFIX .. "Failed"
end

return Core
