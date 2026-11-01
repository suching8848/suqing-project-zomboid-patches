-- SuPrimitiveEquipment's visual helpers request '<magazine>_Attachment'
-- without checking the item definition and can remove another mod's Clip.
-- Real ammunition remains handled by the unmodified native action methods.
CodexMFSMagazineVisualCompat = CodexMFSMagazineVisualCompat or {}
local State = CodexMFSMagazineVisualCompat
State.VERSION = "1.0.0"

local function expectedVisualType(weapon)
    if not weapon or not weapon:IsWeapon() or not weapon:isRanged() then return nil end
    local magazine = weapon:getMagazineType()
    if type(magazine) ~= "string" or magazine == "" then return nil end
    if not string.find(magazine, ".", 1, true) then magazine = "Base." .. magazine end
    return magazine .. "_Attachment"
end

local function visualIsDefined(fullType)
    return fullType ~= nil and ScriptManager and ScriptManager.instance
        and ScriptManager.instance:getItem(fullType) ~= nil
end

local function excluded(part)
    return part and PEReloadClipManager and PEReloadClipManager.isExcludedClip
        and PEReloadClipManager.isExcludedClip(part:getType())
end

local function removeOwnVisual(weapon, character)
    local expected = expectedVisualType(weapon)
    if not expected then return end
    local part = weapon:getWeaponPart("Clip")
    if not part or part:getFullType() ~= expected or excluded(part) then return end
    -- An already attached helper can safely be removed even after its script
    -- disappears. Never instantiate a missing item and never detach a foreign Clip.
    if character then
        weapon:detachWeaponPart(character, part)
    else
        weapon:detachWeaponPart(part)
    end
end

local function addOwnVisual(weapon, recalculate)
    local expected = expectedVisualType(weapon)
    if not expected or weapon:getWeaponPart("Clip") or not visualIsDefined(expected) then return end
    local part = instanceItem(expected)
    if not part or not instanceof(part, "WeaponPart") or part:getPartType() ~= "Clip"
        or part:getFullType() ~= expected then return end
    if recalculate then
        weapon:attachWeaponPart(part, true)
    else
        weapon:attachWeaponPart(part)
    end
end

local function safeEquip(_, weapon)
    if not expectedVisualType(weapon) then return end
    if weapon:isContainsClip() then
        addOwnVisual(weapon, false)
    else
        removeOwnVisual(weapon)
    end
end

local function safeInsertComplete(self)
    if self.gun and self.gun:isContainsClip() then addOwnVisual(self.gun, true) end
    return true
end

local function safeEjectComplete(self)
    -- The ammo animation already cleared containsClip. If completion runs early
    -- or an action is interrupted, do not remove the currently loaded visual.
    if self.gun and not self.gun:isContainsClip() then
        removeOwnVisual(self.gun, self.character)
    end
    return true
end

local function install()
    if State.installed then return true end
    if not PEReloadClipManager or not Events.OnEquipPrimary
        or not ISInsertMagazine or not ISEjectMagazine then return false end

    State.originalEquip = PEReloadClipManager.attachMagazine
    State.originalInsertComplete = ISInsertMagazine.complete
    State.originalEjectComplete = ISEjectMagazine.complete
    if State.originalEquip then Events.OnEquipPrimary.Remove(State.originalEquip) end
    PEReloadClipManager.attachMagazine = safeEquip
    Events.OnEquipPrimary.Add(safeEquip)
    ISInsertMagazine.complete = safeInsertComplete
    ISEjectMagazine.complete = safeEjectComplete
    State.safeEquip = safeEquip
    State.safeInsertComplete = safeInsertComplete
    State.safeEjectComplete = safeEjectComplete
    State.installed = true
    print("[CodexMagazineVisualCompat] v" .. State.VERSION .. " installed")
    return true
end

State.install = install
install()
-- Retry only at boot if the optional source module was not present yet.
-- Do not rewrite action methods at OnGameStart: later wrappers keep their chain.
if not State.bootRegistered then
    Events.OnGameBoot.Add(install)
    State.bootRegistered = true
end
