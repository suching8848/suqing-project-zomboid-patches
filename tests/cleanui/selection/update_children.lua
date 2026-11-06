local V = PerfTest
V.gameStart()
local function childrenPane()
    local items = {}; for i = 1, 6 do items[i] = V.item("Wood") end
    items[#items + 1] = V.item("Zinc")
    local p = V.prox(items)
    p.collapsed.Wood = false; p:refreshContainer(); p:renderdetails(false)
    V.click(p, 2); V.click(p, 4, true)
    V.eq(V.selectedCount(p), 3, "three physical rows initially selected")
    return p
end
V.case("actual update retains Proximity children owned by real source", function()
    local p = childrenPane()
    p:update()
    V.eq(V.selectedCount(p), 3, "virtual container must not prune valid physical selections")
    V.eq(p.selected[2], p.items[2], "physical selected item remains exact object")
    V.eq(p.items[2]:getContainer(), p.fixtureSource, "real ownership remains unchanged")
end)
V.case("actual update honors removal from virtual and real lists", function()
    local p = childrenPane()
    local removed = p.items[2]
    for i, value in ipairs(p.inventory.nativeItems) do
        if value == removed then table.remove(p.inventory.nativeItems, i); break end
    end
    p:update()
    V.eq(p.selected[2], nil, "item no longer in aggregate is pruned")
    local another = p.items[3]
    -- Source is copied here so a stale aggregate can deliberately retain it.
    p.fixtureSource.nativeItems = V.copyList(p.inventory.nativeItems)
    for i, value in ipairs(p.fixtureSource.nativeItems) do
        if value == another then table.remove(p.fixtureSource.nativeItems, i); break end
    end
    p:update()
    V.eq(p.selected[3], nil, "stale virtual entry missing from true source is pruned")
end)
V.case("only-child Ctrl+A retains native all-row behavior", function()
    local p = childrenPane()
    p.hovered = true; V.ctrl = true; V.keyA = true
    p:update()
    V.eq(V.selectedCount(p), #p.items, "Ctrl+A selects every drawn row")
    V.ctrl = false; V.keyA = false
end)
V.case("transferred item and source leaving proximity retain native pruning", function()
    local p = childrenPane()
    local moved = p.items[2]
    local destination = V.nativeContainer({moved})
    moved.fixtureContainer = destination
    V.player.inventory = destination
    p:update()
    V.eq(p.selected[2], nil, "stale virtual reference moved into player inventory is pruned")
    p.parent.backpacks = {{inventory = p.inventory}}
    p:update()
    V.eq(p.selected[3], nil, "source no longer among surrounding containers is pruned")
end)
V.case("favorite flag and real ownership are untouched", function()
    local p = childrenPane()
    local item = p.items[2]
    function item:isFavorite() return true end
    p:update()
    V.eq(p.selected[2], item, "favorite physical item remains selected")
    V.eq(item:isFavorite(), true, "favorite flag preserved")
    V.eq(item:getContainer(), p.fixtureSource, "source ownership preserved")
end)
V.case("large prior stack refresh then update retains second-stack child", function()
    local items = {}; for i = 1, 240 do items[i] = V.item("Wood") end
    for i = 1, 3 do items[#items + 1] = V.item("Zinc") end
    local p = V.prox(items)
    p.collapsed.Wood = false; p.collapsed.Zinc = false
    p:refreshContainer(); p:renderdetails(false)
    V.eq(#p.items, 55, "both expanded stacks use actual cap")
    V.click(p, 53)
    local item = p.items[53]
    p:refreshContainer(); p:update(); p:renderdetails(false)
    V.eq(p.selected[53], item, "pending physical item survives intervening native update")
    V.eq(p.firstSelect, 53, "pending physical anchor uses capped actual row")
end)
return V.done()
