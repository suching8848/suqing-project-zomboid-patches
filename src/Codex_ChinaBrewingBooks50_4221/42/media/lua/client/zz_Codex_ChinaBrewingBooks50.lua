require "TimedActions/ISReadABook"
local B = require "CodexChinaBrewingBooks50/Core"

local function localPlayer()
    return getSpecificPlayer and getSpecificPlayer(0) or nil
end

local function sync(player, item)
    local ok, err = pcall(function() B.Sync(player, item) end)
    if not ok and not B._runtimeError then
        B._runtimeError = true
        print("[CodexChinaBrewingBooks50] synchronization failed: " .. tostring(err))
    end
end

if not B._readWrapper and ISReadABook and ISReadABook.checkMultiplier then
    local original = ISReadABook.checkMultiplier
    B._readWrapper = function(action)
        B.PrepareAction(action)
        local result = original(action)
        if action and action.item and action.item:getSkillTrained() == "ChinaBrewing" then
            sync(action.character, action.item)
        end
        return result
    end
    ISReadABook.checkMultiplier = B._readWrapper
end

if not B._completeWrapper and ISReadABook and ISReadABook.complete then
    local original = ISReadABook.complete
    B._completeWrapper = function(action)
        B.PrepareAction(action)
        local result = original(action)
        if action and action.item and action.item:getSkillTrained() == "ChinaBrewing" then
            sync(action.character, action.item)
        end
        return result
    end
    ISReadABook.complete = B._completeWrapper
end

if not B._eventsInstalled then
    B._eventsInstalled = true
    Events.OnGameStart.Add(function() sync(localPlayer()) end)
    Events.OnCreatePlayer.Add(function(index, player)
        if index == 0 then sync(player or localPlayer()) end
    end)
    local ticks = 0
    Events.OnPlayerUpdate.Add(function(player)
        if not player or player:getPlayerNum() ~= 0 then return end
        ticks = ticks + 1
        if ticks >= 60 then ticks = 0; sync(player) end
    end)
end
