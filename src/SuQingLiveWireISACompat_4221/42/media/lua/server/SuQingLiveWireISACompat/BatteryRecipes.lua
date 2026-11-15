local Recipes = {}
local marker = "SuQingLiveWireISAMeteredBattery"
local wired = "ISA.WiredCarBattery"
local rawModels = {
    ["Base.CarBattery1"] = true,
    ["Base.CarBattery2"] = true,
    ["Base.CarBattery3"] = true,
}
local installed = false

function Recipes.mark(item)
    local model = item:getFullType()
    if rawModels[model] or model == wired then
        local data = item:getModData()
        if data[marker] ~= true then data[marker] = true end
    end
end

local function markedInput(data, models)
    local items = data:getAllConsumedItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and models[item:getFullType()] then
            if item:getModData()[marker] == true then return item end
            return nil
        end
    end
end

function Recipes.install(isaCapacity, fromMod, ready)
    if installed then return true end
    local isaRecipes = require "ImmersiveSolarArrays/RecipeCode"
    local create = type(isaRecipes) == "table" and isaRecipes.OnCreate
    local battery = LiveWire and LiveWire.Batteries
    local path = "media/lua/shared/ImmersiveSolarArrays/RecipeCode.lua"
    if type(isaCapacity) ~= "function" or not create or not battery
        or type(battery.energy) ~= "function" or type(battery.setEnergy) ~= "function"
        or type(battery.capacity) ~= "function" or type(battery.condition) ~= "function"
        or type(create.wireCarBattery) ~= "function" or type(create.unwireCarBattery) ~= "function"
        or not Actions or type(Actions.addOrDropItem) ~= "function" then
        return false, "recipe_interface_missing"
    end
    if fromMod and (not fromMod(create.wireCarBattery, "ISA", path)
        or not fromMod(create.unwireCarBattery, "ISA", path)) then
        return false, "recipe_source_changed"
    end

    local function rawCapacity(item)
        return battery.capacity(item:getFullType(), battery.condition(item))
    end

    local function transferCharge(output, amount, capacity)
        -- Native wear/capacity rolls can shrink the destination. A smaller
        -- battery keeps only the energy it can hold, without creating charge.
        battery.setEnergy(output, math.min(amount, capacity), capacity)
        Recipes.mark(output)
    end

    local wire = create.wireCarBattery
    create.wireCarBattery = function(data, character)
        if ready and not ready() then return wire(data, character) end
        local input = markedInput(data, rawModels)
        local energy = input and battery.energy(input, rawCapacity(input))
        wire(data, character)
        if not input then return end
        local output = data:getFirstCreatedItem()
        if output and output:getFullType() == wired then
            transferCharge(output, energy, isaCapacity(output))
            output:syncItemFields()
        end
    end

    local wiredModels = { [wired] = true }
    local unwire = create.unwireCarBattery
    create.unwireCarBattery = function(data, character)
        if ready and not ready() then return unwire(data, character) end
        local input = markedInput(data, wiredModels)
        if not input then return unwire(data, character) end
        local model = input:getModData().unwiredType or "Base.CarBattery1"
        if not rawModels[model] then return unwire(data, character) end
        local energy = battery.energy(input, isaCapacity(input))
        -- The pinned native recipe creates and hands off its result inside
        -- OnCreate. Intercept only that delivery during this synchronous call.
        local actions = Actions
        local add = actions.addOrDropItem
        actions.addOrDropItem = function(recipient, item)
            if recipient == character and item and item:getFullType() == model then
                transferCharge(item, energy, rawCapacity(item))
            end
            return add(recipient, item)
        end
        local ok, reason = pcall(unwire, data, character)
        actions.addOrDropItem = add
        if not ok then error(reason) end
    end
    installed = true
    return true
end

return Recipes
