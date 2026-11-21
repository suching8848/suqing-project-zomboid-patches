local PREFIX = "UI_SuQingPortableVirusDetector_"
local DETECTOR = "Gunpart.HeartbeatSensorPlus"
local WATCH = "Base.WristWatch_Left_DigitalBlack"
local assertions = 0

local function check(value, message)
    assert(value, message)
    assertions = assertions + 1
end

local function newItem(kind, fullType, tag, location)
    return {
        kind = kind,
        tags = { [tag or "none"] = true },
        getFullType = function() return fullType end,
        getBodyLocation = function() return location end,
        getContainer = function(self) return self.container end,
        hasTag = function(self, key) return self.tags[key] == true end,
        isBroken = function(self) return self.broken == true end,
        hasModData = function(self)
            for _ in pairs(self.data or {}) do return true end
            return false
        end,
        getModData = function(self)
            self.data = self.data or {}
            return self.data
        end,
        setJobDelta = function(self, delta) self.jobDelta = delta end,
    }
end

local function newContainer()
    local items = {}
    return {
        contains = function(self, item, recurse)
            if items[item] then return true end
            return recurse and self.nested and self.nested:contains(item) or false
        end,
        AddItem = function(self, item) items[item] = true; item.container = self end,
        Remove = function(self, item)
            items[item] = nil
            item.container = nil
            if self.failAfterRemoving then error("debit interrupted") end
        end,
        getFirstTypeRecurse = function(self, fullType)
            for item in pairs(items) do
                if item:getFullType() == fullType then return item end
            end
            return self.nested and self.nested:getFirstTypeRecurse(fullType)
        end,
        getFirstTagEvalRecurse = function(self, tag, predicate)
            for item in pairs(items) do
                if item:hasTag(tag) and predicate(item) then return item end
            end
            return self.nested and self.nested:getFirstTagEvalRecurse(tag, predicate)
        end,
        setDrawDirty = function(self, dirty) self.dirty = dirty end,
    }
end

local handlers = {}
local function event(name)
    return { Add = function(callback) handlers[name] = callback end }
end

Events = { OnFillInventoryObjectContextMenu = event("fill"),
    OnGameStart = event("load"), OnMainMenuEnter = event("exit") }
ItemTag = { DIGITAL = "digital", SCREWDRIVER = "screwdriver" }
ItemBodyLocation = { LEFT_WRIST = "leftWrist", RIGHT_WRIST = "rightWrist" }
ISInventoryPane = {}
assert(loadstring(SOURCES.Selection, "inventory selection"))()
ISToolTip = { new = function() return { initialise = function() end } end }
UIFont = { NewSmall = "small" }
local panel, queued, scans, now, network = nil, nil, 0, 1000, false
local function derive(base)
    local class = { __index = nil }
    class.__index = class
    return setmetatable(class, { __index = base })
