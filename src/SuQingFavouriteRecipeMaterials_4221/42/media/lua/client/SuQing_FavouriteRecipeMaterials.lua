require "ISUI/ISToolTipInv"

if SuQingFavouriteRecipeMaterialsLoaded then return end
SuQingFavouriteRecipeMaterialsLoaded = true

local materialsByType
local installed = false
local activeItem, activeTooltip

local function buildIndex()
    local manager = getScriptManager()
    local byName = {}
    for _, recipes in ipairs({ manager:getAllCraftRecipes(), manager:getAllBuildableRecipes() }) do
        for i = 0, recipes:size() - 1 do
            local recipe = recipes:get(i)
            local name = recipe:getName()
            local previous = byName[name]
            -- Stock favourites use a short name, so an ambiguous key cannot identify a custom recipe.
            if previous == nil then
                byName[name] = recipe
            elseif previous ~= recipe then
                byName[name] = false
            end
        end
    end

    local index = {}
    for _, recipe in pairs(byName) do
        if recipe and string.sub(recipe:getScriptObjectFullType(), 1, 5) ~= "Base." then
            local entry = {
                recipe = recipe,
                key = BaseCraftingLogic.getFavouriteModDataString(recipe),
                needsLearning = recipe:needToBeLearn(),
            }
            local seen = {}
            local inputs = recipe:getInputs()
            for i = 0, inputs:size() - 1 do
                local input = inputs:get(i)
                -- Vanilla does not mark every item for wildcard recipes.
                if not input:isAcceptsAnyItem() then
                    local items = input:getPossibleInputItems()
                    for j = 0, items:size() - 1 do
                        local fullType = items:get(j):getFullName()
                        if not seen[fullType] then
                            seen[fullType] = true
                            local entries = index[fullType]
                            if not entries then
                                entries = {}
                                index[fullType] = entries
                            end
                            entries[#entries + 1] = entry
                        end
                    end
                end
            end
        end
    end
    return index
end

local function isCustomFavouriteInput(item, player)
    if not player then return false end
    -- Read the resolved inputs after start-up handlers have finished changing them.
    if not materialsByType then
        local ok, result = pcall(buildIndex)
        materialsByType = ok and result or {}
        if not ok then print("[SuQing Favourite Recipe Materials] index unavailable: " .. tostring(result)) end
    end
    local entries = materialsByType[item:getFullType()]
    if not entries then return false end
    local data = player:getModData()
    for _, entry in ipairs(entries) do
        if data[entry.key] == true and (not entry.needsLearning or SandboxVars.SeeNotLearntRecipe
            or player:isRecipeActuallyKnown(entry.recipe)) then
            return true
        end
    end
    return false
end

local function appendTooltipLine(tooltip)
    local text = getText("Tooltip_item_IsFavouriteInput")
    local height = tooltip:getHeight()
    tooltip:adjustWidth(5, text)
    tooltip:setHeight(height + tooltip:getLineSpacing())
    if not tooltip:isMeasureOnly() then
        local color = getCore():getGoodHighlitedColor()
        tooltip:DrawText(tooltip:getFont(), text, 5, height - 2, color:getR(), color:getG(), color:getB(), 1)
    end
end

local function install()
    materialsByType = nil
    if installed or isClient() or isServer() or getCore():getVersionNumber() ~= "42.21" then return end

    local tooltips = ISToolTipInv
    local render = tooltips and tooltips.render
    if not render or type(__classmetatables) ~= "table" then return end

    local originals = {}
    local found = false
    for _, metatable in pairs(__classmetatables) do
        local methods = rawget(metatable, "__index")
        if type(methods) == "table" and not originals[methods] then
            local favourite = rawget(methods, "isFavouriteRecipeInput")
            local doTooltip = favourite and rawget(methods, "DoTooltip")
            if doTooltip then
                originals[methods] = { favourite, doTooltip }
                found = true
            end
        end
    end
    if not found then
        print("[SuQing Favourite Recipe Materials] item bindings unavailable")
        return
    end

    -- Snapshot before replacing methods because item subclasses can share inherited dispatch.
    for methods, original in pairs(originals) do
        local favourite, doTooltip = original[1], original[2]
        methods.isFavouriteRecipeInput = function(item, player)
            return favourite(item, player) or isCustomFavouriteInput(item, player)
        end
        methods.DoTooltip = function(item, tooltip, ...)
            doTooltip(item, tooltip, ...)
            if item == activeItem and tooltip == activeTooltip and select("#", ...) == 0 then
                appendTooltipLine(tooltip)
            end
        end
    end

    tooltips.render = function(panel, ...)
        local item, tooltip = panel.item, panel.tooltip
        local player = tooltip and tooltip:getCharacter()
        if not item or not player or not instanceof(player, "IsoPlayer") or not isCustomFavouriteInput(item, player) then
            return render(panel, ...)
        end
        local script = item:getScriptItem()
        if not script or script:isFavouriteRecipeInput(player) then return render(panel, ...) end

        -- Preserve the actual item and other mods' render chain. Extend both native layout passes.
        local previousItem, previousTooltip = activeItem, activeTooltip
        activeItem, activeTooltip = item, tooltip
        local ok, result = pcall(render, panel, ...)
        activeItem, activeTooltip = previousItem, previousTooltip
        if not ok then error(result, 0) end
        return result
    end
    installed = true
    print("[SuQing Favourite Recipe Materials] 0.1.0 ready")
end

Events.OnGameStart.Add(install)

