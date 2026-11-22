local Core = {}

local STATE_KEY = "SuQingMFSFirearmUpgrade"
local STATE_VERSION = 2
local ERROR_PREFIX = "UI_SuQingMFSFirearmUpgrade_Error_"
local DAMAGE_SANDBOX_ID = "ModernFirearmsSystemDamageSandbox"
local MAOMAO_RIFLE = "Base.MaoMaoDianLanZhuZui"
local MAOMAO_AMMO = "Base.MaoMaoEnergyBullet"
local MAOMAO_DAMAGE_BONUS = 2.00
local MAOMAO_CRITICAL_FACTOR = 2.00
local MAOMAO_MAX_RANGE = 800
local MAOMAO_BASE_HIT_CHANCE = 90
local METAL_PARTS = "Base.part2_cat"
local POLYMER_PARTS = "Base.part3_cat"
local WIPE_MATERIALS = {
    { type = "Base.DishCloth", replacement = "Base.DishClothWet", drainable = true },
    { type = "Base.BathTowel", replacement = "Base.BathTowelWet", drainable = true },
    { type = "Base.RippedSheets", replacement = "Base.RippedSheetsDirty", drainable = false },
    { type = "Base.DenimStrips", replacement = "Base.DenimStripsDirty", drainable = false },
    { type = "Base.BurlapPiece", drainable = false },
    { type = "Base.CheeseCloth", drainable = false },
    { type = "Base.Bandage", replacement = "Base.BandageDirty", drainable = false },
}

local tiers = {
    { multiplier = 0.10, critPoints = 20, critMultiplier = 1.10, metal = 2, polymer = 1 },
    { multiplier = 0.20, critPoints = 35, critMultiplier = 1.20, metal = 4, polymer = 2 },
    { multiplier = 0.30, critPoints = 50, critMultiplier = 1.50, metal = 6, polymer = 4 },
    { multiplier = 0.40, critPoints = 75, critMultiplier = 1.75, metal = 8, polymer = 6 },
    { multiplier = 0.50, critPoints = 100, critMultiplier = 2.00, metal = 10, polymer = 8 },
}

local criticalHookReady = false
local activeSightByPlayer = setmetatable({}, { __mode = "k" })

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

function Core.isMaoMaoRifle(weapon)
    return isHandWeapon(weapon) and weapon:getFullType() == MAOMAO_RIFLE
end

function Core.isSupported(weapon)
    if not isHandWeapon(weapon) or not weapon:isRanged() or not weapon:isAimedFirearm() then
        return false
    end
    local ammo = weapon:getAmmoType()
    local itemKey = ammo and ammo:getItemKey()
    if Core.isMaoMaoRifle(weapon) then
        return itemKey == MAOMAO_AMMO
    end
    return type(itemKey) == "string" and itemKey ~= ""
        and not specialAmmo[string.lower(itemKey)] and not specialWeapons[weapon:getFullType()]
end

local function validNumber(value)
    return type(value) == "number" and value >= 0 and value < math.huge
end

local function validHitChance(value)
    return type(value) == "number" and value >= -2147483648 and value <= 2147483647
        and value == math.floor(value)
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

local function attachmentRange(weapon)
    local bonus = 0
    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        bonus = bonus + parts:get(i):getMaxRange()
    end
    return bonus
end

local function maomaoHitDelta(weapon, currentHitChance)
    local bareHitChance = currentHitChance
    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        bareHitChance = bareHitChance - parts:get(i):getHitChance()
    end
    return MAOMAO_BASE_HIT_CHANCE - bareHitChance
end

local function validSavedRange(range)
    return type(range) == "table" and validNumber(range.min) and validNumber(range.minRanged)
        and validNumber(range.maxWithoutParts)
        and (range.maxSight == nil or validNumber(range.maxSight))
end

