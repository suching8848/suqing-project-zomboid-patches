local V = PerfTest
V.gameStart()
V.case("native draw highlights semantic selection on first reordered frame", function()
    local items = {}; for i = 1, 240 do items[i] = V.item("Wood") end
    items[#items + 1] = V.item("Zinc")
    local p = V.prox(items)
    p.collapsed.Wood = false; p:refreshContainer(); p:renderdetails(false)
    V.click(p, 52); p:refreshContainer()
    function p:getYScroll() return -1000 end
    function p:drawItemDetails() end
    p.column4 = 600
    p.drawnSelections = {}
    function p:drawRect(x, y, width, height, a, r, g, b)
        if a == 0.20 and r == 1 and g == 1 and b == 1 then
            self.drawnSelections[#self.drawnSelections + 1] = self.items[math.floor(y / self.itemHgt) + 1].name
        end
    end
    p:renderdetails(false)
    V.eq(#p.drawnSelections, 1, "one selected row is actually drawn")
    V.eq(p.drawnSelections[1], "Zinc", "visible Zinc receives native highlight on the first refresh frame")
    V.eq(getmetatable(p.selected), nil, "temporary selection metatable is removed")
end)
return V.done()
