-- No candidate patch is loaded in this suite. It diagnoses the controlled
-- input/refresh boundary rather than claiming how the actual Java dispatcher runs.
local V=PerfTest
local p=V.pane(V.container(1000),false)
local page=p.parent
page:refreshBackpacks();page:collapseNow()
page.isCollapsed=false;page:prerender()
V.case("unpatched controlled input needs the native refresh notification too",function()
 V.change(p,2345)
 p:onMouseDown(0,0)
 V.eq(p.lastReadCount,1000,"unpatched mock also keeps old rows without renderer or dirtyUI")
 V.eq(p.inputCount,1000,"unpatched input boundary reads the existing row snapshot")
 V.eq(p.inventory:isDrawDirty(),true,"mutation remains dirty until normal UI refresh")
 ISInventoryPage.dirtyUI();p:onMouseDown(0,0)
 V.eq(p.lastReadCount,2345,"native dirtyUI refresh publishes new rows")
 V.eq(p.inputCount,2345,"native input reads refreshed snapshot")
end)
return "Page notification control passed; cases="..V.cases.."; assertions="..V.assertions
