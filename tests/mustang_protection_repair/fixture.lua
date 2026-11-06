local function class()
    local base = {}
    base.__index = base
    function base:derive(name)
        local cls = { name = name }
        cls.__index = cls
        return setmetatable(cls, { __index = self })
    end
    return base
end

function isClient() return false end
function isServer() return false end
function require(path) end
function getText(key, a, b)
    if a then return key .. " " .. tostring(a) .. (b and (" " .. tostring(b)) or "") end
    return key
end

UIManager = {}
UI_FONT = { MeasureStringX = function(_, font, text) return #text * 5 end }
function getTextManager() return UI_FONT end
UIFont = { Small = 1 }
Perks = { MetalWelding = "MetalWelding" }

local buttons = class()
function buttons:new(x, y, width, height, title, target, callback)
    return setmetatable({
        x = x, y = y, width = width, height = height, title = title,
        target = target, callback = callback,
    }, self)
end
function buttons:initialise() end
function buttons:setVisible(value) self.visible = value end
function buttons:getIsVisible() return self.visible end
function buttons:setEnable(value) self.enabled = value end
function buttons:setTitle(value) self.title = value end
function buttons:setTooltip(value) self.tooltip = value end
function buttons:setX(value) self.x = value end
function buttons:setY(value) self.y = value end
function buttons:setWidth(value) self.width = value end
function buttons:getX() return self.x end
function buttons:getY() return self.y end
function buttons:getWidth() return self.width end
ISButton = buttons

ISVehicleTuning2 = class()
function ISVehicleTuning2:createChildren()
    self.craftOneButton = ISButton:new(400, 330, 60, 25, "Uninstall", self)
    self.craftOneButton:setVisible(true)
    self.debugGiveIngredientsButton = ISButton:new(465, 330, 100, 25, "Debug", self)
    self.debugGiveIngredientsButton:setVisible(false)
end
function ISVehicleTuning2:render() self.renders = self.renders + 1 end
function ISVehicleTuning2:addChild(button) self.children[#self.children + 1] = button end
function ISVehicleTuning2:close() self.closed = true end

ISBaseTimedAction = class()
function ISBaseTimedAction:new(character)
    return setmetatable({ character = character }, self)
end
function ISBaseTimedAction:setActionAnim(animation) self.animation = animation end
function ISBaseTimedAction:stop() self.stopped = true end
queued = {}
ISTimedActionQueue = { add = function(action) queued[#queued + 1] = action end }
ISPathFindAction = { pathToVehicleArea = function(_, player, vehicle, area) return { path = area } end }
function sendRemoveItemFromContainer(container, item) end

ATA2TuningTable = {}
function ATA2Tuning_AddNewCars(definitions)
    for name, car in pairs(definitions) do ATA2TuningTable[name] = car end
end

function newFixture(options)
    options = options or {}
    local slot = options.slot or "ATA2Bullbar"
    local model = options.model or "ATABullbar1"
    local inventory = { items = {} }
    function inventory:Remove(item)
        assert(item.owner == self)
        item.owner = nil
        for i, candidate in ipairs(self.items) do
            if candidate == item then table.remove(self.items, i); return end
        end
        error("Cannot remove unowned item")
    end
    function inventory:getAllTypeRecurse(itemType)
        local matched = {}
        for _, item in ipairs(self.items) do
            if item.itemType == itemType then matched[#matched + 1] = item end
        end
        return { size = function() return #matched end, get = function(_, i) return matched[i + 1] end }
    end
    function inventory:getBestConditionRecurse(itemType)
        return self:getAllTypeRecurse(itemType):get(0)
    end

    local function inventoryItem(itemType, uses, broken)
        local item = { itemType = itemType, owner = inventory, uses = uses }
        function item:getContainer() return self.owner end
        function item:isBroken() return broken end
        function item:IsDrainable() return self.uses ~= nil end
        function item:getCurrentUses() return self.uses end
        function item:UseAndSync()
            assert(self.uses > 0 and self.owner == inventory)
            self.uses = self.uses - 1
        end
        inventory.items[#inventory.items + 1] = item
        return item
    end

    local mask = not options.noMask and inventoryItem("Base.WeldingMask", nil, options.brokenMask)
    local metal = not options.noMetal and inventoryItem("Base.SheetMetal")
    local link = not options.noLink and inventoryItem("Base.HeavyChainLink")
    local torch = inventoryItem("Base.BlowTorch", options.fuel or 5)
    local second = options.secondFuel and inventoryItem("Base.BlowTorch", options.secondFuel)
    local player = { skill = options.skill or 2, inside = nil }
    function player:getInventory() return inventory end
    function player:getPerkLevel(perk) assert(perk == Perks.MetalWelding); return self.skill end
    function player:getVehicle() return self.inside end
    function player:removeFromHands(item) assert(item.owner == inventory) end
    function player:Say(line) self.lastLine = line end
    function player:isTimedActionInstant() return false end
    function player:faceThisObject(object) self.facing = object end
    function player:shouldBeTurning() return false end

    local backing = { condition = options.condition or 62 }
    local part = { backing = backing, condition = backing.condition, data = { tuning2 = { model = model } } }
    function part:getInventoryItem() return self.backing end
    function part:getCondition() return self.condition end
    function part:getModData() return self.data end
    function part:getArea() return "Engine" end
    function part:setCondition(value)
        self.condition = value
        self.backing.condition = value
    end
    local protected = { condition = 35 }
    local car = {
        script = options.car or "ATAMustang", present = true, near = true, transmitted = 0,
        parts = { [slot] = part, Windshield = protected },
    }
    function car:getScript() return { getName = function() return self.script end } end
    function car:getPartById(id) return self.parts[id] end
    function car:getSquare()
        return { getMovingObjects = function()
            return { indexOf = function(_, candidate) return self.present and candidate == self and 0 or -1 end }
        end }
    end
    function car:isInArea(area, character)
        assert(area == "Engine" or area == "TireFrontLeft" or area == "TireRearRight")
        assert(character == player)
        return self.near
    end
    function car:transmitPartCondition(updated)
        assert(updated == part)
        self.transmitted = self.transmitted + 1
    end

    local recipe = { type = "uninstall", partName = slot, modelName = model }
    local view = {
        category = "IGUI_TuningCategory_Installed",
        recipes = { items = { { item = recipe } }, selected = 1 },
    }
    local window = setmetatable({
        character = player, vehicle = car, renders = 0, children = {},
        panel = { activeView = { view = view } },
    }, ISVehicleTuning2)
    queued = {}
    window:createChildren()
    window:render()
    return {
        window = window, button = window.sqMustangRepairButton, inventory = inventory, player = player,
        part = part, car = car, recipe = recipe, view = view, mask = mask, link = link, metal = metal,
        torch = torch, second = second, protected = protected,
    }
end