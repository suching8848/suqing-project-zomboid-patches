local MOD = "SuQingMustangProtectionRepair"

if isClient() or isServer() then return end

require "ISUI/ISButton"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "Vehicles/TimedActions/ISPathFindAction"
require "Tuning2/ISVehicleTuning2"

local REPAIR_POINTS = 30
local FUEL_USES = 3
local WELDING_LEVEL = 2

local sheet = "Base.SheetMetal"
local link = "Base.HeavyChainLink"
local repairableModels = {
    ATA2Bullbar = { ATABullbar1 = sheet, ATABullbar2 = sheet, ATABullbar3 = sheet },
    ATA2ProtectionWindowFrontLeft = { Default = sheet },
    ATA2ProtectionWindowFrontRight = { Default = sheet },
    ATA2ProtectionWindshield = { Default = sheet },
    ATA2ProtectionWindshieldRear = { Default = sheet },
    ATA2ProtectionWheels = { ATAProtection = link },
}

local allowedVehicles = {
    ATAMustang = true,
    ATAMustangClassic = true,
    ATAMustangPolice = true,
}

local function getTarget(vehicle, slot, model)
    local modelsForSlot = repairableModels[slot]
    local material = modelsForSlot and modelsForSlot[model]
    if not material or not vehicle then return end

    local script = vehicle:getScript()
    local tuning = ATA2TuningTable
    if not script or not tuning then return end

    local name = script:getName()
    local car = tuning[name]
    local mustang = tuning.ATAMustang
    if not car or not car.parts then return end
    if not allowedVehicles[name] then
        -- The NIKKE add-on registers its Mustang variants as aliases of the base car.
        if not name:match("^ATAMustangNikke") or not mustang or car.parts ~= mustang.parts then
            return
        end
    end

    local models = car.parts[slot]
    local definition = models and models[model]
    if not definition or not definition.protection or #definition.protection == 0 then return end

    local part = vehicle:getPartById(slot)
    local item = part and part:getInventoryItem()
    local state = part and part:getModData().tuning2
    if not item or not state or state.model ~= model then return end

    return part, item, material, definition
end

