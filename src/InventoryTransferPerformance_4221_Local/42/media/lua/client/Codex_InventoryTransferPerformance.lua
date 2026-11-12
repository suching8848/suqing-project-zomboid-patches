-- Standalone, client-side UI work coalescing for CleanUI on B42.21.
-- Actual item transfers, action timing, selection and renderer remain native.
if isServer() then return end
require "ISUI/ISInventoryPage"
require "ISUI/ISInventoryPane"
require "TimedActions/ISTimedActionQueue"

CodexInventoryTransferPerformance = CodexInventoryTransferPerformance or {}
local M = CodexInventoryTransferPerformance
if M.loaded then return end
M.loaded = true
M.version = "1.2.4"
M.enabled = true
M.refreshIntervalMs = 180
M.stats = { pageRefreshes = 0, pageDeferred = 0, paneRefreshes = 0,
    paneDeferred = 0, forcedFlushes = 0, priorityBarriers = 0, failOpen = 0 }

local panes = setmetatable({}, { __mode = "k" })
local pages = setmetatable({}, { __mode = "k" })
local players = {}
local originals = {}
local automaticDepth, forceDepth, renderDepth, inputDepth, refreshDepth = 0, 0, 0, 0, 0

local function nowMs()
    if type(getTimestampMs) ~= "function" then return nil end
    return getTimestampMs()
end

local function stopOptimizing(err)
    M.enabled = false
    M.stats.failOpen = M.stats.failOpen + 1
    if not M.warned then
        M.warned = true
        print("[Codex InventoryTransferPerformance] disabled; native refresh retained: " .. tostring(err))
    end
end

local function interval()
    return math.max(100, math.min(300, tonumber(M.refreshIntervalMs) or 180))
end

local function playerState(playerNum)
    local s = players[playerNum]
    if not s then s = { forceUntil = 0 }; players[playerNum] = s end
    return s
end

local function hasBulkItems(action, queue)
    -- B42 merges actions into groups, including up to 20 tiny items/group.
    local list = action.queueList
    if type(list) == "table" then
        if #list > 1 then return true end
        if list[1] and type(list[1].items) == "table" and #list[1].items > 1 then return true end
    end
    local nextAction = queue.queue and queue.queue[2]
    return nextAction ~= nil and nextAction.Type == "ISInventoryTransferAction"
end

local function bulkContext(playerNum, time)
    if not M.enabled or not time or forceDepth > 0 or inputDepth > 0 then return false end
    if type(isClient) == "function" and isClient() then return false end
    if type(getGameSpeed) == "function" and getGameSpeed() <= 0 then return false end
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() or player:getVehicle() or player:isPlayerMoving() then return false end
    -- Do not create a timed-action queue merely to inspect it.
    local queue = ISTimedActionQueue.queues and ISTimedActionQueue.queues[player]
    local action = queue and (queue.current or (queue.queue and queue.queue[1]))
    if not action or action.Type ~= "ISInventoryTransferAction" or action.started ~= true then
        local previous = players[playerNum]
        if previous then previous.action = nil; previous.bulk = false end
        return false
    end
    local s = playerState(playerNum)
    if (s.lastSeen and time < s.lastSeen) or s.forceUntil > time + interval() then
        -- Wall clocks can be corrected while the game is running.
        -- Do not retain an input grace period from a future timestamp.
        s.forceUntil, s.action, s.bulk = time, nil, false
    end
    s.lastSeen = time
    local x, y, z = player:getX(), player:getY(), player:getZ()
    if s.x ~= nil and (s.x ~= x or s.y ~= y or s.z ~= z) then s.forceUntil = time + interval() end
    s.x, s.y, s.z = x, y, z
    if time < s.forceUntil then return false end
    if s.action ~= action then s.action = action; s.bulk = false end
    if not s.bulk then s.bulk = hasBulkItems(action, queue) end
    return s.bulk == true
end

