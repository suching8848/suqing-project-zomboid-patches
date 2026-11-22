if isClient() or isServer() then return end

local Core = require "SuQingMFSFirearmUpgrade/Core"
local fallbackShots = {
    AW_LOCKWOOD780_Fire_Sup = true, AW_FSSHURRICANE_Fire_Sup = true,
    AW_BASILISK_Fire_Sup = true, AW_KASTOV545_Fire_Sup = true,
    AW_KASTOV762_Fire_Sup = true, AW_SIGNAL50_Fire_Sup = true,
    AW_M4A1_Fire_Sup = true, AW_P890_Fire_Sup = true,
}
local shotLayers, layersByGun = {}, {}
local loopSounds = {M16ShootFullAuto = true, MaoMaoDianLanZhuZuiShootFullAuto = true}
local pendingWorld

local function levelOf(gun)
    if not Core.isSupported(gun) then return 0 end
    local level = Core.getState(gun)
    return level or 0
end

local function gainFor(level)
    return (100 - level * 2) / 100
end

local function eligibleLayer(owner, name)
    local gun = owner:getPrimaryHandItem()
    local level = levelOf(gun)
    if level == 0 then return end
    if not owner:isUnlimitedAmmo() and gun:getCurrentAmmoCount() <= 0 and not gun:isRoundChambered() then return end
    local layers = layersByGun[gun:getType()] or fallbackShots
    if layers[name] then return gainFor(level) end
end

local function endWorldFallback()
    pendingWorld = nil
    Events.OnTick.Remove(endWorldFallback)
end

local function enablePlayerShots(methods)
    local original = methods.playRangedWeaponShootSound
    methods.playRangedWeaponShootSound = function(player, name)
        local handle = original(player, name)
        if handle and handle ~= 0 and player:isLocalPlayer() then
            local level = levelOf(player:getPrimaryHandItem())
            if level > 0 then player:getEmitter():setVolume(handle, gainFor(level)) end
        end
        return handle
    end

    -- The native loop manager owns its emitter and exposes no playback handle.
    -- Each level has its own copy of the same clip, including room parameters.
    local function loopName(player, name)
        if not loopSounds[name] or not player:isLocalPlayer() then return name end
        local level = levelOf(player:getPrimaryHandItem())
        if level == 0 then return name end
        local alias = "SuQingUpgrade" .. tostring(level) .. name
        if not GameSounds.isKnownSound(alias) or not GameSounds.isKnownSound(name) then return name end
        GameSounds.getSound(alias):setUserVolume(GameSounds.getSound(name):getUserVolume())
        return alias
    end
    local startLoop, playingLoop = methods.startAttackLoopSound, methods.isPlayingAttackLoopSound
    methods.startAttackLoopSound = function(player, name)
        return startLoop(player, loopName(player, name))
    end
    methods.isPlayingAttackLoopSound = function(player, name)
        return playingLoop(player, loopName(player, name))
    end
end

local function enableMFSCharacterShots(methods)
    local play = methods.playSound
    methods.playSound = function(emitter, name, ...)
        local handle = play(emitter, name, ...)
        if not shotLayers[name] then return handle end
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player and player:getEmitter() == emitter then
                local gain = eligibleLayer(player, name)
                if gain then
                    if handle and handle ~= 0 then
                        emitter:setVolume(handle, gain)
                    elseif player:isInvisible() and player:getSquare() then
                        -- MFS immediately retries a rejected invisible-player shot
                        -- on a world emitter at exactly the same square.
                        if not pendingWorld then Events.OnTick.Add(endWorldFallback) end
                        pendingWorld = {name = name, square = player:getSquare(), gain = gain}
                    end
                end
                break
            end
        end
        return handle
    end
end

local function enableMFSWorldShots(methods)
    local play = methods.playSoundImpl
    methods.playSoundImpl = function(emitter, name, square, ...)
        local matching = pendingWorld and pendingWorld.name == name and pendingWorld.square == square
        local gain = matching and pendingWorld.gain
        if matching then endWorldFallback() end
        local handle = play(emitter, name, square, ...)
        if gain and handle and handle ~= 0 then emitter:setVolume(handle, gain) end
        return handle
    end
end

local function wrap(class, key, attach)
    local meta = class and __classmetatables and __classmetatables[class.class]
    local methods = meta and meta.__index
    if methods and methods[key] and not rawget(methods, "__sqUpgradeShotGain") then
        attach(methods)
        rawset(methods, "__sqUpgradeShotGain", true)
    end
end

local function install()
    for name in pairs(fallbackShots) do shotLayers[name] = true end
    for gunType, profile in pairs(AWCWF_GunShotProfiles or {}) do
        local layers = {}
        for _, kind in ipairs({"normalLayers", "suppressorLayers"}) do
            for _, sound in ipairs(profile[kind] or {}) do
                layers[sound] = true
                shotLayers[sound] = true
            end
        end
        layersByGun[gunType] = layers
    end
    wrap(IsoPlayer, "playRangedWeaponShootSound", enablePlayerShots)
    wrap(CharacterSoundEmitter, "playSound", enableMFSCharacterShots)
    wrap(FMODSoundEmitter, "playSoundImpl", enableMFSWorldShots)
end

Events.OnGameStart.Add(install)
