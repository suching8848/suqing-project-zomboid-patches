require "SQBoatRVRoomGuard/Core"
require "SQBoatRVRoomGuard/SourcePins"
local Core = SQBoatRVRoomGuardCore
SuQingBoatRVRoomGuard = SuQingBoatRVRoomGuard or {}
local G = SuQingBoatRVRoomGuard
G.version = "0.1.0-rc.2"

local function multiplayer()
    return (isClient and isClient()) or (isServer and isServer())
        or (isMultiplayer and isMultiplayer())
end

local function message(reason, player)
    G.messages = G.messages or {}
    if G.messages[reason] then return end
    G.messages[reason] = true
    local key = reason == "collision" and "IGUI_SQBoatRVRoomGuard_Collision"
        or reason == "full" and "IGUI_SQBoatRVRoomGuard_Full"
        or "IGUI_SQBoatRVRoomGuard_Blocked"
    local text = getText and getText(key) or key
    if not text or text == key then text = "Boat/RV room safety check blocked entry; see the log." end
    print("[SuQingBoatRVRoomGuard] " .. tostring(reason) .. ": " .. text)
    if player and HaloTextHelper and HaloTextHelper.addBadText then
        local ok, err = pcall(HaloTextHelper.addBadText, player, text)
        if not ok then print("[SuQingBoatRVRoomGuard] notification: " .. tostring(err)) end
    end
end

local function safeMessage(reason, player)
    local ok, err = pcall(message, reason, player)
    if not ok then
        G.lastNotificationError = tostring(err)
        pcall(print, "[SuQingBoatRVRoomGuard] notification failed: " .. tostring(err))
    end
end

local function affectedVehicle(vehicle)
    if not vehicle then return false end
    local script = vehicle:getScript()
    local name = script and tostring(script:getFullName()) or ""
    if name == "Base.CabineFantasmaBR" then return true end
    local md = vehicle:getModData()
    if md and (md.projectRV_type == Core.nativeKey or md.projectRV_type == Core.boatKey) then return true end
    for _, typeKey in ipairs({Core.nativeKey, Core.boatKey}) do
        local def = VehicleTypes and VehicleTypes[typeKey]
        for _, candidate in ipairs(def and def.scripts or {}) do if name == candidate then return true end end
    end
    return false
end

local function sync()
    if not G.ready or not G.allocator or VehicleTypes ~= G.types then return nil, G.error or "changed_vehicle_types" end
    local data = ModData.getOrCreate("modPROJECTRVInterior")
    local view, reason = G.allocator:sync(data)
    if not view then G.ready, G.error = false, reason; return nil, reason end
    return data
end

local function beforeEntry(ctx)
    if type(ctx) ~= "table" then return false end
    if ctx.typeKey ~= Core.nativeKey and ctx.typeKey ~= Core.boatKey then return true end
    local ok, allowed, reason = pcall(function()
        local data, err = sync()
        if not data then return false, err end
        return G.allocator:checkEntry(ctx, data)
    end)
    if not ok then
        G.ready, G.error = false, tostring(allowed)
        safeMessage("entry_check_error: " .. tostring(allowed), ctx.player)
        return false
    end
    if not allowed then safeMessage(reason or "entry_blocked", ctx.player); return false end
    return true
end

local function readFingerprint(pin)
    if type(getModFileReader) ~= "function" then return nil end
    local reader = getModFileReader(pin.mod, pin.path, false)
    if not reader then return nil end
    local hash, count, previousCR, openLine = 0, 0, false, false
    local function feed(value)
        hash = (hash * 131 + value) % 1000000007
        count = count + 1
    end
    local ok, err = pcall(function()
        while true do
            -- Java int UTF-16 units avoid BOTH byte() and pattern-engine
            -- differences between stock Kahlua and optimized runtimes.
            local value = reader:read()
            if value == -1 then break end
            if value == 13 then
                feed(10)
                previousCR, openLine = true, false
            elseif value == 10 then
                if not previousCR then feed(10) end
                previousCR, openLine = false, false
            else
                previousCR, openLine = false, true
                if value > 0 and value < 128 then feed(value) end
            end
        end
        if openLine then feed(10) end
    end)
    reader:close()
    if not ok then error(err) end
    return hash, count
end

function G.install()
    if multiplayer() then G.error = "multiplayer_unsupported"; return false end
    if G.installed then return G.ready end
    G.installed, G.ready, G.messages = true, false, {}
    local ok, reason = pcall(function()
        for _, pin in ipairs(SQBoatRVRoomGuardPins) do
            local hash, count = readFingerprint(pin)
            if hash ~= pin.hash or count ~= pin.count then
                error("source_changed_or_unreadable: " .. pin.mod .. "/" .. pin.path
                    .. " expected=" .. pin.hash .. "/" .. pin.count
                    .. " actual=" .. tostring(hash) .. "/" .. tostring(count))
            end
        end
        assert(RVHooks and type(RVHooks.register) == "function", "missing_RVHooks")
        local allocator, err = Core.new(VehicleTypes)
        assert(allocator, err)
        G.allocator, G.types, G.ready = allocator, VehicleTypes, true
        local data, syncError = sync()
        assert(data, syncError)
    end)
    if not ok then G.ready, G.error = false, tostring(reason) end
    if RVHooks and type(RVHooks.register) == "function" then
        G.hookRegistered = RVHooks.register("preEnter", beforeEntry, 1000000) == true
    end
    if not G.hookRegistered then G.ready, G.error = false, "entry_hook_unavailable" end
    if ISVehicleMenu and type(ISVehicleMenu.getVehicleToInteractWith) == "function" then
        local base = ISVehicleMenu.getVehicleToInteractWith
        G.originalLookup = base
        G.lookup = function(player, ...)
            local vehicle = base(player, ...)
            if not affectedVehicle(vehicle) then return vehicle end
            local safe, data, err = pcall(sync)
            if not safe or not data then
                G.ready = false
                G.error = not safe and tostring(data) or err
                safeMessage(G.error or "lookup_blocked", player)
                return nil
            end
            return vehicle
        end
        ISVehicleMenu.getVehicleToInteractWith = G.lookup
    else
        G.ready, G.error = false, "vehicle_lookup_unavailable"
    end
    if G.ready then
        print("[SuQingBoatRVRoomGuard] " .. G.version .. " ready; 38 shared slots; existing assignments retained")
    else
        safeMessage(G.error or "initialization_failed", getSpecificPlayer and getSpecificPlayer(0) or nil)
    end
    return G.ready
end

Events.OnGameStart.Add(G.install)
