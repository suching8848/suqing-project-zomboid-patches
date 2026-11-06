local V=PerfTest
V.emit("OnGameBoot");V.emit("OnGameStart")
V.check(CodexInventoryTransferPerformance.installed,"candidate installs with actual CleanUI 2.10.3")
V.check(CodexInventoryTransferPerformance.enabled,"candidate enabled")
V.case("actual source stack header and expanded row mapping",function()
 local items={};for i=1,240 do items[i]=V.item("Wood")end
 local p=V.nativePane(items)
 V.eq(#p.itemslist,1,"one stack")
 V.eq(p.itemslist[1].cleanUIFirstActualIndex,1,"large collapsed virtual header")
 V.eq(#p.items,1,"collapsed one visible logical row")
 V.deferNative(p,V.item("Zinc"));p:onKeyRelease(0)
 V.assertRowsMatchRender(p)
 p.collapsed.Wood=false;p:refreshContainer();p:renderdetails(false)
 V.eq(p.itemslist[1].cleanUIFirstActualIndex,2,"expanded physical header")
 V.eq(#p.items,52,"expanded native 51 plus second group")
 V.deferNative(p,V.item("Copper"));p:onKeyRelease(0)
 V.assertRowsMatchRender(p)
end)
V.case("real Pinyin wrapper native reconcile and group anchor",function()
 local p=V.nativePane({V.item("ping-apple"),V.item("苹果"),V.item("Zinc")})
 p.itemSortFunc=function(a,b)return a.name>b.name end
 p:searchContainer("ping",nil,"name");p:renderdetails(false)
 V.eq(p.items[1].name,"苹果","current source preserves pinyin search priority after search")
 local target
 for row,g in ipairs(p.items)do if g.name=="苹果" then p.selected={[row]=g};p.firstSelect=row;target=g end end
 V.check(target~=nil,"Pinyin target exists")
 V.deferNative(p,V.item("Banana"));p:onKeyRelease(0)
 V.assertRowsMatchRender(p)
 V.eq(p.items[p.firstSelect].name,"苹果","anchor keeps group")
 V.eq(p.selected[p.firstSelect].name,"苹果","selected group follows final order")
end)
V.case("real Neat wrapper hides equipment and flushes filtered rows",function()
 local shirt=V.item("Shirt");V.player.primary=shirt
 local p=V.nativePane({shirt,V.item("Wood")},true)
 NEQ_State.hideEquipped=true;p:refreshContainer();p:renderdetails(false)
 V.eq(#p.items,1,"equipped and separator hidden")
 V.eq(p.items[1].name,"Wood","plain row remains")
 V.deferNative(p,V.item("Copper"));p:onKeyRelease(0)
 V.assertRowsMatchRender(p)
 for _,v in ipairs(p.items)do V.check(v.name~="equipped:Shirt" and v.type~="separator","no hidden row in input map")end
 NEQ_State.hideEquipped=false;p:renderdetails(false)
 V.check(#p.items>=3,"eye off restores equipment and separator")
 V.player.primary=nil
end)
V.case("real rebuild work coalesces for 180 milliseconds",function()
 local p=V.nativePane({V.item("Wood")},true)
 V.transfer(p);p.parent:refreshBackpacks()
 local baseline=V.nativeSourceCalls
 for i=1,10 do
  V.clock=V.clock+10
  p.inventory.nativeItems[#p.inventory.nativeItems+1]=V.item("Wood")
  p.inventory:setDrawDirty(true);ISInventoryPage.dirtyUI();p:renderdetails(false)
 end
 V.eq(V.nativeSourceCalls,baseline,"automatic rebuilds coalesced within interval")
 V.clock=V.clock+181;V.emit("OnPlayerUpdate",V.player)
 V.check(V.nativeSourceCalls>baseline,"deadline refresh executes actual source")
 local wood=p.itemindex.Wood
 V.eq(wood.realCount,11,"all transferred items reflected")
end)
V.case("barrier keeps raw nil search fields and adds no refresh",function()
 local p=V.nativePane({V.item("Wood"),V.item("Apple")})
 p.searchText=nil;p.searchCategoryText=nil;p.searchMode=nil
 p:refreshContainer();p:renderdetails(false)
 V.deferNative(p,V.item("Copper"))
 local count=V.nativeSourceCalls
 local barriers=CodexInventoryTransferPerformance.stats.priorityBarriers
 p:onKeyRelease(0)
 V.eq(V.nativeSourceCalls-count,1,"one real refresh, public barrier reuses it")
 V.eq(CodexInventoryTransferPerformance.stats.priorityBarriers-barriers,1,"public native barrier executed")
 V.eq(rawget(p,"refreshContainer"),nil,"instance shim removed")
 V.eq(p.searchText,nil,"name nil preserved")
 V.eq(p.searchCategoryText,nil,"category nil preserved")
 V.eq(p.searchMode,nil,"mode nil preserved")
 V.assertRowsMatchRender(p)
end)
V.case("barrier restores existing instance method and raw search text",function()
 local p=V.nativePane({V.item("Wood"),V.item("苹果")})
 local base=ISInventoryPane.refreshContainer
 local custom=function(self,...)return base(self,...)end
 rawset(p,"refreshContainer",custom)
 p.searchText="  PING  ";p.searchCategoryText=" Material ";p.searchMode="both"
 p:refreshContainer();p:renderdetails(false)
 V.deferNative(p,V.item("Copper"))
 local count=V.nativeSourceCalls;p:onKeyRelease(0)
 V.eq(V.nativeSourceCalls-count,1,"custom instance method does not cause duplicate rebuild")
 V.eq(rawget(p,"refreshContainer"),custom,"existing raw method restored exactly")
 V.eq(p.searchText,"  PING  ","raw name query preserved")
 V.eq(p.searchCategoryText," Material ","raw category query preserved")
 V.eq(p.searchMode,"both","both mode preserved")
 V.assertRowsMatchRender(p)
end)
V.case("Neat full and filtered lists settle before any later renderer",function()
 local shirt=V.item("Shirt");V.player.primary=shirt
 local p=V.nativePane({shirt,V.item("Wood"),V.item("Apple"),V.item("Zinc")},true)
 NEQ_State.hideEquipped=true;p.searchText="wood";p.searchCategoryText="";p.searchMode="name"
 p:refreshContainer();p:renderdetails(false)
 local chosen
 for row,g in ipairs(p.items)do if g.name=="Wood" then p.selected={[row]=g};p.firstSelect=row;chosen=g end end
 V.check(chosen~=nil,"visible selection seeded")
 V.deferNative(p,V.item("Copper"))
 local count=V.nativeSourceCalls
 local barriers=CodexInventoryTransferPerformance.stats.priorityBarriers
 p:onKeyRelease(0)
 V.eq(V.nativeSourceCalls-count,1,"dual-view barrier does not repeat actual refresh")
 V.eq(CodexInventoryTransferPerformance.stats.priorityBarriers-barriers,2,"both Neat arrays reconciled")
 V.eq(p.itemslist,p.neqFullItemList,"full array pointer restored")
 local full=V.copyList(p.itemslist);local filtered=V.copyList(p.neqFilteredItemList)
 V.eq(p.items[p.firstSelect].name,"Wood","filtered anchor restored")
 V.eq(p.selected[p.firstSelect].name,"Wood","filtered selection restored")
 V.assertRowsMatchRender(p)
 V.assertListSame(full,p.itemslist,"full array remains settled after filtered render")
 V.assertListSame(filtered,p.neqFilteredItemList,"filtered array remains settled")
 NEQ_State.hideEquipped=false
 -- Disabling the eye normally rebuilds once; inspect the already settled full
 -- array by directly invoking the saved actual renderer without that toggle path.
 p.neqHiding=false
 local before=V.nativeSourceCalls;V.nativeRender(p,false)
 V.eq(V.nativeSourceCalls,before,"full render reuses already refreshed data")
 V.assertListSame(full,p.itemslist,"full render does not change row ordering")
 V.eq(rawget(p,"refreshContainer"),nil,"dual-view shim removed")
 V.player.primary=nil
end)
V.case("category-only search keeps hits order selection and raw nil name",function()
 local p=V.nativePane({V.item("Apple","Food"),V.item("Bandage","FirstAid"),V.item("Zinc","Material")})
 p:searchContainer(nil,"food","category");p:renderdetails(false)
 V.eq(p.searchText,nil,"category mode begins with nil name query")
 p.selected={[1]=p.items[1]};p.firstSelect=1
 V.eq(p.items[1].name,"Apple","initial category match selected")
 V.deferNative(p,V.item("Aardvark","Food"))
 local count=V.nativeSourceCalls
 local barriers=CodexInventoryTransferPerformance.stats.priorityBarriers
 p:onKeyRelease(0)
 V.eq(V.nativeSourceCalls-count,1,"category barrier adds no actual rebuild")
 V.eq(CodexInventoryTransferPerformance.stats.priorityBarriers-barriers,1,"category barrier used")
 V.eq(p.searchText,nil,"category mode nil name query retained")
 V.eq(p.searchCategoryText,"food","category query retained")
 V.eq(p.searchMode,"category","category mode retained")
 local expected={"Aardvark","Apple","Bandage","Zinc"}
 for row,name in ipairs(expected)do
  V.eq(p.itemslist[row].name,name,"category match priority final row "..row)
  V.eq(p.itemslist[row].matchesSearch,row<=2,"category-only hit flag "..row)
 end
 V.eq(p.firstSelect,2,"category insertion moves anchor to same group")
 V.eq(p.items[p.firstSelect].name,"Apple","category anchor points to original group")
 V.eq(p.selected[2].name,"Apple","category selection follows final row")
 V.assertRowsMatchRender(p)
 V.eq(p.firstSelect,2,"category renderer keeps anchor")
 V.eq(rawget(p,"refreshContainer"),nil,"category shim removed")
end)
V.case("both search requires name and category and keeps final anchor",function()
 local p=V.nativePane({V.item("Apple","Food"),V.item("AppleTool","Tools"),V.item("Berry","Food"),V.item("Zinc","Material")})
 p:searchContainer("app","food","both");p:renderdetails(false)
 p.selected={[1]=p.items[1]};p.firstSelect=1
 V.eq(p.items[1].name,"Apple","initial combined match selected")
 V.deferNative(p,V.item("Appetizer","Food"))
 local count=V.nativeSourceCalls
 local barriers=CodexInventoryTransferPerformance.stats.priorityBarriers
 p:onKeyRelease(0)
 V.eq(V.nativeSourceCalls-count,1,"both barrier adds no actual rebuild")
 V.eq(CodexInventoryTransferPerformance.stats.priorityBarriers-barriers,1,"both barrier used")
 V.eq(p.searchText,"app","both name query retained")
 V.eq(p.searchCategoryText,"food","both category query retained")
 V.eq(p.searchMode,"both","both mode retained")
 local expected={"Appetizer","Apple","AppleTool","Berry","Zinc"}
 for row,name in ipairs(expected)do
  V.eq(p.itemslist[row].name,name,"combined match priority final row "..row)
  V.eq(p.itemslist[row].matchesSearch,row<=2,"both constraints hit flag "..row)
 end
 V.eq(p.firstSelect,2,"combined insertion moves anchor to same group")
 V.eq(p.items[p.firstSelect].name,"Apple","combined anchor points to original group")
 V.eq(p.selected[2].name,"Apple","combined selection follows final row")
 V.assertRowsMatchRender(p)
 V.eq(p.firstSelect,2,"combined renderer keeps anchor")
 V.eq(rawget(p,"refreshContainer"),nil,"combined shim removed")
end)
V.case("raw uppercase external search keeps ordinary native matching semantics",function()
 local control=V.nativePane({V.item("Apple"),V.item("Copper"),V.item("Wood"),V.item("Zinc")})
 control.searchText="WOOD";control.searchCategoryText=nil;control.searchMode="name"
 control:refreshContainer();control:renderdetails(false)
 local expected={};local expectedFlags={};local expectedAnchor
 for row,group in ipairs(control.itemslist)do
  expected[row]=group.name
  expectedFlags[group.name]=group.matchesSearch
  if group.name=="Wood" then expectedAnchor=row end
 end
 local p=V.nativePane({V.item("Apple"),V.item("Wood"),V.item("Zinc")})
 -- External mods may assign these fields without calling searchContainer.
 -- Ordinary CleanUI refresh/render compares the raw uppercase needle with
 -- lowercase names; the compatibility barrier must preserve that behavior.
 p.searchText="WOOD";p.searchCategoryText=nil;p.searchMode="name"
 p:refreshContainer();p:renderdetails(false)
 for _,group in ipairs(p.itemslist)do V.eq(group.matchesSearch,expectedFlags[group.name],"ordinary current matching control")end
 V.eq(p.itemslist[1].name,"Wood","ordinary Pinyin decoration order remains after native resets hit flags")
 for row,group in ipairs(p.items)do if group.name=="Wood" then p.selected={[row]=group};p.firstSelect=row end end
 V.deferNative(p,V.item("Copper"))
 local count=V.nativeSourceCalls
 local barriers=CodexInventoryTransferPerformance.stats.priorityBarriers
 p:onKeyRelease(0)
 V.eq(V.nativeSourceCalls-count,1,"raw uppercase barrier adds no actual rebuild")
 V.eq(CodexInventoryTransferPerformance.stats.priorityBarriers-barriers,1,"raw uppercase barrier used")
 V.eq(p.searchText,"WOOD","raw uppercase query retained")
 V.eq(p.searchCategoryText,nil,"raw uppercase nil category retained")
 V.eq(p.searchMode,"name","raw uppercase mode retained")
 for row,name in ipairs(expected)do
  V.eq(p.itemslist[row].name,name,"raw uppercase ordinary order retained "..row)
  V.eq(p.itemslist[row].matchesSearch,expectedFlags[name],"barrier preserves current matching semantics "..row)
 end
 V.eq(p.firstSelect,expectedAnchor,"raw uppercase anchor equals ordinary final group position")
 V.eq(p.selected[p.firstSelect].name,"Wood","raw uppercase selected group retained")
 V.assertRowsMatchRender(p)
 for _,group in ipairs(p.itemslist)do V.eq(group.matchesSearch,expectedFlags[group.name],"next native renderer keeps control matching")end
 V.eq(rawget(p,"refreshContainer"),nil,"raw uppercase shim removed")
end)
V.case("2.10.3 viewport culling preserves full hit map after flush",function()
 for _,scroll in ipairs({0,-24,-120,-100000}) do
  local items={};for i=1,12 do items[#items+1]=V.item("Item"..i) end
  for i=1,8 do items[#items+1]=V.item("Stack") end
  local p=V.nativePane(items);p.height=55;p.getYScroll=function()return scroll end
  p.collapsed.Stack=false;p:refreshContainer();V.nativeRender(p,false)
  V.check(#p.items>12,"renderer maintains off-screen rows")
  local target=p.items[7];p.selected={[7]=target};p.firstSelect=7
  V.deferNative(p,V.item("Another"));p:onKeyRelease(0)
  V.check(p.items[p.firstSelect]~=nil,"selected anchor remains mapped")
  V.eq(p.items[p.firstSelect].name,target.name,"selected anchor identity preserved")
  V.assertRowsMatchRender(p)
 end
end)
V.case("native barrier failure restores shim query and full-list pointer",function()
 local p=V.nativePane({V.item("Wood"),V.item("Apple")})
 p.searchText="  wood ";p.searchCategoryText=nil;p.searchMode="name"
 p:refreshContainer();p:renderdetails(false)
 V.deferNative(p,V.item("Copper"))
 V.failNativeSearch=true
 local ok,err=pcall(p.onKeyRelease,p,0)
 V.failNativeSearch=false
 V.eq(ok,false,"input aborts on native barrier failure")
 V.check(string.find(tostring(err),"injected native search barrier failure",1,true)~=nil,"original native barrier exception propagates unchanged")
 V.eq(p.inputRows,nil,"ambiguous row map never reaches native input callback")
 V.eq(CodexInventoryTransferPerformance.enabled,false,"optimization disabled after barrier failure")
 V.eq(rawget(p,"refreshContainer"),nil,"error path shim removed")
 V.eq(p.searchText,"  wood ","error path raw name retained")
 V.eq(p.searchCategoryText,nil,"error path nil category retained")
 V.eq(p.searchMode,"name","error path search mode retained")
 V.check(p.itemslist~=nil,"error path full row list retained")
 V.eq(p.inventory:isDrawDirty(),true,"error path requests native redraw")
end)
return "native integration passed; cases="..V.cases.."; assertions="..V.assertions
