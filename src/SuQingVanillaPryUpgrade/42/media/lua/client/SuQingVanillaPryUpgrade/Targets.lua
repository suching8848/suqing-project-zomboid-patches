local Targets = {}

function Targets.enabled()
    return not isClient() and not isServer()
end

function Targets.isCrowbar(item)
    return item and item:hasTag(ItemTag.CROWBAR) and not item:isBroken()
end

function Targets.findCrowbar(character)
    return character:getInventory():getFirstTagEvalRecurse(ItemTag.CROWBAR, Targets.isCrowbar)
end

local function hasPadlock(object)
    return instanceof(object, "IsoThumpable")
        and (object:isLockedByPadlock() or object:getLockedByCode() > 0)
end

function Targets.worldKind(object)
    if not object or object:getObjectIndex() == -1 then return nil end

    local isThumpable = instanceof(object, "IsoThumpable")
    local isDoor = instanceof(object, "IsoDoor") or (isThumpable and object:isDoor())
    if isDoor then
        if object:isOpen() or object:isBarricaded() then return nil end
        if hasPadlock(object) then return "padlockedDoor" end
        if object:isForceLocked() and (object:isLocked() or object:isLockedByKey()) then
            return "reinforcedDoor"
        end
    elseif isThumpable and object:getContainer() ~= nil and hasPadlock(object) then
        return "padlockedContainer"
    end
    return nil
end

function Targets.worldReachable(character, object, kind)
    if kind ~= "padlockedContainer" then
        return IsoGridSquare.isWithinReachOfCharacter(character, object)
    end
    local from = character:getCurrentSquare()
    local to = object:getSquare()
    return from and to and (from == to or (from:isAdjacentTo(to) and from:canReachTo(to)))
end

function Targets.vehicleLock(character, vehicle, part)
    if not part or not vehicle or not vehicle:getSquare() or part:getVehicle() ~= vehicle
        or vehicle:getPartById(part:getId()) ~= part or character:getVehicle()
        or not part:getInventoryItem() or math.abs(vehicle:getCurrentSpeedKmHour()) > 0.8
        or math.floor(character:getZ()) ~= math.floor(vehicle:getZ()) then
        return nil
    end
    local area = part:getArea()
    if not area or not vehicle:isInArea(area, character) then return nil end

    local door = part:getDoor()
    if door and not door:isOpen() and door:isLocked() then return door end
    return nil
end

return Targets
