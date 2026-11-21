local Core = {}
local DETECTOR_TYPE = "Gunpart.HeartbeatSensorPlus"
local INSTALL_KEY = "SuQingPortableVirusDetector"

function Core.isWatch(item)
    if not item or not instanceof(item, "AlarmClockClothing") or not item:hasTag(ItemTag.DIGITAL) then
        return false
    end
    local slot = item:getBodyLocation()
    return slot == ItemBodyLocation.LEFT_WRIST or slot == ItemBodyLocation.RIGHT_WRIST
end

function Core.isCarried(character, item)
    local container = item and item:getContainer()
    return character and container and container:contains(item) and character:getInventory():contains(item, true)
end

function Core.isInstalled(watch)
    return Core.isWatch(watch) and watch:hasModData() and watch:getModData()[INSTALL_KEY] == true
end

local function isUsableTool(item)
    return item:hasTag(ItemTag.SCREWDRIVER) and not item:isBroken()
end

function Core.findParts(character)
    local inventory = character:getInventory()
    local detector = inventory:getFirstTypeRecurse(DETECTOR_TYPE)
    return detector, inventory:getFirstTagEvalRecurse(ItemTag.SCREWDRIVER, isUsableTool)
end

function Core.canInstall(character, watch, detector, screwdriver)
    if not Core.isWatch(watch) or not Core.isCarried(character, watch) then
        return false, "WatchMoved"
    end
    if Core.isInstalled(watch) then return false, "AlreadyInstalled" end
    if not Core.isCarried(character, detector) or detector:getFullType() ~= DETECTOR_TYPE then
        return false, "NeedDetector"
    end
    if not Core.isCarried(character, screwdriver) or not isUsableTool(screwdriver) then
        return false, "NeedScrewdriver"
    end
    return true
end

function Core.install(character, watch, detector, screwdriver)
    local ready, reason = Core.canInstall(character, watch, detector, screwdriver)
    if not ready then return false, reason end

    local container = detector:getContainer()
    local state = watch:getModData()
    local removed = pcall(function()
        container:Remove(detector)
    end)
    if not removed or container:contains(detector) or detector:getContainer() then
        if not container:contains(detector) and not detector:getContainer() then
            container:AddItem(detector)
        end
        return false, "InstallFailed"
    end
    state[INSTALL_KEY] = true
    container:setDrawDirty(true)
    watch:getContainer():setDrawDirty(true)
    return true
end

return Core
