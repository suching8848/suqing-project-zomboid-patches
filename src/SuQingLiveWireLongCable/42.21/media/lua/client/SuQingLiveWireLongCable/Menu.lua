if isClient() or isServer() then return end
require "SuQingLiveWireLongCable/Action"

local Cable = SQLongCable
local menuKey = "ContextMenu_SQLongCable"

local function addSubmenu(menu, label)
    local option = menu:addOption(label, nil, nil)
    local child = ISContextMenu:getNew(menu)
    menu:addSubMenu(option, child)
    return child
end

local function queueLink(player, obj, masterId)
    local ok, reason, arg, arg2 = Cable.check(player, obj, masterId)
    if not ok then
        LiveWire.notify(player, reason or "Tooltip_LW_Invalid", { arg, arg2 }, true)
        return
    end
    if luautils.walkAdj(player, obj:getSquare()) then
        ISTimedActionQueue.add(SQLongCableAction:new(player, obj, masterId))
    else
        LiveWire.notify(player, "IGUI_LW_CannotReach", {}, true)
    end
end

local function addCandidates(menu, player, obj, candidates)
    for _, candidate in ipairs(candidates) do
        local master = candidate.master
        local grid = master.grid and LiveWire.Registry.grid(master.grid)
        local name = grid and grid.name
        if type(name) ~= "string" or name == "" then
            name = getText("IGUI_LW_Model_" .. master.model)
        end
        local label = string.format("%s [%d, %d, %d / %s]", name, master.x, master.y, master.z, master.id)
        local distance = tostring(math.floor(candidate.distance + 0.5))
        local wires = tostring(LiveWire.Install.wiresFor(candidate.distance))
        local option = menu:addOption(getText(menuKey .. "_Target", label, distance, wires),
            player, queueLink, obj, master.id)
        local ok, reason, arg, arg2 = Cable.check(player, obj, master.id)
        if not ok then
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = LiveWire.Client.text(reason or "Tooltip_LW_Invalid", { arg, arg2 })
            option.toolTip = tooltip
            option.notAvailable = true
        end
    end
end

local function onFillWorld(playerNum, context, worldobjects, test)
    if test or not Cable.ready() then return end
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end

    local fetch = ISWorldObjectContextMenu.fetchVars
    local clicked = fetch and fetch.clickedSquare
    if not clicked and worldobjects[1] then clicked = worldobjects[1]:getSquare() end
    if not clicked then return end

    local targets = {}
    local objects = clicked:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local target = Cable.target(obj)
        if target then
            local candidates = Cable.candidates(target)
            if #candidates > 0 then
                targets[#targets + 1] = { obj = obj, device = target, candidates = candidates }
            end
        end
    end
    if #targets == 0 then return end

    local liveWireOption = context:getOptionFromName(getText("ContextMenu_LW_Root"))
    local liveWireMenu = liveWireOption and liveWireOption.subOption and context:getSubMenu(liveWireOption.subOption)
    local menu = addSubmenu(liveWireMenu or context, getText(menuKey))
    for _, target in ipairs(targets) do
        local deviceMenu = menu
        if #targets > 1 then
            local device = target.device
            local label = getText("IGUI_LW_Model_" .. device.model) .. " [" .. device.id .. "]"
            deviceMenu = addSubmenu(menu, label)
        end
        addCandidates(deviceMenu, player, target.obj, target.candidates)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorld)