local function samePaneView(s, pane)
    return s and s.inventory == pane.inventory and s.mode == pane.mode
        and s.width == pane.width and s.height == pane.height
        and s.itemHgt == pane.itemHgt and s.font == pane.font
        and s.sort == pane.itemSortFunc and s.search == pane.searchText
        and s.searchCategory == pane.searchCategoryText and s.searchMode == pane.searchMode
        and s.equippedCollapsed == pane.equippedCollapsed
        and s.headerHgt == pane.headerHgt
        and s.titleBarPosition == (pane.parent and pane.parent._cleanUITitleBarPosition)
        and s.containerPosition == (pane.parent and pane.parent._cleanUIContainerPosition)
        and s.containerColumns == (pane.parent and pane.parent._cleanUIContainerColumns)
end

local function rememberPane(pane, time)
    local s = panes[pane] or {}
    s.inventory, s.mode, s.width, s.height = pane.inventory, pane.mode, pane.width, pane.height
    s.itemHgt, s.font, s.sort = pane.itemHgt, pane.font, pane.itemSortFunc
    s.search, s.searchCategory, s.searchMode = pane.searchText, pane.searchCategoryText, pane.searchMode
    s.equippedCollapsed = pane.equippedCollapsed
    s.headerHgt = pane.headerHgt
    s.titleBarPosition = pane.parent and pane.parent._cleanUITitleBarPosition
    s.containerPosition = pane.parent and pane.parent._cleanUIContainerPosition
    s.containerColumns = pane.parent and pane.parent._cleanUIContainerColumns
    s.last = time or 0
    s.generation = (s.generation or 0) + 1
    s.pending = false
    panes[pane] = s
    return s
end

local function canDefer(pane, time)
    if not pane or not pane.inventory or type(pane.itemslist) ~= "table" then return false end
    if pane.mode ~= "details" or pane.doController or pane.dragging ~= nil or pane.dragStarted
        or pane.draggingMarquis or pane.resizingColumn or pane.resizingRarityColumn
        or pane.resizingWeightColumn or pane.resizingExternalWeightColumn
        or pane._cleanUIDividerPendingResize or pane._cleanUIResizeState then return false end
    if (type(isCtrlKeyDown) == "function" and isCtrlKeyDown())
        or (type(isShiftKeyDown) == "function" and isShiftKeyDown()) then return false end
    if pane.isMouseOver and pane:isMouseOver() then return false end
    if ISMouseDrag and type(ISMouseDrag.dragging) == "table" and #ISMouseDrag.dragging > 0 then return false end
    local page = pane.parent
    if not page or page.isCollapsed or (page.isVisible and not page:isVisible()) then return false end
    return bulkContext(pane.player, time)
end

-- Rebuild only the renderer's row-to-item lookup after an input-time flush.
-- Never write to a container's items or to the stack tables themselves.
local function rebuildRows(pane)
    if pane.mode ~= "details" then return end
    local list = pane.itemslist or {}
    if pane.neqHiding and pane.neqFilteredFor == pane.inventory and pane.neqFilteredItemList then
        list = pane.neqFilteredItemList
    end
    local rows = pane.items or {}
    table.wipe(rows)
    local maxChildren = ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER or 50
    for _, group in ipairs(list) do
        if group.type == "separator" then
            table.insert(rows, group)
        elseif not (pane.equippedCollapsed and group.equipped) then
            local count = 1
            for _, item in ipairs(group.items or {}) do
                table.insert(rows, count == 1 and group or item)
                if count == 1 and pane.collapsed and pane.collapsed[group.name] then break end
                if count == maxChildren + 1 then break end
                count = count + 1
            end
        end
    end
    pane.items = rows
end

local function selectionKey(value)
    if type(value) == "table" and value.items then return value.name, true end
    return value, false
end

local function captureSelection(pane)
    local saved = { inventory = pane.inventory, items = {}, groups = {} }
    for _, value in pairs(pane.selected or {}) do
        local key, group = selectionKey(value)
        if key ~= nil then
            if group then saved.groups[key] = true else saved.items[key] = true end
        end
    end
    if pane.firstSelect and pane.items then
        saved.anchor, saved.anchorGroup = selectionKey(pane.items[pane.firstSelect])
    end
    return saved
end

