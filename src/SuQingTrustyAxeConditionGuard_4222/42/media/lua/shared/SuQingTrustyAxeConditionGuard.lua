local axeType = "TrustyFireAxe.Trusty_Firefighter_Axe"
local logPrefix = "[SuQingTrustyAxeConditionGuard] "

local function isSinglePlayer()
    return not isClient() and not isServer()
end

local function clampAxe(item)
    if not item or item:getFullType() ~= axeType or not item:hasHeadCondition() then
        return
    end

    local maximum = item:getHeadConditionMax()
    local condition = item:getHeadCondition()
    if maximum > 0 and condition > maximum then
        item:setHeadCondition(maximum)
        if item:hasSharpness() then
            local sharpnessLimit = item:getMaxSharpness()
            if item:getSharpness() > sharpnessLimit then
                item:setSharpness(sharpnessLimit)
            end
        end
        print(logPrefix .. "blade condition " .. condition .. " -> " .. maximum)
    end
end

local function clampTemplate()
    if not isSinglePlayer() then
        return
    end

    local script = getScriptManager():getItem(axeType)
    local attributes = script and script:getComponentScriptFor(ComponentType.Attributes)
    local template = attributes and attributes:getTemplateContainer()
    if not template then
        return
    end

    local blade = template:getAttribute(Attribute.TypeFromName("HeadCondition"))
    local bladeMax = template:getAttribute(Attribute.TypeFromName("HeadConditionMax"))
    -- Match InventoryItem:getHeadConditionMax() when the blade has no explicit maximum.
    local maximum = bladeMax and bladeMax:getIntValue() or script:getConditionMax()
    if blade and maximum > 0 and blade:getIntValue() > maximum then
        blade:setValueFromScriptString(string.format("%d", maximum))
    end
end

local function clampInventory(_, player)
    if not isSinglePlayer() or not player then
        return
    end

    local axes = player:getInventory():getItemsFromFullType(axeType, true)
    for index = 0, axes:size() - 1 do
        clampAxe(axes:get(index))
    end
end

local function onEquip(_, item)
    if isSinglePlayer() then
        clampAxe(item)
    end
end

local function onBeforeInventoryMenu(_, _, selectedItems)
    if not isSinglePlayer() then
        return
    end

    for _, item in ipairs(ISInventoryPane.getActualItems(selectedItems)) do
        clampAxe(item)
    end
end

local function guardSharpening(callbackName)
    local original = RecipeCodeOnCreate[callbackName]
    if not original then
        print(logPrefix .. "missing recipe callback " .. callbackName)
        return
    end

    RecipeCodeOnCreate[callbackName] = function(recipeData, character)
        if isSinglePlayer() then
            clampAxe(recipeData:getFirstInputItemWithFlag("IsSharpenable"))
        end
        return original(recipeData, character)
    end
end

-- Register before CraftRecipeData resolves and caches its OnCreate callback.
guardSharpening("sharpenBlade")
guardSharpening("sharpenBladeGrindstone")

Events.OnGameBoot.Add(clampTemplate)
Events.OnInitWorld.Add(clampTemplate)
Events.OnCreatePlayer.Add(clampInventory)
Events.OnEquipPrimary.Add(onEquip)
Events.OnEquipSecondary.Add(onEquip)
Events.OnPreFillInventoryObjectContextMenu.Add(onBeforeInventoryMenu)