local function captureMaoMaoRange(weapon, state, tier)
    return {
        min = weapon:getMinRange(),
        minRanged = weapon:getMinRangeRanged(),
        maxSight = weapon:getMaxSightRange(),
        maxWithoutParts = weapon:getMaxRange() - rangeBonus(state, tier) - attachmentRange(weapon),
    }
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
        or (state.maomao ~= nil and (state.maomao ~= true or state.level ~= Core.MAX_LEVEL
            or not Core.isMaoMaoRifle(weapon))) then
        return nil, nil, ERROR_PREFIX .. "InvalidState"
    end
    if state.maomaoHitDelta ~= nil and (not state.maomao or not validHitChance(state.maomaoHitDelta)) then
        return nil, nil, ERROR_PREFIX .. "InvalidState"
    end
    local originalRange = state.maomaoOriginalRange
    if originalRange ~= nil and (not state.maomao or not validSavedRange(originalRange)) then
        return nil, nil, ERROR_PREFIX .. "InvalidState"
    end
    -- Old MaoMao upgrades saved the +100% delta and did not override range.
    local damageBonus = tier.multiplier
    if state.maomao then
        damageBonus = originalRange and MAOMAO_DAMAGE_BONUS or 1.00
    end
    if state.minDelta ~= state.baseMinDamage * damageBonus
        or state.maxDelta ~= state.baseMaxDamage * damageBonus then
        return nil, nil, ERROR_PREFIX .. "InvalidState"
    end
    return state.level, state
end

function Core.getState(weapon)
    local level, _, errorKey = readState(weapon)
    return level, errorKey
end

-- Mirror the installed MFS noise sync: use the script's radius, then the first
-- recognized suppressor. MFS passes the result to the native integer setter.
local function baselineNoiseRadius(weapon)
    local script = weapon:getScriptItem()
    local radius = script and script:getSoundRadius()
    if not validNumber(radius) then return nil end
    if AWCWF_SilencerSet then
        for slot, options in pairs(AWCWF_SilencerSet) do
            local part = weapon:getWeaponPart(slot)
            local modifier = part and options[part:getType()]
            if modifier then return math.floor(radius * modifier.SoundRadiusModifier) end
        end
    end
    return radius
end

function Core.getNoiseRadius(weapon, level)
    if not Core.isSupported(weapon) then return nil end
    if level == nil then level = Core.getState(weapon) end
    if level == 0 or tiers[level] then
        local percent = 100 - level * 10
        local original = baselineNoiseRadius(weapon)
        if original then return math.floor(original * percent / 100 + 0.5), percent, original end
    end
end

-- Native B42 loads these three fields as absolute saved values. Replace our
-- prior base and its tier bonus together, preserving any other contribution.
function Core.rebaseSavedDamageAndRange(weapon, previousRange)
    local level, state = readState(weapon)
    local tier = level and tiers[level]
    if not tier or state.maomao then return false end
    local script = weapon:getScriptItem()
    if not script then return false end
    local minBase, maxBase = script:getMinDamage(), script:getMaxDamage()
    local rangeBase = readBaseRange(script)
    if not validDamage(minBase, maxBase) or not rangeBase then return false end

    local minDelta = minBase * tier.multiplier
    local maxDelta = maxBase * tier.multiplier
    local min = weapon:getMinDamage() - state.baseMinDamage - state.minDelta + minBase + minDelta
    local max = weapon:getMaxDamage() - state.baseMaxDamage - state.maxDelta + maxBase + maxDelta
    local oldRangeBase = state.baseMaxRange or previousRange
    local range = weapon:getMaxRange() - oldRangeBase - rangeBonus(state, tier)
        + rangeBase * (1 + tier.multiplier)
    if not validDamage(min, max) or not validBaseRange(range) then return false end

    weapon:setMinDamage(min)
    weapon:setMaxDamage(max)
    weapon:setMaxRange(range)
    state.baseMinDamage, state.baseMaxDamage, state.baseMaxRange = minBase, maxBase, rangeBase
    state.minDelta, state.maxDelta = minDelta, maxDelta
    local radius = Core.getNoiseRadius(weapon, level)
    if radius then weapon:setSoundRadius(radius) end
    return true
end


function Core.getDamageBonus(weapon)
    local _, state = readState(weapon)
    if state then return state.minDelta, state.maxDelta end
end

local function modeError(weapon, mode, level, state)
    if mode == "upgrade" and Core.isSupported(weapon) then
        if level == Core.MAX_LEVEL then
            return ERROR_PREFIX .. "MaxLevel"
        end
        return nil
    end
    if mode == "maomao" and Core.isMaoMaoRifle(weapon) and Core.isSupported(weapon) then
        if level ~= Core.MAX_LEVEL then return ERROR_PREFIX .. "MaoMaoNeedsMax" end
        if state.maomao then return ERROR_PREFIX .. "MaoMaoAlready" end
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

local function criticalStats(base, tier, state)
    if not tier then return base.chance, base.multiplier + base.partMultiplier end
    local chance = base.chance + tier.critPoints
    if state and state.maomao then
        return chance, base.multiplier * MAOMAO_CRITICAL_FACTOR
    end
    return chance, base.multiplier * tier.critMultiplier + base.partMultiplier
