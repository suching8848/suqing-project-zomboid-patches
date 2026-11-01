if isServer() then return end

CodexAttachedGroupingFix = CodexAttachedGroupingFix or {}
CodexAttachedGroupingFix.HotbarGrouping = CodexAttachedGroupingFix.HotbarGrouping or {}
local G = CodexAttachedGroupingFix.HotbarGrouping
local unpackResults = unpack

local function packResults(...)
    return { n = select("#", ...), ... }
end

local function invalidateCharacterInventory(hotbar)
    local character = hotbar and (hotbar.chr or hotbar.character)
    if not character then return end
    local inventory = character:getInventory()
    if inventory then inventory:setDrawDirty(true) end
end

local function afterHotbarChange(original)
    return function(self, ...)
        -- Native setAttachedItem fires OnClothingUpdated before the Lua slot
        -- fields/cache are restored. That event can clear DrawDirty after
        -- building a list from the temporary, incomplete hotbar state.
        local results = packResults(original(self, ...))
        invalidateCharacterInventory(self)
        return unpackResults(results, 1, results.n)
    end
end

function G.install()
    local hotbar = ISHotbar
    if type(hotbar) ~= "table" or hotbar._codexAttachedGroupingInstalled then return end
    if type(hotbar.refresh) ~= "function" or type(hotbar.reloadIcons) ~= "function" then return end

    -- refresh also covers RTH's final slot reorder. reloadIcons covers direct
    -- attach/remove operations that do not run a full clothing refresh.
    -- Do not refresh the pane here: defer to its normal render-time rebuild.
    hotbar.refresh = afterHotbarChange(hotbar.refresh)
    hotbar.reloadIcons = afterHotbarChange(hotbar.reloadIcons)
    hotbar._codexAttachedGroupingInstalled = true
end

-- Installed last, after the active hotbar/Noir/NeatUI wrappers are in place.
Events.OnGameStart.Add(G.install)
