require "RadioCom/ISTCBoomboxAction"

-- This patch targets 42.21 single-player. Multiplayer needs server actions.
local function install()
    if isClient() or isServer() then return end
    local Action = ISTCBoomboxAction
    if Action._codexHeadphones4221 then return end

    local originalToggleOnOff = Action.performToggleOnOff
    local originalRemoveBattery = Action.performRemoveBattery

    local function stopInventoryPlayback(action)
        local music = action.device:getModData().tcmusic
        if music.deviceType ~= "InventoryItem" or not music.isPlaying then return end
        music.isPlaying = false

        local playerData = action.character:getModData()
        if playerData.tcmusicid then
            action.character:getEmitter():stopSound(playerData.tcmusicid)
            playerData.tcmusicid = nil
        end
        local state = ModData.getOrCreate("trueMusicData")
        if state.now_play then
            local musicId = action.character:getUsername()
            state.now_play[musicId] = nil
        end
    end

    function Action:performAddHeadphones()
        if not self:isValidAddHeadphones() or not self.secondaryItem then return end
        local item = self.secondaryItem
        local fullType = item:getFullType()
        if fullType ~= "Base.Headphones" and fullType ~= "Base.Earbuds" then return end
        local source = item:getContainer()
        if not source then return end

        -- DeviceData owns removal from this exact source container.
        self.deviceData:addHeadphones(item, source)
        if self.deviceData:getHeadphoneType() >= 0 then
            self:actionWhenPlaying()
        end
    end

    function Action:performRemoveHeadphones()
        if not self:isValidRemoveHeadphones() then return end
        local inventory = self.character:getInventory()
        if not inventory then return end

        self.deviceData:addHeadphonesToInventory(inventory)
        if self.deviceData:getHeadphoneType() >= 0 then return end
        local music = self.device:getModData().tcmusic
        if music.deviceType == "InventoryItem" and TCMusic.WalkmanPlayer[self.device:getFullType()] then
            stopInventoryPlayback(self)
        end
        -- Ordinary boomboxes keep playing after their headphones are removed.
        self:actionWhenPlaying()
    end

    function Action:performToggleOnOff()
        if self.device:getModData().tcmusic.deviceType ~= "InventoryItem" then
            return originalToggleOnOff(self)
        end
        if self:isValidToggleOnOff() then
            stopInventoryPlayback(self)
            self.deviceData:setIsTurnedOn(not self.deviceData:getIsTurnedOn())
        end
    end

    function Action:performRemoveBattery()
        if self.device:getModData().tcmusic.deviceType ~= "InventoryItem" then
            return originalRemoveBattery(self)
        end
        -- Preserve True Music's battery operation and order; fix its cleanup key.
        if self.deviceData:getHasBattery() then
            self.deviceData:setIsTurnedOn(not self.deviceData:getIsTurnedOn())
        end
        if self:isValidRemoveBattery() and self.character:getInventory() then
            self.deviceData:getBattery(self.character:getInventory())
        end
        stopInventoryPlayback(self)
    end

    Action._codexHeadphones4221 = true
    print("[Codex True Music Headphones 42.21] Single-player compatibility patch loaded (1.0.0)")
end

Events.OnGameStart.Add(install)