end

function Core.getCriticalStats(weapon)
    local level, state = readState(weapon)
    local base = level and criticalHookReady and readCriticalBase(weapon)
    if base then return criticalStats(base, tiers[level], state) end
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

local function restore(callback)
    local restored, restoreError = pcall(callback)
    if not restored then
        print("[SuQingMFSFirearmUpgrade] rollback failed: " .. tostring(restoreError))
    end
end

local function setMaoMaoRange(weapon)
    weapon:setMinRange(0)
    weapon:setMinRangeRanged(0)
    weapon:setMaxRange(MAOMAO_MAX_RANGE)
    weapon:setMaxSightRange(MAOMAO_MAX_RANGE)
end

local function syncMaoMaoUpgrade(weapon, state, tier)
    local original = state.maomaoOriginalRange
    if original then
        -- Existing upgrades need a restore value for the newly extended sight range.
        if original.maxSight == nil then original.maxSight = weapon:getMaxSightRange() end
        setMaoMaoRange(weapon)
        return
    end
    local range = captureMaoMaoRange(weapon, state, tier)
    local min, max = weapon:getMinDamage(), weapon:getMaxDamage()
    local maxRange = weapon:getMaxRange()
    local minDelta = state.baseMinDamage * MAOMAO_DAMAGE_BONUS
    local maxDelta = state.baseMaxDamage * MAOMAO_DAMAGE_BONUS
    local newMin = min - state.minDelta + minDelta
    local newMax = max - state.maxDelta + maxDelta
    if not validSavedRange(range) or not validDamage(newMin, newMax) then return end

    local ok, reason = pcall(function()
        weapon:setMinDamage(newMin)
        weapon:setMaxDamage(newMax)
        setMaoMaoRange(weapon)
    end)
    if not ok then
        restore(function() weapon:setMinDamage(min) end)
        restore(function() weapon:setMaxDamage(max) end)
        restore(function() weapon:setMinRange(range.min) end)
        restore(function() weapon:setMinRangeRanged(range.minRanged) end)
        restore(function() weapon:setMaxRange(maxRange) end)
        restore(function() weapon:setMaxSightRange(range.maxSight) end)
        print("[SuQingMFSFirearmUpgrade] MaoMao migration failed: " .. tostring(reason))
        return
    end
    state.minDelta = minDelta
    state.maxDelta = maxDelta
    state.maomaoOriginalRange = range
end

local function applyMaoMaoHitChance(weapon, state)
    if state.maomaoHitDelta ~= nil then return end
    local current = weapon:getHitChance()
    local delta = maomaoHitDelta(weapon, current)
    if not validHitChance(delta) or not validHitChance(current + delta) then return end

    -- The engine saves the effective hit value and applies attach/detach changes itself.
    weapon:setHitChance(current + delta)
    state.maomaoHitDelta = delta
end

function Core.updateActiveSight(player)
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() then return end
    local weapon = player:getPrimaryHandItem()
    local sight
    if not player:isDead() and Core.isMaoMaoRifle(weapon) and not damageSandboxActive() then
        local _, state = readState(weapon)
        if state and state.maomaoOriginalRange then
            applyMaoMaoHitChance(weapon, state)
            sight = weapon:getActiveSight()
        end
    end

    local current = activeSightByPlayer[player]
    if current and current.sight == sight then return end
    if current then
        if current.sight:getMaxSightRange() == MAOMAO_MAX_RANGE then
            current.sight:setMaxSightRange(current.original)
        end
        activeSightByPlayer[player] = nil
    end
    -- The engine reads the selected sight's range in place of the rifle's range.
    -- This particular part is restored as soon as it is deselected or the rifle is put away.
    if sight then
        local original = sight:getMaxSightRange()
        if validNumber(original) and original < MAOMAO_MAX_RANGE then
            sight:setMaxSightRange(MAOMAO_MAX_RANGE)
            activeSightByPlayer[player] = { sight = sight, original = original }
        end
    end
end

