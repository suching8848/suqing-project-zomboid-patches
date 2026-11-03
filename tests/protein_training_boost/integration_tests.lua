-- Exercise the actual installed B42 drink update, both bridge modules and Core.
assert(GAME_DRINK_SOURCE_PATH, "the integration suite needs --game-root")
local now = 100
getGameTime = function() return { getWorldAgeHours = function() return now end } end
isClient = function() return false end
isServer = function() return false end
local B = require "SuQingProteinTrainingBoost/Core"

ISBaseTimedAction = { derive = function(_, name) return { Type = name } end }
package.loaded["TimedActions/ISBaseTimedAction"] = ISBaseTimedAction
dofile(GAME_DRINK_SOURCE_PATH)
package.loaded["TimedActions/ISDrinkFluidAction"] = ISDrinkFluidAction

local function perk(name)
    return { getId = function() return name end,
        getTotalXpForLevel = function() return 487500 end }
end
Perks = { Strength = perk("Strength"), Fitness = perk("Fitness"), Cooking = perk("Cooking") }
local handlers = {}
Events = { AddXP = { Add = function(fn) handlers[#handlers + 1] = fn end } }
local fluidTypes = {}
for _, id in ipairs(B.FLUID_IDS) do fluidTypes[id] = id end
Fluid = { Get = function(id) return fluidTypes[id] end }

local player = { md = { strengthUpTimer = 20000, fitnessUpTimer = 20000 }, totals = {}, proteins = 100 }
function player:getModData() return self.md end
function player:isDead() return false end
function player:getNutrition() return { getProteins = function() return self.proteins end } end
function player:getInventory() return { contains = function() return true end } end
local xp = {}
function player:getXp() return xp end
function xp:getXP(skill) return player.totals[skill] or 0 end
function xp:AddXP(skill, amount, callLua, boost)
    if skill == Perks.Strength then
        if player.proteins > 50 and player.proteins < 300 then amount = amount * 1.5 end
        if player.proteins < -300 then amount = amount * 0.7 end
    end
    if boost ~= false then amount = amount * 5 end
    local old = self:getXP(skill)
    player.totals[skill] = math.min(487500, old + amount)
    amount = player.totals[skill] - old
    -- Deliberately fire even with callLua=false, like the installed B42.21 class.
    local md = player:getModData()
    if amount > 0 and skill == Perks.Strength then md.strengthUpTimer = md.strengthUpTimer - 3000 end
    if amount > 0 and skill == Perks.Fitness then md.fitnessUpTimer = md.fitnessUpTimer - 3000 end
    for _, handler in ipairs(handlers) do handler(player, skill, amount) end
end
addXpNoMultiplier = function(p, skill, amount) p:getXp():AddXP(skill, amount, true, false, false) end
local X = require "SuQingProteinTrainingBoost/XP"
local D = require "SuQingProteinTrainingBoost/Drinking"
assert(X.Install())
assert(D.Install())

local function container(contents, capacity)
    local c = { contents = contents, capacity = capacity or 0.5 }
    function c:getAmount()
        local total = 0
        for _, litres in pairs(self.contents) do total = total + litres end
        return total
    end
    function c:getFilledRatio() return self:getAmount() / self.capacity end
    function c:getSpecificFluidAmount(fluid) return self.contents[fluid] or 0 end
    return c
end
function player:DrinkFluid(item, fraction)
    for id, volume in pairs(item.container.contents) do
        item.container.contents[id] = volume * (1 - fraction)
    end
end
local function action(c, fraction)
    return setmetatable({ character = player, fluidContainer = c,
        item = { container = c, syncItemFields = function() end },
        startRatio = c:getFilledRatio(), targetConsumedRatio = c:getFilledRatio() * fraction },
        { __index = ISDrinkFluidAction })
end
local function near(actual, wanted, label)
    assert(math.abs(actual - wanted) < 0.00001, label .. ": " .. tostring(actual))
end

local vanilla = "VFX_VanillaProteinShake"
local strawberry = "VFX_StrawberryProteinShakeCowMilk"
local c = container({ [vanilla] = 0.5 })
local a = action(c, 1)
a:updateEat(0.25)
near(B.GetRemainingHours(player), 0.75, "first quarter is forty-five minutes")
xp:AddXP(Perks.Strength, 1)
near(xp:getXP(Perks.Strength), 75, "global five and protein 1.5, then x10")
near(player.md.strengthUpTimer, 17000, "single native training-timer change")
a:updateEat(0.25)
near(B.GetRemainingHours(player), 0.75, "duplicate progress grants no extra time")
a:updateEat(0.5)
near(B.GetRemainingHours(player), 1.5, "half drink retained after interruption")
xp:AddXP(Perks.Fitness, 1)
near(xp:getXP(Perks.Fitness), 50, "global five and final ten for Fitness")
near(player.md.fitnessUpTimer, 17000, "Fitness timer unchanged by supplemental event")
a:complete()
near(B.GetRemainingHours(player), 3, "complete drinks only the remainder")

now = 101
local mixed = action(container({ [strawberry] = 0.125, Water = 0.375 }), 1)
mixed:complete()
near(B.GetRemainingHours(player), 2.75, "dilution grants only the protein-shake portion")
local before = xp:getXP(Perks.Strength)
addXpNoMultiplier(player, Perks.Strength, 10)
near(xp:getXP(Perks.Strength) - before, 15, "journal/flat XP is not amplified again")
xp:AddXP(Perks.Cooking, 1)
near(xp:getXP(Perks.Cooking), 5, "unrelated skill unchanged")
now = 103.75
assert(not B.IsActive(player), "exact expiry ends the boost")
before = xp:getXP(Perks.Strength)
xp:AddXP(Perks.Strength, 1)
near(xp:getXP(Perks.Strength) - before, 7.5, "normal gain returns after expiry")
local water = action(container({ Water = 0.5 }), 1)
water:complete()
assert(not B.IsActive(player), "water in the same container does not activate the effect")
print("protein_training_boost integration tests passed")
return { suite = "protein_training_boost/integration", checks = 14 }
