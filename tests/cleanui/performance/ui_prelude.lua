-- Independent offline fixtures: exercise wrapper behavior in the real Kahlua
-- interpreter. No claim is made about actual Java UI drawing or measured FPS.
PerfTest = { assertions = 0, cases = 0, clock = 10000, trace = {} }
local V = PerfTest
function V.check(condition, message)
    V.assertions = V.assertions + 1
    assert(condition, message or "assertion failed")
end
function V.eq(actual, expected, message)
    V.check(actual == expected, (message or "equality") .. " got=" .. tostring(actual) .. " expected=" .. tostring(expected))
end
function V.case(name, fn)
    fn()
    V.cases = V.cases + 1
    print("PASS " .. name)
end
function V.list(values)
    local list = { values = values or {} }
    function list:size() return #self.values end
    function list:get(index) return self.values[index + 1] end
    function list:isEmpty() return #self.values == 0 end
    function list:add(value) self.values[#self.values + 1] = value end
    function list:contains(value) for _, v in ipairs(self.values) do if v == value then return true end end return false end
    return list
end
function V.emit(name, ...)
    for _, handler in ipairs(Events[name].handlers) do handler(...) end
end
Events = setmetatable({}, { __index = function(self, name)
    local event = { handlers = {} }
    function event.Add(fn) event.handlers[#event.handlers + 1] = fn end
    function event.Remove(fn)
        for i = #event.handlers, 1, -1 do
            if event.handlers[i] == fn then table.remove(event.handlers, i) end
        end
    end
    self[name] = event
    return event
end })
function require(name) return true end
function getModInfoByID(id)
    if V.missingMetadata then return nil end
    return {getModVersion=function()return (V.modVersions or {})[id] or (id=="NeatUI_Equipment" and "1.0.2" or "2.9.9")end}
end
function getActivatedMods() return V.list(V.activeMods or {}) end
function table.wipe(t) for k in pairs(t) do t[k] = nil end end
function getTimestampMs() return V.clock end
function getNumActivePlayers() return 1 end
function getSpecificPlayer(index) return index == 0 and V.player or nil end
function getPlayer() return V.player end
function isClient() return false end
function isServer() return false end
function instanceof(value, name) return type(value) == "table" and value.kind == name end
function isMouseButtonDown(index) return V.mouseDown == index end
function isKeyDown(index) return false end
function isCtrlKeyDown() return V.ctrl == true end
function isShiftKeyDown() return V.shift == true end
function getGameSpeed() return V.speed or 1 end
function getPlayerInventory(index) return V.leftPage end
function getPlayerLoot(index) return V.rightPage end
function getGameTime() return {getMultiplier = function() return V.multiplier or 1 end} end
function getCore() return { getGameMode = function() return "Sandbox" end } end
ISMouseDrag = {}
Keyboard = { KEY_A = 30 }
ISTimedActionQueue = {}
ISTimedActionQueue.queues = {}
function ISTimedActionQueue.getTimedActionQueue(character) return character and character.actionQueue or nil end
ISInventoryTransferAction = { Type = "ISInventoryTransferAction" }
function ISInventoryTransferAction.perform(self) V.performCalls = (V.performCalls or 0) + 1; return "performed" end
function ISInventoryTransferAction.stop(self) V.stopCalls = (V.stopCalls or 0) + 1; return "stopped" end
ISInventoryPage = {}
ISInventoryPane = {}
function ISInventoryPane.refreshContainer(self)
    self.baseRefreshes = (self.baseRefreshes or 0) + 1
    self.itemslist = self.inventory.groups or { { name = "actual-" .. tostring(self.inventory.count), items = {} } }
    self.lastReadContainer = self.inventory
    self.lastReadCount = self.inventory.count
    self.inventory:setDrawDirty(false)
    return "refresh-result"
end
function ISInventoryPane.renderdetails(self, dragged)
    self.baseRenders = (self.baseRenders or 0) + 1
    if V.renderError then error("injected renderer failure") end
    if dragged == false and self.inventory:isDrawDirty() then self:refreshContainer() end
    return "render-result"
end
function ISInventoryPane.update(self)
    self.baseUpdates = (self.baseUpdates or 0) + 1
    self.updateReadCount = self.lastReadCount
    return "update-result"
end
function ISInventoryPane.onMouseDown(self, x, y)
    self.inputCount = self.lastReadCount
    return "mouse-result"
end
function ISInventoryPane.onMouseUp(self, x, y) self.inputCount = self.lastReadCount; return "mouseup-result" end
function ISInventoryPane.onRightMouseUp(self, x, y) self.inputCount = self.lastReadCount; return "right-result" end
function ISInventoryPane.lootAll(self) self.inputCount = self.lastReadCount; return "loot-result" end
function ISInventoryPane.transferAll(self) self.inputCount = self.lastReadCount; return "transfer-result" end
function ISInventoryPane.setInventory(self, inventory) self.inventory = inventory end
function ISInventoryPage.refreshBackpacks(self)
    self.baseRefreshes = (self.baseRefreshes or 0) + 1
    V.clock=V.clock+(V.refreshCost or 0)
    if self.inventoryPane then self.inventoryPane:refreshContainer() end
    return "backpacks-result"
end
function ISInventoryPage.cleanUIApplyScaleSettings(self) end
function ISInventoryPage.prerender(self) self.basePrerenders=(self.basePrerenders or 0)+1;return "page-render-result" end
function ISInventoryPage.setVisible(self, visible) self.visible = visible end
function ISInventoryPage.dirtyUI()
    if V.leftPage then V.leftPage:refreshBackpacks() end
    if V.rightPage then V.rightPage:refreshBackpacks() end
    return "dirty-result"
end
function ISInventoryPage.selectContainer(self, container)
    self.inventoryPane.inventory = container
    self.inventory = container
    self:refreshBackpacks()
end
function V.container(count)
    local c = { kind = "ItemContainer", count = count or 1000, dirty = true }
    function c:getItems() return V.list({}) end
    function c:isDrawDirty() return self.dirty end
    function c:setDrawDirty(value) self.dirty = value end
    function c:isInCharacterInventory(character) return self == character.inventory end
    function c:getType() return "crate" end
    return c
end
function V.pane(container, onCharacter)
    local p = { inventory = container or V.container(), player = 0, mode = "details", itemslist = {}, items = {},
        selected = {}, collapsed = {}, inventoryPage = {}, searchText = "", searchCategoryText = "", searchMode = "name", visible = true }
    local page = { inventory = p.inventory, inventoryPane = p, onCharacter = onCharacter == true, player = 0 }
    setmetatable(page, { __index = ISInventoryPage })
    function page:isVisible() return self.visible ~= false end
    p.parent = page
    p.inventoryPage = page
    function p:isVisible() return self.visible end
    function p:isReallyVisible() return self.visible end
    function p:isMouseOver() return self.hovered == true end
    function p:setVisible(value) self.visible = value end
    setmetatable(p, { __index = ISInventoryPane })
    if onCharacter then V.leftPage = page else V.rightPage = page end
    return p
end
V.player = { kind = "IsoPlayer", inventory = V.container(30), x = 20, y = 20, z = 0, moving = false, dead = false }
function V.player:getPlayerNum() return 0 end
function V.player:getInventory() return self.inventory end
function V.player:getX() return self.x end
function V.player:getY() return self.y end
function V.player:getZ() return self.z end
function V.player:isMoving() return self.moving end
function V.player:isPlayerMoving() return self.moving end
function V.player:isDead() return self.dead end
function V.player:getVehicle() return self.vehicle end
function V.player:getCurrentSquare() return self.square end
function V.transfer(pane)
    local action = { Type = "ISInventoryTransferAction", type = "ISInventoryTransferAction", character = V.player,
        srcContainer = pane.inventory, destContainer = V.player.inventory, queueList = {{items={1,2,3}}}, started = true }
    setmetatable(action, { __index = ISInventoryTransferAction })
    V.player.actionQueue = { queue = {action} }
    ISTimedActionQueue.queues[V.player] = V.player.actionQueue
    return action
end
function V.noAction() V.player.actionQueue = { queue = {} }; ISTimedActionQueue.queues[V.player] = V.player.actionQueue end
function V.change(pane, count)
    pane.inventory.count = count or (pane.inventory.count + 1)
    pane.inventory.dirty = true
end
return "UI fixtures ready"