function Core.installCriticalHook()
    if criticalHookReady then return end
    local applyPartStats = AWCWF_ApplyPartStats
    if type(applyPartStats) ~= "function" or type(AWCWF_GetPartStatBonus) ~= "function" then return end

    AWCWF_ApplyPartStats = function(player, weapon)
        applyPartStats(player, weapon)
        if isClient() or isServer() or not Core.isSupported(weapon) then return end
        if SQBalanceMigration then SQBalanceMigration.apply(weapon) end
        local level, state = readState(weapon)
        local tier = level and tiers[level]
        if not tier or damageSandboxActive() then return end
        -- The native Attack hook and MFS's inspection panel both read this
        -- runtime field. Always calculate from the unupgraded MFS baseline.
        local radius = Core.getNoiseRadius(weapon, level)
        if radius and weapon:getSoundRadius() ~= radius then weapon:setSoundRadius(radius) end
        applyExistingRange(weapon, state, tier)
        if state.maomao then
            syncMaoMaoUpgrade(weapon, state, tier)
            if state.maomaoOriginalRange then applyMaoMaoHitChance(weapon, state) end
        end
        -- The wear denominator is rebuilt from the script on load, like crit.
        weapon:setConditionLowerChance(wearRollFor(weapon, tier))
        -- The engine reloads raw crit fields and MFS overwrites them when syncing.
        -- Rebuild from the bare gun and current parts so repeated syncs are idempotent.
        local base = readCriticalBase(weapon)
        if not base then return end
        local chance, multiplier = criticalStats(base, tier, state)
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
    return workError(inventory, weapon, mode ~= "reset")
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

local function usableCloth(item, material)
    return item and item:getFullType() == material.type
        and instanceof(item, "DrainableComboItem") == material.drainable
        and not item:isWet() and item:getCurrentUses() > 0
end

function Core.getMaintenanceQuote(character, weapon)
    local inventory = character and character:getInventory()
    local errorKey = maintenanceError(inventory, weapon)
    if errorKey then return nil, errorKey end

    local condition, maxCondition = weapon:getCondition(), weapon:getConditionMax()
    local quotes = {}
    for _, material in ipairs(WIPE_MATERIALS) do
        local cloth = inventory:getFirstTypeEvalRecurse(material.type, function(item)
            return usableCloth(item, material)
        end)
        if cloth then
            quotes[#quotes + 1] = {
                condition = condition,
                maxCondition = maxCondition,
                towel = cloth,
                uses = cloth:getCurrentUses(),
                material = material,
            }
        end
    end
    if #quotes == 0 then return nil, ERROR_PREFIX .. "DryTowel" end
    return quotes[1], nil, quotes
end

function Core.checkMaintenance(character, weapon, quote)
    local inventory = character and character:getInventory()
    local errorKey = maintenanceError(inventory, weapon)
    if errorKey then return false, errorKey end
    if not quote or weapon:getCondition() ~= quote.condition or weapon:getConditionMax() ~= quote.maxCondition then
        return false, ERROR_PREFIX .. "Stale"
    end
    local cloth = quote.towel
    if not usableCloth(cloth, quote.material) or not cloth:getContainer() or not inventory:contains(cloth, true) then
        return false, ERROR_PREFIX .. "DryTowel"
    end
    if cloth:getCurrentUses() ~= quote.uses then return false, ERROR_PREFIX .. "Stale" end
    return true
end

function Core.maintain(character, weapon, quote)
    local allowed, errorKey = Core.checkMaintenance(character, weapon, quote)
    if not allowed then return false, errorKey end

    local nextCondition = quote.condition + 1
    local cloth = quote.towel
    local clothContainer = cloth:getContainer()
    local replacement = quote.uses == 1 and quote.material.replacement
    local existingReplacements = replacement and clothContainer:getItemsFromFullType(replacement):size()
    local ok, reason = pcall(function()
        weapon:setCondition(nextCondition)
        if weapon:getCondition() ~= nextCondition then error("condition did not increase") end
        cloth:Use()
    end)
    local remaining = cloth:getCurrentUses()
    local container = cloth:getContainer()
    local replacementAdded = replacement and clothContainer:getItemsFromFullType(replacement):size() > existingReplacements
    local consumed = remaining == quote.uses - 1
        and ((remaining > 0 and container == clothContainer) or (remaining == 0 and not container))
        and (not replacement or replacementAdded)
    if weapon:getCondition() == nextCondition and consumed then
        if not ok then print("[SuQingMFSFirearmUpgrade] maintenance completed with error: " .. tostring(reason)) end
        return true
    end

    -- A towel stays put on a failed replacement. Ordinary cloth can still be removed by Use().
    if remaining ~= quote.uses and (container == clothContainer or (not container and not replacementAdded)) then
        cloth:setCurrentUses(quote.uses)
        if not container then clothContainer:AddItem(cloth) end
    end
    if weapon:getCondition() ~= quote.condition then
        weapon:setConditionWhileLoading(quote.condition)
    end
    print("[SuQingMFSFirearmUpgrade] maintenance failed: " .. tostring(reason or "cloth use did not register"))
    return false, ERROR_PREFIX .. "Failed"
