local core = require("SuQingMFSFirearmUpgrade/Core")
local metal = "Base.part2_cat"
local polymer = "Base.part3_cat"
local stateKey = "SuQingMFSFirearmUpgrade"

local function list(items)
    return {
        size = function() return #items end,
        get = function(_, index) return items[index + 1] end,
    }
end

ItemTag = { SCREWDRIVER = "screwdriver", HAMMER = "hammer" }
local client, server, damageSandbox = false, false, false
function isClient() return client end
function isServer() return server end
function getActivatedMods()
    return { contains = function(_, id) return damageSandbox and id == "ModernFirearmsSystemDamageSandbox" end }
end
function instanceof(item, class)
    return item and item.class == class
end

local function newItem(fullType, class, tag)
    return {
        fullType = fullType,
        class = class,
        tag = tag,
        getFullType = function(self) return self.fullType end,
        getContainer = function(self) return self.container end,
        isBroken = function(self) return self.broken == true end,
    }
end

local inventoryMethods = {}

function inventoryMethods:contains(item, recurse)
    for _, candidate in ipairs(self.items) do
        if candidate == item then return true end
    end
    return recurse and self.bag and self.bag:contains(item, true) or false
end

function inventoryMethods:getFirstTagEvalRecurse(tag, evaluate)
    for _, item in ipairs(self.items) do
        if item.tag == tag and evaluate(item) then return item end
    end
    return self.bag and self.bag:getFirstTagEvalRecurse(tag, evaluate)
end

