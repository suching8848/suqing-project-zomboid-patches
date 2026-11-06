local V = PerfTest
V.gameStart()
V.case("explicit clear after refresh never resurrects selection", function()
    local p = V.prox({V.item("Apple"), V.item("Zinc")})
    V.click(p, 1); p:refreshContainer()
    table.wipe(p.selected); p.firstSelect = nil
    p:renderdetails(false)
    V.eq(V.selectedCount(p), 0, "same-table explicit clear preserved")
    V.eq(p.firstSelect, nil, "same-table cleared anchor preserved")
    V.click(p, 1); p:refreshContainer()
    p.selected = {}; p.firstSelect = nil
    p:renderdetails(false)
    V.eq(V.selectedCount(p), 0, "replacement-table explicit clear preserved")
end)
V.case("container switch discards pending snapshot", function()
    local p = V.prox({V.item("Apple"), V.item("Zinc")})
    V.click(p, 1); p:refreshContainer()
    local c = V.nativeContainer({V.item("Apple"), V.item("Copper")})
    function c:getType() return "proxInv" end
    p.inventory = c; p.parent.inventory = c; p.selected = {}; p.firstSelect = nil
    p:refreshContainer(); p:renderdetails(false)
    V.eq(V.selectedCount(p), 0, "equal group name in another container not restored")
    V.eq(p.firstSelect, nil, "old container anchor discarded")
end)
return V.done()
