local Core = {}

local MATERIALS = {
    { type = "Base.DishCloth", replacement = "Base.DishClothWet", drainable = true },
    { type = "Base.BathTowel", replacement = "Base.BathTowelWet", drainable = true },
    { type = "Base.RippedSheets", replacement = "Base.RippedSheetsDirty", drainable = false },
    { type = "Base.DenimStrips", replacement = "Base.DenimStripsDirty", drainable = false },
    { type = "Base.BurlapPiece", drainable = false },
    { type = "Base.CheeseCloth", drainable = false },
    { type = "Base.Bandage", replacement = "Base.BandageDirty", drainable = false },
}
local SHARPNESS_GAIN = 0.05
local EPSILON = 0.000001

local SPECIAL_AMMO = {
    ["base.capguncap"] = true,
    ["base.crossbowbolt"] = true,
    ["base.grenadeammo"] = true,
    ["flamethrower.flamefuel"] = true,
}

local SPECIAL_WEAPONS = {
    ["Base.MTL30_cat"] = true,
    ["Base.MFS_MTL30_cat"] = true,
    ["Flamethrower.Flamethrower"] = true,
}

function Core.isSupportedFirearm(weapon)
    if not instanceof(weapon, "HandWeapon") or not weapon:isRanged() or not weapon:isAimedFirearm() then
        return false
    end
    local ammo = weapon:getAmmoType()
    local itemKey = ammo and ammo:getItemKey()
    return type(itemKey) == "string" and itemKey ~= ""
        and not SPECIAL_AMMO[string.lower(itemKey)] and not SPECIAL_WEAPONS[weapon:getFullType()]
end

function Core.isSupported(weapon)
    if not instanceof(weapon, "HandWeapon") then return false end
    if weapon:isRanged() then return Core.isSupportedFirearm(weapon) end
    if weapon:isBareHands() or weapon:getMaxDamage() <= 0 then
        return false
    end
    local projectile = weapon:getPhysicsObject()
    return projectile == nil or projectile == ""
end

local function usableCloth(item, material)
    return item and item:getFullType() == material.type
        and instanceof(item, "DrainableComboItem") == material.drainable
        and not item:isWet() and item:getCurrentUses() > 0
end

local function conditionAfterWipe(current, maximum)
    return math.max(current, math.min(current + 1, maximum))
end

local function inspectWeapon(inventory, weapon)
    if not Core.isSupported(weapon) then return nil, "Unsupported" end
    if not inventory or not weapon:getContainer() or not inventory:contains(weapon, true) then
        return nil, "NotCarried"
    end

    local firearm = weapon:isRanged()
    local condition = weapon:getCondition()
    local conditionMax = weapon:getConditionMax()
    if weapon:isBroken() or condition <= 0 or conditionMax <= 0 then return nil, "Broken" end
    if firearm and (weapon:isRoundChambered() or weapon:isSpentRoundChambered()
        or weapon:getCurrentAmmoCount() ~= 0 or weapon:isContainsClip()) then
        return nil, "Unload"
    end

    local state = {
        firearm = firearm,
        condition = condition,
        conditionMax = conditionMax,
        nextCondition = conditionAfterWipe(condition, conditionMax),
    }
    local bladeCondition = state.nextCondition
    local bladeConditionMax = conditionMax
    if not firearm and weapon:hasHeadCondition() then
        state.headCondition = weapon:getHeadCondition()
        state.headConditionMax = weapon:getHeadConditionMax()
        if state.headCondition <= 0 or state.headConditionMax <= 0 then return nil, "Broken" end
        state.nextHeadCondition = conditionAfterWipe(state.headCondition, state.headConditionMax)
        bladeCondition = state.nextHeadCondition
        bladeConditionMax = state.headConditionMax
    end
    if not firearm and weapon:hasSharpness() then
        state.sharpness = weapon:getSharpness()
        -- Preview the native sharpness ceiling using the condition after the wipe.
        local limit = math.min(1, bladeCondition / bladeConditionMax)
        local sharpness = math.min(state.sharpness + SHARPNESS_GAIN, limit)
        state.nextSharpness = state.sharpness
        if sharpness > state.sharpness + EPSILON then state.nextSharpness = sharpness end
    end
    if state.condition == state.nextCondition and state.headCondition == state.nextHeadCondition
        and state.sharpness == state.nextSharpness then
        return nil, "NoGain"
    end
    return state