function inventoryMethods:getAllTypeRecurse(fullType)
    local matches = {}
    for _, item in ipairs(self.items) do
        if item.fullType == fullType then matches[#matches + 1] = item end
    end
    if self.bag then
        local nested = self.bag:getAllTypeRecurse(fullType)
        for index = 0, nested:size() - 1 do matches[#matches + 1] = nested:get(index) end
    end
    return list(matches)
end

function inventoryMethods:getFirstTypeEvalRecurse(fullType, evaluate)
    local matches = self:getAllTypeRecurse(fullType)
    for i = 0, matches:size() - 1 do
        local item = matches:get(i)
        if evaluate(item) then return item end
    end
end

function inventoryMethods:AddItem(item)
    self.items[#self.items + 1] = item
    item.container = self
    return item
end

function inventoryMethods:Remove(item)
    if item == self.failRemoval then return end
    for index, candidate in ipairs(self.items) do
        if candidate == item then
            table.remove(self.items, index)
            item.container = nil
            return
        end
    end
end

local function newInventory()
    return setmetatable({ items = {} }, { __index = inventoryMethods })
end

local function newWeapon(fullType, ammo)
    local gun = newItem(fullType or "Base.G17_cat", "HandWeapon")
    gun.baseMin, gun.baseMax = 1.7, 2
    gun.min, gun.max = gun.baseMin, gun.baseMax
    gun.baseRange, gun.range = 51, 51
    gun.baseWearRoll, gun.wearRoll = 118, 118
    gun.condition, gun.conditionMax = 19, 25
    gun.ammo, gun.loaded, gun.md = ammo or "Base.Bullets9mm", 0, { MFS = "keep" }
    gun.critChance, gun.critMultiplier, gun.parts = 20, 2, {}
    function gun:IsWeapon() return true end
    function gun:isRanged() return not self.melee end
    function gun:isAimedFirearm() return not self.melee end
    function gun:getAmmoType()
        if self.ammo then return { getItemKey = function() return self.ammo end } end
    end
    function gun:getScriptItem()
        return {
            getMinDamage = function() return self.baseMin end,
            getMaxDamage = function() return self.baseMax end,
            getMaxRange = function() return self.baseRange end,
            getConditionLowerChance = function() return self.baseWearRoll end,
        }
    end
    function gun:getModData() return self.md end
    function gun:hasModData()
        for _ in pairs(self.md) do return true end
        return false
    end
    function gun:isRoundChambered() return self.chambered == true end
    function gun:isSpentRoundChambered() return self.spent == true end
    function gun:isContainsClip() return self.clip == true end
    function gun:getCurrentAmmoCount() return self.loaded end
    function gun:getAllWeaponParts() return list(self.parts) end
    function gun:getCriticalChance() return self.critChance end
    function gun:getCriticalDamageMultiplier() return self.critMultiplier end
    function gun:setCriticalChance(value) self.critChance = value end
    function gun:setCriticalDamageMultiplier(value)
        if self.failCritical then
            self.failCritical = false
            error("simulated critical setter failure")
        end
        self.critMultiplier = value
    end
    function gun:getCondition() return self.condition end
    function gun:getConditionMax() return self.conditionMax end
    function gun:setCondition(value)
        if not self.failCondition then
            self.condition = math.max(0, math.min(self.conditionMax, value))
        end
    end
    function gun:setConditionWhileLoading(value) self.condition = value end
    function gun:getConditionLowerChance() return self.wearRoll end
    function gun:setConditionLowerChance(value)
        if self.failWear then
            self.failWear = false
            error("simulated wear setter failure")
        end
        self.wearRoll = value
    end
    function gun:getMaxRange() return self.range end
    function gun:setMaxRange(value) self.range = value end
    function gun:getMinDamage() return self.min end
    function gun:getMaxDamage() return self.max end
    function gun:setMinDamage(value) self.min = value end
    function gun:setMaxDamage(value)
        if self.failSetter then
            self.failSetter = false
            error("simulated damage setter failure")
        end
        self.max = value
    end
    return gun
end

function instanceItem(fullType)
    return newWeapon(fullType)
end

local function fixture(metals, polymers)
    local inventory = newInventory()
    inventory.bag = newInventory()
    local first = inventory.bag:AddItem(newWeapon())
    local second = inventory:AddItem(newWeapon())
    local screwdriver = inventory.bag:AddItem(newItem("Base.Screwdriver", nil, ItemTag.SCREWDRIVER))
    local hammer = inventory:AddItem(newItem("Base.Hammer", nil, ItemTag.HAMMER))
    for index = 1, metals do
        inventory:AddItem(newItem(metal))
    end
    for index = 1, polymers do
        inventory.bag:AddItem(newItem(polymer))
    end
    local player = { getInventory = function() return inventory end }
    return player, inventory, first, second, screwdriver, hammer
end

local function close(actual, expected)
    assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " differs from " .. tostring(expected))
end

local function count(inventory, fullType)
    return inventory:getAllTypeRecurse(fullType):size()
end

local function blocked(player, gun, mode, expectedLevel, reason)
    local result, message = core.commit(player, gun, mode, expectedLevel)
    assert(not result, "commit should have been blocked")
    local key = "UI_SuQingMFSFirearmUpgrade_Error_" .. reason
    assert(message == key, "expected " .. key .. ", got " .. tostring(message))
    assert(MFSUpgradeTranslations[message], "missing translation for " .. message)
end

local player, inventory, gun, sameModel, screwdriver, hammer = fixture(30, 21)
local metalCost = { 2, 4, 6, 8, 10 }
local polymerCost = { 1, 2, 4, 6, 8 }
local multipliers = { 1.10, 1.20, 1.30, 1.40, 1.50 }
local critPoints = { 20, 35, 50, 75, 100 }
local wearRolls = { 131, 148, 169, 197, 236 }
local critMultipliers = { 1.10, 1.20, 1.50, 1.75, 2.00 }
local remainingMetal, remainingPolymer = 30, 21
local attachment = 0.2
local attachmentRange = 5
gun.min, gun.max = gun.min + attachment, gun.max + attachment
gun.range = gun.range + attachmentRange
gun.parts = { { getType = function() return "VortexSight" end } }

blocked(player, gun, "upgrade", 0, "CriticalIntegration")
require("Gun_Vars/EFK_Part_Stat_Set")
core.installCriticalHook()
local installedHook = AWCWF_ApplyPartStats
core.installCriticalHook()
assert(AWCWF_ApplyPartStats == installedHook)
AWCWF_ApplyPartStats(player, gun)
close(gun.critChance, 25)
close(gun.critMultiplier, 2.25)

for level, multiplier in ipairs(multipliers) do
    local quote, problem = core.getQuote(player, gun, "upgrade")
    assert(quote and not problem, tostring(problem))
    assert(quote.level == level - 1 and quote.nextLevel == level)
    close(quote.minDamage, gun.baseMin * multiplier + attachment)
    close(quote.maxDamage, gun.baseMax * multiplier + attachment)
    close(quote.maxRange, gun.baseRange * multiplier + attachmentRange)
    assert(quote.wearRoll == wearRolls[level])
    close(quote.critChance, 25 + critPoints[level])
    close(quote.critMultiplier, 2 * critMultipliers[level] + 0.25)
    assert(count(inventory, metal) == remainingMetal and count(inventory, polymer) == remainingPolymer)
    assert(core.commit(player, gun, "upgrade", level - 1))
    remainingMetal = remainingMetal - metalCost[level]
    remainingPolymer = remainingPolymer - polymerCost[level]
    assert(count(inventory, metal) == remainingMetal and count(inventory, polymer) == remainingPolymer)
    assert(inventory:contains(screwdriver, true) and inventory:contains(hammer, true))
    assert(core.getState(gun) == level and core.getState(sameModel) == 0)
    close(gun.min, gun.baseMin * multiplier + attachment)
    close(gun.max, gun.baseMax * multiplier + attachment)
    close(gun.critChance, quote.critChance)
    close(gun.critMultiplier, quote.critMultiplier)
    AWCWF_ApplyPartStats(player, gun)
    AWCWF_ApplyPartStats(player, gun)
    close(gun.critChance, quote.critChance)
    close(gun.critMultiplier, quote.critMultiplier)
    close(gun.range, quote.maxRange)
    close(sameModel.range, sameModel.baseRange)
    assert(gun.wearRoll == wearRolls[level] and sameModel.wearRoll == 118)
    assert(gun.condition == 19 and gun.conditionMax == 25)
    close(sameModel.critChance, 20)
    close(sameModel.critMultiplier, 2)
    close(sameModel.min, sameModel.baseMin)
    close(sameModel.max, sameModel.baseMax)
    assert(gun.md.MFS == "keep")
    if level < #multipliers then
        blocked(player, gun, "upgrade", level - 1, "Stale")
    end
end
blocked(player, gun, "upgrade", 5, "MaxLevel")

-- Simulate native save/load preserving the saved numeric fields and modData.
local loadedGun = newWeapon()
loadedGun.min, loadedGun.max, loadedGun.range = gun.min, gun.max, gun.range
loadedGun.parts = gun.parts
loadedGun.md[stateKey] = {}
for key, value in pairs(gun.md[stateKey]) do loadedGun.md[stateKey][key] = value end
inventory:AddItem(loadedGun)
assert(core.getState(loadedGun) == 5)
blocked(player, loadedGun, "upgrade", 5, "MaxLevel")
close(loadedGun.min, 2.55 + attachment)
close(loadedGun.max, 3 + attachment)
close(loadedGun.range, 76.5 + attachmentRange)
close(loadedGun.critChance, 20)
close(loadedGun.critMultiplier, 2)
assert(loadedGun.wearRoll == 118)
AWCWF_ApplyPartStats(player, loadedGun)
assert(loadedGun.wearRoll == 236)
close(loadedGun.critChance, 125)
close(loadedGun.critMultiplier, 4.25)
loadedGun.parts = {}
loadedGun.min, loadedGun.max = loadedGun.min - attachment, loadedGun.max - attachment
loadedGun.range = loadedGun.range - attachmentRange
AWCWF_ApplyPartStats(player, loadedGun)
close(loadedGun.critChance, 120)
close(loadedGun.critMultiplier, 4)
close(loadedGun.range, 76.5)
assert(core.commit(player, loadedGun, "reset", 5))
AWCWF_ApplyPartStats(player, loadedGun)
assert(loadedGun.wearRoll == 118 and loadedGun.condition == 19 and loadedGun.conditionMax == 25)
close(loadedGun.critChance, 20)
close(loadedGun.critMultiplier, 2)
assert(core.getState(loadedGun) == 0 and loadedGun.md[stateKey] == nil)
assert(loadedGun.md.MFS == "keep" and core.getState(gun) == 5)
close(loadedGun.min, 1.7)
close(loadedGun.max, 2)
close(loadedGun.range, 51)
blocked(player, loadedGun, "reset", 0, "NoUpgrade")

-- 0.2.0 already saved damage and rank. It receives the range bonus once.
local oldGun = inventory:AddItem(newWeapon())
oldGun.min, oldGun.max = gun.min, gun.max
oldGun.range = oldGun.baseRange + attachmentRange
oldGun.md[stateKey] = {}
for key, value in pairs(gun.md[stateKey]) do
    if key ~= "baseMaxRange" then oldGun.md[stateKey][key] = value end
end
assert(core.getState(oldGun) == 5)
AWCWF_ApplyPartStats(player, oldGun)
AWCWF_ApplyPartStats(player, oldGun)
close(oldGun.range, 76.5 + attachmentRange)
close(oldGun.min, gun.min)
close(oldGun.max, gun.max)
assert(count(inventory, metal) == 0 and count(inventory, polymer) == 0)
assert(core.commit(player, oldGun, "reset", 5))
close(oldGun.range, 51 + attachmentRange)

local secondPlayer, bag, unloaded, _, nestedDriver, ownedHammer = fixture(3, 2)
for _, unsafe in ipairs({ "chambered", "spent", "clip", "loaded" }) do
    unloaded[unsafe] = unsafe == "loaded" and 1 or true
    blocked(secondPlayer, unloaded, "upgrade", 0, "Unload")
    unloaded[unsafe] = unsafe == "loaded" and 0 or false
end
unloaded.broken = true
blocked(secondPlayer, unloaded, "upgrade", 0, "Broken")
unloaded.broken = false
nestedDriver.broken = true
blocked(secondPlayer, unloaded, "upgrade", 0, "Screwdriver")
nestedDriver.broken = false
ownedHammer.broken = true
blocked(secondPlayer, unloaded, "upgrade", 0, "Hammer")
ownedHammer.broken = false
blocked(secondPlayer, newWeapon(), "upgrade", 0, "NotOwned")
client = true
blocked(secondPlayer, unloaded, "upgrade", 0, "Multiplayer")
client, server = false, true
blocked(secondPlayer, unloaded, "upgrade", 0, "Multiplayer")
server, damageSandbox = false, true
blocked(secondPlayer, unloaded, "upgrade", 0, "DamageSandbox")
damageSandbox = false
MFSDamageSandbox = { Apply = function() end }
blocked(secondPlayer, unloaded, "upgrade", 0, "DamageSandbox")
MFSDamageSandbox = nil

assert(not core.isSupported(newItem("Base.Screws")))
for _, ammo in ipairs({ "Base.CrossbowBolt", "Base.GrenadeAmmo", "Flamethrower.FlameFuel" }) do
    local special = bag:AddItem(newWeapon("Base.SpecialGun", ammo))
    assert(not core.isSupported(special), ammo)
    blocked(secondPlayer, special, "upgrade", 0, "Unsupported")
end
unloaded.md[stateKey] = {
    level = 4, version = 1, fullType = unloaded.fullType,
    baseMinDamage = 1.7, baseMaxDamage = 2, minDelta = 1.275, maxDelta = 1.5,
}
blocked(secondPlayer, unloaded, "upgrade", 0, "InvalidState")
unloaded.md[stateKey] = nil

unloaded.failSetter = true
blocked(secondPlayer, unloaded, "upgrade", 0, "Failed")
assert(count(bag, metal) == 3 and count(bag, polymer) == 2)
assert(core.getState(unloaded) == 0 and unloaded.md.MFS == "keep")
close(unloaded.min, 1.7)
close(unloaded.max, 2)

unloaded.failCritical = true
blocked(secondPlayer, unloaded, "upgrade", 0, "Failed")
assert(count(bag, metal) == 3 and count(bag, polymer) == 2)
assert(core.getState(unloaded) == 0)
close(unloaded.min, 1.7)
close(unloaded.max, 2)
close(unloaded.critChance, 20)
close(unloaded.critMultiplier, 2)
close(unloaded.range, 51)

unloaded.failWear = true
blocked(secondPlayer, unloaded, "upgrade", 0, "Failed")
assert(count(bag, metal) == 3 and count(bag, polymer) == 2)
assert(core.getState(unloaded) == 0 and unloaded.wearRoll == 118)
close(unloaded.critChance, 20)
close(unloaded.critMultiplier, 2)
close(unloaded.range, 51)

bag.bag.failRemoval = bag:getAllTypeRecurse(polymer):get(0)
blocked(secondPlayer, unloaded, "upgrade", 0, "Failed")
assert(count(bag, metal) == 3 and count(bag, polymer) == 2)
assert(core.getState(unloaded) == 0)
close(unloaded.min, 1.7)
close(unloaded.max, 2)
bag.bag.failRemoval = nil

local quote = assert(core.getQuote(secondPlayer, unloaded, "upgrade"))
bag:Remove(bag:getAllTypeRecurse(metal):get(0))
bag:Remove(bag:getAllTypeRecurse(metal):get(0))
blocked(secondPlayer, unloaded, "upgrade", quote.level, "Materials")
assert(core.getState(unloaded) == 0 and count(bag, metal) == 1 and count(bag, polymer) == 2)
close(unloaded.min, 1.7)
close(unloaded.max, 2)

MFSUpgradeFixture = { new = fixture, newWeapon = newWeapon, count = count, close = close, metal = metal, polymer = polymer }
