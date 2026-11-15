if isClient() or isServer() then return end

local selected = {}
local prefix = "ContextMenu_SQLWISA_"

local function say(player, key)
    player:Say(getText(prefix .. key))
end

local function selectCabinet(player, bridge, object)
    if not bridge.selectable(player, object) then
        say(player, "InvalidTarget")
        return
    end
    selected[player] = object
    say(player, "Selected")
end

local function attach(player, bridge, inverter)
    local success, result = bridge.attach(player, selected[player], inverter)
    if success then selected[player] = nil end
    say(player, result)
end

local function detach(player, bridge, object)
    local _, result = bridge.detach(player, object)
    say(player, result)
end

local function fill(playerNum, context, worldobjects, test)
    -- Single-player loads the client menu before the server Lua phase.
    local bridge = SuQingLiveWireISACompatBridge
    if not bridge or not bridge.ready then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local fetchVars = ISWorldObjectContextMenu.fetchVars
    local clicked = fetchVars and fetchVars.clickedSquare
        or (worldobjects[1] and worldobjects[1]:getSquare())
    if not clicked then return end

    local bank, object = bridge.bankAt(clicked)
    local inverter
    if selected[player] then
        local objects = clicked:getObjects()
        for i = 0, objects:size() - 1 do
            local candidate = objects:get(i)
            if bridge.inverterGrid(candidate) then inverter = candidate; break end
        end
    end
    if not bank and not inverter then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    if bank then
        if bridge.linkFor(bank, object) then
            context:addOption(getText(prefix .. "Detach"), player, detach, bridge, object)
        else
            context:addOption(getText(prefix .. "Select"), player, selectCabinet, bridge, object)
        end
    end
    if inverter then context:addOption(getText(prefix .. "Attach"), player, attach, bridge, inverter) end
end

Events.OnFillWorldObjectContextMenu.Add(fill)
Events.OnGameStart.Add(function() selected = {} end)