local function restoreRowSelection(pane, saved)
    if saved.inventory ~= pane.inventory then return end
    local selected = pane.selected or {}
    table.wipe(selected)
    pane.firstSelect = nil
    local stackSelected = false
    for row, value in ipairs(pane.items or {}) do
        local key, group = selectionKey(value)
        local separator = type(value) == "table" and value.type == "separator"
        if separator then
            stackSelected = false
        elseif group then
            stackSelected = saved.groups[key]
            local displayItem = value.cleanUIDisplayItem or value.firstItem or value.items[1]
            if stackSelected then
                selected[row] = value
            elseif M.expandedSelection and saved.items[displayItem] then
                selected[row] = displayItem
            end
        elseif saved.items[key] or (M.expandedSelection and stackSelected) then
            selected[row] = value
        end
        if saved.anchor ~= nil and group == saved.anchorGroup and key == saved.anchor then pane.firstSelect = row end
    end
    pane.selected = selected
end

local function runForced(fn, ...)
    forceDepth = forceDepth + 1
    local ok, a, b, c = pcall(fn, ...)
    forceDepth = forceDepth - 1
    if not ok then error(a, 0) end
    return a, b, c
end

-- CleanUI 2.10.1 through 2.10.5 finish category/search/pin ordering in a private helper,
-- after external refresh wrappers have run. Its public searchContainer method
-- reaches that helper without drawing. Reuse the already completed refresh
-- exactly once, then let all of CleanUI's own reconciliation execute normally.
-- This adapter is gated to the reviewed version below; no renderer is copied.
local function reconcileRows(pane)
    if not M.needsPriorityBarrier then return end
    local originalList = pane.itemslist
    local query, category, mode = pane.searchText, pane.searchCategoryText, pane.searchMode
    local instanceRefresh = rawget(pane, "refreshContainer")
    local views = { originalList }
    if pane.neqHiding and pane.neqFilteredFor == pane.inventory
        and pane.neqFilteredItemList and pane.neqFilteredItemList ~= originalList then
        views[#views + 1] = pane.neqFilteredItemList
    end
    local ok, err = pcall(function()
        for _, list in ipairs(views) do
            pane.itemslist = list
            local refreshGeneration = pane.refreshContainerCount
            -- Neat keeps independent full/filtered arrays. Both must be settled
            -- before sharing CleanUI's per-refresh generation markers.
            pane._cleanUIRowPriorityRefreshCount = nil
            pane._cleanUICategoryPresentationRefreshCount = nil
            local reused = 0
            rawset(pane, "refreshContainer", function(self)
                rawset(pane, "refreshContainer", instanceRefresh)
                if self ~= pane then error("unexpected reconciliation receiver") end
                -- External callers can assign raw queries directly. The search
                -- entry normalizes them; restore the actual refresh semantics
                -- before its private ordering helper observes those fields.
                pane.searchText, pane.searchCategoryText, pane.searchMode = query, category, mode
                reused = reused + 1
            end)
            runForced(originals.searchContainer, pane, query, category, mode)
            rawset(pane, "refreshContainer", instanceRefresh)
            if reused ~= 1 or pane.refreshContainerCount ~= refreshGeneration then
                error("unsupported CleanUI search refresh contract")
            end
            M.stats.priorityBarriers = M.stats.priorityBarriers + 1
        end
    end)
    rawset(pane, "refreshContainer", instanceRefresh)
    pane.itemslist = originalList
    pane.searchText, pane.searchCategoryText, pane.searchMode = query, category, mode
    if not ok then
        -- Keep pending work observable and restore native refresh frequency.
        -- Abort this input rather than use a potentially ambiguous row map.
        if pane.inventory then pane.inventory:setDrawDirty(true) end
        stopOptimizing(err)
        error(err, 0)
    end
end

local function refreshPointer(pane)
    if pane.isMouseOver and pane:isMouseOver() and type(pane.onMouseMove) == "function" then
        runForced(pane.onMouseMove, pane, 0, 0)
    end
end

local function flushPane(pane)
    local s = pane and panes[pane]
    if not s or not s.pending then return end
    local selected = captureSelection(pane)
    runForced(pane.refreshContainer, pane)
    reconcileRows(pane)
    rebuildRows(pane)
    restoreRowSelection(pane, selected)
    refreshPointer(pane)
    M.stats.forcedFlushes = M.stats.forcedFlushes + 1
end

local function flushPage(page)
    local s = page and pages[page]
    if s and s.pending then
        local pane = page.inventoryPane
        local selected = pane and captureSelection(pane)
        runForced(page.refreshBackpacks, page)
        -- refreshBackpacks rebuilds the pane; refresh its hit-test lookup too.
        if page.inventoryPane then
            reconcileRows(page.inventoryPane)
            rebuildRows(page.inventoryPane)
            if selected then restoreRowSelection(page.inventoryPane, selected) end
            refreshPointer(page.inventoryPane)
        end
        M.stats.forcedFlushes = M.stats.forcedFlushes + 1
    else
        flushPane(page and page.inventoryPane)
    end
end

local function flushPaneOwner(pane)
    local page = pane and (pane.parent or pane.inventoryPage)
    if page and page.inventoryPane == pane then flushPage(page) else flushPane(pane) end
end

function M.flush(playerNum)
    local time = nowMs() or 0
    if playerNum ~= nil then
        playerState(playerNum).forceUntil = time + interval()
        flushPage(getPlayerInventory(playerNum))
        flushPage(getPlayerLoot(playerNum))
    else
        for page in pairs(pages) do flushPage(page) end
        for pane in pairs(panes) do flushPane(pane) end
        for _, s in pairs(players) do s.forceUntil = time + interval() end
    end
end

local function wrapInput(class, name, isPage)
    local old = class[name]
    if type(old) ~= "function" then return end
    class[name] = function(self, ...)
        -- Native refreshContainer calls onMouseMove(0,0) internally.
        if inputDepth > 0 or forceDepth > 0 or renderDepth > 0 or refreshDepth > 0 then return old(self, ...) end
        inputDepth = inputDepth + 1
        local ok, a, b, c = pcall(function(...)
            local time = nowMs() or 0
            playerState(self.player).forceUntil = time + interval()
            if isPage then flushPage(self) else flushPaneOwner(self) end
            return old(self, ...)
        end, ...)
        inputDepth = inputDepth - 1
        if not ok then error(a, 0) end
        return a, b, c
    end
end

local function install()
    if M.installed then return end
    -- Unknown layouts retain the unmodified native code path.
    if type(ISInventoryPage.refreshBackpacks) ~= "function" or type(ISInventoryPage.dirtyUI) ~= "function"
        or type(ISInventoryPage.cleanUIApplyScaleSettings) ~= "function"
        or type(ISInventoryPane.refreshContainer) ~= "function" or type(ISInventoryPane.renderdetails) ~= "function" then
        stopOptimizing("supported CleanUI interface unavailable")
        return
    end
    -- The small hit-test map is reviewed against this concrete renderer.
    -- A newer CleanUI can keep the same public methods but change its rows.
    if type(getModInfoByID) ~= "function" then
        stopOptimizing("CleanUI version metadata unavailable")
        return
    end
    local info = getModInfoByID("CleanUI") or getModInfoByID("\\CleanUI")
    local cleanVersion = info and info.getModVersion and tostring(info:getModVersion())
    local branch = info and info.getVersionDir and info:getVersionDir()
    local branchName = type(branch) == "string" and branch:gsub("\\", "/"):match("/([^/]+)/?$")
    local clean2105 = cleanVersion == "2.10.5" and (branchName == "42.19" or branchName == "42.22")
    local needsPriorityBarrier = cleanVersion == "2.10.1" or cleanVersion == "2.10.2"
        or cleanVersion == "2.10.3" or cleanVersion == "2.10.4" or clean2105
    if cleanVersion ~= "2.9.9" and not needsPriorityBarrier then
        stopOptimizing("unreviewed CleanUI version or branch")
        return
    end
    if needsPriorityBarrier and type(ISInventoryPane.searchContainer) ~= "function" then
        stopOptimizing("CleanUI search reconciliation interface unavailable")
        return
    end
    -- This optional mod suppresses rows through a private renderer helper.
    -- Decline optimization rather than construct an ambiguous hit-test map.
    local active = type(getActivatedMods) == "function" and getActivatedMods() or nil
    if clean2105 and active and (active:contains("SMP_SnakeUtilsPack") or active:contains("\\SMP_SnakeUtilsPack")) then
        stopOptimizing("CleanUI Snake Utils renderer takeover")
        return
    end
    if active and (active:contains("EQUIPMENT_UI") or active:contains("\\EQUIPMENT_UI")) then
        stopOptimizing("Equipment UI private row layout is unsupported")
        return
    end
    if active and (active:contains("NeatUI_Equipment") or active:contains("\\NeatUI_Equipment")) then
        local neat = getModInfoByID("NeatUI_Equipment") or getModInfoByID("\\NeatUI_Equipment")
        if not neat or not neat.getModVersion or tostring(neat:getModVersion()) ~= "1.0.2" then
            stopOptimizing("NeatUI Equipment 1.0.2 required; review newer filtered row layout")
            return
        end
    end
    M.expandedSelection = (cleanVersion == "2.10.4" or clean2105) and branchName == "42.22"
    M.cleanUIVersion = cleanVersion
    M.needsPriorityBarrier = needsPriorityBarrier
    originals.searchContainer = ISInventoryPane.searchContainer
    M.installed = true
    originals.refreshContainer = ISInventoryPane.refreshContainer
    ISInventoryPane.refreshContainer = function(self, ...)
        -- Explicit refreshes are never throttled, including search and sort.
        refreshDepth = refreshDepth + 1
        local ok, a, b, c = pcall(originals.refreshContainer, self, ...)
        refreshDepth = refreshDepth - 1
        if not ok then error(a, 0) end
        rememberPane(self, nowMs())
        M.stats.paneRefreshes = M.stats.paneRefreshes + 1
        return a, b, c
    end
    originals.refreshBackpacks = ISInventoryPage.refreshBackpacks
    ISInventoryPage.refreshBackpacks = function(self, ...)
        local time = nowMs()
        local s = pages[self]
        local pane = self.inventoryPane
        if automaticDepth > 0 and s and s.inventory == (pane and pane.inventory)
            and time and time >= s.last and time - s.last < interval()
            and samePaneView(panes[pane], pane) and canDefer(pane, time)
            and not self.forceSelectedContainer then
            s.pending = true
            M.stats.pageDeferred = M.stats.pageDeferred + 1
            return
        end
        local a, b, c = originals.refreshBackpacks(self, ...)
        pages[self] = { last = nowMs() or time or 0, inventory = self.inventoryPane and self.inventoryPane.inventory, pending = false }
        M.stats.pageRefreshes = M.stats.pageRefreshes + 1
        return a, b, c
    end
    originals.dirtyUI = ISInventoryPage.dirtyUI
    ISInventoryPage.dirtyUI = function(...)
        automaticDepth = automaticDepth + 1
        local ok, a, b, c = pcall(originals.dirtyUI, ...)
        automaticDepth = automaticDepth - 1
        if not ok then error(a, 0) end
        return a, b, c
    end
    originals.prerender = ISInventoryPage.prerender
    if type(originals.prerender) == "function" then
        ISInventoryPage.prerender = function(self, ...)
            local s = pages[self]
            local time = nowMs()
            -- UI keeps rendering when a paused game stops OnPlayerUpdate.
            if s and s.pending and (not time or time < s.last or time - s.last >= interval()
                or not canDefer(self.inventoryPane, time)) then flushPage(self) end
            return originals.prerender(self, ...)
        end
    end
    originals.renderdetails = ISInventoryPane.renderdetails
    ISInventoryPane.renderdetails = function(self, doDragged, ...)
        local time = nowMs()
        local s = panes[self]
        local inventory = self.inventory
        local mask = doDragged == false and samePaneView(s, self) and time
            and time >= s.last and time - s.last < interval() and canDefer(self, time)
            and inventory:isDrawDirty()
        local generation = s and s.generation
        if mask then
            -- Keep original draw, tooltip and progress code running every frame.
            inventory:setDrawDirty(false)
            s.pending = true
            M.stats.paneDeferred = M.stats.paneDeferred + 1
        end
        renderDepth = renderDepth + 1
        local ok, a, b, c = pcall(originals.renderdetails, self, doDragged, ...)
        renderDepth = renderDepth - 1
        if mask and (not ok or (panes[self] and panes[self].generation == generation)) then
            inventory:setDrawDirty(true)
        end
        if not ok then error(a, 0) end
        return a, b, c
    end
    local paneInputs = { "onMouseDown", "onMouseUp", "onMouseDoubleClick", "onRightMouseUp",
        "onMouseMove", "onMouseWheel", "onMouseDownOutside", "onMouseUpOutside",
        "doContextOnJoypadSelected", "onJoypadDown", "onJoypadDirUp", "onJoypadDirDown",
        "onJoypadDirLeft", "onJoypadDirRight", "onKeyPress", "onKeyRelease", "lootAll", "transferAll" }
    local pageInputs = { "selectContainer", "setNewContainer", "setForceSelectedContainer", "cycleContainer",
        "onBackpackMouseDown", "onBackpackClick", "onBackpackRightMouseDown", "onMouseDown", "onMouseUp",
        "onMouseWheel", "onJoypadDown", "onJoypadDirUp", "onJoypadDirDown", "onJoypadDirLeft",
        "onJoypadDirRight", "onKeyPress", "onKeyRelease", "onTransferAllClick", "onTransferClick",
        "lootAll", "transferAll", "setPinned", "collapse", "collapseNow" }
    for _, name in ipairs(paneInputs) do wrapInput(ISInventoryPane, name, false) end
    for _, name in ipairs(pageInputs) do wrapInput(ISInventoryPage, name, true) end
    originals.setVisible = ISInventoryPage.setVisible
    if type(originals.setVisible) == "function" then
        ISInventoryPage.setVisible = function(self, visible, ...)
            if visible and self.isVisible and not self:isVisible() then
                playerState(self.player).forceUntil = (nowMs() or 0) + interval()
                flushPage(self)
            end
            return originals.setVisible(self, visible, ...)
        end
    end
    originals.update = ISInventoryPane.update
    if type(originals.update) == "function" then
        ISInventoryPane.update = function(self, ...)
            -- Ctrl+A is read inside native update(), before the next renderer.
            if (type(isCtrlKeyDown) == "function" and isCtrlKeyDown())
                or (type(isShiftKeyDown) == "function" and isShiftKeyDown()) then flushPaneOwner(self) end
            return originals.update(self, ...)
        end
    end
    print("[Codex InventoryTransferPerformance] " .. M.version .. " ready; CleanUI=" .. cleanVersion
        .. "; SP bulk refresh interval=" .. tostring(interval()) .. "ms")
end
M.install = install
Events.OnGameStart.Add(install)

local function updatePlayer(player)
    if not M.installed or not player then return end
    local number = player:getPlayerNum()
    local time = nowMs()
    local bulk = bulkContext(number, time)
    local pagesToCheck = { getPlayerInventory(number), getPlayerLoot(number) }
    for _, page in ipairs(pagesToCheck) do
        local ps = pages[page]
        local pane = page and page.inventoryPane
        local ns = pane and panes[pane]
        if (ps and ps.pending and (not bulk or not time or time < ps.last or time - ps.last >= interval()))
            or (ns and ns.pending and (not bulk or not time or time < ns.last or time - ns.last >= interval())) then
            flushPage(page)
        end
    end
end
Events.OnPlayerUpdate.Add(updatePlayer)

local function equipmentChanged(player)
    if not player or not player.getPlayerNum then return end
    local number = player:getPlayerNum()
    if number and number >= 0 and getSpecificPlayer(number) == player then M.flush(number) end
end
for _, name in ipairs({ "OnClothingUpdated", "OnEquipPrimary", "OnEquipSecondary" }) do
    if Events[name] then Events[name].Add(equipmentChanged) end
end
