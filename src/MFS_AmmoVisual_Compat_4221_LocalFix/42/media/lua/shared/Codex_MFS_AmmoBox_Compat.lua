-- Narrow compatibility fix for MFS M110's legacy AmmoBox typo.
-- Existing weapons are changed in place; no inventory or world objects are replaced.
Codex_MFS_AmmoBox_Compat = Codex_MFS_AmmoBox_Compat or {}
local Fix = Codex_MFS_AmmoBox_Compat
Fix.VERSION = "1.0.0"

local WEAPON_TYPE = "Base.ar_10_cat"
local AMMO_BOX_TYPE = "Base.308Box"

local function isLegacyTypo(value)
    return value == "308bOX" or value == "Base.308bOX"
end

local function scriptsExist()
    local manager = ScriptManager and ScriptManager.instance
    if not manager then return nil end
    local weaponScript = manager:getItem(WEAPON_TYPE)
    if not weaponScript or not manager:getItem(AMMO_BOX_TYPE) then return nil end
    return weaponScript
end

function Fix.applyScript()
    local weaponScript = scriptsExist()
    if not weaponScript or not instanceItem then return false end

    -- B42.21 Item has DoParam but no getAmmoBox getter. Read the script value
    -- through a temporary, unattached HandWeapon; it never enters an inventory.
    local ok, probe = pcall(instanceItem, WEAPON_TYPE)
    if not ok or not probe or not instanceof(probe, "HandWeapon") then return false end
    if isLegacyTypo(probe:getAmmoBox()) then
        weaponScript:DoParam("AmmoBox = " .. AMMO_BOX_TYPE)
        return true
    end
    return false
end

function Fix.fixWeapon(item)
    if not item or not instanceof(item, "HandWeapon") then return false end
    if item:getFullType() ~= WEAPON_TYPE or not isLegacyTypo(item:getAmmoBox()) then
        return false
    end
    if not scriptsExist() then return false end
    item:setAmmoBox(AMMO_BOX_TYPE)
    return true
end

local scanContainer

local function scanItem(item, seenItems, seenContainers)
    if not item or seenItems[item] then return end
    seenItems[item] = true
    Fix.fixWeapon(item)
    if instanceof(item, "InventoryContainer") then
        scanContainer(item:getInventory(), seenItems, seenContainers)
    end
end

scanContainer = function(container, seenItems, seenContainers)
    if not container or seenContainers[container] then return end
    seenContainers[container] = true
    local items = container:getItems()
    if not items then return end
    for index = 0, items:size() - 1 do
        scanItem(items:get(index), seenItems, seenContainers)
    end
end

function Fix.scanPlayer(playerObj)
    if not playerObj then return end
    local seenItems, seenContainers = {}, {}
    scanContainer(playerObj:getInventory(), seenItems, seenContainers)
    scanItem(playerObj:getPrimaryHandItem(), seenItems, seenContainers)
    scanItem(playerObj:getSecondaryHandItem(), seenItems, seenContainers)
    local attachedItems = playerObj:getAttachedItems()
    if attachedItems then
        for index = 0, attachedItems:size() - 1 do
            scanItem(attachedItems:getItemByIndex(index), seenItems, seenContainers)
        end
    end
end

function Fix.onGameStart()
    Fix.applyScript()
    for playerIndex = 0, getNumActivePlayers() - 1 do
        Fix.scanPlayer(getSpecificPlayer(playerIndex))
    end
end

function Fix.onCreatePlayer(playerIndex, playerObj)
    Fix.applyScript()
    Fix.scanPlayer(playerObj or getSpecificPlayer(playerIndex))
end

function Fix.onEquip(_, item)
    Fix.fixWeapon(item)
end

-- Script registration can finish after shared files load, so retry at both
-- lifecycle events. The exact-value guard preserves correct and future values.
Fix.applyScript()
if not Fix._scriptEventsRegistered then
    Events.OnInitGlobalModData.Add(Fix.applyScript)
    Events.OnGameBoot.Add(Fix.applyScript)
    Fix._scriptEventsRegistered = true
end

-- Inventory scans are local-player lifecycle operations, never world scans.
if not isServer() and not Fix._clientEventsRegistered then
    Events.OnGameStart.Add(Fix.onGameStart)
    Events.OnCreatePlayer.Add(Fix.onCreatePlayer)
    Events.OnEquipPrimary.Add(Fix.onEquip)
    Events.OnEquipSecondary.Add(Fix.onEquip)
    Fix._clientEventsRegistered = true
end
