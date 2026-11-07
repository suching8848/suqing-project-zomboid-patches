-- Original bridge code. Upstream food definitions and nutrition stay untouched.
SuQingProteinTrainingBoost = SuQingProteinTrainingBoost or {}
local B = SuQingProteinTrainingBoost

B.VERSION = "1.1.0"
B.MULTIPLIER = 10
B.DOSE_LITRES = 0.5
B.MAX_HOURS = 3
B.MOD_DATA_KEY = "SuQingProteinTrainingBoost"
B.FLUID_IDS = {}
for _, flavour in ipairs({ "Vanilla", "Chocolate", "Strawberry", "Banana" }) do
    for _, milk in ipairs({ "", "CowMilk", "SheepMilk", "SoyMilk" }) do
        B.FLUID_IDS[#B.FLUID_IDS + 1] = "VFX_" .. flavour .. "ProteinShake" .. milk
    end
end

function B.IsFinite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

function B.IsSinglePlayer()
    return (not isClient or not isClient()) and (not isServer or not isServer())
end

function B.NowHours()
    if not getGameTime then return nil end
    local clock = getGameTime()
    if not clock or not clock.getWorldAgeHours then return nil end
    local hours = clock:getWorldAgeHours()
    if not B.IsFinite(hours) or hours < 0 then return nil end
    return hours
end

function B.Log(message)
    print("[SuQingProteinTrainingBoost] " .. tostring(message))
end

local function playerData(player)
    if not player or not player.getModData then return nil end
    if player.isDead and player:isDead() then return nil end
    return player:getModData()
end

function B.GetRemainingHours(player)
    if not B.IsSinglePlayer() or B.RuntimeReady == false then return 0 end
    local now = B.NowHours()
    local data = playerData(player)
    if not now or not data then return 0 end
    local state = data[B.MOD_DATA_KEY]
    if type(state) ~= "table" or state.schema ~= 1 or not B.IsFinite(state.expiresAt) then
        return 0
    end
    local remaining = state.expiresAt - now
    -- Reject invalid future records instead of granting a perpetually capped buff.
    if remaining <= 0 or remaining > B.MAX_HOURS + 0.000001 then return 0 end
    return math.min(remaining, B.MAX_HOURS)
end

function B.IsActive(player)
    if B.XP and B.XP.HasFault and B.XP.HasFault(player) then return false end
    return B.GetRemainingHours(player) > 0
end

function B.AddDose(player, litres)
    if not B.IsSinglePlayer() or B.RuntimeReady == false
        or not B.IsFinite(litres) or litres <= 0 then return false end
    if B.XP and B.XP.HasFault and B.XP.HasFault(player) then return false end
    local now = B.NowHours()
    local data = playerData(player)
    if not now or not data then return false end
    local hours = math.min(B.MAX_HOURS, B.GetRemainingHours(player)
        + math.min(litres / B.DOSE_LITRES, 1) * B.MAX_HOURS)
    data[B.MOD_DATA_KEY] = { schema = 1, expiresAt = now + hours }
    return true
end

function B.FormatRemaining(player)
    local minutes = math.ceil(B.GetRemainingHours(player) * 60 - 0.0000001)
    minutes = math.max(0, math.min(minutes, B.MAX_HOURS * 60))
    return string.format("%02d:%02d", math.floor(minutes / 60), minutes % 60)
end

return B
