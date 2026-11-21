require "ISUI/ISInventoryPane"
require "ISUI/ISToolTip"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

local Core = require "SuQingPortableVirusDetector/Core"
local Radar = require "SuQingPortableVirusDetector/Radar"
local Action = ISBaseTimedAction:derive("SuQingInstallPortableVirusDetector")
local TEXT = "UI_SuQingPortableVirusDetector_"

function Action:isValid()
    local valid, reason = Core.canInstall(self.character, self.watch, self.detector, self.screwdriver)
    self.invalidReason = reason
    return valid
end

function Action:start()
    self:setActionAnim("Craft")
    self.watch:setJobType(getText(TEXT .. "Installing"))
    self.watch:setJobDelta(0)
end

function Action:update()
    self.watch:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.UsingTools)
end

function Action:stop()
    self.watch:setJobDelta(0)
    if self.invalidReason then self.character:Say(getText(TEXT .. self.invalidReason)) end
    ISBaseTimedAction.stop(self)
end

function Action:perform()
    self.watch:setJobDelta(0)
    ISBaseTimedAction.perform(self)
end

function Action:complete()
    local ok, reason = Core.install(self.character, self.watch, self.detector, self.screwdriver)
    self.character:Say(getText(TEXT .. (ok and "Installed" or reason)))
    return ok
end

function Action:new(character, watch, detector, screwdriver)
    local action = ISBaseTimedAction.new(self, character)
    action.watch = watch
    action.detector = detector
    action.screwdriver = screwdriver
    action.maxTime = character:isTimedActionInstant() and 1 or 60
    return action
end

local function queueInstall(watch, character, detector, screwdriver)
    local valid, reason = Core.canInstall(character, watch, detector, screwdriver)
    if not valid then
        character:Say(getText(TEXT .. reason))
        return
    end
    ISTimedActionQueue.add(Action:new(character, watch, detector, screwdriver))
end

local function toggleRadar(watch, character)
    if Radar.isOpen(watch) then
        Radar.close()
    elseif not Radar.open(character, watch) then
        character:Say(getText(TEXT .. "WatchMoved"))
    end
end

local function fillMenu(playerNum, context, items)
    if isClient() or isServer() then return end
    local selected = ISInventoryPane.getActualItems(items)
    local watch = selected[1]
    if #selected ~= 1 or not Core.isWatch(watch) then return end
    local character = getSpecificPlayer(playerNum)
    if not character or character:isDead() or not Core.isCarried(character, watch) then return end

    if Core.isInstalled(watch) then
        local label = Radar.isOpen(watch) and "RadarOff" or "RadarOn"
        context:addOption(getText(TEXT .. label), watch, toggleRadar, character)
        return
    end

    local detector, screwdriver = Core.findParts(character)
    local ready, reason = Core.canInstall(character, watch, detector, screwdriver)
    local option = context:addOption(getText(TEXT .. "Install"), watch, queueInstall, character, detector, screwdriver)
    option.notAvailable = not ready
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = getText(TEXT .. (ready and "Requirements" or reason))
    option.toolTip = tooltip
end

Events.OnFillInventoryObjectContextMenu.Add(fillMenu)
Events.OnGameStart.Add(Radar.close)
Events.OnMainMenuEnter.Add(Radar.close)
