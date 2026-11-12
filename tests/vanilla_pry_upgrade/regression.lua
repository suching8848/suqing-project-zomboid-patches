local assertions = 0
local function expect(value, message)
    assert(value, message)
    assertions = assertions + 1
end

local client, server = false, false
local activePlayer
local worldHandlers = {}
local event = { Add = function() end }
Events = { OnFillWorldObjectContextMenu = { Add = function(fn) table.insert(worldHandlers, fn) end },
    OnKeyPressed = event, OnKeyStartPressed = event }
function isClient() return client end
function isServer() return server end
function getSpecificPlayer(index) assert(index == 0); return activePlayer end
function getText(key)
    if string.find(key, "SuQingPry_", 1, true) then assert(translations[key], key) end
    return key
end
function getTexture(path) return path end
function instanceof(object, class) return object.class == class end

ISBaseObject = {}
function ISBaseObject:derive(name)
    local class = { Type = name }
    self.__index = self
    return setmetatable(class, self)
end
require "TimedActions/ISBaseTimedAction"
local completed = 0
function ISBaseTimedAction:perform() completed = completed + 1 end

ItemTag = { CROWBAR = "crowbar" }
Perks = { Strength = "Strength", Maintenance = "Maintenance" }
CharacterTrait = { BURGLAR = "Burglar" }
Metabolics = { UsingTools = "UsingTools" }

