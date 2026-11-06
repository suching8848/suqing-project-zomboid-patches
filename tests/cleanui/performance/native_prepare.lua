-- Controlled Java/UI boundaries; actual CleanUI/Pinyin/Neat Lua is loaded intact.
local V=PerfTest
V.activeMods={"NeatUI_Equipment"}
V.modVersions={CleanUI="2.10.4",NeatUI_Equipment="1.0.2"}
V.nativeSourceCalls=0
UIFont={Small="Small",Medium="Medium",Large="Large"}
local font={getLineHeight=function()return 14 end}
function getTextManager()return {getFontHeight=function()return 14 end,getFontFromEnum=function()return font end,MeasureStringX=function(_,_,s)return #tostring(s)*7 end}end
function getCore()return {getGameMode=function()return "Sandbox" end,getGoodHighlitedColor=function()return {r=0,g=1,b=0,a=1}end,getOptionInventoryFont=function()return "Small" end}end
function getText(key)return key end
function getTexture()return nil end
function getPlayerHotbar()return nil end
function getMouseX()return 0 end
function getMouseY()return 0 end
function round(n,p)local scale=10^(p or 0);return math.floor(n*scale+0.5)/scale end
function CleanUI_shouldShowWeightColumn()return false end
function CleanUI_shouldShowColumnHeaders()return false end
function CleanUI_getInventoryTitleBarPosition()return V.titlePosition or "top" end
Translator={getLanguage=function()return {name=function()return "CN" end}end}
ItemType={KEY_RING="KEY_RING"};ItemTag={KEY_RING="KEY_RING"}
ISHandCraftPanel={};ISBuildPanel={}
ISPanel={}
function ISPanel:derive(name)local class={Type=name};setmetatable(class,{__index=self});class.__index=class;return class end
local noop=function()end
for _,name in ipairs({"drawRect","drawRectStatic","drawRectBorder","drawText","drawTextRight","drawTexture","drawTextureScaled","drawTextureScaledAspect","suspendStencil","resumeStencil","setScrollHeight","setScrollWidth"})do ISPanel[name]=noop end
function ISPanel:getWidth()return self.width end
function ISPanel:getHeight()return self.height end
function ISPanel:getMouseX()return -100 end
function ISPanel:getMouseY()return -100 end
function ISPanel:getYScroll()return -100000 end
function ISPanel:isVScrollBarVisible()return false end
function ISPanel:isMouseOver()return self.hovered==true end
function ISPanel:isVisible()return self.visible~=false end
function ISPanel:isReallyVisible()return self.visible~=false end
function ISPanel:setVisible(value)self.visible=value end
function require(name)
 if name=="pinyin" then return function(s)return (s:gsub("苹果","ping-guo"):gsub("木头","mu-tou"))end end
 if name=="NeatEquipment/NEQ_State" then return NEQ_State end
 if name=="NeatEquipment/ModCompatibility/NEQ_InventoryTetris" then return NEQ_InventoryTetris end
 return true
end
function V.player:isLocalPlayer()return true end
function V.player:getWornItems()return V.list(self.worn or {})end
function V.player:getPrimaryHandItem()return self.primary end
function V.player:getSecondaryHandItem()return self.secondary end
function V.player:isRecipeActuallyKnown()return false end
function instanceof(value,name)
 return type(value)=="table" and (value.kind==name or (name=="InventoryItem" and value.isNativeItem==true))
end
return "native Java/UI boundary fixtures ready"
