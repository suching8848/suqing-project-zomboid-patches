-- Local compatibility layer for yxjs_PinYinSearch 1.3, CleanUI 2.10.x and PZ 42.21.
-- Handles recipe sources, inventory name+category filtering and inventory pinyin highlights.
-- Load after CleanUI, Neat Crafting, Neat Building and yxjs_PinYinSearch.
-- Capture originals before the workshop mod patches them at OnGameStart.
require "ISUI/ISInventoryPane"
require "Entity/ISUI/CraftRecipe/ISHandCraftPanel"
require "Entity/ISUI/BuildRecipe/ISBuildPanel"
pcall(require, "Neat_Crafting/NC_handcraftPanel")
pcall(require, "Neat_Building/nb_buildingpanel")
local convert = require "pinyin"
local inventoryClass = ISInventoryPane
local inventoryRefresh = inventoryClass and inventoryClass.refreshContainer
local inventorySearch = inventoryClass and inventoryClass.searchContainer
local inventoryRenderdetails = inventoryClass and inventoryClass.renderdetails
local vanillaCraftUpdate = ISHandCraftPanel.onUpdateRecipeList
local originalFilters = {
    {class = ISHandCraftPanel, kind = "craft", original = ISHandCraftPanel.filterRecipeList},
    {class = ISBuildPanel, kind = "build", original = ISBuildPanel.filterRecipeList},
    {class = NC_HandCraftPanel, kind = "neatcraft", original = NC_HandCraftPanel and NC_HandCraftPanel.filterRecipeList},
    {class = NB_BuildingPanel, kind = "build", original = NB_BuildingPanel and NB_BuildingPanel.filterRecipeList},
}
local cache = {}
local warned = {}
local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    print("[PinyinSafeCompat] " .. tostring(message))
end
local function lower(text) return tostring(text or ""):lower() end
local function contains(text, query) return string.find(lower(text), lower(query), 1, true) ~= nil end
local function matches(text, query)
    if query == "" then return true end
    text = tostring(text or "")
    if contains(text, query) then return true end
    local converted = cache[text]
    if converted == nil then
        local ok, value = pcall(convert, text, "-")
        converted = ok and type(value) == "string" and value or ""
        cache[text] = converted
    end
    return converted ~= "" and contains(converted, query)
end
local function categoryKeyMatches(key, query)
    if key == nil then return false end
    return contains(key, query) or contains(getText("IGUI_ItemCat_" .. tostring(key)), query)
end
local function inventoryCategoryMatches(group, query)
    if not query or query == "" then return true end
    -- Reconcile fills these presentation-category fields before the post-search
    -- hook runs; prefer them so pinyin "both" mode follows CleanUI's own category.
    if group._cleanUICategoryKey and contains(group._cleanUICategoryKey, query) then return true end
    if group._cleanUICategoryText and contains(group._cleanUICategoryText, query) then return true end
    if categoryKeyMatches(group.cat, query) then return true end
    for _, item in ipairs(group.items or {}) do
        if categoryKeyMatches(item:getDisplayCategory(), query) or categoryKeyMatches(item:getCategory(), query) then return true end
    end
    return false
end
local function inventoryNameMatches(group, query, player)
    if matches(group.name, query) then return true end
    for _, item in ipairs(group.items or {}) do
        if matches(item:getDisplayName(), query) or contains(item:getType(), query) then return true end
        if item.getName then
            local ok, value = pcall(item.getName, item, player)
            if ok and matches(value, query) then return true end
        end
    end
    return false
