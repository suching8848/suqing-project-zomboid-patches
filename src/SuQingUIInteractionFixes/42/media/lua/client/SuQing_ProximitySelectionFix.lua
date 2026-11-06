-- Preserve Proximity Inventory selections across CleanUI's row rebuilds.
-- No container contents, renderer, transfer actions or selection gestures are replaced.
if isServer() then return end
require "ISUI/ISInventoryPane"

SuQingUIInteractionFixes = SuQingUIInteractionFixes or {}
local M = SuQingUIInteractionFixes.proximitySelection or {}
SuQingUIInteractionFixes.proximitySelection = M
if M.loaded then return end
M.loaded = true
M.version = "1.0.1"
M.enabled = true
M.stats = { captured = 0, restored = 0, invalidated = 0 }

local states = setmetatable({}, { __mode = "k" })
local function hasEntries(values)
    for _ in pairs(values or {}) do return true end
    return false
end
local function sourceListed(pane, container)
    local page = pane.parent
    for _, button in ipairs((page and page.backpacks) or {}) do
        if button.inventory == container then return true end
    end
    return false
end

local function stateFor(pane)
    local inventory = pane and pane.inventory
    if not M.enabled or (pane and pane.doController) or not inventory or not inventory.getType
        or inventory:getType() ~= "proxInv" then
        if pane then states[pane] = nil end
        return nil
    end
    local s = states[pane]
    if not s or s.inventory ~= inventory then
        s = { inventory = inventory, refreshDepth = 0, renderDepth = 0, inputDepth = 0 }
        states[pane] = s
    end
    return s
end

local function identity(value)
    if value == nil then return nil end
    if instanceof(value, "InventoryItem") then return value, false end
    if type(value) == "table" and value.items and value.name ~= nil
        and value.type ~= "separator" then return value.name, true end
    return nil
end

local function capture(pane)
    local saved = { inventory = pane.inventory, items = {}, groups = {} }
    for _, value in pairs(pane.selected or {}) do
        local key, group = identity(value)
        if key ~= nil then
            if group then saved.groups[key] = true else saved.items[key] = true end
        end
    end
    if pane.firstSelect and pane.items then
        saved.anchor, saved.anchorGroup = identity(pane.items[pane.firstSelect])
    end
    M.stats.captured = M.stats.captured + 1
    return saved
end

-- A refresh may restore wrong row numbers, but user input and explicit clearing
-- must win over a pending snapshot. Track exactly what the last refresh left.
local function rememberExpected(pane, saved)
    saved.expectedTable = pane.selected
    saved.expectedAnchor = pane.firstSelect
    saved.expected = {}
    for row, value in pairs(pane.selected or {}) do saved.expected[row] = value end
end

local function unchangedSinceRefresh(pane, saved)
    if pane.inventory ~= saved.inventory or pane.selected ~= saved.expectedTable
        or pane.firstSelect ~= saved.expectedAnchor then return false end
    for row, value in pairs(pane.selected or {}) do
        if saved.expected[row] ~= value then return false end
    end
    for row, value in pairs(saved.expected or {}) do
        if not pane.selected or pane.selected[row] ~= value then return false end
    end
    return true
end

local function pendingFor(pane, s)
    local saved = s.pending
    if saved and not unchangedSinceRefresh(pane, saved) then
        s.pending = nil
        M.stats.invalidated = M.stats.invalidated + 1
        return nil
    end
    return saved
end

local function restore(pane, saved)
    if pane.inventory ~= saved.inventory or type(pane.items) ~= "table" then return end
    local selected = pane.selected or {}
    table.wipe(selected)
    pane.firstSelect = nil
    -- These are the rows actually drawn by the complete renderer chain. This
    -- respects the 50-child limit, virtual headers, search ordering and filters.
    for row, value in ipairs(pane.items) do
        local key, group = identity(value)
        if key ~= nil then
            if (group and saved.groups[key]) or (not group and saved.items[key]) then
                selected[row] = value
            end
            if saved.anchor ~= nil and group == saved.anchorGroup and key == saved.anchor then
                pane.firstSelect = row
            end
        end
    end
    pane.selected = selected
    M.stats.restored = M.stats.restored + 1
