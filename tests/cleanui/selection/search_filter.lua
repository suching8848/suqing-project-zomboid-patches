local V = PerfTest
V.gameStart()
V.case("current Pinyin/CleanUI search order retains group identity", function()
    local p = V.prox({V.item("Bandage"), V.item("苹果"), V.item("Zinc")})
    local row
    for i, v in ipairs(p.items) do if v.name == "苹果" then row = i end end
    V.check(row ~= nil, "Chinese item rendered")
    V.click(p, row)
    p:searchContainer("ping", nil, "name"); p:renderdetails(false)
    V.eq(V.anchorName(p), "苹果", "anchor follows actual Pinyin final order")
    V.eq(p.firstSelect, 1, "Pinyin hit is first")
    V.eq(p.selected[1], p.items[1], "selected group follows search")
end)
V.case("actual final drawn rows override unfiltered itemslist", function()
    local p = V.prox({V.item("Apple"), V.item("Bandage"), V.item("Zinc")})
    V.click(p, 2)
    p.fixtureHideName = "Apple"
    p.inventory:setDrawDirty(true); p:renderdetails(false)
    V.eq(p.firstSelect, 1, "visible Bandage index ignores filtered Apple")
    V.eq(V.anchorName(p), "Bandage", "filtered rows retain Bandage")
    p.fixtureHideName = "Bandage"
    p.inventory:setDrawDirty(true); p:renderdetails(false)
    V.eq(p.firstSelect, nil, "removed anchor is not forced onto another row")
    V.eq(V.selectedCount(p), 0, "hidden selected group not resurrected")
end)
return V.done()
