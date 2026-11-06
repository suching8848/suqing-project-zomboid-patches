local V, M = PerfTest, CodexInventoryTransferPerformance
V.emit("OnGameStart")
V.pane(V.player.inventory, true)
local p = V.pane(V.container(3000), false)
V.transfer(p)
V.emit("OnPlayerUpdate", V.player)
V.clock = V.clock + 1000
p.parent:refreshBackpacks()
V.change(p)
ISInventoryPage.dirtyUI()
local before = p.refreshContainerCount
local query, category, mode = p.searchText, p.searchCategoryText, p.searchMode
V[V.failureFlag] = true
local ok = pcall(p.onMouseDown, p, 1, 1)
V.check(not ok, "unsafe reconciliation aborts input")
V.eq(M.enabled, false, "future rebuilds use native frequency")
V.eq(M.stats.failOpen, 1, "failure diagnostic")
V.eq(rawget(p, "refreshContainer"), nil, "shim removed on error")
V.eq(p.searchText, query, "query restored on error")
V.eq(p.searchCategoryText, category, "category restored on error")
V.eq(p.searchMode, mode, "mode restored on error")
V.check(p.inventory:isDrawDirty(), "failed state remains dirty for native redraw")
V.eq(p.inputCount, nil, "no input dispatched with ambiguous rows")
V[V.failureFlag] = nil
p:refreshContainer()
V.check(p.refreshContainerCount > before, "subsequent native refresh works")
return "adapter failure cleanup passed; assertions="..V.assertions