local sounds, strain, reach, tested, transfers, lootUpdates = 0, 0, true, 0, 0, 0
local lastRadius, lastHalo
local rolls = {}
function ZombRand(max)
    assert(max == 100 and #rolls > 0, "missing simulated random roll")
    return table.remove(rolls, 1)
end
function getGameTime() return { getMultiplier = function() return 1 end } end
function addSound(_, _, _, _, radius) sounds = sounds + 1; lastRadius = radius end
function triggerEvent(name) assert(name == "OnContainerUpdate"); lootUpdates = lootUpdates + 1 end
HaloTextHelper = { addBadText = function(_, message) lastHalo = message end }
IsoGridSquare = { isWithinReachOfCharacter = function(character, object)
    assert(character == activePlayer and object.class, "wrong reach arguments")
    return reach
end }

local square = { isAdjacentTo = function() return true end, canReachTo = function() return true end }
local crowbar = { condition = 10,
    hasTag = function(_, tag) return tag == ItemTag.CROWBAR end,
    isBroken = function(self) return self.condition == 0 end,
    getCondition = function(self) return self.condition end,
    setCondition = function(self, value) self.condition = value end }
local inventory = { tool = crowbar, getFirstTagEvalRecurse = function(self, tag, predicate)
    assert(tag == ItemTag.CROWBAR)
    if predicate(self.tool) then return self.tool end
end,
    haveThisKeyId = function() return false end }
local player = {
    hand = nil, z = 0, burglar = false, sitting = false,
    getPlayerNum = function() return 0 end,
    getCurrentSquare = function() return square end,
    getInventory = function() return inventory end,
    getPrimaryHandItem = function(self) return self.hand end,
    getVehicle = function(self) return self.sitting and self.nearVehicle or nil end,
    getUseableVehicle = function(self) return self.nearVehicle end,
    isBlockMovement = function() return false end,
    isTimedActionInstant = function() return true end,
    DistToProper = function() return 1 end,
    hasTrait = function(self, trait) assert(trait == CharacterTrait.BURGLAR); return self.burglar end,
    getPerkLevel = function(_, perk) return perk == Perks.Strength and 10 or 0 end,
    getBaseForceOpenChance = function() return 20 end,
    getX = function() return 0 end, getY = function() return 0 end, getZ = function(self) return self.z end,
    exertForForcing = function() strain = strain + 1 end,
    setMetabolicTarget = function(_, value) assert(value == Metabolics.UsingTools) end,
    playSound = function(_, sound) assert(sound == "CrowbarHit") end,
    faceThisObject = function(self, object) self.facing = object end,
    shouldBeTurning = function() return false end
}
activePlayer = player

ISWorldObjectContextMenu = {
    transferIfNeeded = function(character, tool) assert(character == player and tool == crowbar); transfers = transfers + 1 end,
    setTest = function() tested = tested + 1; return true end
}
ISInventoryPaneContextMenu = { equipWeapon = function(tool, primary, twoHands, index)
    assert(tool == crowbar and primary and twoHands and index == 0)
    player.hand = tool
end }
local queued
ISTimedActionQueue = { add = function(action) queued = action end, clear = function() queued = nil end }
local walkTarget
luautils = {
    walkAdj = function(character, targetSquare) assert(character == player and targetSquare == square); walkTarget = "container"; return reach end,
    walkAdjWindowOrDoor = function(character, targetSquare, target)
        assert(character == player and targetSquare == square and target.class)
        walkTarget = target
        return reach
    end
}

local function worldObject(class)
    return {
        class = class, forced = true, locked = true, boarded = false, present = true,
        getObjectIndex = function(self) return self.present and 0 or -1 end,
        getSquare = function() return square end,
        isDoor = function(self) return self.class == "IsoDoor" or self.door == true end,
        getContainer = function(self) return self.container end,
        isOpen = function(self) return self.open == true end,
        isBarricaded = function(self) return self.boarded end,
        isForceLocked = function(self) return self.forced end,
        isLocked = function(self) return self.locked end,
        isLockedByKey = function() return false end,
        isLockedByPadlock = function(self) return self.padlock == true end,
        getLockedByCode = function(self) return self.code or 0 end,
        setLockedByPadlock = function(self, value) self.padlock = value end,
        setLockedByCode = function(self, value) self.code = value end,
        failForceOpen = function(self) self.failed = true end,
        forceOpen = function(self) self.locked = false; self.open = not self.blocked end,
        sync = function(self) self.synced = true end
    }
end

local context = { options = {}, addOption = function(self, name, character, fn, object)
    table.insert(self.options, { name = name, callback = fn, target = object, character = character })
end }
local radial = { slices = {}, sounds = {}, displayed = false,
    addSlice = function(self, name, icon, fn, ...) table.insert(self.slices, {name, icon, fn, ...}) end,
    clear = function(self) self.slices = {} end, isEmpty = function(self) return #self.slices == 0 end,
    isReallyVisible = function(self) return self.displayed end,
    undisplay = function(self) self.displayed = false end,
    addToUIManager = function(self) self.displayed = true end,
    setX = function() end, setY = function() end,
    getWidth = function() return 100 end, getHeight = function() return 100 end
}
local function zero() return 0 end
getPlayerScreenLeft = zero
getPlayerScreenTop = zero
getPlayerScreenWidth = zero
getPlayerScreenHeight = zero
getPlayerRadialMenu = function() return radial end
getSoundManager = function() return { playUISound = function() end } end
JoypadState = { players = {} }
VehicleUtils = { getItems = function() return {} end }
ISWashVehicle = { hasBlood = function() return false end }

local function makeVehicle()
    local part, lock = { id = "DoorFrontLeft", mounted = true, area = "front" }, { locked = true }
    local vehicle = { part = part, speed = 0, z = 0, access = true, present = true, transmitted = 0,
        getUseablePart = function(self) return self.part end,
        getAnimalTrailerSize = zero, getScript = function() return nil end,
        getPartCount = function() return 1 end, getPartByIndex = function(self) return self.part end,
        isEngineStarted = function() return false end,
        getClosestWindow = function() return nil end,
        canUnlockDoor = function() return false end, canLockDoor = function() return false end,
        getSquare = function(self) return self.present and square or nil end,
        getCurrentSpeedKmHour = function(self) return self.speed end,
        getZ = function(self) return self.z end,
        isInArea = function(self, area, character) return self.access and area == part.area and character == player end,
        getPartById = function(self, id) if id == self.part.id then return self.part end end,
        transmitPartDoor = function(self, value) assert(value == self.part); self.transmitted = self.transmitted + 1 end,
        isPreviouslyEntered = function(self) return self.entered end,
        setPreviouslyEntered = function(self, value) self.entered = value end,
        getKeyId = function() return 7 end, isKeysInIgnition = function() return false end,
        isAlarmed = function() return true end,
        triggerAlarm = function(self) self.alarm = true end
    }
    function lock:isOpen() return self.open == true end
    function lock:isLocked() return self.locked end
    function lock:setOpen(value) self.open = value end
    function lock:setLocked(value) self.locked = value end
    function part:getId() return self.id end
    function part:getDoor() return lock end
    function part:getArea() return self.area end
    function part:isContainer() return false end
    function part:isVehicleTrunk() return self.trunk == true end
    function part:getVehicle() return vehicle end
    function part:getInventoryItem() return self.mounted and {} or nil end
    function part:getContainerSeatNumber() return -1 end
    return vehicle, part, lock
end

Vector3f = { new = function() return {} end }
local moduleName = "SuQingVanillaPryUpgrade/"
require "Vehicles/ISUI/ISVehicleMenu"
ISVehicleMenu.doTowingMenu = function() end
local baseFill = ISVehicleMenu.FillPartMenu
local vehicleCalls = 0
ISVehicleMenu.FillPartMenu = function(...)
    vehicleCalls = vehicleCalls + 1
    return baseFill(...)
end
client = true
assert(loadstring(sources[moduleName .. "Menus"]))()
expect(#worldHandlers == 1 and not ISVehicleMenu.SuQingVanillaPryUpgrade, "client registers no addon")
client = false
server = true
assert(loadstring(sources[moduleName .. "Menus"]))()
expect(#worldHandlers == 1 and not ISVehicleMenu.SuQingVanillaPryUpgrade, "server registers no addon")
server = false
require(moduleName .. "Menus")
assert(loadstring(sources[moduleName .. "Menus"]))()
expect(#worldHandlers == 2, "menu hook is registered once")
local worldMenu = worldHandlers[2]

local door = worldObject("IsoDoor")
local normal = worldObject("IsoDoor")
normal.forced = false
local window = worldObject("IsoWindow")
local boarded = worldObject("IsoDoor")
boarded.boarded = true
local removed = worldObject("IsoDoor")
removed.present = false
local unlocked = worldObject("IsoDoor")
unlocked.locked = false
local storage = worldObject("IsoThumpable")
storage.container, storage.code = {}, 1234
local keyedStorage = worldObject("IsoThumpable")
keyedStorage.container, keyedStorage.padlock = {}, true
local fridge = worldObject("IsoThumpable")
fridge.container = {}
local nonContainer = worldObject("IsoThumpable")
nonContainer.code = 1234
worldMenu(0, context, { fridge, nonContainer }, false)
expect(#context.options == 0, "unlocked fridge and non-container thumpables do not offer prying")
worldMenu(0, context, { normal, window, boarded, removed, unlocked }, false)
expect(#context.options == 0, "ordinary, unlocked, barricaded and removed targets stay untouched")
worldMenu(0, context, { door }, true)
expect(tested == 1 and #context.options == 0, "controller probe does not populate the menu")
crowbar.condition = 0
worldMenu(0, context, { door }, false)
expect(#context.options == 0, "broken tool hides action")
crowbar.condition = 10
worldMenu(0, context, { fridge, door, door, storage, keyedStorage }, false)
expect(#context.options == 3, "world menu deduplicates doors and skips the unlocked fridge")
expect(context.options[1].name == "ContextMenu_SuQingPry_ReinforcedDoor"
    and context.options[2].name == "ContextMenu_SuQingPry_Padlock", "world labels resolve")
expect(context.options[3].target == keyedStorage
    and context.options[3].name == "ContextMenu_SuQingPry_Padlock", "keyed padlock on storage is recognized")

local function attachActionMethods(action)
    action.forceComplete = function(self) self.finished = true end
    action.forceStop = function(self) self.stopped = true end
    action.addAfter = function(self, nextAction) self.nextAction = nextAction end
    return action
end

local function selectWorld(index)
    local option = context.options[index]
    option.callback(option.character, option.target)
    return attachActionMethods(assert(queued))
end

local action = selectWorld(1)
expect(walkTarget == door and transfers == 1 and action:isValid(), "world action walks, equips and queues")
door.boarded = true
action:update()
expect(action.stopped and door.locked and strain == 0, "added barricade cancels before rolling")
door.boarded = false
action = selectWorld(1)
rolls = { 99, 99, 0 }
action:update()
expect(not action.finished and door.locked and strain == 1, "failed success roll continues same action")
action:update()
action:perform()
expect(action.finished and door.failed and door.locked and lastHalo == "IGUI_SuQingPry_Failed", "hard failure uses vanilla door damage")
action = selectWorld(1)
rolls = { 99, 9 }
action:update()
action:perform()
expect(door.open and not door.locked, "strength floor applies to a reinforced door")
local thumpable = worldObject("IsoThumpable")
thumpable.door, thumpable.padlock, thumpable.code = true, true, 987
context.options = {}
worldMenu(0, context, { thumpable, storage }, false)
action = selectWorld(1)
rolls = { 99, 0 }
action:update()
action:perform()
expect(not thumpable.padlock and thumpable.code == 0 and thumpable.open, "door lock fields clear together")
action = selectWorld(2)
rolls = { 99, 0 }
action:update()
action:perform()
expect(walkTarget == "container" and storage.code == 0 and storage.synced and lootUpdates == 1, "padlocked storage becomes available")
local otherDoor = worldObject("IsoDoor")
otherDoor.blocked = true
context.options = {}
worldMenu(0, context, { otherDoor }, false)
action = selectWorld(1)
rolls = { 99, 0 }
action:update()
action:perform()
expect(not otherDoor.locked and not otherDoor.open and lastHalo == "IGUI_SuQingPry_Blocked", "does not override a physically blocked opening")

local vehicle, part, lock = makeVehicle()
player.nearVehicle = vehicle
local function openRadial()
    radial.displayed = false
    ISVehicleMenu.showRadialMenuOutside(player)
    return radial.slices[2]
end
local option = openRadial()
expect(vehicleCalls == 1 and #radial.slices == 3 and option[1] == "ContextMenu_SuQingPry_VehicleDoor", "outside wheel keeps vanilla slices and adds vehicle lock")
ISVehicleMenu.showRadialMenuOutside(player)
expect(not radial.displayed and vehicleCalls == 1, "vanilla toggle closes the radial")
local function selectVehicle()
    local entry = openRadial()
    assert(entry[1] == "ContextMenu_SuQingPry_VehicleDoor")
    entry[3](entry[4], entry[5], entry[6])
    return attachActionMethods(assert(queued))
end
action = selectVehicle()
part.mounted = false
expect(not action:isValid(), "removed vehicle door invalidates queued action")
part.mounted = true
vehicle.access = false
expect(not action:isValid(), "leaving the selected door's area invalidates queued action")
vehicle.access = true
player.z = 1
expect(not action:isValid(), "cannot pry across floors")
player.z = 0
vehicle.speed = 10
openRadial()
expect(#radial.slices == 2 and not action:isValid(), "moving vehicle hides the option and invalidates a queued attempt")
vehicle.speed = 0
lock.locked = false
openRadial()
expect(#radial.slices == 2, "unlocked car door does not show pry option")
lock.locked = true
part.id = "TrunkDoor"
expect(openRadial()[1] == "ContextMenu_SuQingPry_VehicleTrunk", "trunk has separate wording")
part.id = "EngineDoor"
expect(openRadial()[1] == "ContextMenu_SuQingPry_VehicleHood", "hood has separate wording")
part.id = "DoorFrontLeft"
action = selectVehicle()
rolls = { 0, 0 }
action:update()
action:perform()
expect(lock.locked and not action.nextAction and crowbar.condition == 9, "vehicle failure can wear the crowbar and leaves the lock")
player.burglar = true
action = selectVehicle()
rolls = { 7, 34 }
action:update()
action:perform()
expect(not lock.locked and not lock.open and vehicle.transmitted == 1 and lastRadius == 7, "burglar threshold, noise and selected lock update")
expect(action.nextAction and action.nextAction.Type == "ISOpenVehicleDoor" and action.nextAction.part == part,
    "queue contains exactly the native open action for this door")
function action.nextAction:selectContainerInLootWindow() end
action.nextAction:complete()
expect(lock.open and vehicle.alarm and lootUpdates == 2 and completed == 7 and sounds == strain, "native opening keeps alarm and loot side effects")

return "PASS " .. assertions .. " assertions"
