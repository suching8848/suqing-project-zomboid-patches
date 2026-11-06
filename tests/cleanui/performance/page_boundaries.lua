local V=PerfTest
-- Real collapse, expand, reconcile, geometry and child-visibility functions stay intact.
for _,name in ipairs({"refreshBackpacks","dirtyUI","selectContainer","setVisible"})do
 ISInventoryPage[name]=V.mockPage[name]
end
ISInventoryPage.prerender=function(self)
 self:cleanUIReconcileCollapseGeometry()
 return V.mockPage.prerender(self)
end
local originalPane=V.pane
local function childMethods(o)
 function o:getY()return self.y or 0 end
 function o:getHeight()return self.height or 0 end
 function o:getIsVisible()return self.visible~=false end
 function o:setVisible(v)self.visible=v end
 function o:setY(v)self.y=v end
 function o:setHeight(v)self.height=v end
 return o
end
V.pane=function(...)
 local p=originalPane(...)
 childMethods(p)
 local page=p.parent
 page.x,page.y,page.width,page.height=20,100,600,317.4
 page.titleFontHgt,page.titleButtonSize,page.padding=14,16,4
 page._cleanUITitleBarPosition="bottom"
 page.updateCleanUITransferButtonLayout=false
 page.controlsUI=childMethods({visible=true,height=30})
 page.containerButtonPanel=childMethods({visible=false})
 function page:getHeight()return self.height end
 function page:setHeight(v)self.height=v end
 function page:getY()return self.y end
 function page:setY(v)self.y=v end
 function page:setMaxDrawHeight(v)self.maxDrawHeight=v end
 function page:clearMaxDrawHeight()self.maxDrawHeight=nil end
 return p
end
return "page Java/UI boundaries ready; real Bottom geometry retained"
