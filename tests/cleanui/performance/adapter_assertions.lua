local V, M = PerfTest, CodexInventoryTransferPerformance
local function setup()
    V.clock = V.clock + 1000
    V.player.moving, V.player.dead, V.player.vehicle = false, false, nil
    V.ctrl, V.shift, V.speed, V.mouseDown = false, false, 1, nil
    ISMouseDrag.dragging = nil
    V.pane(V.player.inventory, true)
    local p = V.pane(V.container(3000), false)
    V.transfer(p)
    V.emit("OnPlayerUpdate", V.player)
    V.clock = V.clock + 1000
    p.parent:refreshBackpacks()
    return p
end
local function pending(p)
    V.change(p)
    ISInventoryPage.dirtyUI()
end
V.case("native reconciliation reuses a completed refresh and restores raw method", function()
    local p = setup()
    pending(p)
    local before, barriers = p.baseRefreshes, M.stats.priorityBarriers
    local query, category, mode = p.searchText, p.searchCategoryText, p.searchMode
    V.eq(rawget(p, "refreshContainer"), nil, "method initially inherited")
    p:onMouseDown(1,1)
    V.eq(p.baseRefreshes, before+1, "one rebuild, no duplicate search refresh")
    V.eq(M.stats.priorityBarriers, barriers+1, "native search reconciliation called")
    V.eq(rawget(p, "refreshContainer"), nil, "no instance shim remains")
    V.eq(p.searchText, query, "query exact")
    V.eq(p.searchCategoryText, category, "category exact")
    V.eq(p.searchMode, mode, "mode exact")
end)
V.case("Neat full and filtered order settle before input and preserve semantic selection", function()
    local p = setup()
    local a = {name="A", items={"a"}}
    local b = {name="B", items={"b"}}
    p.inventory.groups = {b,a}
    p.itemslist, p.items, p.selected, p.firstSelect = {b,a}, {b,a}, {[1]=b}, 1
    p.neqHiding, p.neqFilteredFor, p.neqFilteredItemList = true, p.inventory, {b,a}
    local visible = p.neqFilteredItemList
    V.orderRows = true
    pending(p)
    p:onRightMouseUp(1,1)
    V.eq(p.itemslist[1], a, "full order settled")
    V.eq(visible[1], a, "filtered order settled independently")
    V.eq(p.items[2], b, "hit rows use final filtered order")
    V.eq(p.selected[2], b, "selected group mapped by identity")
    V.eq(p.firstSelect, 2, "shift anchor remapped")
    V.eq(p._cleanUIRowPriorityRefreshCount, p.refreshContainerCount, "native generation remains current")
    V.orderRows = nil
end)
V.case("instance-specific refresh is restored rather than replaced with inherited method", function()
    local p = setup()
    local custom = function(self, ...) return ISInventoryPane.refreshContainer(self, ...) end
    rawset(p, "refreshContainer", custom)
    pending(p)
    p:onMouseDown(1,1)
    V.eq(rawget(p,"refreshContainer"), custom, "exact instance function restored")
end)
V.case("all new column resize states bypass automatic deferral", function()
    for _, key in ipairs({"resizingRarityColumn", "resizingWeightColumn", "resizingExternalWeightColumn", "_cleanUIResizeState"}) do
        local p = setup()
        p[key] = true
        local before = p.baseRefreshes
        pending(p)
        V.eq(p.baseRefreshes, before+1, key .. " page immediate")
        V.change(p)
        p:renderdetails(false)
        V.eq(p.baseRefreshes, before+2, key .. " pane immediate")
    end
end)
V.case("new titlebar and container layout invalidates deferred pane snapshot", function()
    for _, key in ipairs({"_cleanUITitleBarPosition", "_cleanUIContainerPosition", "_cleanUIContainerColumns"}) do
        local p = setup()
        local before = p.baseRefreshes
        p.parent[key] = "changed"
        V.change(p)
        p:renderdetails(false)
        V.eq(p.baseRefreshes, before+1, key .. " native rebuild")
    end
    local p = setup()
    local before = p.baseRefreshes
    p.headerHgt = 99
    V.change(p)
    p:renderdetails(false)
    V.eq(p.baseRefreshes, before+1, "header geometry native rebuild")
end)
return "adapter tests passed; cases="..V.cases.."; assertions="..V.assertions