end

local function selectedValue(pane, saved, row)
    if type(row) ~= "number" then return nil end
    local value = pane.items and pane.items[row]
    local key, group = identity(value)
    if key ~= nil and ((group and saved.groups[key]) or (not group and saved.items[key])) then
        return value
    end
    return nil
end

local function wrapInput(name)
    local original = ISInventoryPane[name]
    if type(original) ~= "function" then return end
    ISInventoryPane[name] = function(self, ...)
        local s = stateFor(self)
        if not s or s.refreshDepth > 0 or s.renderDepth > 0 or s.inputDepth > 0 then
            return original(self, ...)
        end
        local saved = pendingFor(self, s)
        -- Before a draw, self.items still describes the last displayed frame.
        -- Restore against that frame before the existing input/flush chain runs.
        if saved then restore(self, saved) end
        s.pending = nil
        local generation = self.refreshContainerCount
        s.inputDepth = s.inputDepth + 1
        local ok, a, b, c, d = pcall(original, self, ...)
        s.inputDepth = s.inputDepth - 1
        s.pending = nil
        if not ok then error(a, 0) end
        if self.inventory == s.inventory and (saved or generation ~= self.refreshContainerCount) then
            -- The input used the last displayed rows. Keep its *new* semantics
            -- until the already refreshed list gets drawn, rather than replaying
            -- the selection that existed before the gesture.
            s.pending = capture(self)
            rememberExpected(self, s.pending)
        end
        return a, b, c, d
    end
end

