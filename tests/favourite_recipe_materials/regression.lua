-- Load this fixture, the stock ISToolTipInv.lua, the candidate, then this fixture again.
-- The Kahlua VM and tooltip control flow are real. Java values and drawing are fixtures.
local T = FavouriteRecipeMaterialTest
if not T then
    T = { installers = {}, scanCount = 0, assertions = 0, cases = 0 }
    FavouriteRecipeMaterialTest = T

    local function list(values)
        return {
            size = function() return #values end,
            get = function(_, index) return values[index + 1] end,
        }
    end

    local function scriptItem(fullName, native)
        return {
            getFullName = function() return fullName end,
            isFavouriteRecipeInput = function() return native == true end,
        }
    end

    local function input(items, wildcard)
        local possible = {}
        for i, fullName in ipairs(items) do possible[i] = scriptItem(fullName) end
        return {
            isAcceptsAnyItem = function() return wildcard == true end,
            getPossibleInputItems = function() return list(possible) end,
            addFixtureItem = function(fullName) possible[#possible + 1] = scriptItem(fullName) end,
        }
    end

    local function recipe(module, name, inputs, needsLearning)
        return {
            getName = function() return name end,
            getScriptObjectFullType = function() return module .. "." .. name end,
            getModule = function() return { getName = function() return module end } end,
            getInputs = function() return list(inputs) end,
            needToBeLearn = function() return needsLearning == true end,
        }
    end

    local expandedTag = input({"Base.TagMember"})
    T.addLateInput = expandedTag.addFixtureItem
    local normal = {
        recipe("Base", "Vanilla", { input({"Base.RubberBand"}) }),
        recipe("Fixture", "Outfit", { input({"Base.LeatherStrips", "Base.DuctTape"}) }),
        recipe("Fixture", "ExpandedTag", { expandedTag }),
        recipe("Fixture", "Learning", { input({"Base.ManualPart"}) }, true),
        recipe("Fixture", "Wildcard", { input({"Base.WildcardBait"}, true) }),
        recipe("Fixture", "Duplicate", { input({"Base.FirstCollision"}) }),
        recipe("Other", "Duplicate", { input({"Base.SecondCollision"}) }),
    }
    local build = {
        recipe("Fixture", "Construct", { input({"Base.Sheet"}) }),
    }
    local manager = {
        getAllCraftRecipes = function()
            T.scanCount = T.scanCount + 1
            return list(normal)
        end,
        getAllBuildableRecipes = function() return list(build) end,
    }

    function getScriptManager() return manager end
    ScriptManager = { instance = manager }
    Events = { OnGameStart = { Add = function(fn) T.installers[#T.installers + 1] = fn end } }
    function require() end
    function isClient() return false end
    function isServer() return false end
    function instanceof(value, class) return value.fixtureClass == class end
    function getMouseX() return 10 end
    function getMouseY() return 10 end
    function getText(key) return key end
    function getCore() return T.core end
    T.core = {
        getVersionNumber = function() return "42.21" end,
        getScreenWidth = function() return 1920 end,
        getScreenHeight = function() return 1080 end,
        getGoodHighlitedColor = function()
            return {
                getR = function() return 0.1 end,
                getG = function() return 0.9 end,
                getB = function() return 0.2 end,
            }
        end,
    }
    SandboxVars = { SeeNotLearntRecipe = false }
    ISContextMenu = {}
    ISPanel = { derive = function() return {} end }
    BaseCraftingLogic = { getFavouriteModDataString = function(recipe) return "recipeFavourite:" .. recipe:getName() end }

    T.nativeMarker = function(item) return item.native == true end
    T.nativeTooltip = function(item, tooltip, layout)
        if layout then
            layout.forwarded = item
            return
        end
        if tooltip.fail then error("fixture native tooltip failure") end
        tooltip.calls[#tooltip.calls + 1] = { item = item, measure = tooltip:isMeasureOnly() }
        tooltip:setHeight(32)
        if not tooltip:isMeasureOnly() and item.native then
            tooltip:DrawText(tooltip:getFont(), "Tooltip_item_IsFavouriteInput", 5, 5, 0.1, 0.9, 0.2, 1)
        end
    end

    __classmetatables = {}
    local function expose(class)
        local index = {
            isFavouriteRecipeInput = T.nativeMarker,
            DoTooltip = T.nativeTooltip,
            isNoRecipes = function(item) return item.noRecipes == true end,
            getScriptItem = function(item) return item.scriptItem end,
            getFullType = function(item) return item.fullName end,
        }
        class.class = {}
        __classmetatables[class.class] = { __index = index }
        return class
    end
    InventoryItem = expose({})
    DrainableComboItem = expose({})
    InventoryContainer = expose({})
    function T.item(fullName, class, native)
        return setmetatable({ fullName = fullName, scriptItem = scriptItem(fullName, native), native = native },
            __classmetatables[(class or InventoryItem).class])
    end

    function T.player(stars)
        local modData, known = {}, {}
        for _, name in ipairs(stars) do modData["recipeFavourite:" .. name] = true end
        return {
            fixtureClass = "IsoPlayer",
            getModData = function() return modData end,
            isRecipeActuallyKnown = function(_, recipe)
                local name = type(recipe) == "string" and recipe or recipe:getName()
                return known[name] == true
            end,
            known = known,
        }
    end

    function T.panel(item, player)
        local tooltip = { x = 0, y = 0, width = 0, height = 0, calls = {}, text = {} }
        function tooltip:setX(x) self.x = x end
        function tooltip:setY(y) self.y = y end
        function tooltip:getX() return self.x end
        function tooltip:getY() return self.y end
        function tooltip:setWidth(width) self.width = width end
        function tooltip:setHeight(height) self.height = height end
        function tooltip:getWidth() return self.width end
        function tooltip:getHeight() return self.height end
        function tooltip:setMeasureOnly(measure) self.measure = measure end
        function tooltip:isMeasureOnly() return self.measure == true end
        function tooltip:getCharacter() return player end
        function tooltip:getFont() return "fixture font" end
        function tooltip:getLineSpacing() return 13 end
        function tooltip:adjustWidth(left, text) self.width = math.max(self.width, left + #text * 4 + 5) end
        function tooltip:DrawText(font, text, x, y, r, g, b, alpha)
            assert(not self:isMeasureOnly(), "tooltip text was drawn during measure")
            self.text[#self.text + 1] = { font = font, text = text, x = x, y = y, r = r, g = g, b = b, alpha = alpha }
        end

        local panel = {
            item = item, tooltip = tooltip, x = 100, y = 100, width = 50, height = 0,
            backgroundColor = { a = 1, r = 0, g = 0, b = 0 },
            borderColor = { a = 1, r = 0, g = 0, b = 0 },
        }
        function panel:setX(x) self.x = x end
        function panel:setY(y) self.y = y end
        function panel:getX() return self.x end
        function panel:getY() return self.y end
        function panel:setWidth(width) self.width = width end
        function panel:setHeight(height) self.height = height end
        function panel:drawRect() end
        function panel:drawRectBorder() end
        return setmetatable(panel, { __index = ISToolTipInv })
    end

    return
end

local function eq(actual, expected, reason)
    T.assertions = T.assertions + 1
    assert(actual == expected, reason .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function scenario(fn)
    fn()
    T.cases = T.cases + 1
end

local player = T.player({"Vanilla", "Outfit", "ExpandedTag", "Learning", "Wildcard", "Duplicate", "Construct"})
local rubberBand = T.item("Base.RubberBand", nil, true)
local leather = T.item("Base.LeatherStrips")
local ductTape = T.item("Base.DuctTape", DrainableComboItem)

eq(#T.installers, 1, "single installation callback")
eq(leather:isFavouriteRecipeInput(player), false, "native negative before installation")
T.installers[1]()
eq(T.scanCount, 0, "index waits until after startup callbacks")
T.addLateInput("Fixture.RuntimeAdded")

scenario(function()
    eq(rubberBand:isFavouriteRecipeInput(player), true, "native positive remains positive")
    eq(T.item("Base.RubberBand"):isFavouriteRecipeInput(player), false, "Base material retains native result")
    eq(leather:isFavouriteRecipeInput(player), true, "mod recipe marks ordinary material")
    eq(ductTape:isFavouriteRecipeInput(player), true, "mod recipe marks drainable subclass")
    eq(T.item("Base.LeatherStrips", InventoryContainer):isFavouriteRecipeInput(player), true, "mod recipe marks container subclass")
    leather.noRecipes = true
    eq(leather:isNoRecipes(player), true, "explicit no-recipes preference is preserved")
    leather.noRecipes = false
    eq(T.item("Base.Unrelated"):isFavouriteRecipeInput(player), false, "unrelated material stays unmarked")
end)

scenario(function()
    eq(T.item("Base.Sheet"):isFavouriteRecipeInput(player), true, "buildable recipe input")
    eq(T.item("Base.TagMember"):isFavouriteRecipeInput(player), true, "tag-expanded input")
    eq(T.item("Fixture.RuntimeAdded"):isFavouriteRecipeInput(player), true, "runtime-expanded input")
    eq(T.item("Base.WildcardBait"):isFavouriteRecipeInput(player), false, "any-item wildcard stays unmarked")
    eq(T.item("Base.FirstCollision"):isFavouriteRecipeInput(player), false, "ambiguous short name, first module")
    eq(T.item("Base.SecondCollision"):isFavouriteRecipeInput(player), false, "ambiguous short name, second module")
end)

scenario(function()
    local part = T.item("Base.ManualPart")
    eq(part:isFavouriteRecipeInput(player), false, "unlearned recipe is hidden")
    player.known.Learning = true
    eq(part:isFavouriteRecipeInput(player), true, "learned recipe is visible")
    player.known.Learning = false
    SandboxVars.SeeNotLearntRecipe = true
    eq(part:isFavouriteRecipeInput(player), true, "sandbox allows unlearned recipes")
    SandboxVars.SeeNotLearntRecipe = false
end)

scenario(function()
    local other = T.player({})
    local scanCount = T.scanCount
    eq(leather:isFavouriteRecipeInput(other), false, "player favorite state is isolated")
    player:getModData()["recipeFavourite:Outfit"] = false
    eq(leather:isFavouriteRecipeInput(player), false, "unstar takes effect immediately")
    player:getModData()["recipeFavourite:Outfit"] = true
    eq(ductTape:isFavouriteRecipeInput(player), true, "restar takes effect immediately")
    eq(T.scanCount, scanCount, "render lookups reuse recipe index")
end)

scenario(function()
    local panel = T.panel(ductTape, player)
    panel:render()
    eq(panel.item, ductTape, "tooltip retains the real item")
    eq(#panel.tooltip.calls, 2, "native measure and native draw each run once")
    eq(panel.tooltip.calls[1].item, ductTape, "native measure receives original item")
    eq(panel.tooltip.calls[1].measure, true, "first call measures")
    eq(panel.tooltip.calls[2].item, ductTape, "native draw receives original item")
    eq(panel.tooltip.calls[2].measure, false, "second call draws")
    eq(panel.height, 45, "one line is reserved during native measure")
    eq(panel.width > 50, true, "measure accounts for text width")
    eq(#panel.tooltip.text, 1, "one green line is appended")
    eq(panel.tooltip.text[1].text, "Tooltip_item_IsFavouriteInput", "native translated label is reused")
    eq(panel.tooltip.text[1].g, 0.9, "native highlight color is reused")
    player:getModData()["recipeFavourite:Outfit"] = false
    local unstarred = T.panel(ductTape, player)
    unstarred:render()
    eq(unstarred.height, 32, "unstarred tooltip has native height")
    eq(#unstarred.tooltip.text, 0, "unstarred tooltip has no added line")
    player:getModData()["recipeFavourite:Outfit"] = true
end)

scenario(function()
    local panel = T.panel(rubberBand, player)
    panel:render()
    eq(panel.height, 32, "native-positive tooltip height is unchanged")
    eq(#panel.tooltip.text, 1, "native positive is not duplicated")
    local nativeAndCustom = T.panel(T.item("Base.DuctTape", DrainableComboItem, true), player)
    nativeAndCustom:render()
    eq(nativeAndCustom.height, 32, "native-positive tooltip wins when custom fallback also matches")
    eq(#nativeAndCustom.tooltip.text, 1, "overlapping native and custom matches render one line")
    local layout = {}
    ductTape:DoTooltip(panel.tooltip, layout)
    eq(layout.forwarded, ductTape, "unrelated native overload is forwarded")
    local hidden = T.panel(ductTape, player)
    ISContextMenu.instance = { visibleCheck = true }
    hidden:render()
    ISContextMenu.instance = nil
    eq(#hidden.tooltip.calls, 0, "open context menu still suppresses native tooltip")
    eq(#hidden.tooltip.text, 0, "open context menu also suppresses added line")
end)

scenario(function()
    local panel = T.panel(ductTape, player)
    panel.tooltip.fail = true
    local ok = pcall(panel.render, panel)
    eq(ok, false, "native error is propagated")
    panel.tooltip.fail = false
    panel.tooltip:setMeasureOnly(false)
    ductTape:DoTooltip(panel.tooltip)
    eq(#panel.tooltip.text, 0, "failed tooltip does not leak extension to direct native calls")
    local replacement = T.panel(ductTape, player)
    replacement:render()
    eq(#replacement.tooltip.text, 1, "next tooltip still renders after a failure")
end)

return "favourite recipe materials: cases=" .. T.cases .. "; assertions=" .. T.assertions
