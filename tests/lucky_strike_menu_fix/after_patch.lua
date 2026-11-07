local T=LuckyTest
T.start()
T.check(SuQingLuckyStrikeMenuFix.installed==true,SuQingLuckyStrikeMenuFix.inactiveReason)
T.eq(#Events.OnGameStart.handlers,1,"duplicate chunk has one lifecycle handler")
local installedMenu=ISInventoryPaneContextMenu.createMenu
T.start();T.eq(ISInventoryPaneContextMenu.createMenu,installedMenu,"repeat event does not wrap twice")

local function sameMembers(actual,expected)
 T.eq(#actual,#expected,"member count")
 for i,v in ipairs(expected)do T.eq(actual[i],v,"member identity/order "..i)end
end
local function smoke(kind,optimized)
 local values=T.ten(kind);local group=T.group(values,optimized);local selection={group}
 local before=SuQingLuckyStrikeMenuFix.normalizedMenus
 local context=T.call(selection)
 T.eq(T.lastItems,selection,"homogeneous original selection reference")
 sameMembers(T.lastActual,values)
 T.eq(SuQingLuckyStrikeMenuFix.normalizedMenus,before)
 T.eq(T.contextCreated,1);T.eq(context.origin,"offline-origin")
 if kind=="Food"then T.eq(#T.foodMenuItems,10);T.eq(T.hungerCalls,10);T.eq(T.pillsMenuItems,nil)
 else T.eq(#T.pillsMenuItems,10);T.eq(T.hungerCalls,0);T.eq(T.foodMenuItems,nil)end
end
T.case("patched ten singles unchanged",function()smoke("Food",false)end)
T.case("patched ten packs unchanged",function()smoke("DrainableComboItem",false)end)
T.case("optimized homogeneous ten singles unchanged",function()smoke("Food",true)end)
T.case("optimized homogeneous ten packs unchanged",function()smoke("DrainableComboItem",true)end)

local function mixed(optimized)
 local values=T.ten("Food");values[7]=T.item("DrainableComboItem")
 local group=T.group(values,optimized);local selection={group};local before=SuQingLuckyStrikeMenuFix.normalizedMenus
 local raw={};for i,v in ipairs(group.items)do raw[i]=v end
 T.call(selection)
 T.check(T.lastItems~=selection,"unsafe selection normalized")
 sameMembers(T.lastActual,values)
 T.eq(T.foodMenuItems,nil);T.eq(T.pillsMenuItems,nil);T.eq(T.hungerCalls,0)
 T.eq(T.contextCreated,1);T.eq(SuQingLuckyStrikeMenuFix.normalizedMenus,before+1)
 T.eq(selection[1],group);sameMembers(group.items,raw)
end
T.case("mixed ordinary ten items no longer call Food method on pack",function()mixed(false)end)
T.case("mixed optimized ten items retain every member",function()mixed(true)end)
T.case("pack first mixed group stays safe original route",function()
 local values=T.ten("Food");values[1]=T.item("DrainableComboItem")
 local selection={T.group(values)};local before=SuQingLuckyStrikeMenuFix.normalizedMenus
 T.call(selection);T.eq(T.lastItems,selection);sameMembers(T.lastActual,values)
 T.eq(T.foodMenuItems,nil);T.eq(#T.pillsMenuItems,10)
 T.eq(SuQingLuckyStrikeMenuFix.normalizedMenus,before)
end)
T.case("stale Food header over ten actual packs normalizes",function()
 local values=T.ten("DrainableComboItem");local group=T.group(values,false,T.item("Food"));local selection={group}
 T.call(selection);T.check(T.lastItems~=selection);sameMembers(T.lastActual,values)
 T.eq(T.foodMenuItems,nil);T.eq(#T.pillsMenuItems,10);T.eq(T.hungerCalls,0)
end)
T.case("group plus explicit child plus unrelated group deduplicates whole selection",function()
 local a=T.item("Food");local b=T.item("DrainableComboItem");local c=T.item("Food","Base.Apple")
 local group=T.group({a,b});local other=T.group({c});local selection={group,a,other,b}
 T.call(selection);sameMembers(T.lastActual,{a,b,c});sameMembers(T.lastItems,{a,b,c})
 T.eq(#selection,4);T.eq(selection[1],group);T.eq(selection[3],other);T.eq(T.contextCreated,1)
end)
T.case("unrelated same-name mixed group is outside patch scope",function()
 local a=T.item("Food","Other.Food");local b=T.item("DrainableComboItem","Other.Pack")
 local selection={T.group({a,b})};local before=SuQingLuckyStrikeMenuFix.normalizedMenus
 local ok,err=pcall(T.call,selection)
 T.eq(ok,false);T.check(tostring(err):find("Object tried to call nil",1,true)~=nil)
 T.eq(SuQingLuckyStrikeMenuFix.normalizedMenus,before)
end)
T.case("direct single item selection is unchanged",function()
 local a=T.item("Food");local selection={a};T.call(selection)
 T.eq(T.lastItems,selection);sameMembers(T.lastActual,{a});T.eq(T.contextCreated,1)
end)
T.case("downstream menu exception remains visible",function()
 local old=ISInventoryPaneContextMenu.doMoreContextMenu
 ISInventoryPaneContextMenu.doMoreContextMenu=function()error("injected downstream menu failure")end
 local a=T.item("Food");local b=T.item("DrainableComboItem")
 local ok,err=pcall(T.call,{T.group({a,b})})
 ISInventoryPaneContextMenu.doMoreContextMenu=old
 T.eq(ok,false);T.check(tostring(err):find("injected downstream menu failure",1,true)~=nil,tostring(err));T.eq(T.contextCreated,1)
end)
return "cases="..T.cases.."; assertions="..T.assertions.."; tests="..table.concat(T.names," | ")