end
local function applyInventoryPinyinMatches(self, reorder)
    if not self or not self.itemslist then return false end
    local query = lower(self.searchText)
    local mode = self.searchMode or "name"
    if mode == "category" then return false end

    local categoryQuery = lower(self.searchCategoryText)
    if query == "" then
        -- A "both" search with only a category query must keep CleanUI's native
        -- category result. Otherwise an empty name query clears stale highlights.
        if mode == "both" and categoryQuery ~= "" then return false end
        local cleared = false
        for _, group in ipairs(self.itemslist) do
            if group and group.type ~= "separator" and group.matchesSearch then
                group.matchesSearch = false
                cleared = true
            end
        end
        return cleared
    end

    local player = getSpecificPlayer(self.player)
    local changed = false

    for _, group in ipairs(self.itemslist) do
        if group and group.type ~= "separator" then
            local categoryAllowed = true
            if mode == "both" and categoryQuery ~= "" then
                categoryAllowed = inventoryCategoryMatches(group, categoryQuery)
            end
            local nameMatched = inventoryNameMatches(group, query, player)
            -- In name mode recompute from scratch so a stale flag cannot survive a
            -- query change. In "both" mode keep CleanUI's current native result,
            -- which already enforces the name+category combination, and add pinyin
            -- name hits only when our category check also allows the row.
            local matched
            if mode == "both" then
                matched = group.matchesSearch or (categoryAllowed and nameMatched)
            else
                matched = nameMatched
            end
            if group.matchesSearch ~= matched then
                group.matchesSearch = matched
                changed = true
            end
        end
    end

    if changed and reorder and self.itemSortFunc then
        local selection = nil
        if type(self.saveSelection) == "function" then
            local ok, value = pcall(self.saveSelection, self, {})
            if ok then selection = value end
        end
        if self.selected then table.wipe(self.selected) end
        table.sort(self.itemslist, function(a, b)
            if a.matchesSearch and not b.matchesSearch then return true end
            if not a.matchesSearch and b.matchesSearch then return false end
            return self.itemSortFunc(a, b)
        end)
        if selection and type(self.restoreSelection) == "function" then
            local ok, err = pcall(self.restoreSelection, self, selection)
            if not ok then warnOnce("restoreSearchSelection", "restoreSelection after search sort failed: " .. tostring(err)) end
            table.wipe(selection)
        end
    end
    return changed
end

local function installInventory()
    if not inventoryClass or not inventoryRefresh then return end
    inventoryClass.refreshContainer = function(self)
        inventoryRefresh(self)
        -- Sort pinyin hits to the top. CleanUI's own reconcile pass runs later and
        -- re-evaluates matchesSearch with literal text; installInventoryHighlight()
        -- restores the pinyin flags after that pass.
        local ok, err = pcall(applyInventoryPinyinMatches, self, true)
        if not ok then warnOnce("applyInventoryRefresh", "pinyin inventory match failed: " .. tostring(err)) end
    end
end

local function installInventoryHighlight()
    if not inventoryClass then return end

    if inventorySearch then
        inventoryClass.searchContainer = function(self, ...)
            local result = inventorySearch(self, ...)
            -- This runs after CleanUI_reconcileRowPriorityAfterRefresh(), which
            -- otherwise rewrites matchesSearch from literal text only.
            local ok, err = pcall(applyInventoryPinyinMatches, self, true)
            if not ok then warnOnce("applyInventorySearch", "pinyin search highlight failed: " .. tostring(err)) end
            self._pinyinSafeLastHighlightCount = self.refreshContainerCount or 0
            return result
        end
    end

    if inventoryRenderdetails then
        inventoryClass.renderdetails = function(self, doDragged)
            local result = inventoryRenderdetails(self, doDragged)
            -- CleanUI runs reconcile once per refresh inside renderdetails. When the
            -- inventory refreshes while a search is active, restore the pinyin flags
            -- for the next frame without reordering rows after they were drawn.
            local count = self.refreshContainerCount or 0
            if self._pinyinSafeLastHighlightCount ~= count and lower(self.searchText) ~= "" then
                self._pinyinSafeLastHighlightCount = count
                local ok, err = pcall(applyInventoryPinyinMatches, self, false)
                if not ok then warnOnce("applyInventoryRender", "pinyin render highlight failed: " .. tostring(err)) end
            end
            return result
        end
    end
