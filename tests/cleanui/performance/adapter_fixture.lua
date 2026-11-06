-- Extend the wrapper fixtures to exercise the reviewed public search barrier.
-- Full CleanUI/Neat source integration is tested separately by native_*.
local V = PerfTest
V.modVersions = { CleanUI = "2.10.1" }
local refresh = ISInventoryPane.refreshContainer
ISInventoryPane.refreshContainer = function(self, ...)
    local result = refresh(self, ...)
    self.refreshContainerCount = (self.refreshContainerCount or 0) + 1
    return result
end
function ISInventoryPane.searchContainer(self, query, category, mode)
    self.searchText, self.searchCategoryText, self.searchMode = query, category, mode or "name"
    if not V.skipBarrierRefresh then self:refreshContainer() end
    if V.doubleBarrierRefresh then self:refreshContainer() end
    if V.barrierError then error("injected reconciliation error") end
    self._cleanUICategoryPresentationRefreshCount = self.refreshContainerCount
    if self._cleanUIRowPriorityRefreshCount == self.refreshContainerCount then return end
    self._cleanUIRowPriorityRefreshCount = self.refreshContainerCount
    if V.orderRows then table.sort(self.itemslist, function(a,b) return a.name < b.name end) end
end
return "2.10.1 barrier fixtures ready"
