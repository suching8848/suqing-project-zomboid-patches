local player, inventory, gun, sameModel = MFSUpgradeFixture.new(2, 1)
local fixture = MFSUpgradeFixture
local core = require("SuQingMFSFirearmUpgrade/Core")
local prefix = "UI_SuQingMFSFirearmUpgrade_"

function player:isTimedActionInstant() return false end
function player:Say(text) self.lastMessage = text end
function player:setMetabolicTarget(target) self.metabolicTarget = target end
function gun:setJobType(text) self.jobType = text end
function gun:setJobDelta(delta) self.jobDelta = delta end
function gun:getContainer()
    local container = self.container
    if container then
        container.setDrawDirty = function(target, dirty) target.drawDirty = dirty end
    end
    return container
end

function getText(key, ...)
    local args = { ... }
    local text = assert(MFSUpgradeTranslations[key], "untranslated key: " .. tostring(key))
    return (text:gsub("%%(%d+)", function(index) return assert(args[tonumber(index)], key) end))
end
function getSpecificPlayer(index) if index == 0 then return player end end
function getItemNameFromFullType(fullType) return fullType end

local fill
Events = { OnFillInventoryObjectContextMenu = { Add = function(listener) fill = listener end } }
ISInventoryPane = { getActualItems = function(items) return items end }
ISToolTip = {
    new = function()
        return { initialise = function(self) self.initialised = true end }
    end,
}
ISTimedActionQueue = {
    add = function(action)
        assert(action:isValidStart())
        ISTimedActionQueue.last = action
    end,
}
ISBaseTimedAction = {
    derive = function(self)
        return setmetatable({}, { __index = self })
    end,
    new = function(self, character)
        return setmetatable({ character = character }, { __index = self })
    end,
    isValidStart = function(self) return self:isValid() end,
    setActionAnim = function(self, name) self.animation = name end,
    getJobDelta = function() return 0.25 end,
    perform = function(self) self.performed = true end,
    stop = function(self) self.stopped = true end,
}
Metabolics = { UsingTools = "tools" }

