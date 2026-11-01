-- Single-player only. Bind the authoritative progress record to per-character modData.
if isClient() or isServer() then return end
require "XFDynamic/Server"
local T = XFDynamic
local S = T and T.Server
local M = T and T.Model
if not S or not M or type(S.record) ~= "function" or type(S.database) ~= "function" then
    print("[XFRecordGuard] WARNING: unsupported XFACTION API; guard not installed")
    return
end
if S.codexRecordGuard then return end
local original = S.record
local pending = {}
local TOKEN = "Codex_XFDynamic_CharacterToken_v1"
local BINDING = "codexCharacterTokenV1"
local function token(key)
    return tostring(key) .. ":" .. tostring(getTimestampMs())
end
local function bind(player, record, key, forceNew)
    local md = player:getModData()
    local id = forceNew and token(key) or md[TOKEN]
    if type(id) ~= "string" or id == "" then id = token(key) end
    md[TOKEN] = id
    record[BINDING] = id
    return id
end
S.record = function(player)
    local key = S.account(player)
    if not key then return nil end
    local records = S.database()
    local r = records[key]
    if not r or player:isDead() or r.dead then
        local result, resultKey = original(player)
        if result and not player:isDead() then bind(player, result, resultKey, r ~= nil and r.dead == true) end
        pending[key] = nil
        return result, resultKey
    end
    local md = player:getModData()
    local current, bound = md[TOKEN], r[BINDING]
    if type(bound) ~= "string" or bound == "" then
        -- One-time migration of an existing living character and progress record.
        bind(player, r, key, false)
        pending[key] = nil
        print("[XFRecordGuard] Bound existing record " .. key)
        return r, key
    end
    if current == bound then
        pending[key] = nil
        return r, key
    end
    if type(current) == "string" and current ~= "" then
        -- Different persisted character marker: keep native fresh-life behavior.
        local fresh = M.new(key .. ":" .. tostring(getTimestampMs()), T.Runtime.owned(player))
        records[key] = fresh; S.runtime[key] = nil
        bind(player, fresh, key, false); pending[key] = nil
        print("[XFRecordGuard] New character marker; created a new progress record " .. key)
        return fresh, key
    end
    -- A missing marker can mean a newly created character OR delayed loading.
    -- Wait for both real time and advancing world time before deciding.
    local age = player:getHoursSurvived()
    if type(age) == "number" and age + 1 >= M.number(r.age) then
        md[TOKEN] = bound; pending[key] = nil
        print("[XFRecordGuard] Reattached record after missing character marker " .. key)
        return r, key
    end
    local stamp, hour = getTimestampMs(), getGameTime():getWorldAgeHours()
    local wait = pending[key]
    if not wait or wait.player ~= player then
        pending[key] = {player=player, stamp=stamp, hour=hour}
        print("[XFRecordGuard] Waiting to identify character " .. key)
        return nil
    end
    if stamp - wait.stamp < 15000 or hour - wait.hour < 0.02 then return nil end
    age = player:getHoursSurvived()
    if type(age) ~= "number" or age < 0 then return nil end
    if age + 1 >= M.number(r.age) then
        md[TOKEN] = bound; pending[key] = nil
        return r, key
    end
    local fresh = M.new(key .. ":" .. tostring(stamp), T.Runtime.owned(player))
    records[key] = fresh; S.runtime[key] = nil
    bind(player, fresh, key, true); pending[key] = nil
    print("[XFRecordGuard] Confirmed different unbound character; created new progress record " .. key)
    return fresh, key
end
S.codexRecordGuard = true
print("[XFRecordGuard] Record guard installed")
