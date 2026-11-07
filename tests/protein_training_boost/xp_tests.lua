-- Run with Lua 5.1/Kahlua from the repository root, or pass the absolute XP.lua
-- path as the first argument. This fixture never accesses a game save.
local modulePath = (arg and arg[1]) or
    "src/SuQingProteinTrainingBoost/42/media/lua/shared/SuQingProteinTrainingBoost/XP.lua"
local active, singlePlayer, worldHours, expiresAt = true, true, 0, 3
local logMessages, handlers = {}, {}
local B = {
    VERSION = "test",
    MULTIPLIER = 10,
    IsSinglePlayer = function() return singlePlayer end,
    IsActive = function() return active and worldHours < expiresAt end,
    Log = function(message) logMessages[#logMessages + 1] = message end,
}
package.loaded["SuQingProteinTrainingBoost/Core"] = B

local function perk(id)
    return { getId = function() return id end,
        getTotalXpForLevel = function() return 100000 end }
end
Perks = { Strength = perk("Strength"), Fitness = perk("Fitness"), Other = perk("Other") }
Events = { AddXP = {
    Add = function(handler) handlers[#handlers + 1] = handler end,
    Remove = function(handler)
        for i = #handlers, 1, -1 do
            if handlers[i] == handler then table.remove(handlers, i) end
        end
    end,
} }

local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 0.00001,
        (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local nativeObserverAfter = false
local function nativeObserver(player, skill, amount)
    local data = player:getModData()
    data.strengthUpTimer = tonumber(data.strengthUpTimer) or -50000
    data.fitnessUpTimer = tonumber(data.fitnessUpTimer) or -50000
    data.strengthMod = data.strengthMod or 0
    data.fitnessMod = data.fitnessMod or 0
    if amount > 0 and skill == Perks.Strength then
        data.strengthUpTimer = math.max(-50000, data.strengthUpTimer - 3000)
    elseif amount > 0 and skill == Perks.Fitness then
        data.fitnessUpTimer = math.max(-50000, data.fitnessUpTimer - 3000)
    end
end

local function fire(player, skill, amount)
    -- The production listener must work on either side of xpUpdate.addXp.
    if not nativeObserverAfter then nativeObserver(player, skill, amount) end
    for i = 1, #handlers do handlers[i](player, skill, amount) end
    if nativeObserverAfter then nativeObserver(player, skill, amount) end
end

local function newPlayer(proteins, globalMultiplier)
    local p = { proteins = proteins, global = globalMultiplier or 5,
        data = { strengthUpTimer = 20000, fitnessUpTimer = 18000,
            strengthMod = 7, fitnessMod = 8 }, total = {}, calls = 0 }
    local xp = {}
    function p:getModData() return self.data end
    function p:getXp() return xp end
    function p:getNutrition()
        return { getProteins = function() return p.proteins end }
    end
    function xp:getXP(skill) return p.total[skill] or 0 end
    function xp:AddXP(skill, amount, callLua, doBoost, remote, haloText)
        p.calls = p.calls + 1
        if p.fail then error("injected native failure") end
        if callLua == false and doBoost == false then
            assert(remote == false and haloText == false, "six-argument native bridge changed")
        end
        if skill == Perks.Strength then
            if p.proteins > 50 and p.proteins < 300 then amount = amount * 1.5 end
            if p.proteins < -300 then amount = amount * 0.7 end
        end
        if doBoost ~= false then amount = amount * p.global * (p.book or 1) end
        local old = self:getXP(skill)
        local value = math.min(100000, old + amount)
        p.total[skill] = value
        fire(p, skill, value - old) -- callLua=false intentionally does not suppress it.
        if p.failAfter then error("injected post-commit failure") end
        if p.failRestoreAfter then p.restoreBlocked = true end
    end
    return p
end

local flatCalls = 0
addXpNoMultiplier = function(player, skill, amount)
    flatCalls = flatCalls + 1 -- Represents SRJ's existing wrapper/accounting.
    player:getXp():AddXP(skill, amount, true, false, false)
    return "kept", nil, "tail"
end

local XP = dofile(modulePath)
assert(XP.Install())
assert(XP.Install())
assert(#handlers == 1, "duplicate event registration")

for _, case in ipairs({ { 0, 1 }, { 100, 1.5 }, { -400, 0.7 },
    { 50, 1 }, { 300, 1 }, { -300, 1 } }) do
    local p = newPlayer(case[1], 5)
    p:getXp():AddXP(Perks.Strength, 1)
    near(p:getXp():getXP(Perks.Strength), 50 * case[2], "global/protein stacking")
    assert(p.calls == 2, "recursive bonus must stop after one supplement")
    assert(p.data.strengthUpTimer == 17000, "duplicate native timer change")
    assert(p.data.fitnessUpTimer == 18000, "other timer changed")
    assert(p.data.strengthMod == 7 and p.data.fitnessMod == 8, "mod fields changed")
end

local p = newPlayer(100, 5)
p.book = 3
p:getXp():AddXP(Perks.Strength, 1)
near(p:getXp():getXP(Perks.Strength), 225, "book stacking")
p:getXp():AddXP(Perks.Fitness, 1)
near(p:getXp():getXP(Perks.Fitness), 150, "fitness ignores protein")

active = false
p = newPlayer(100)
p:getXp():AddXP(Perks.Strength, 1)
near(p:getXp():getXP(Perks.Strength), 7.5, "inactive")
active, worldHours = true, 3
p = newPlayer(0)
p:getXp():AddXP(Perks.Fitness, 1)
near(p:getXp():getXP(Perks.Fitness), 5, "expired")
worldHours = 0

p = newPlayer(0)
p.fail = true
local ok, reason = XP.Handle(p, Perks.Strength, 5)
assert(not ok and reason == "error", "native error was not reported")
assert(not XP._locks[p][Perks.Strength], "error retained reentry lock")
assert(XP.HasFault(p) == "error", "native error did not latch the player")
p.fail = false
local faultLogCount = #logMessages
assert(not XP.Handle(p, Perks.Strength, 5), "faulted player was retried")
assert(#logMessages == faultLogCount, "fault latch logged repeatedly")
p:getXp():AddXP(Perks.Fitness, 1)
near(p:getXp():getXP(Perks.Fitness), 5, "fault must cover the other skill too")
p = newPlayer(0)
assert(not XP.HasFault(p), "fault leaked to a different player")
assert(XP.Handle(p, Perks.Strength, 5), "different player did not work")
near(p:getXp():getXP(Perks.Strength), 45, "different player bonus")

-- Even an exception after XP and observer side effects were committed must
-- release the lock, restore duplicate timers, and never issue a second award.
p = newPlayer(0)
p.failAfter = true
ok, reason = XP.Handle(p, Perks.Strength, 5)
assert(not ok and reason == "error")
assert(not XP._locks[p][Perks.Strength], "post-commit error retained lock")
assert(p.calls == 1, "post-commit error was retried")
near(p:getXp():getXP(Perks.Strength), 45, "committed XP must not be rolled back")
assert(p.data.strengthUpTimer == 20000, "post-commit error retained duplicate timer change")
assert(XP.HasFault(p) == "error")
p.failAfter = false
faultLogCount = #logMessages
p:getXp():AddXP(Perks.Strength, 1)
near(p:getXp():getXP(Perks.Strength), 50, "normal event after partial award must stay unboosted")
assert(p.calls == 2 and #logMessages == faultLogCount)

-- A changed native path must latch a mismatch after the first uncertain award.
p = newPlayer(0)
local nativeAddXP = p:getXp().AddXP
p:getXp().AddXP = function(self, skill, amount, callLua, doBoost, remote, haloText)
    if callLua == false and doBoost == false then amount = amount * 2 end
    return nativeAddXP(self, skill, amount, callLua, doBoost, remote, haloText)
end
ok, reason = XP.Handle(p, Perks.Strength, 5)
assert(not ok and reason.reason == "mismatch" and XP.HasFault(p) == "mismatch")
assert(not XP._locks[p][Perks.Strength])
near(p:getXp():getXP(Perks.Strength), 90, "mismatch must not roll back XP")
faultLogCount = #logMessages
p:getXp():AddXP(Perks.Strength, 1)
near(p:getXp():getXP(Perks.Strength), 95, "mismatch latch did not stop next supplement")
assert(#logMessages == faultLogCount)

-- Simulate a ModData bridge failing only during final restoration.
p = newPlayer(0)
local backing = p.data
p.data = setmetatable({}, {
    __index = backing,
    __newindex = function(_, key, value)
        if p.restoreBlocked then error("injected timer restoration failure") end
        backing[key] = value
    end,
})
p.failRestoreAfter = true
ok, reason = XP.Handle(p, Perks.Fitness, 5)
assert(not ok and reason == "timer-restore-error")
assert(XP.HasFault(p) == "timer-restore-error" and not XP._locks[p][Perks.Fitness])
near(p:getXp():getXP(Perks.Fitness), 45, "timer failure must not roll back XP")
p.failRestoreAfter, p.restoreBlocked = false, false
faultLogCount = #logMessages
p:getXp():AddXP(Perks.Fitness, 1)
near(p:getXp():getXP(Perks.Fitness), 50, "timer restoration fault did not pause supplement")
assert(#logMessages == faultLogCount)

nativeObserverAfter = true
p = newPlayer(100)
p:getXp():AddXP(Perks.Strength, 1)
near(p:getXp():getXP(Perks.Strength), 75, "observer-order independence")
assert(p.data.strengthUpTimer == 17000, "later native observer ran more than once")
assert(p.data.strengthMod == 7 and p.data.fitnessMod == 8)
nativeObserverAfter = false

-- Restore nil fields as nil even if the native supplementary event initialized them.
p = newPlayer(0)
p.data = {}
assert(XP.Handle(p, Perks.Fitness, 5))
assert(p.data.strengthUpTimer == nil and p.data.fitnessUpTimer == nil)
assert(p.data.strengthMod == nil and p.data.fitnessMod == nil)

p = newPlayer(100)
local first, middle, last = addXpNoMultiplier(p, Perks.Strength, 10)
assert(first == "kept" and middle == nil and last == "tail", "wrapper lost return values")
near(p:getXp():getXP(Perks.Strength), 15, "flat grant got drink bonus")
assert(flatCalls == 1, "existing flat wrapper was not preserved")
assert(XP._flatDepth[p] == nil, "flat suppression was retained")
p.fail = true
assert(not pcall(addXpNoMultiplier, p, Perks.Strength, 1), "flat error not propagated")
assert(XP._flatDepth[p] == nil, "flat error retained suppression")

p = newPlayer(0)
p.total[Perks.Fitness] = 99998
p:getXp():AddXP(Perks.Fitness, 1)
near(p:getXp():getXP(Perks.Fitness), 100000, "level-10 cap")
assert(p.calls == 1, "maxed skill should not issue bonus call")

p = newPlayer(0)
p.total[Perks.Strength] = 99960
assert(XP.Handle(p, Perks.Strength, 5))
near(p:getXp():getXP(Perks.Strength), 100000, "bonus capped to remaining XP")

p = newPlayer(0)
assert(not XP.Handle(p, Perks.Other, 5))
assert(not XP.Handle(p, Perks.Strength, 0))
assert(not XP.Handle(p, Perks.Strength, -1))
assert(not XP.Handle(p, Perks.Strength, 0 / 0))
singlePlayer = false
assert(not XP.Handle(p, Perks.Strength, 5))
assert(not XP.Install())

print("protein_training_boost XP tests passed")
