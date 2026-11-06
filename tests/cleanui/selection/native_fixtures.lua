local V=PerfTest
V.nativeRefresh=ISInventoryPane.refreshContainer
V.nativeRender=ISInventoryPane.renderdetails
V.nativeSearch=ISInventoryPane.searchContainer
ISInventoryPane.searchContainer=function(self,...)
 local result=V.nativeSearch(self,...)
 if V.failNativeSearch then error("injected native search barrier failure")end
 return result
end
ISInventoryPane.updateScrollbars=function()end
ISInventoryPane.updateWorldObjectHighlight=function()end
ISInventoryPane.onMouseMove=function(self)self.pointerRows=self.items end
ISInventoryPane.onKeyRelease=function(self)
 self.inputRows={};for i,v in ipairs(self.items or {})do self.inputRows[i]=v end
 self.inputAnchor=self.firstSelect
end
ISInventoryPane.refreshContainer=function(self,...)
 V.nativeSourceCalls=V.nativeSourceCalls+1
 return V.nativeRefresh(self,...)
end
function V.item(name,category)
 local item={kind="InventoryItem",isNativeItem=true,name=name,category=category or "Material",ageCalls=0}
 function item:isUnwanted()return false end
 function item:getJobDelta()return 0 end
 function item:getItemHeat()return 1 end
 function item:getTex()return nil end
 function item:isFavorite()return false end
 function item:getName()return self.name end
 function item:getDisplayName()return self.name end
 function item:getType()return self.name end
 function item:getFullType()return "Base."..self.name end
 function item:getDisplayCategory()return self.category end
 function item:getCategory()return self.category end
 function item:isHidden()return false end
 function item:IsFood()return false end
 function item:isItemType(t)return self.itemType==t end
 function item:hasTag()return false end
 function item:updateAge()self.ageCalls=self.ageCalls+1 end
 function item:getEquippedWeight()return 0 end
 return item
end
function V.nativeContainer(items)
 local c=V.container(#(items or {}));c.nativeItems=items or {}
 function c:getItems()return V.list(self.nativeItems)end
 function c:contains(item)for _,v in ipairs(self.nativeItems)do if v==item then return true end end return false end
 return c
end
function V.nativePane(items,onCharacter)
 V.leftPage=nil;V.rightPage=nil
 local c=V.nativeContainer(items)
 if onCharacter then V.player.inventory=c end
 local p=V.pane(c,onCharacter)
 p.width=600;p.height=400;p.itemHgt=20;p.headerHgt=0;p.fontHgt=14;p.font=UIFont.Small;p.zoom=1
 p.column2=40;p.column3=320;p.padding=4;p._cleanUIWeightCollapsed=true
 p.itemSortFunc=function(a,b)return a.name<b.name end
 V.clock=V.clock+500
 p:updateScrollbars();p.parent:refreshBackpacks();p:renderdetails(false)
 return p
end
function V.rowName(v)return v and (v.name or v:getName())end
function V.copyList(values)local copy={};for i,v in ipairs(values or {})do copy[i]=v end;return copy end
function V.assertListSame(expected,actual,label)
 V.eq(#actual,#expected,label.." count")
 for i,v in ipairs(expected)do V.eq(actual[i],v,label.." row "..i)end
end
function V.assertRowsMatchRender(p)
 local old={};for i,v in ipairs(p.items)do old[i]=v end
 p:renderdetails(false)
 V.eq(#old,#p.items,"input row count equals renderer")
 for i,v in ipairs(old)do V.eq(v,p.items[i],"input row identity equals renderer "..i)end
end
function V.deferNative(p,newItem)
 V.noAction();V.mouseDown=nil;V.ctrl=false;V.shift=false;p.hovered=false;V.player.moving=false
 V.transfer(p)
 if newItem then p.inventory.nativeItems[#p.inventory.nativeItems+1]=newItem;p.inventory.count=#p.inventory.nativeItems end
 p.inventory:setDrawDirty(true)
 ISInventoryPage.dirtyUI()
 p:renderdetails(false)
end
return "native inventory fixtures ready"
