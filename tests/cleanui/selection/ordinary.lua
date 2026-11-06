local V = PerfTest
V.gameStart()
V.case("ordinary container retains its exact original refresh behavior", function()
    local p = V.nativePane({V.item("Apple"), V.item("Bandage"), V.item("Zinc")}, false)
    V.click(p, 1); p.inventory:setDrawDirty(true); p:renderdetails(false)
    V.eq(p.firstSelect, nil, "native ordinary-container anchor result unchanged")
    V.click(p, 3, true)
    V.eq(V.selectedCount(p), 2, "native ordinary-container selection unchanged")
end)
V.case("Neat actual character filter remains outside fix scope", function()
    local shirt = V.item("Shirt"); V.player.primary = shirt
    local p = V.nativePane({shirt, V.item("Wood")}, true)
    NEQ_State.hideEquipped = true; p:refreshContainer(); p:renderdetails(false)
    V.eq(#p.items, 1, "actual Neat equipped filter still hides shirt and separator")
    V.eq(p.items[1].name, "Wood", "actual Neat filtered row unchanged")
    NEQ_State.hideEquipped = false; V.player.primary = nil
end)
return V.done()