end
local function ignore() end
ISPanel = {
    derive = derive,
    new = function(class, x, y, width, height)
        return setmetatable({ x = x, y = y, width = width, height = height, visible = true, text = {} }, class)
    end,
    initialise = ignore,
    addToUIManager = function(self) panel = self end,
    removeFromUIManager = function(self) if panel == self then panel = nil end end,
    setVisible = function(self, visible) self.visible = visible end,
    drawRect = ignore,
    drawRectBorder = ignore,
    drawTextCentre = function(self, text) self.text[#self.text + 1] = text end,
    drawText = function(self, text) self.text[#self.text + 1] = text end,
}
ISBaseTimedAction = { derive = derive, stop = ignore,
    new = function(class, character) return setmetatable({ character = character }, class) end }
ISTimedActionQueue = { add = function(action) queued = action end }
function getText(key)
    check(TRANSLATIONS[key], "missing translation " .. key)
    return key
end
function instanceof(item, name) return item.kind == name or (name == "InventoryItem" and item.kind ~= nil) end
function isClient() return network end
function isServer() return false end
function getTimestampMs() return now end

local inventory = newContainer()
local bag, ground = newContainer(), newContainer()
inventory.nested = bag
local player = {
    getInventory = function() return inventory end,
    getX = function() return 10 end,
    getY = function() return 20 end,
    getZ = function() return 2 end,
    isTimedActionInstant = function() return false end,
    isDead = function(self) return self.dead end,
    Say = function(self, line) self.line = line end,
}
function getSpecificPlayer() return player end

local function zombie(x, y, z, dead)
    return { getX = function() return x end, getY = function() return y end,
        getZ = function() return z end, isDead = function() return dead end }
end
local zombies = {
    zombie(40, 20, 3), zombie(10, 22, 2), zombie(11, 19, 1),
    zombie(60, 20, 2), zombie(14, 24, 2, true), zombie(50, 60, 2),
}
function getCell()
    return { getZombieList = function()
        scans = scans + 1
        return { size = function() return #zombies end, get = function(_, i) return zombies[i + 1] end }
    end }
end

local loaded = {}
function require(name)
    if loaded[name] then return loaded[name] end
    local source = SOURCES[name]
    if not source then return end
    loaded[name] = assert(loadstring(source, name))()
    return loaded[name]
end
local Core = require("SuQingPortableVirusDetector/Core")
assert(loadstring(SOURCES.Menu, "Menu"))()

local function menu(...)
    local options = {}
    handlers.fill(0, { addOption = function(_, label, item, callback, ...)
        local option = { label = label, item = item, callback = callback, args = { ... } }
        options[#options + 1] = option
        return option
    end }, { ... })
    return options[1], #options
end
local function use(option)
    check(option and not option.notAvailable, "menu option is actionable")
    option.callback(option.item, unpack(option.args))
end

local watch = newItem("AlarmClockClothing", WATCH, "digital", "leftWrist")
local classic = newItem("AlarmClockClothing", "Base.WristWatch_Left_ClassicBlack", nil, "leftWrist")
local handheldClock = newItem("AlarmClock", "Base.AlarmClock2", "digital")
local tool = newItem("HandWeapon", "Base.Screwdriver", "screwdriver")
local basic = newItem("WeaponPart", "Gunpart.HeartbeatSensor")
local detector = newItem("WeaponPart", DETECTOR)
for _, item in ipairs({ watch, classic, handheldClock, tool, basic }) do inventory:AddItem(item) end
check(not menu(classic) and not menu(handheldClock), "analog watches and clocks have no option")
check(not menu(watch, classic), "multiple selected items have no option")
check(menu({ items = { watch, watch } }, watch) ~= nil, "dummy stack row is deduplicated")
check(not menu({ items = { watch, watch, classic } }), "multiple actual items in a stack have no option")
check(menu(watch).toolTip.description == PREFIX .. "NeedDetector", "basic sensor does not qualify")
ground:AddItem(detector)
check(not Core.canInstall(player, watch, detector, tool), "ground detector is not a supply")
ground:Remove(detector)
bag:AddItem(detector)
tool.broken = true
check(menu(watch).toolTip.description == PREFIX .. "NeedScrewdriver", "broken tool does not qualify")
tool.broken = false
local install = menu(watch)
check(install.label == PREFIX .. "Install", "install action on a digital watch")
use(install)
check(queued:isValid() and queued.maxTime == 60, "timed action validates nested supplies")
queued:stop()
check(bag:contains(detector) and not Core.isInstalled(watch), "cancel resets progress and keeps parts")
use(install)
inventory:Remove(tool)
check(not queued:complete() and bag:contains(detector), "lost tool blocks debit at completion")
inventory:AddItem(tool)
use(install)
bag.failAfterRemoving = true
check(not queued:complete() and bag:contains(detector) and not Core.isInstalled(watch),
    "failed debit restores the same detector and leaves watch unmodified")
bag.failAfterRemoving = false
use(install)
check(queued:complete() and Core.isInstalled(watch), "install marks the original watch")
check(not bag:contains(detector) and inventory:contains(tool) and inventory:contains(watch),
    "only the virus detector is consumed")
check(inventory.dirty and bag.dirty, "both changed UI containers refresh")
local secondDetector = newItem("WeaponPart", DETECTOR)
bag:AddItem(secondDetector)
check(not Core.install(player, watch, secondDetector, tool) and bag:contains(secondDetector),
    "repeat completion cannot debit another detector")
check(not panel and scans == 0, "installed watch starts with radar off")

local enable = menu(watch)
check(enable.label == PREFIX .. "RadarOn", "installed watch offers radar")
local gunPanel = {}
HeartbeatSensor = { instance = gunPanel }
use(enable)
check(panel and #panel.contacts == 3 and scans == 1, "one scan excludes dead, distant and boundary contacts")
check(panel.contacts[1].x == 30 and panel.contacts[1].color[3] == 1, "above contact relative position and blue")
check(panel.contacts[2].y == 2 and panel.contacts[2].color[1] == 1, "same floor red")
check(panel.contacts[3].color[2] == 1 and panel.contacts[3].color[3] == 1, "below contact cyan")
check(panel.moveWithMouse, "portable panel can be moved")
panel:render()
check(#panel.text == 4, "localized radar title and floor legend render")
panel:update()
now = 1499
panel:update()
check(scans == 1, "scan throttle prevents per-frame scans")
now = 1500
panel:update()
check(scans == 2, "next scan after 500 ms")
local previousPanel = panel
local disable = menu(watch)
check(disable.label == PREFIX .. "RadarOff", "right-click label follows radar state")
use(disable)
previousPanel:update()
check(not panel and not previousPanel.visible and scans == 2, "closing stops scans")
check(HeartbeatSensor.instance == gunPanel, "watch radar leaves the MFS panel alone")
use(menu(watch))
inventory:Remove(watch)
ground:AddItem(watch)
now = 2000
panel:update()
check(not panel and not menu(watch), "external storage closes the radar and removes its menu")
ground:Remove(watch)
inventory:AddItem(watch)

local onRight = newItem("AlarmClockClothing", "Base.WristWatch_Right_DigitalBlack", "digital", "rightWrist")
onRight.data = watch.data
inventory:AddItem(onRight)
check(Core.isInstalled(onRight), "vanilla wrist replacement can carry the mod data")
use(menu(onRight))
check(panel.watch == onRight, "right-wrist replacement opens the HUD")
handlers.exit()
check(not panel, "return to menu clears the HUD")
use(menu(onRight))
handlers.load()
check(not panel and menu(onRight).label == PREFIX .. "RadarOn", "load retains installation with radar off")
network = true
check(not menu(onRight), "multiplayer menu is disabled")
return "PASS " .. assertions .. " checks"
