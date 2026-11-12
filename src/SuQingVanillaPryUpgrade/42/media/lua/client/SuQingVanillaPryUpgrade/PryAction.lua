require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISForceOpen"
require "Vehicles/TimedActions/ISOpenVehicleDoor"

local Targets = require "SuQingVanillaPryUpgrade/Targets"
local PryAction = ISBaseTimedAction:derive("SuQingVanillaPryUpgradeAction")

local ATTEMPT_TICKS = 80

function PryAction:isValid()
    local character = self.character
    if not Targets.enabled() or character:getVehicle() or character:isBlockMovement()
        or character:getPrimaryHandItem() ~= self.tool or not Targets.isCrowbar(self.tool) then
        return false
    end
    if self.vehicle then
        return Targets.vehicleLock(character, self.vehicle, self.target) ~= nil
    end
    return Targets.worldKind(self.target) == self.kind
        and Targets.worldReachable(character, self.target, self.kind) == true
end

function PryAction:waitToStart()
    self.character:faceThisObject(self.vehicle or self.target)
    return self.character:shouldBeTurning()
end

function PryAction:start()
    self:setActionAnim("RemoveBarricade")
    self:setAnimVariable("RemoveBarricade", "CrowbarMid")
    self:setOverrideHandModels(self.tool, nil)
end

function PryAction:update()
    if self.outcome then return end
    self.character:setMetabolicTarget(Metabolics.UsingTools)
    self.elapsed = self.elapsed + getGameTime():getMultiplier()
    if self.elapsed < self.interval then return end
    self.elapsed = self.elapsed - self.interval
    if not self:isValid() then
        self:forceStop()
        return
    end

    local character = self.character
    local burglar = character:hasTrait(CharacterTrait.BURGLAR)
    local radius = burglar and 7 or 12
    character:exertForForcing()
    character:playSound("CrowbarHit")
    addSound(character, character:getX(), character:getY(), character:getZ(), radius, radius)

    local failChance = burglar and ISForceOpen.FAIL_CHANCE_BURGLAR or ISForceOpen.FAIL_CHANCE
    if ZombRand(100) < failChance then
        self.outcome = "failed"
    else
        local modifier = self.kind == "vehicle" and -5 or -10
        if burglar then modifier = modifier + 20 end
        local strength = character:getPerkLevel(Perks.Strength)
        local chance = math.max(1, strength, character:getBaseForceOpenChance() + modifier)
        if ZombRand(100) < chance then self.outcome = "opened" end
    end
    if self.outcome then self:forceComplete() end
end

function PryAction:perform()
    if self.outcome and self:isValid() then
        local target = self.target
        if self.outcome == "failed" then
            if self.kind == "reinforcedDoor" or self.kind == "padlockedDoor" then
                target:failForceOpen(self.character)
            elseif ZombRand(100) < 50 - 3 * self.character:getPerkLevel(Perks.Maintenance) then
                self.tool:setCondition(self.tool:getCondition() - 1)
            end
            HaloTextHelper.addBadText(self.character, getText("IGUI_SuQingPry_Failed"))
        elseif self.vehicle then
            local door = Targets.vehicleLock(self.character, self.vehicle, target)
            door:setLocked(false)
            self.vehicle:transmitPartDoor(target)
            self:addAfter(ISOpenVehicleDoor:new(self.character, self.vehicle, target))
        else
            if self.kind ~= "reinforcedDoor" then
                target:setLockedByPadlock(false)
                target:setLockedByCode(0)
            end
            if self.kind == "padlockedContainer" then
                target:sync()
                triggerEvent("OnContainerUpdate")
            else
                target:forceOpen(self.character)
                if not target:isOpen() then
                    HaloTextHelper.addBadText(self.character, getText("IGUI_SuQingPry_Blocked"))
                end
            end
        end
    end

    ISBaseTimedAction.perform(self)
end

function PryAction:new(character, tool, target, kind, vehicle)
    local action = ISBaseTimedAction.new(self, character)
    action.tool = tool
    action.target = target
    action.kind = kind
    action.vehicle = vehicle
    action.elapsed = 0
    action.interval = character:isTimedActionInstant() and 1 or ATTEMPT_TICKS
    action.maxTime = -1
    return action
end

return PryAction
