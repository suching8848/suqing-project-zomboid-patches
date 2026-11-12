require "ISUI/ISWorldObjectContextMenu"
require "Vehicles/ISUI/ISVehicleMenu"

local Targets = require "SuQingVanillaPryUpgrade/Targets"
local PryAction = require "SuQingVanillaPryUpgrade/PryAction"

local function canStart(character)
    return Targets.enabled() and character and not character:getVehicle() and not character:isBlockMovement()
end

local function equipAndQueue(character, tool, target, kind, vehicle)
    ISWorldObjectContextMenu.transferIfNeeded(character, tool)
    ISInventoryPaneContextMenu.equipWeapon(tool, true, true, character:getPlayerNum())
    ISTimedActionQueue.add(PryAction:new(character, tool, target, kind, vehicle))
end

local function pryWorld(character, target)
    if not canStart(character) then return end
    local kind = Targets.worldKind(target)
    local tool = Targets.findCrowbar(character)
    local square = target:getSquare()
    if not kind or not tool or not square then return end

    local canWalk
    if kind == "padlockedContainer" then
        canWalk = luautils.walkAdj(character, square)
    else
        canWalk = luautils.walkAdjWindowOrDoor(character, square, target)
    end
    if canWalk then equipAndQueue(character, tool, target, kind) end
end

local function onWorldMenu(playerIndex, context, worldobjects, test)
    local character = getSpecificPlayer(playerIndex)
    if not canStart(character) then return end

    local seen = {}
    for _, object in ipairs(worldobjects) do
        local kind = Targets.worldKind(object)
        if kind and not seen[object] then
            if not Targets.findCrowbar(character) then return end
            if test then return ISWorldObjectContextMenu.setTest() end
            seen[object] = true
            local key = kind == "reinforcedDoor" and "ContextMenu_SuQingPry_ReinforcedDoor"
                or "ContextMenu_SuQingPry_Padlock"
            context:addOption(getText(key), character, pryWorld, object)
        end
    end
end

local function pryVehicle(character, vehicle, part)
    if not canStart(character) or not Targets.vehicleLock(character, vehicle, part) then return end
    local tool = Targets.findCrowbar(character)
    if not tool then return end
    ISTimedActionQueue.clear(character)
    equipAndQueue(character, tool, part, "vehicle", vehicle)
end

local function addVehicleSlice(playerIndex, menu, vehicle)
    local character = getSpecificPlayer(playerIndex)
    if not canStart(character) then return end
    local part = vehicle:getUseablePart(character)
    if not Targets.vehicleLock(character, vehicle, part) or not Targets.findCrowbar(character) then return end

    local label = "ContextMenu_SuQingPry_VehicleDoor"
    local partId = part:getId()
    if partId == "TrunkDoor" or partId == "DoorRear" or part:isVehicleTrunk() then
        label = "ContextMenu_SuQingPry_VehicleTrunk"
    elseif partId == "EngineDoor" then
        label = "ContextMenu_SuQingPry_VehicleHood"
    end
    menu:addSlice(getText(label), getTexture("Item_Crowbar"), pryVehicle, character, vehicle, part)
end

if not ISVehicleMenu.SuQingVanillaPryUpgrade and Targets.enabled() then
    ISVehicleMenu.SuQingVanillaPryUpgrade = true
    local fillPartMenu = ISVehicleMenu.FillPartMenu
    function ISVehicleMenu.FillPartMenu(playerIndex, context, radial, vehicle)
        fillPartMenu(playerIndex, context, radial, vehicle)
        if radial and vehicle then addVehicleSlice(playerIndex, radial, vehicle) end
    end
    Events.OnFillWorldObjectContextMenu.Add(onWorldMenu)
end
