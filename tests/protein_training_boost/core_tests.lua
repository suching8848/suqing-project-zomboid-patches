-- Runs in Lua 5.1 or Kahlua with the mod's shared Lua directory on package.path.
-- No game files or saves are touched. Fixtures replace and restore time/MP APIs.
local previous = {
    getGameTime = getGameTime,
    isClient = isClient,
    isServer = isServer,
}

local now, client, server = 100, false, false
getGameTime = function()
    return { getWorldAgeHours = function() return now end }
end
isClient = function() return client end
isServer = function() return server end

local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end

local function equal(actual, expected, message)
    check(actual == expected,
        message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function near(actual, expected, message)
    check(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
        message .. ": expected approximately " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function newPlayer(data)
    local player = { data = data or {} }
    function player:getModData() return self.data end
    function player:isDead() return false end
    return player
end

local ok, failure = pcall(function()
    local B = require("SuQingProteinTrainingBoost/Core")
    equal(B.VERSION, "1.0.0", "version")
    equal(B.MULTIPLIER, 10, "experience multiplier")
    near(B.DOSE_LITRES, 0.5, "full dose volume")
    near(B.MAX_HOURS, 3, "duration cap")
    equal(B.MOD_DATA_KEY, "SuQingProteinTrainingBoost", "save namespace")
    equal(B.IsSinglePlayer(), true, "single player detected")
    near(B.NowHours(), 100, "world time read")

    local p = newPlayer({ unrelated = { retained = true } })
    near(B.GetRemainingHours(p), 0, "new player has no effect")
    equal(B.IsActive(p), false, "new player inactive")
    equal(B.FormatRemaining(p), "00:00", "inactive display")
    equal(B.AddDose(p, 0.5), true, "full dose accepted")
    near(B.GetRemainingHours(p), 3, "full cup grants three hours")
    equal(B.IsActive(p), true, "full dose activates effect")
    equal(B.FormatRemaining(p), "03:00", "full dose display")
    equal(p.data[B.MOD_DATA_KEY].schema, 1, "saved state schema")
    near(p.data[B.MOD_DATA_KEY].expiresAt, 103, "expiry uses world hours")
    equal(p.data.unrelated.retained, true, "other mod data retained")

    p = newPlayer()
    equal(B.AddDose(p, 0.25), true, "half dose accepted")
    near(B.GetRemainingHours(p), 1.5, "half cup grants ninety minutes")
    equal(B.FormatRemaining(p), "01:30", "half dose display")
    p = newPlayer()
    equal(B.AddDose(p, 0.125), true, "quarter dose accepted")
    near(B.GetRemainingHours(p), 0.75, "quarter cup grants forty-five minutes")
    equal(B.FormatRemaining(p), "00:45", "quarter dose display")

    p = newPlayer()
    B.AddDose(p, 0.25)
    B.AddDose(p, 0.125)
    near(B.GetRemainingHours(p), 2.25, "partial doses accumulate")
    now = 101
    near(B.GetRemainingHours(p), 1.25, "elapsed world time is deducted")
    B.AddDose(p, 0.25)
    near(B.GetRemainingHours(p), 2.75, "new dose extends remaining duration")
    B.AddDose(p, 0.5)
    near(B.GetRemainingHours(p), 3, "remaining duration is capped at three hours")
    near(p.data[B.MOD_DATA_KEY].expiresAt, 104, "capped expiry is relative to current time")
    B.AddDose(p, 50)
    near(B.GetRemainingHours(p), 3, "large valid dose cannot bypass cap")

    local saved = p.data[B.MOD_DATA_KEY]
    local reloaded = newPlayer({
        [B.MOD_DATA_KEY] = { schema = saved.schema, expiresAt = saved.expiresAt },
    })
    now = 102.5
    near(B.GetRemainingHours(reloaded), 1.5, "reloaded state retains original expiry")
    equal(B.FormatRemaining(reloaded), "01:30", "reloaded display")
    now = 103.99
    equal(B.FormatRemaining(reloaded), "00:01", "display rounds remaining minutes upward")
    now = 104
    near(B.GetRemainingHours(reloaded), 0, "exact expiry has no remaining time")
    equal(B.IsActive(reloaded), false, "exact expiry disables effect")
    equal(B.FormatRemaining(reloaded), "00:00", "expired display")
    now = 110
    near(B.GetRemainingHours(reloaded), 0, "expired duration never becomes negative")
    B.AddDose(reloaded, 0.125)
    near(B.GetRemainingHours(reloaded), 0.75, "fresh drink after expiry starts fresh duration")

    for _, state in ipairs({
        { schema = 2, expiresAt = 113 },
        { schema = 1, expiresAt = "bad" },
        { schema = 1, expiresAt = math.huge },
        { schema = 1, expiresAt = 0 / 0 },
        { schema = 1 },
    }) do
        local invalid = newPlayer({ [B.MOD_DATA_KEY] = state })
        near(B.GetRemainingHours(invalid), 0, "invalid saved state is inactive")
        equal(B.IsActive(invalid), false, "invalid saved state never activates")
    end
    near(B.GetRemainingHours(nil), 0, "missing player has no effect")
    equal(B.AddDose(nil, 0.5), false, "missing player rejects dose")

    local invalidVolumes = { 0, -0.5, "0.5", math.huge, -math.huge, 0 / 0 }
    for _, litres in ipairs(invalidVolumes) do
        local invalid = newPlayer()
        equal(B.AddDose(invalid, litres), false, "invalid volume is rejected: " .. tostring(litres))
        near(B.GetRemainingHours(invalid), 0, "invalid volume grants no time")
    end
    equal(B.AddDose(newPlayer(), nil), false, "missing volume rejected")

    for _, badTime in ipairs({ "bad", math.huge, -math.huge, 0 / 0, -1 }) do
        now = badTime
        equal(B.NowHours(), nil, "invalid world time rejected: " .. tostring(badTime))
        equal(B.AddDose(newPlayer(), 0.5), false, "invalid time cannot grant dose")
    end
    now = nil
    equal(B.NowHours(), nil, "missing world time rejected")
    equal(B.AddDose(newPlayer(), 0.5), false, "missing world time cannot grant dose")
    local validClock = getGameTime
    getGameTime = function() return nil end
    equal(B.NowHours(), nil, "missing clock rejected")
    equal(B.AddDose(newPlayer(), 0.5), false, "missing clock cannot grant dose")
    getGameTime = validClock

    now = 200
    p = newPlayer()
    B.AddDose(p, 0.5)
    client = true
    equal(B.IsSinglePlayer(), false, "multiplayer client detected")
    equal(B.IsActive(p), false, "saved boost inactive on multiplayer client")
    equal(B.AddDose(newPlayer(), 0.5), false, "client rejects dose")
    client, server = false, true
    equal(B.IsSinglePlayer(), false, "multiplayer server detected")
    equal(B.IsActive(p), false, "saved boost inactive on multiplayer server")
    equal(B.AddDose(newPlayer(), 0.5), false, "server rejects dose")
    client, server = false, false
    equal(B.IsActive(p), true, "single-player state remains valid")
end)

getGameTime = previous.getGameTime
isClient = previous.isClient
isServer = previous.isServer

if not ok then error(failure, 0) end
return { suite = "protein_training_boost/core", checks = checks }
