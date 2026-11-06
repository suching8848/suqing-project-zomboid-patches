local V = PerfTest
function V.player:nullifyAiming() end
local originalItem = V.item
function V.item(...)
    local item = originalItem(...)
    function item:getContainer() return self.fixtureContainer end
    return item
end
local originalCore = getCore
function getCore()
    local core = originalCore()
    function core:setIsSelectingAll(value) V.selectingAll = value end
    function core:getOptionFontSizeReal() return 1 end
    return core
end
function isKeyDown(key) return key == Keyboard.KEY_A and V.keyA == true end
ISInventoryPane.updateTooltip = function() end
V.modVersions.CleanUI = "2.10.3"
V.modVersions.NeatUI_Equipment = "1.0.2"
local originalRender = ISInventoryPane.renderdetails
-- Controlled external final-row filter, in addition to the actual Neat source.
-- It deliberately does not change itemslist: the candidate must use drawn rows.
Events.OnGameStart.Add(function()
    local currentRender = ISInventoryPane.renderdetails
    ISInventoryPane.renderdetails = function(self, dragged, ...)
        if self.fixtureRenderError then error("injected selection render failure") end
        local result = currentRender(self, dragged, ...)
        if dragged == false and self.fixtureHideName then
            for row = #self.items, 1, -1 do
                local value = self.items[row]
                if value.name == self.fixtureHideName then table.remove(self.items, row) end
            end
        end
        return result
    end
end)
function V.prox(items)
    local p = V.nativePane(items, false)
    p.inventory.fixtureType = "proxInv"
    function p.inventory:getType() return self.fixtureType end
    local source = V.nativeContainer(V.copyList(items))
    for _, item in ipairs(items) do item.fixtureContainer = source end
    p.fixtureSource = source
    p.parent.backpacks = {{inventory = p.inventory}, {inventory = source}}
    p.draggedItems = {reset = function() end}
    function p.parent:isMouseOver() return p.hovered == true end
    V.leftPage = {inventoryPane = {selected = {}}, refreshBackpacks = function() end, isVisible = function() return false end,
        isMouseOver = function() return false end}
    return p
end
function V.click(p, row, shift)
    V.shift = shift == true
    p.mouseOverOption = row
    p:onMouseDown(100, row * p.itemHgt)
    p.dragging = nil; p.dragStarted = false
    ISMouseDrag.dragging = nil; ISMouseDrag.draggingFocus = nil
    V.shift = false
end
function V.selectedCount(p)
    local n = 0; for _ in pairs(p.selected) do n = n + 1 end; return n
end
function V.anchorName(p) return p.firstSelect and V.rowName(p.items[p.firstSelect]) end
function V.gameStart()
    V.emit("OnGameBoot"); V.emit("OnGameStart")
    if SelectionFixed then
        V.check(SuQingUIInteractionFixes.proximitySelection.installed, "fix installed")
    end
end
function V.done() return "cases=" .. V.cases .. "; assertions=" .. V.assertions end