end

function Core.getQuote(character, weapon)
    if isClient() or isServer() then return nil, "Unsupported" end
    local inventory = character and character:getInventory()
    local state, reason = inspectWeapon(inventory, weapon)
    if not state then return nil, reason end

    local quotes = {}
    for _, material in ipairs(MATERIALS) do
        local cloth = inventory:getFirstTypeEvalRecurse(material.type, function(item)
            return usableCloth(item, material)
        end)
        if cloth then
            local quote = { cloth = cloth, uses = cloth:getCurrentUses(), material = material }
            for key, value in pairs(state) do quote[key] = value end
            quotes[#quotes + 1] = quote
        end
    end
    if #quotes == 0 then return nil, "DryCloth" end
    return quotes[1], nil, quotes
end

function Core.check(character, weapon, quote)
    if isClient() or isServer() then return false, "Unsupported" end
    local inventory = character and character:getInventory()
    local current, reason = inspectWeapon(inventory, weapon)
    if not current then return false, reason end
    if not quote or current.firearm ~= quote.firearm
        or current.condition ~= quote.condition or current.conditionMax ~= quote.conditionMax
        or current.headCondition ~= quote.headCondition or current.headConditionMax ~= quote.headConditionMax
        or current.sharpness ~= quote.sharpness then
        return false, "Stale"
    end
    local cloth = quote.cloth
    if not usableCloth(cloth, quote.material) or not cloth:getContainer() or not inventory:contains(cloth, true) then
        return false, "DryCloth"
    end
    if cloth:getCurrentUses() ~= quote.uses then return false, "Stale" end
    return true
end

function Core.wipe(character, weapon, quote)
    local allowed, reason = Core.check(character, weapon, quote)
    if not allowed then return false, reason end

    local cloth = quote.cloth
    local clothContainer = cloth:getContainer()
    local replacement = quote.uses == 1 and quote.material.replacement
    local existingReplacements = replacement and clothContainer:getItemsFromFullType(replacement):size()
    local applied = false
    local ok, failure = pcall(function()
        if quote.condition ~= quote.nextCondition then
            weapon:setCondition(quote.nextCondition)
        end
        if quote.headCondition ~= quote.nextHeadCondition then
            weapon:setHeadCondition(quote.nextHeadCondition)
        end
        if quote.sharpness ~= quote.nextSharpness then
            local limit = math.min(1, weapon:getMaxSharpness())
            weapon:setSharpness(math.min(quote.nextSharpness, limit))
        end
        if weapon:getCondition() ~= quote.nextCondition
            or (quote.nextHeadCondition and weapon:getHeadCondition() ~= quote.nextHeadCondition)
            or (quote.nextSharpness and math.abs(weapon:getSharpness() - quote.nextSharpness) > EPSILON) then
            error("weapon state differs from preview")
        end
        applied = true
        cloth:Use()
    end)

    local remaining = cloth:getCurrentUses()
    local container = cloth:getContainer()
    local replacementAdded = replacement and clothContainer:getItemsFromFullType(replacement):size() > existingReplacements
    local consumed = remaining == quote.uses - 1
        and ((remaining > 0 and container == clothContainer) or (remaining == 0 and not container))
        and (not replacement or replacementAdded)
    if applied and consumed then
        if not ok then print("[SuQingMeleeWeaponWipe] wipe completed with error: " .. tostring(failure)) end
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
    if quote.headCondition and weapon:getHeadCondition() ~= quote.headCondition then
        weapon:setHeadCondition(quote.headCondition)
    end
    if quote.sharpness and math.abs(weapon:getSharpness() - quote.sharpness) > EPSILON then
        weapon:setSharpness(quote.sharpness)
    end
    print("[SuQingMeleeWeaponWipe] wipe failed: " .. tostring(failure or "cloth use did not register"))
    return false, "Failed"
end

return Core