end
local function recipeMatches(recipe, query, mode)
    if query == "" then return true end
    if mode == "name" or mode == "RecipeName" or mode == nil then
        return matches(recipe:getTranslationName(), query) or contains(recipe:getName(), query)
    end
    if mode == "InputName" then
        local inputs = recipe:getInputs()
        for i = 0, inputs:size() - 1 do
            local possible = inputs:get(i):getPossibleInputItems()
            if possible then
                for j = 0, possible:size() - 1 do
                    local item = possible:get(j)
                    if item and (matches(item:getDisplayName(), query) or contains(item:getFullName(), query:gsub("^!", ""))) then return true end
                end
            end
        end
        return false
    end
    if mode == "OutputName" then
        local outputs = recipe:getOutputs()
        for i = 0, outputs:size() - 1 do
            local possible = outputs:get(i):getPossibleResultItems()
            if possible then
                for j = 0, possible:size() - 1 do
                    local item = possible:get(j)
                    if item and (matches(item:getDisplayName(), query) or contains(item:getFullName(), query)) then return true end
                end
            end
        end
        return false
    end
    return nil -- Unknown future modes keep native behavior.
end
local function sourceRecipes(panel, kind)
    if kind == "build" then return panel.logic:getAllBuildableRecipes() end
    if kind == "neatcraft" then return panel._ncSourceRecipeList end
    if panel.seeAllRecipe then return ScriptManager.instance:getAllCraftRecipes() end
    if panel.recipeQuery then return CraftRecipeManager.queryRecipes(panel.recipeQuery) end
    if panel.craftBench then return panel.craftBench:getRecipes() end
    return nil
end
local function nativeFilter(panel)
    -- Keep the visible query on the panel while the native logic filters.
    -- Neat's category fallback must still see an active query when the
    -- native onUpdateRecipeList callback runs synchronously.
    local result = panel.logic:filterRecipeList("", panel._categoryString)
    if panel.recipesPanel and panel.recipesPanel.filterRecipeList then
        panel.recipesPanel:filterRecipeList()
    end
    return result
end
local function installRecipeFilter(entry)
    if not entry.class or not entry.original then return end
    entry.class.filterRecipeList = function(self)
        if self._pinyinSafeFiltering then return end
        local rawQuery = self._filterString
        local query = lower(rawQuery)
        local mode = (self.recipeListPanel and self.recipeListPanel._filterMode) or self._filterMode or "RecipeName"
        local marker = query:find("-@-", 1, true)
        if marker then
            mode = tostring(rawQuery):sub(marker + 3)
            query = query:sub(1, marker - 1)
        end
        query = query:match("^%s*(.-)%s*$")
        self._pinyinSafeFiltering = true
        local ok, result = pcall(function()
            local source = sourceRecipes(self, entry.kind)
            if not source or not source.size or not source.get then return entry.original(self) end
            if query == "" then
                self.logic:setRecipes(source)
                return nativeFilter(self)
            end
            local filtered = ArrayList.new()
            for i = 0, source:size() - 1 do
                local recipe = source:get(i)
                local match = recipe and recipeMatches(recipe, query, mode)
                if match == nil then
                    self.logic:setRecipes(source)
                    return entry.original(self)
                end
                if match then filtered:add(recipe) end
            end
            self.logic:setRecipes(filtered)
            return nativeFilter(self)
        end)
        self._filterString = rawQuery
        self._pinyinSafeFiltering = nil
        if not ok then
            print("[PinyinSafeCompat] search failed; restoring native candidates: " .. tostring(result))
            local restored = pcall(function()
                local source = sourceRecipes(self, entry.kind)
                if source then self.logic:setRecipes(source) end
            end)
            return entry.original(self)
        end
        return result
    end
end
local function install()
    local language = Translator.getLanguage():name()
    if language ~= "CN" and language ~= "CH" then return end
    installInventory()
    installInventoryHighlight()
    ISHandCraftPanel.onUpdateRecipeList = vanillaCraftUpdate
    for _, entry in ipairs(originalFilters) do installRecipeFilter(entry) end
    print("[PinyinSafeCompat] v1.1 loaded; original recipe sources, category filters and pinyin inventory highlights retained")
end
Events.OnGameStart.Add(install)
PinyinSafeCompat = {matches = matches, recipeMatches = recipeMatches, inventoryCategoryMatches = inventoryCategoryMatches, applyInventoryPinyinMatches = applyInventoryPinyinMatches, install = install}
