local B = require "SuQingProteinTrainingBoost/Core"

B.XP = B.XP or {}
local XP = B.XP

XP._locks = XP._locks or setmetatable({}, { __mode = "k" })
XP._flatDepth = XP._flatDepth or setmetatable({}, { __mode = "k" })
XP._faults = XP._faults or setmetatable({}, { __mode = "k" })

local TRAINING_FIELDS = {
    "strengthUpTimer", "strengthMod", "fitnessUpTimer", "fitnessMod",
}

local function finite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function log(message)
    -- Logging must never keep an XP lock held or interrupt another event observer.
    if type(B.Log) == "function" then pcall(B.Log, message) end
end

function XP.HasFault(player)
    return player and XP._faults[player] or nil
end

local function latchFault(player, reason, message)
    if not XP._faults[player] then
        XP._faults[player] = reason
        log(message)
    end
end

local function skillKind(perk)
    if not Perks then return nil end
    if perk == Perks.Strength then return "strength" end
    if perk == Perks.Fitness then return "fitness" end
    return nil
end

local function pack(...)
    return { n = select("#", ...), ... }
end

-- The native protein adjustment runs even when doXPBoost is false.
-- This is deliberately not a replacement for the character's nutrition state.
function XP.GetProteinFactor(player, perk)
    if skillKind(perk) ~= "strength" then return 1 end
    local nutrition = player:getNutrition()
    if not nutrition then error("missing character nutrition") end
    local proteins = nutrition:getProteins()
    if not finite(proteins) then error("invalid character protein value") end
    if proteins > 50 and proteins < 300 then return 1.5 end
    if proteins < -300 then return 0.7 end
    return 1
end

-- Public bridge so the native overload and its recursive event can be tested.
-- In B42.21 callLua=false does NOT suppress Events.AddXP; Handle's lock does.
-- doXPBoost=false skips the second sandbox/book calculation, not nutrition.
function XP.AddXP(player, perk, input)
    return player:getXp():AddXP(perk, input, false, false, false, false)
end

local function snapshotTrainingData(player)
    local data = player:getModData()
    if type(data) ~= "table" then error("missing character ModData") end
    local saved = {}
    for i = 1, #TRAINING_FIELDS do
        local field = TRAINING_FIELDS[i]
        saved[i] = data[field]
    end
    return data, saved
end

local function restoreTrainingData(data, saved)
    for i = 1, #TRAINING_FIELDS do
        -- Assignment also restores an originally absent field to nil.
        data[TRAINING_FIELDS[i]] = saved[i]
    end
end

-- The same effective multiplier is used by the award and the status panel.
function XP.GetMultiplier(player)
    if B.RuntimeReady == false or XP.HasFault(player) then return nil end
    local iron = 1
    if B.Iron then
        iron = B.Iron.GetMultiplier(player)
        if not iron then return nil end
    end
    return iron * (B.IsActive(player) and B.MULTIPLIER or 1)
end