local function newContext()
    local context = { options = {} }
    function context:addOption(label, target, callback, ...)
        local option = { label = label, target = target, callback = callback, args = { ... } }
        self.options[#self.options + 1] = option
        return option
    end
    context.getNew = newContext
    function context:addSubMenu(option, submenu) option.submenu = submenu end
    return context
end

require("SuQingMFSFirearmUpgradeMenu")
assert(fill, "inventory context menu callback was not registered")

local function options(items)
    local context = newContext()
    fill(0, context, items)
    return context.options
end

local function choose(option)
    assert(not option.notAvailable)
    option.callback(option.target, option.args[1], option.args[2], option.args[3])
    return assert(ISTimedActionQueue.last)
end

assert(#options({ gun, sameModel }) == 0, "multi-selection must not queue upgrades")
local first = options({ gun })
assert(#first == 2 and first[2].label == getText(prefix .. "MenuWithLevel", "0", "5"))
assert(first[1].label == getText(prefix .. "Maintain") and first[1].notAvailable)
assert(first[1].toolTip.description == getText(prefix .. "Error_DryTowel"))
local upgrade = first[2].submenu.options[1]
assert(upgrade.label == getText(prefix .. "Upgrade", "1"))
assert(upgrade.toolTip.initialised)
assert(upgrade.toolTip.description:find("1.70", 1, true) and upgrade.toolTip.description:find("1.87", 1, true))
assert(upgrade.toolTip.description:find("20.0%", 1, true) and upgrade.toolTip.description:find("40.0%", 1, true))
assert(upgrade.toolTip.description:find("×2.20", 1, true))
assert(upgrade.toolTip.description:find("51.00 tiles", 1, true))
assert(upgrade.toolTip.description:find("56.10 tiles", 1, true))
assert(upgrade.toolTip.description:find("1/118 → 1/131", 1, true))
assert(upgrade.toolTip.description:find(fixture.metal, 1, true))
assert(upgrade.toolTip.description:find("Base.Screwdriver", 1, true))

local action = choose(upgrade)
action:start()
action:update()
assert(action.animation == "Craft" and gun.jobDelta == 0.25 and player.metabolicTarget == Metabolics.UsingTools)
action:stop()
assert(action.stopped and gun.jobDelta == 0 and core.getState(gun) == 0)
assert(fixture.count(inventory, fixture.metal) == 2 and fixture.count(inventory, fixture.polymer) == 1)

action = choose(upgrade)
action:start()
assert(action:isValid())
assert(action:complete())
action:perform()
assert(action.performed and gun.jobDelta == 0 and gun:getContainer().drawDirty)
assert(core.getState(gun) == 1)
fixture.close(gun.critChance, 40)
fixture.close(gun.critMultiplier, 2.2)
fixture.close(gun.range, 56.1)
assert(gun.wearRoll == 131 and gun.condition == 19)
assert(player.lastMessage == getText(prefix .. "Upgraded", "1"))
assert(fixture.count(inventory, fixture.metal) == 0 and fixture.count(inventory, fixture.polymer) == 0)

local nextOptions = options({ gun })[2].submenu.options
assert(#nextOptions == 2 and nextOptions[1].notAvailable)
assert(nextOptions[1].toolTip.description:find(getText(prefix .. "Error_Materials"), 1, true))
assert(nextOptions[1].toolTip.description:find(fixture.metal, 1, true))
-- An upstream change to the ammo type must not strand a saved upgrade.
gun.ammo = "Base.GrenadeAmmo"
local specialOptions = options({ gun })[1].submenu.options
assert(#specialOptions == 1, "previously upgraded special weapon should offer reset only")
local reset = specialOptions[1]
assert(reset.label == getText(prefix .. "Reset"))
assert(choose(reset):complete())
assert(core.getState(gun) == 0 and player.lastMessage == getText(prefix .. "ResetDone"))
fixture.close(gun.min, gun.baseMin)
fixture.close(gun.max, gun.baseMax)
fixture.close(gun.critChance, 20)
fixture.close(gun.critMultiplier, 2)
fixture.close(gun.range, gun.baseRange)
assert(gun.wearRoll == 118 and gun.condition == 19)
assert(fixture.count(inventory, fixture.metal) == 0 and fixture.count(inventory, fixture.polymer) == 0)

gun.ammo = 'Base.Bullets9mm'
gun.chambered = true
local loaded = options({ gun })[2].submenu.options[1]
assert(loaded.notAvailable and loaded.toolTip.description:find(getText(prefix .. "Error_Unload"), 1, true))
gun.chambered = false



local function dryTowel(uses)
    local towel = { class = "DrainableComboItem", fullType = "Base.BathTowel", uses = uses }
    function towel:getFullType() return self.fullType end
    function towel:getCurrentUses() return self.uses end
    function towel:setCurrentUses(value) self.uses = value end
    function towel:getContainer() return self.container end
    function towel:isWet() return self.wet == true end
    function towel:Use()
        if self.failUse then return end
        self.uses = self.uses - 1
        if self.uses == 0 and not self.failReplacement then
            local bag = self.container
            bag:AddItem({
                fullType = "Base.BathTowelWet",
                getFullType = function(self) return self.fullType end,
            })
            bag:Remove(self)
        end
    end
    return towel
end

local function maintenanceOption()
    local option = options({ gun })[1]
    assert(option.label == getText(prefix .. "Maintain"))
    return option
end

local function maintenanceBlocked(reason)
    local option = maintenanceOption()
    assert(option.notAvailable and option.toolTip.description == getText(prefix .. "Error_" .. reason))
end

local towel = inventory.bag:AddItem(dryTowel(2))
local empty = inventory:AddItem(dryTowel(0))
local wet = inventory:AddItem(dryTowel(3))
wet.wet = true
local option = maintenanceOption()
assert(not option.notAvailable)
assert(option.toolTip.description:find("19/25 → 20/25", 1, true))
assert(option.toolTip.description:find("2 → 1", 1, true))

local wipe = choose(option)
wipe:start()
wipe:stop()
assert(wipe.stopped and gun.condition == 19 and towel.uses == 2)

wipe = choose(maintenanceOption())
inventory.bag:Remove(towel)
assert(not wipe:isValid() and not wipe:complete() and gun.condition == 19 and towel.uses == 2)
inventory.bag:AddItem(towel)

wipe = choose(maintenanceOption())
gun.condition = 18
assert(not wipe:isValid() and not wipe:complete() and gun.condition == 18 and towel.uses == 2)
gun.condition = 19

for _, flag in ipairs({ "loaded", "clip", "chambered", "spent" }) do
    gun[flag] = flag == "loaded" and 1 or true
    maintenanceBlocked("Unload")
    gun[flag] = flag == "loaded" and 0 or false
end
gun.condition = 25
maintenanceBlocked("FullCondition")
gun.condition = 0
maintenanceBlocked("Broken")
gun.condition = 19

towel.failUse = true
assert(not choose(maintenanceOption()):complete())
assert(gun.condition == 19 and towel.uses == 2)
towel.failUse = false
gun.failCondition = true
assert(not choose(maintenanceOption()):complete())
assert(gun.condition == 19 and towel.uses == 2)
gun.failCondition = false

wipe = choose(maintenanceOption())
wipe:start()
assert(gun.jobType == getText(prefix .. "Wiping"))
assert(wipe:complete())
wipe:perform()
assert(wipe.performed and gun.condition == 20 and towel.uses == 1 and sameModel.condition == 19)
assert(player.lastMessage == getText(prefix .. "Maintained", "20", "25"))
assert(not wipe:complete() and gun.condition == 20 and towel.uses == 1)

gun.condition = 24
towel.failReplacement = true
assert(not choose(maintenanceOption()):complete())
assert(gun.condition == 24 and towel.uses == 1 and inventory:contains(towel, true))
assert(fixture.count(inventory, "Base.BathTowelWet") == 0)
towel.failReplacement = false
assert(choose(maintenanceOption()):complete())
assert(gun.condition == 25 and gun.conditionMax == 25 and not inventory:contains(towel, true))
assert(fixture.count(inventory, "Base.BathTowelWet") == 1 and wet.uses == 3 and empty.uses == 0)
assert(core.getState(gun) == 0 and gun.wearRoll == 118)
maintenanceBlocked("FullCondition")
gun.condition = 24
maintenanceBlocked("DryTowel")
