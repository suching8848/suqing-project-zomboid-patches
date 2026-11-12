-- Narrow integration for the audited EX 1.0.0-rc.2 and MaoMao capacity layer.
require "ExSuQingBackpackSuperUpgrade/Capacity"

CodexNekomataEXCompat_4221 = CodexNekomataEXCompat_4221 or {}
local S = CodexNekomataEXCompat_4221
local X = ExSuQingBackpackSuperUpgrade
local C = X and X.Capacity
local MAO_KEY = "__maomao_backpack_capacity_wrappers_v1"
local PATCH_KEY = "__codex_nekomata_ex_room_forward_v1"
local EX_VERSION = "1.0.0-rc.2"

local function supported()
    return X and C and X.version == EX_VERSION and X.IsSinglePlayer()
end

local function indexTable()
    local meta = __classmetatables and ItemContainer and __classmetatables[ItemContainer.class]
    return meta and meta.__index
end

-- The exported record must describe every function currently at the top.
-- Never replace an unknown outer wrapper, including a partially replaced trio.
local function authorLayer()
    if not supported() then return nil end
    local index = indexTable()
    local w = index and rawget(index, MAO_KEY)
    if type(w) ~= "table"
        or type(w.getCapacity) ~= "function"
        or type(w.getEffectiveCapacity) ~= "function"
        or type(w.hasRoomFor) ~= "function"
        or type(w.sourceGetCapacity) ~= "function"
        or type(w.sourceGetEffectiveCapacity) ~= "function"
        or type(w.sourceHasRoomFor) ~= "function"
        or index.getCapacity ~= w.getCapacity
        or index.getEffectiveCapacity ~= w.getEffectiveCapacity
        or index.hasRoomFor ~= w.hasRoomFor then return nil end
    return index, w
end

-- Match the author's two target rules exactly; do not classify another bag.
local function isMaoTarget(container)
    if not container then return false end
    if container.getContainingItem then
        local item = container:getContainingItem()
        if item and item.getFullType and item:getFullType() == "Base.MaoMaoBackpack" then
            return true
        end
    end
    return container.getType and container:getType() == "MaoMaoBackpack"
end

function S.ReadAuthorCapacity(container)
    local _, wrappers = authorLayer()
    if not wrappers or not isMaoTarget(container) then return nil end
    return wrappers.getCapacity(container)
end

local function ownedMao(container)
    local extension = CodexNekomataEXUpgrade_4221
    if not extension or not extension.enabled or not container or not container.getContainingItem then return false end
    local item = container:getContainingItem()
    return item and item.getFullType and item:getFullType() == "Base.MaoMaoBackpack"
        and X.IsSupported(item) and X.IsValidRecord(X.GetRecord(item), item)
end

local function bridgeEffective(index, w, patch)
    local extension = CodexNekomataEXUpgrade_4221
    if not extension or not extension.enabled then return true end
    if patch.forwardedEffective then return w.getEffectiveCapacity == patch.forwardedEffective end
    local authorEffective, sourceEffective = w.getEffectiveCapacity, w.sourceGetEffectiveCapacity
    local forwarded = function(container, player, ...)
        -- Never jump to a global EX function from the pre-EX inner layer:
        -- C.originalEffective may hold that very layer on a later cold load.
        if sourceEffective == C.installedEffective and ownedMao(container) then
            return sourceEffective(container, player, ...)
        end
        return authorEffective(container, player, ...)
    end
    patch.authorEffective, patch.forwardedEffective = authorEffective, forwarded
    w.getEffectiveCapacity, index.getEffectiveCapacity = forwarded, forwarded
    return true
end

function S.BridgeAuthorRoom()
    local index, w = authorLayer()
    if not index then return false end
    local prior = rawget(w, PATCH_KEY)
    if prior then
        local intact = type(prior) == "table" and prior.owner == S
            and prior.forwarded == w.hasRoomFor
            and prior.sourceRoom == w.sourceHasRoomFor
            and prior.sourceEffective == w.sourceGetEffectiveCapacity
        return intact and bridgeEffective(index, w, prior)
    end
    local authorRoom, sourceRoom = w.hasRoomFor, w.sourceHasRoomFor
    local forwarded = function(container, ...)
        if isMaoTarget(container) then
            if sourceRoom == C.installedRoom and ownedMao(container) then
                return sourceRoom(container, ...)
            end
            return authorRoom(container, ...)
        end
        return sourceRoom(container, ...)
    end
    local record = {
        owner = S, forwarded = forwarded, authorRoom = authorRoom,
        sourceRoom = sourceRoom, sourceEffective = w.sourceGetEffectiveCapacity,
    }
    -- Synchronize the author's own idempotence record. Its next clothing/player
    -- event then sees the same trio and does not grow another wrapper layer.
    rawset(w, PATCH_KEY, record)
    w.hasRoomFor = forwarded
    index.hasRoomFor = forwarded
    return bridgeEffective(index, w, record)
end

function S.IsKnownEXChain()
    local index, w = authorLayer()
    if not index then return false end
    local patch = rawget(w, PATCH_KEY)
    return type(C.installedEffective) == "function" and type(C.installedRoom) == "function"
        and w.sourceGetEffectiveCapacity == C.installedEffective
        and w.sourceHasRoomFor == C.installedRoom
        and type(patch) == "table" and patch.owner == S
        and patch.forwarded == w.hasRoomFor
        and patch.sourceRoom == C.installedRoom
        and patch.sourceEffective == C.installedEffective
end

function S.InstallHooks()
    if not supported() then return false end
    if S.hookedCapacity then
        return S.hookedCapacity == C and C.IsReady == S.readyHook and C.Install == S.installHook
    end
    if type(C.IsReady) ~= "function" or type(C.Install) ~= "function"
        or type(C.InstallTransfer) ~= "function" then return false end
    S.originalReady, S.originalInstall = C.IsReady, C.Install
    S.readyHook = function(...)
        local original = S.originalReady(...)
        if original then return original end
        if not supported() or not S.IsKnownEXChain() then return original end
        -- Preserve every other guard in the audited original IsReady. Only the
        -- two direct function-identity checks gain the exact known-chain case.
        return C.installedEffective ~= nil and C.installedTransfer ~= nil
            and javaTransferItems == C.installedTransfer
    end
    S.installHook = function(...)
        local original = S.originalInstall(...)
        if original then return original end
        if not supported() or not S.IsKnownEXChain() then return original end
        -- Do not rebuild EX capacity wrappers beneath a foreign continuation.
        -- The original transfer repair retains its own guards and idempotence.
        C.InstallTransfer()
        return C.IsReady()
    end
    C.IsReady, C.Install = S.readyHook, S.installHook
    S.hookedCapacity = C
    return true
end

function S.Refresh()
    if not S.InstallHooks() then return false end
    if not S.BridgeAuthorRoom() then return false end
    if S.IsKnownEXChain() then return C.Install() end
    return false
end

-- Phase one runs before EX's first startup event, so EX captures a parameter-
-- transparent continuation. Phase two follows MaoMao's later author events.
S.Refresh()
if not S.eventsRegistered then
    S.eventsRegistered = true
    for _, name in ipairs({ "OnGameStart", "OnServerStarted", "OnCreatePlayer", "OnClothingUpdated" }) do
        if Events[name] then Events[name].Add(S.Refresh) end
    end
end
return S