end

function Core.checkTarget(character, weapon, mode, expectedLevel)
    local level, state, errorKey = readState(weapon)
    if errorKey then
        return false, errorKey
    end
    if expectedLevel ~= level then
        return false, ERROR_PREFIX .. "Stale"
    end
    errorKey = modeError(weapon, mode, level, state) or targetError(character and character:getInventory(), weapon, mode)
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
    errorKey = modeError(weapon, mode, level, state)
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
    local hitChance, currentHitChance

    if mode ~= "reset" then
        local maomao = mode == "maomao"
        nextLevel = maomao and level or level + 1
        tier = tiers[nextLevel]
        local damageBonus = maomao and MAOMAO_DAMAGE_BONUS or tier.multiplier
        local script = weapon:getScriptItem()
        local baseMinDamage = state and state.baseMinDamage or script and script:getMinDamage()
        local baseMaxDamage = state and state.baseMaxDamage or script and script:getMaxDamage()
        local baseMaxRange = state and state.baseMaxRange or readBaseRange(script)
        if not validDamage(baseMinDamage, baseMaxDamage) or not baseMaxRange then
            return nil, ERROR_PREFIX .. "InvalidState"
        end
        local originalRange, hitDelta
        if maomao then
            originalRange = captureMaoMaoRange(weapon, state, tiers[level])
            currentHitChance = weapon:getHitChance()
            hitDelta = maomaoHitDelta(weapon, currentHitChance)
            if not validSavedRange(originalRange) or not validHitChance(hitDelta) then
                return nil, ERROR_PREFIX .. "InvalidState"
            end
            hitChance = currentHitChance + hitDelta
        end
        nextState = {
            version = STATE_VERSION,
            fullType = weapon:getFullType(),
            level = nextLevel,
            baseMinDamage = baseMinDamage,
            baseMaxDamage = baseMaxDamage,
            baseMaxRange = baseMaxRange,
            minDelta = baseMinDamage * damageBonus,
            maxDelta = baseMaxDamage * damageBonus,
            maomao = maomao or nil,
            maomaoOriginalRange = originalRange,
            maomaoHitDelta = hitDelta,
        }
    elseif state and state.maomaoHitDelta ~= nil then
        currentHitChance = weapon:getHitChance()
        hitChance = currentHitChance - state.maomaoHitDelta
    end
    if hitChance ~= nil and not validHitChance(hitChance) then
        return nil, ERROR_PREFIX .. "InvalidState"
    end

    -- Subtract only our previous delta, keeping the gun's current attachment bonuses.
    local minDamage = currentMinDamage - minDelta + (nextState and nextState.minDelta or 0)
    local maxDamage = currentMaxDamage - maxDelta + (nextState and nextState.maxDelta or 0)
    local maxRange = currentMaxRange - rangeBonus(state, tiers[level]) + rangeBonus(nextState, tier)
    local minRange, minRangeRanged, maxSightRange
    if nextState and nextState.maomao then
        minRange, minRangeRanged, maxRange = 0, 0, MAOMAO_MAX_RANGE
        maxSightRange = MAOMAO_MAX_RANGE
    elseif state and state.maomaoOriginalRange then
        local original = state.maomaoOriginalRange
        minRange, minRangeRanged = original.min, original.minRanged
        maxRange = original.maxWithoutParts + attachmentRange(weapon)
        maxSightRange = original.maxSight
    end
    if not validDamage(currentMinDamage, currentMaxDamage) or not validDamage(minDamage, maxDamage)
        or not validNumber(currentMaxRange) or not validNumber(maxRange) then
        return nil, ERROR_PREFIX .. "InvalidState"
    end

    local inventory = character and character:getInventory()
    errorKey = targetError(inventory, weapon, mode)
    if not criticalHookReady then return nil, errorKey end
    local criticalBase = readCriticalBase(weapon)
    if not criticalBase then return nil, errorKey or ERROR_PREFIX .. "InvalidState" end
    local currentCritChance, currentCritMultiplier = criticalStats(criticalBase, tiers[level], state)
    local critChance, critMultiplier = criticalStats(criticalBase, tier, nextState)
    local currentNoiseRadius, currentNoiseRadiusPercent = Core.getNoiseRadius(weapon, level)
    local noiseRadius, noiseRadiusPercent = Core.getNoiseRadius(weapon, nextLevel)
    if mode == "reset" and noiseRadius == nil then noiseRadius = baselineNoiseRadius(weapon) end
    local quote = {
        level = level,
        nextLevel = nextLevel,
        currentMinDamage = currentMinDamage,
        currentMaxDamage = currentMaxDamage,
        minDamage = minDamage,
        maxDamage = maxDamage,
        currentMinRange = minRange and weapon:getMinRange(),
        currentMinRangeRanged = minRange and weapon:getMinRangeRanged(),
        currentMaxRange = currentMaxRange,
        currentMaxSightRange = maxSightRange and weapon:getMaxSightRange(),
        maxSightRange = maxSightRange,
        minRange = minRange,
        minRangeRanged = minRangeRanged,
        maxRange = maxRange,
        currentWearRoll = weapon:getConditionLowerChance(),
        wearRoll = wearRollFor(weapon, tier),
        currentHitChance = currentHitChance,
        hitChance = hitChance,
        currentCritChance = currentCritChance,
        currentCritMultiplier = currentCritMultiplier,
        currentNoiseRadius = currentNoiseRadius,
        currentNoiseRadiusPercent = currentNoiseRadiusPercent,
        noiseRadius = noiseRadius,
        noiseRadiusPercent = noiseRadiusPercent,
        rawNoiseRadius = noiseRadius and weapon:getSoundRadius(),
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
            or (quote.maxSightRange and weapon:getMaxSightRange() ~= quote.currentMaxSightRange)
            or (quote.minRange and (weapon:getMinRange() ~= quote.currentMinRange
                or weapon:getMinRangeRanged() ~= quote.currentMinRangeRanged))
            or weapon:getConditionLowerChance() ~= quote.currentWearRoll
            or (quote.noiseRadius ~= nil and weapon:getSoundRadius() ~= quote.rawNoiseRadius)
            or (quote.hitChance ~= nil and weapon:getHitChance() ~= quote.currentHitChance)
            or weapon:getCriticalChance() ~= previousCritChance
            or weapon:getCriticalDamageMultiplier() ~= previousCritMultiplier then
            error("weapon changed before applying the upgrade")
        end

        attemptedStats = true
        weapon:setMinDamage(quote.minDamage)
        weapon:setMaxDamage(quote.maxDamage)
        weapon:setMaxRange(quote.maxRange)
        if quote.maxSightRange then weapon:setMaxSightRange(quote.maxSightRange) end
        if quote.minRange then
            weapon:setMinRange(quote.minRange)
            weapon:setMinRangeRanged(quote.minRangeRanged)
        end
        if quote.hitChance ~= nil then weapon:setHitChance(quote.hitChance) end
        weapon:setCriticalChance(quote.critChance)
        weapon:setCriticalDamageMultiplier(quote.critMultiplier)
        weapon:setConditionLowerChance(quote.wearRoll)
        if quote.noiseRadius then weapon:setSoundRadius(quote.noiseRadius) end
        modData[STATE_KEY] = nextState
    end)
    if committed then
        return true
    end

    if attemptedStats then
        restore(function() weapon:setMinDamage(quote.currentMinDamage) end)
        restore(function() weapon:setMaxDamage(quote.currentMaxDamage) end)
        restore(function() weapon:setMaxRange(quote.currentMaxRange) end)
        if quote.maxSightRange then
            restore(function() weapon:setMaxSightRange(quote.currentMaxSightRange) end)
        end
        if quote.minRange then
            restore(function() weapon:setMinRange(quote.currentMinRange) end)
            restore(function() weapon:setMinRangeRanged(quote.currentMinRangeRanged) end)
        end
        if quote.hitChance ~= nil then
            restore(function() weapon:setHitChance(quote.currentHitChance) end)
        end
        restore(function() weapon:setCriticalChance(previousCritChance) end)
        restore(function() weapon:setCriticalDamageMultiplier(previousCritMultiplier) end)
        restore(function() weapon:setConditionLowerChance(quote.currentWearRoll) end)
        if quote.rawNoiseRadius then restore(function() weapon:setSoundRadius(quote.rawNoiseRadius) end) end
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