local function install()
    if M.installed then return end
    if type(getModInfoByID) ~= "function" then return end
    local info = getModInfoByID("CleanUI") or getModInfoByID("\\CleanUI")
    local cleanVersion = info and info.getModVersion and tostring(info:getModVersion())
    if cleanVersion ~= "2.10.3" and cleanVersion ~= "2.10.4" then
        print("[SuQing UI Interaction] proximity selection inactive; reviewed CleanUI 2.10.3 or 2.10.4 required")
        return
    end
    if not ISInventoryPane or type(ISInventoryPane.refreshContainer) ~= "function"
        or type(ISInventoryPane.renderdetails) ~= "function" then return end

    local originalRefresh = ISInventoryPane.refreshContainer
    ISInventoryPane.refreshContainer = function(self, ...)
        local s = stateFor(self)
        if not s then return originalRefresh(self, ...) end
        if s.refreshDepth == 0 and s.renderDepth == 0 and s.inputDepth == 0 then
            s.pending = pendingFor(self, s) or capture(self)
        end
        s.refreshDepth = s.refreshDepth + 1
        local ok, a, b, c, d = pcall(originalRefresh, self, ...)
        s.refreshDepth = s.refreshDepth - 1
        if ok and s.pending and self.inventory == s.inventory then
            rememberExpected(self, s.pending)
        end
        if not ok then s.pending = nil; error(a, 0) end
        return a, b, c, d
    end

    local originalRender = ISInventoryPane.renderdetails
    ISInventoryPane.renderdetails = function(self, doDragged, ...)
        local s = stateFor(self)
        if not s or doDragged ~= false or s.renderDepth > 0 or self.draggingMarquis then
            return originalRender(self, doDragged, ...)
        end
        local saved = pendingFor(self, s) or capture(self)
        local wasPending = s.pending ~= nil
        s.pending = nil
        local generation = self.refreshContainerCount
        local selected = self.selected or {}
        -- Only the reviewed ordinary selection table is adapted. Preserve an
        -- unknown owner's metatable and its behavior verbatim.
        if getmetatable(selected) ~= nil then return originalRender(self, doDragged, ...) end
        local originalValues = {}
        for row, value in pairs(selected) do originalValues[row] = value end
        table.wipe(selected)
        self.selected = selected
        -- CleanUI writes each real row into self.items before asking whether it
        -- is highlighted. Resolve that query from semantic identity while the
        -- native renderer is building the actual row map. Numeric writes from
        -- its obsolete refresh restoration are held until the map is complete.
        setmetatable(selected, {
            __index = function(_, row) return selectedValue(self, saved, row) end,
            __newindex = function(t, row, value)
                if type(row) ~= "number" then rawset(t, row, value) end
            end,
        })
        s.renderDepth = s.renderDepth + 1
        local ok, a, b, c, d = pcall(originalRender, self, doDragged, ...)
        s.renderDepth = s.renderDepth - 1
        setmetatable(selected, nil)
        table.wipe(selected)
        for row, value in pairs(originalValues) do rawset(selected, row, value) end
        if not ok then error(a, 0) end
        if self.selected == selected and self.inventory == s.inventory
            and (wasPending or self.refreshContainerCount ~= generation) then restore(self, saved) end
        return a, b, c, d
    end

    local originalUpdate = ISInventoryPane.update
    if type(originalUpdate) == "function" then
        ISInventoryPane.update = function(self, ...)
            local s = stateFor(self)
            if not s then return originalUpdate(self, ...) end
            local pending = pendingFor(self, s)
            if pending then restore(self, pending) end
            s.pending = nil
            local generation = self.refreshContainerCount
            local selected = self.selected
            local candidates = {}
            local virtualItems = self.inventory:getItems()
            for row, value in pairs(selected or {}) do
                if instanceof(value, "InventoryItem") then
                    local container = value:getContainer()
                    if container and container ~= self.inventory and sourceListed(self, container) and virtualItems:contains(value)
                        and container:getItems():contains(value) and self.items[row] == value then
                        candidates[row] = { item = value, container = container }
                    end
                end
            end
            local page = self.parent
            local selectAll = hasEntries(candidates) and isCtrlKeyDown()
                and isKeyDown(Keyboard.KEY_A) and page and page:isVisible()
                and not page.isCollapsed and page:isMouseOver() and hasEntries(selected)
            local ok, a, b, c, d = pcall(originalUpdate, self, ...)
            if not ok then error(a, 0) end
            -- Real item ownership stays in its source container. Only undo the
            -- native validator's false removal from this virtual aggregate view.
            if self.inventory == s.inventory and self.selected == selected and not self.doController then
                for row, value in pairs(candidates) do
                    local item, container = value.item, value.container
                    if selected[row] == nil and self.items[row] == item and item:getContainer() == container and sourceListed(self, container)
                        and self.inventory:getItems():contains(item) and container:getItems():contains(item) then
                        selected[row] = item
                    end
                end
                -- With only physical child rows selected, the faulty prune also
                -- hides eligibility from the native Ctrl+A check later in update.
                if selectAll and hasEntries(selected) then
                    table.wipe(selected)
                    for row, value in ipairs(self.items) do selected[row] = value end
                end
                if pending or generation ~= self.refreshContainerCount then
                    s.pending = capture(self)
                    rememberExpected(self, s.pending)
                end
            end
            return a, b, c, d
        end
    end

    for _, name in ipairs({ "onMouseDown", "onMouseUp", "onMouseDoubleClick",
        "onRightMouseUp", "onMouseDownOutside", "onMouseUpOutside",
        "onKeyPress", "onKeyRelease", "onJoypadDown", "onJoypadDirUp", "onJoypadDirDown",
        "onJoypadDirLeft", "onJoypadDirRight" }) do wrapInput(name) end
    M.installed = true
    print("[SuQing UI Interaction] proximity selection " .. M.version .. " ready; CleanUI=" .. cleanVersion)
end
M.install = install
Events.OnGameStart.Add(install)
