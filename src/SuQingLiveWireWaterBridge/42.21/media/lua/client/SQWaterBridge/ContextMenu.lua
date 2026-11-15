local prefix = "IGUI_SQWaterBridge_"
local reasonKeys = {
    Connected = true, Disconnected = true, Unavailable = true, OnePump = true,
    PumpInUse = true, Unsupported = true, NoInlet = true, NoOutlet = true,
    MixedFeed = true, ReturnFlow = true,
}

local function report(player, reason)
    player:Say(getText(prefix .. (reasonKeys[reason] and reason or "Unavailable")))
end

local function connect(player, pumpKey, direction)
    local _, reason = SQWaterBridge.connect(pumpKey, direction)
    report(player, reason)
end

local function disconnect(player, pumpKey)
    local _, reason = SQWaterBridge.disconnect(pumpKey)
    report(player, reason)
end

local function onContext(playerNum, context, worldobjects, test)
    if test or isClient() or isServer() then return end
    local bridge = SQWaterBridge
    if not bridge or not bridge.ensureReady() then return end
    local fetch = ISWorldObjectContextMenu.fetchVars
    local clicked = fetch and fetch.clickedSquare
    if not clicked and worldobjects[1] then clicked = worldobjects[1]:getSquare() end
    local player = getSpecificPlayer(playerNum)
    if not clicked or not player or player:getVehicle() then return end

    local objects = clicked:getObjects()
    local connection = bridge.getConnection()
    local gmd = GetWPModData()
    if not gmd or not gmd.Pipes then return end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if LiveWire.Install.isPump(obj) then
            local mark = LiveWire.Marks.get(obj)
            local pump, physical = bridge.LiveWire.getPump(mark.id)
            if pump and physical == obj then
                local parent = context:addOption(getText(prefix .. "Menu"), nil, nil)
                local sub = ISContextMenu:getNew(context)
                context:addSubMenu(parent, sub)
                if connection and connection.pumpKey == pump.id then
                    sub:addOption(getText(prefix .. "Disconnect"), player, disconnect, pump.id)
                end
                local adjacent = false
                for _, dir in ipairs(bridge.directions) do
                    local id = WPUtils.Coords2Id(pump.x + dir.dx, pump.y + dir.dy, pump.z)
                    if gmd.Pipes[id] then
                        adjacent = true
                        sub:addOption(getText(prefix .. "Connect" .. dir.label), player, connect, pump.id, dir)
                    end
                end
                if not adjacent then
                    sub:addOption(getText(prefix .. "NoInlet"), nil, nil).notAvailable = true
                end
                return
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onContext)