-- amount is the positive increment already committed by the native XP method.
-- Return values are diagnostic; the Events API ignores them.
function XP.Handle(player, perk, amount)
    if not B.IsSinglePlayer() then return false, "multiplayer" end
    if not player or not skillKind(perk) then return false, "unrelated" end
    if not finite(amount) or amount <= 0 then return false, "nonpositive" end
    -- A previous uncertain award must never be repeated in this game session.
    -- This is per character, covering both skills, and leaves normal XP alone.
    if XP.HasFault(player) then return false, "faulted" end
    if (XP._flatDepth[player] or 0) > 0 then return false, "flat-xp" end
    local locks = XP._locks[player]
    if locks and locks[perk] then return false, "recursive" end
    local multiplier = XP.GetMultiplier(player)
    if not multiplier or multiplier <= 1 then return false, "inactive" end

    locks = locks or {}
    XP._locks[player] = locks
    locks[perk] = true

    local trainingData, trainingSaved
    local beforeXP, xp, expectedExtra
    local ok, result = pcall(function()
        xp = player:getXp()
        beforeXP = xp:getXP(perk)
        local maximum = perk:getTotalXpForLevel(10)
        if not finite(beforeXP) or not finite(maximum) or maximum <= 0 then
            error("invalid XP total or level-10 maximum")
        end
        if beforeXP >= maximum then return { reason = "maximum", extra = 0 } end

        local requestedExtra = amount * (multiplier - 1)
        if not finite(requestedExtra) then error("XP bonus overflow") end
        expectedExtra = math.min(requestedExtra, maximum - beforeXP)
        local factor = XP.GetProteinFactor(player, perk)
        local input = expectedExtra / factor
        if not finite(input) or input <= 0 then error("invalid XP bonus input") end

        -- The extra native event repeats xpUpdate.addXp's training-decay update.
        -- Preserve just its four fields, including absent values, around that call.
        trainingData, trainingSaved = snapshotTrainingData(player)
        XP.AddXP(player, perk, input)

        local afterXP = xp:getXP(perk)
        if not finite(afterXP) then error("invalid XP total after bonus") end
        local actualExtra = afterXP - beforeXP
        -- Native totals are float32; allow rounding of large accumulated totals.
        local tolerance = math.max(0.001, math.abs(beforeXP) * 0.00000024,
            expectedExtra * 0.00001)
        local matches = math.abs(actualExtra - expectedExtra) <= tolerance
        return {
            reason = matches and "applied" or "mismatch",
            observedAmount = amount,
            expectedExtra = expectedExtra,
            extra = actualExtra,
            proteinFactor = factor,
            input = input,
        }
    end)

    -- Restore and unlock on both native errors and validation failures. Never
    -- retry a failed call: it might already have committed some or all of its XP.
    local restored, restoreError = true, nil
    if trainingData and trainingSaved then
        restored, restoreError = pcall(restoreTrainingData, trainingData, trainingSaved)
    end
    locks[perk] = nil
    if not restored then
        latchFault(player, "timer-restore-error",
            "XP boost paused for this session; training-timer restoration failed: "
                .. tostring(restoreError))
        return false, "timer-restore-error"
    end
    if not ok then
        latchFault(player, "error", "XP boost paused for this session; bonus failed without retry: "
            .. tostring(result))
        return false, "error"
    end
    if result.reason == "mismatch" then
        latchFault(player, "mismatch", "XP boost paused for this session; bonus mismatch: expected "
            .. tostring(result.expectedExtra) .. ", received " .. tostring(result.extra))
        return false, result
    end
    return true, result
end

-- Explicit flat grants include SRJ recovery. Chain the function that is present
-- at installation time, after SRJ's OnGameBoot wrapper; do not replace its work.
function XP.InstallFlatSuppression()
    local original = addXpNoMultiplier
    if type(original) ~= "function" then return false, "missing-flat-api" end
    if original == XP._flatWrapper then return true end

    local wrapper = function(player, ...)
        local arguments = pack(...)
        local depth = player and (XP._flatDepth[player] or 0) or 0
        if player then XP._flatDepth[player] = depth + 1 end
        local results = pack(pcall(function()
            return original(player, unpack(arguments, 1, arguments.n))
        end))
        if player then
            XP._flatDepth[player] = depth > 0 and depth or nil
        end
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2, results.n)
    end
    XP._flatOriginal = original
    XP._flatWrapper = wrapper
    addXpNoMultiplier = wrapper
    return true
end

-- Called by the entry point on OnGameStart. Repeated installation is safe and
-- only replaces this module's own previously registered handler on Lua reload.
function XP.Install()
    if not B.IsSinglePlayer() then return false, "multiplayer" end
    if not Events or not Events.AddXP then return false, "missing-event" end
    local ok, reason = XP.InstallFlatSuppression()
    if not ok then
        log("XP flat-grant suppression unavailable: " .. tostring(reason))
        return false, reason
    end
    if XP._registeredHandler ~= XP.Handle then
        if XP._registeredHandler and Events.AddXP.Remove then
            Events.AddXP.Remove(XP._registeredHandler)
        end
        Events.AddXP.Add(XP.Handle)
        XP._registeredHandler = XP.Handle
    end
    return true
end

return XP