local function getSupplies(character, material)
    if character:getPerkLevel(Perks.MetalWelding) < WELDING_LEVEL then
        return nil, "IGUI_SQ_MPR_NeedSkill"
    end

    local inventory = character:getInventory()
    local mask = inventory:getBestConditionRecurse("Base.WeldingMask")
    if not mask or mask:isBroken() then return nil, "IGUI_SQ_MPR_NeedMask" end

    local stock = inventory:getBestConditionRecurse(material)
    if not stock then
        local key = material == link and "IGUI_SQ_MPR_NeedLink" or "IGUI_SQ_MPR_NeedSheet"
        return nil, key
    end

    local torches = inventory:getAllTypeRecurse("Base.BlowTorch")
    local fuel = {}
    local remaining = FUEL_USES
    for i = 0, torches:size() - 1 do
        local torch = torches:get(i)
        if torch:IsDrainable() and not torch:isBroken() then
            local count = math.min(remaining, torch:getCurrentUses())
            if count > 0 then
                fuel[#fuel + 1] = { item = torch, count = count }
                remaining = remaining - count
                if remaining == 0 then return { stock = stock, fuel = fuel } end
            end
        end
    end

    return nil, "IGUI_SQ_MPR_NeedFuel"
end

local RepairAction = ISBaseTimedAction:derive("SuQingMustangProtectionRepairAction")

function RepairAction:new(character, vehicle, slot, model, item, area)
    local action = ISBaseTimedAction.new(self, character)
    action.vehicle = vehicle
    action.slot = slot
    action.model = model
    action.item = item
    action.area = area
    action.maxTime = action:getDuration()
    action.stopOnWalk = true
    action.stopOnRun = true
    action.stopOnAim = true
    return action
end

function RepairAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 100
end

function RepairAction:getPart()
    local character = self.character
    local square = self.vehicle:getSquare()
    if self.finished or character:getVehicle() or not square
        or square:getMovingObjects():indexOf(self.vehicle) < 0
        or not self.vehicle:isInArea(self.area, character) then
        return
    end

    local part, item, material = getTarget(self.vehicle, self.slot, self.model)
    if not part or item ~= self.item or part:getCondition() >= 100 then return end
    return part, material
end

function RepairAction:isValid()
    return self:getPart() ~= nil
end

function RepairAction:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function RepairAction:start()
    self:setActionAnim("Loot")
end

function RepairAction:stop()
    self.finished = true
    ISBaseTimedAction.stop(self)
end

function RepairAction:forceCancel()
    self.finished = true
end

function RepairAction:complete()
    local part, material = self:getPart()
    if not part then return false end

    local supplies, reason = getSupplies(self.character, material)
    if not supplies then
        self.character:Say(getText(reason))
        return false
    end

    local before = part:getCondition()
    local stock = supplies.stock
    local container = stock:getContainer()
    if not container then return false end

    self.finished = true
    for _, fuel in ipairs(supplies.fuel) do
        for _ = 1, fuel.count do fuel.item:UseAndSync() end
    end
    self.character:removeFromHands(stock)
    container:Remove(stock)
    sendRemoveItemFromContainer(container, stock)

    -- VehiclePart:setCondition also updates its backing item in B42.21.
    local repaired = math.min(100, before + REPAIR_POINTS)
    part:setCondition(repaired)
    self.vehicle:transmitPartCondition(part)
    self.character:Say(getText("IGUI_SQ_MPR_Done", tostring(repaired)))
    return true
end

local function getSelection(window)
    local view = window.panel and window.panel.activeView
    if not view or not view.view or view.view.category ~= getText("IGUI_TuningCategory_Installed") then return end
    local list = view.view.recipes
    local row = list and list.items and list.items[list.selected]
    local recipe = row and row.item
    if not recipe or recipe.type ~= "uninstall" then return end

    local part, item, material, definition = getTarget(window.vehicle, recipe.partName, recipe.modelName)
    if not part or part:getCondition() >= 100 then return end
    return recipe, part, item, material, definition
end

local function startRepair(window)
    local recipe, part, item, material, definition = getSelection(window)
    local character = window.character
    if not recipe or character:getVehicle() then return end

    local supplies, reason = getSupplies(character, material)
    if not supplies then
        character:Say(getText(reason))
        return
    end

    local area = definition.install and definition.install.area or part:getArea()
    if not area then
        character:Say(getText("IGUI_SQ_MPR_Unavailable"))
        return
    end

    if not window.vehicle:isInArea(area, character) then
        ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(character, window.vehicle, area))
    end
    ISTimedActionQueue.add(RepairAction:new(character, window.vehicle, recipe.partName, recipe.modelName, item, area))
    window:close()
end

local windowClass = ISVehicleTuning2
if not windowClass or type(windowClass.createChildren) ~= "function" or type(windowClass.render) ~= "function" then
    print("[" .. MOD .. "] Tuning2 window unavailable; patch inactive")
    return
end
if windowClass.sqMustangRepairInstalled then return end
windowClass.sqMustangRepairInstalled = true

local createChildren = windowClass.createChildren
function windowClass:createChildren()
    createChildren(self)
    local button = ISButton:new(0, 0, 90, 25, getText("IGUI_SQ_MPR_Repair"), self, startRepair)
    button:initialise()
    self:addChild(button)
    button:setVisible(false)
    self.sqMustangRepairButton = button
end

local render = windowClass.render
function windowClass:render()
    render(self)
    local button = self.sqMustangRepairButton
    if not button then return end

    local original = self.craftOneButton
    local recipe, part, _, material = getSelection(self)
    if not recipe or not original or not original:getIsVisible() or self.isCollapsed then
        button:setVisible(false)
        return
    end

    local before = part:getCondition()
    local title = getText("IGUI_SQ_MPR_RepairRange", tostring(before), tostring(math.min(100, before + REPAIR_POINTS)))
    local x = original:getX() + original:getWidth() + 6
    local debugButton = self.debugGiveIngredientsButton
    if debugButton and debugButton:getIsVisible() then
        x = debugButton:getX() + debugButton:getWidth() + 6
    end

    button:setTitle(title)
    button:setWidth(getTextManager():MeasureStringX(UIFont.Small, title) + 20)
    button:setX(x)
    button:setY(original:getY())
    button:setEnable(self.character:getVehicle() == nil)
    button:setTooltip(getText(material == link and "IGUI_SQ_MPR_LinkCost" or "IGUI_SQ_MPR_SheetCost"))
    button:setVisible(true)
end

print("[" .. MOD .. "] Tuning2 repair ready")