PerfTest.emit("OnGameStart")
local m=SuQingUIInteractionFixes.proximitySelection
assert(not m.installed and ISInventoryPane.refreshContainer == SelectionOriginalRefresh and ISInventoryPane.renderdetails == SelectionOriginalRender, "version gate 2.10.5")
return "version gate PASS"
