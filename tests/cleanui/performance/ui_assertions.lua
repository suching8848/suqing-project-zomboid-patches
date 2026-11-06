local V=PerfTest
local M=CodexInventoryTransferPerformance
V.emit("OnGameStart")
V.check(M.installed and M.enabled,"supported interface installs")
local function setup()
    V.clock=math.max(1000000,V.clock+1000)
    V.player.moving=false V.player.dead=false V.player.vehicle=nil
    V.ctrl=false V.shift=false V.speed=1 V.mouseDown=nil
    ISMouseDrag.dragging=nil
    V.pane(V.player.inventory,true)
    local p=V.pane(V.container(3000),false)
    local a=V.transfer(p)
    V.emit("OnPlayerUpdate",V.player)
    V.clock=V.clock+1000
    p.parent:refreshBackpacks()
    return p,a
end
local function pendingPane(p)
    V.change(p)
    p:renderdetails(false)
end
V.case("merged action refresh requests coalesce and dirty bit remains pending",function()
    local p=setup()
    local before=p.baseRefreshes
    for i=1,50 do V.clock=V.clock+1; pendingPane(p) end
    V.eq(p.baseRefreshes,before,"one merged group recognized as bulk")
    V.check(p.inventory:isDrawDirty(),"deferred mutation not discarded")
    V.eq(p.baseRenders,50,"native renderer still runs each frame")
    V.clock=V.clock+180
    p:renderdetails(false)
    V.eq(p.baseRefreshes,before+1,"deferred mutations become visible by wall interval")
    V.eq(p.lastReadCount,p.inventory.count,"latest contents shown")
end)
V.case("sustained transfer cannot starve refresh or force one rebuild per item",function()
    local p=setup()
    local before=p.baseRefreshes
    for i=1,100 do
        V.clock=V.clock+10
        V.change(p)
        ISInventoryPage.dirtyUI()
        p:renderdetails(false)
        V.emit("OnPlayerUpdate",V.player)
    end
    V.check(p.baseRefreshes-before<=15,"one hundred events coalesced")
    V.check(p.baseRefreshes-before>=5,"continuous changes periodically published")
    V.noAction()
    V.emit("OnPlayerUpdate",V.player)
    V.eq(p.lastReadCount,p.inventory.count,"completion publishes exact final contents")
end)
V.case("cancellation flushes final state before interval elapses",function()
    local p,a=setup()
    pendingPane(p)
    local before=p.baseRefreshes
    a.started=false
    V.emit("OnPlayerUpdate",V.player)
    V.eq(p.baseRefreshes,before+1,"cancelled action final flush")
    V.eq(p.lastReadCount,p.inventory.count,"cancel latest state")
end)
V.case("page-only deferred refresh flushes before click with no intervening render",function()
    local p=setup()
    V.change(p,4242)
    ISInventoryPage.dirtyUI()
    V.eq(p.lastReadCount,3000,"automatic page refresh deferred")
    V.eq(p:onMouseDown(1,1),"mouse-result","native callback result preserved")
    V.eq(p.inputCount,4242,"click reads latest container")
end)
V.case("explicit refresh remains immediate during bulk transfer",function()
    local p=setup()
    V.change(p,4000)
    V.eq(p:refreshContainer(),"refresh-result","return value retained")
    V.eq(p.lastReadCount,4000,"direct call unthrottled")
    V.change(p,4001)
    p.parent:refreshBackpacks()
    V.eq(p.lastReadCount,4001,"direct page call unthrottled")
end)
V.case("container switch cannot retain old cached view",function()
    local p=setup()
    pendingPane(p)
    local nextContainer=V.container(17)
    p.parent:selectContainer(nextContainer)
    V.eq(p.lastReadContainer,nextContainer,"selection refresh uses new container")
    V.eq(p.lastReadCount,17,"selected view exact")
end)
V.case("search and sort changes bypass dirty deferral",function()
    local p=setup()
    local before=p.baseRefreshes
    V.change(p)
    p.searchText="new query"
    p:renderdetails(false)
    V.eq(p.baseRefreshes,before+1,"search immediate")
    V.change(p)
    p.itemSortFunc=function()return true end
    p:renderdetails(false)
    V.eq(p.baseRefreshes,before+2,"sort immediate")
end)
V.case("nontransfer walking death vehicle pause and controller bypass throttling",function()
    local p,a=setup()
    local predicates={
        function()a.Type="ISEatFoodAction"end,
        function()a.Type="ISInventoryTransferAction";V.player.moving=true end,
        function()V.player.moving=false;V.player.dead=true end,
        function()V.player.dead=false;V.player.vehicle={}end,
        function()V.player.vehicle=nil;V.speed=0 end,
        function()V.speed=1;p.doController=true end,
        function()p.doController=false;p.hovered=true end,
        function()p.hovered=false;p.dragging={}end,
        function()p.dragging=nil;ISMouseDrag.dragging={1}end,
    }
    for i,change in ipairs(predicates)do
        change()
        local before=p.baseRefreshes
        V.change(p)
        p:renderdetails(false)
        V.eq(p.baseRefreshes,before+1,"bypass condition "..i)
    end
end)
V.case("keyboard select-all path flushes page-only pending changes before update",function()
    local p=setup()
    V.change(p,4321)
    ISInventoryPage.dirtyUI()
    V.ctrl=true
    p:update()
    V.eq(p.updateReadCount,4321,"Ctrl reads refreshed rows before native update")
end)
V.case("reopening page flushes deferred work before visible transition",function()
    local p=setup()
    pendingPane(p)
    p.parent.visible=false
    p.parent:setVisible(true)
    V.eq(p.lastReadCount,p.inventory.count,"reopen exact")
end)
V.case("wall clock rollback cannot retain deferred changes",function()
    local p=setup()
    pendingPane(p)
    V.clock=V.clock-100000
    V.emit("OnPlayerUpdate",V.player)
    V.eq(p.lastReadCount,p.inventory.count,"clock rewind final flush")
end)
V.case("missing time API fails open to native refresh",function()
    local p=setup()
    local old=getTimestampMs
    getTimestampMs=nil
    V.change(p,8181)
    p:renderdetails(false)
    V.eq(p.lastReadCount,8181,"missing clock native path")
    getTimestampMs=old
end)
V.case("multiplayer client fails open",function()
    local p=setup()
    local old=isClient
    isClient=function()return true end
    V.change(p,9191)
    p:renderdetails(false)
    V.eq(p.lastReadCount,9191,"MP unthrottled")
    isClient=old
end)
V.case("input flush preserves item selection and anchor across reordered row indices",function()
    local p=setup()
    local a,b,c={kind="InventoryItem"},{kind="InventoryItem"},{kind="InventoryItem"}
    local old={name="stack",items={a,a,b}}
    p.inventory.groups={old}
    p:refreshContainer()
    p.items={old,a,b}
    p.selected={[3]=b}
    p.firstSelect=3
    local fresh={name="stack",items={a,a,b}}
    local inserted={name="front",items={c}}
    p.inventory.groups={inserted,fresh}
    pendingPane(p)
    M.flush(0)
    V.eq(p.items[1],inserted,"new leading row")
    V.eq(p.items[2],fresh,"stack header refreshed")
    V.eq(p.items[3],a,"duplicate display item maps to first child")
    V.eq(p.items[4],b,"second child row")
    V.eq(p.selected[4],b,"selected item follows actual new row")
    V.eq(p.selected[3],nil,"old index not retained")
    V.eq(p.firstSelect,4,"shift anchor follows item")
end)
V.case("Neat hidden equipment view uses filtered row map and removes hidden selection",function()
    local p=setup()
    local h,a={kind="InventoryItem"},{kind="InventoryItem"}
    local hidden={name="equipped",equipped=true,items={h}}
    local shown={name="shown",items={a}}
    p.inventory.groups={hidden,shown}
    p:refreshContainer()
    p.items={hidden,shown}
    p.selected={[1]=hidden,[2]=shown}
    p.firstSelect=2
    p.neqHiding=true
    p.neqFilteredFor=p.inventory
    local currentShown={name="shown",items={a}}
    p.neqFilteredItemList={currentShown}
    pendingPane(p)
    M.flush(0)
    V.eq(#p.items,1,"equipped row remains absent")
    V.eq(p.items[1],currentShown,"filtered row current")
    V.eq(p.selected[1],currentShown,"visible group semantic selection retained")
    V.eq(p.selected[2],nil,"hidden selected row removed")
    V.eq(p.firstSelect,1,"visible group anchor remapped")
end)
V.case("row map respects separators collapse and maximum stack display",function()
    local p=setup()
    local values={1,2,3,4,5,6}
    local sep={name="header",type="separator"}
    local collapsed={name="collapsed",items=values}
    local expanded={name="expanded",items=values}
    local equipped={name="equipped",equipped=true,items=values}
    p.inventory.groups={sep,collapsed,expanded,equipped}
    p:refreshContainer()
    p.collapsed.collapsed=true
    p.equippedCollapsed=true
    -- Make view state current before testing a subsequent deferred mutation.
    p:refreshContainer()
    local max=ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER
    ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER=2
    pendingPane(p)
    M.flush(0)
    V.eq(#p.items,5,"separator plus collapsed header plus three expanded rows")
    V.eq(p.items[1],sep,"separator index")
    V.eq(p.items[2],collapsed,"collapsed header only")
    V.eq(p.items[3],expanded,"expanded stack header")
    V.eq(p.items[5],3,"maximum child row honored")
    ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER=max
end)
V.case("renderer exception restores dirty bit and propagates original error",function()
    local p=setup()
    V.change(p,8787)
    V.renderError=true
    local ok,err=pcall(p.renderdetails,p,false)
    V.renderError=false
    V.check(not ok and string.find(tostring(err),"injected renderer failure",1,true),"native renderer error retained")
    V.check(p.inventory:isDrawDirty(),"failed masked render restores dirty flag")
    M.flush(0)
    V.eq(p.lastReadCount,8787,"subsequent final flush remains usable")
end)
V.case("paused game page prerender publishes page-only pending updates",function()
    local p=setup()
    V.change(p,4545)
    ISInventoryPage.dirtyUI()
    V.speed=0
    p.parent:prerender()
    V.eq(p.lastReadCount,4545,"page flush works without player update while paused")
end)
V.case("single item transfer remains native without bulk batching",function()
    local p=setup()
    -- Use a fresh action: shrinking an already merged bulk action to its last
    -- item intentionally retains coalescing until that action completes.
    local a=V.transfer(p)
    a.queueList={{items={1}}}
    local before=p.baseRefreshes
    pendingPane(p)
    V.eq(p.baseRefreshes,before+1,"single item does not enter coalescing")
end)
V.case("expensive full rebuild interval begins at completion",function()
    local p=setup()
    V.refreshCost=220
    p.parent:refreshBackpacks()
    V.refreshCost=0
    local before=p.parent.baseRefreshes
    V.change(p)
    ISInventoryPage.dirtyUI()
    V.eq(p.parent.baseRefreshes,before,"slow previous refresh does not trigger immediate second full pass")
end)
return "UI tests passed; cases="..V.cases.."; assertions="..V.assertions
