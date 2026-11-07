-- Offline Java-object/UI fixtures. Actual upstream Lua is loaded unmodified.
LuckyTest = {cases=0, assertions=0, names={}, modVersion="2.10.4", gameVersion="42.21.0"}
local T=LuckyTest
function T.check(ok, message) T.assertions=T.assertions+1; assert(ok,message or "check failed") end
function T.eq(a,b,message) T.check(a==b,(message or "equal").." got="..tostring(a).." expected="..tostring(b)) end
function T.case(name,fn) fn(); T.cases=T.cases+1; T.names[#T.names+1]=name;print("PASS "..name) end
function T.list(items)
 local x={values=items or {}}
 function x:size()return #self.values end
 function x:get(i)return self.values[i+1] end
 function x:isEmpty()return #self.values==0 end
 return x
end
function require()return true end
function isServer()return false end
function isClient()return false end
function isDebugEnabled()return false end
function isAdmin()return false end
function getCore()return {
 getGameMode=function()return "Sandbox" end,
 getGoodHighlitedColor=function()return {r=0,g=1,b=0,a=1} end,
 getVersionNumber=function()return T.gameVersion end,
 getOptionInventoryFont=function()return "Small" end,
}end
function getModInfoByID(id)
 if T.missingMetadata then return nil end
 return {
  getModVersion=function()return T.modVersion end,
  getVersionDir=function()return T.cleanDir end,
 }
end
function getFilenameOfClosure(fn)
 local info=T.metadata and T.metadata[fn]
 if info then return T.sourceMismatch and "OtherMod/foreign.lua" or info.source end
 return "fixture/unknown.lua"
end
function getFirstLineOfClosure(fn)
 local info=T.metadata and T.metadata[fn]
 return info and (T.lineMismatch and info.line+1 or info.line) or -1
end
Events={OnGameStart={handlers={}}}
function Events.OnGameStart.Add(fn)table.insert(Events.OnGameStart.handlers,fn)end
function T.start()for _,fn in ipairs(Events.OnGameStart.handlers)do fn()end end
UIFont={Small="Small",Medium="Medium",Large="Large"}
function getTextManager()return {getFontHeight=function()return 14 end}end
function getText(key)return key end
function getTexture()return nil end
function table.wipe(t)for k in pairs(t)do t[k]=nil end end
ISPanel={}
function ISPanel:derive(name)local t={Type=name};t.__index=t;return t end
ISToolTip=ISPanel
ISInventoryPaneContextMenu={}
ItemType=setmetatable({},{__index=function(_,k)return k end})
ItemTag=setmetatable({},{__index=function(_,k)return k end})
ComponentType=setmetatable({},{__index=function(_,k)return k end})
function instanceof(v,name)
 return type(v)=="table" and (v.kind==name or name=="InventoryItem" and v.nativeItem==true)
end
function getPlayerHotbar()return nil end
function getCell()return {setDrag=function()end}end
UIManager={getSpeedControls=function()return {getCurrentGameSpeed=function()return 1 end}end}
function triggerEvent()end
CraftRecipeManager={getUniqueRecipeItems=function()return nil end}
RecipeManager={getEvolvedRecipe=function()return nil end}
function getPlayerLoot()return {inventory=nil}end
function getPlayerInventory()return {}end
function isForceDropHeavyItem()return false end
function getGameSpeed()return 1 end
function getNumActivePlayers()return 1 end
function getSpecificPlayer()return T.player end
local nilFn=function()return nil end
local falseFn=function()return false end
local script={isCantEat=falseFn,getOpeningRecipe=nilFn,hasResearchableRecipes=falseFn,isItemType=falseFn,getUsedInRecipes=function()return T.list()end}
local inv={getItems=function()return T.list()end,containsTagRecurse=falseFn,isInCharacterInventory=function()return true end}
T.player=setmetatable({getInventory=function()return inv end,getVehicle=nilFn,getJoypadBind=function()return -1 end},{__index=function()return falseFn end})
function T.item(kind,id)
 local item={kind=kind,nativeItem=true,id=id or(kind=="Food" and "MR.lucky_strike" or "MR.lucky_strike_Pack")}
 function item:getFullType()return self.id end
 function item:getCategory()return self.kind=="Food" and "Food" or "Drainable" end
 function item:getCustomMenuOption()return "Smoke" end
 function item:getScriptItem()return script end
 function item:getType()return self.id end
 function item:getName()return "好彩香烟" end
 function item:hasTag(tag)return tag==ItemTag.CONSUMABLE and self.kind=="DrainableComboItem" end
 function item:isNoRecipes()return true end
 function item:getModData()return {}end
 function item:getCondition()return 1 end
 function item:getConditionMax()return 1 end
 function item:getMaxAmmo()return 0 end
 function item:getContainer()return inv end
 if kind=="Food" then
  function item:getHungChange()T.hungerCalls=(T.hungerCalls or 0)+1;return 0 end
  function item:getOpeningRecipe()return nil end
 end
 return setmetatable(item,{__index=function(_,name)
  -- Do not manufacture the missing Food method: this is the reported failure.
  if name=="getHungChange" then return nil end
  if name=="getClothingItemExtraOption" or name=="getAnimalTracks" or name=="getMediaData" or name=="getFluidContainer" or name=="getWorldItem" or name=="getCanBeEquippedOther" or name=="canBeEquipped" then return nilFn end
  return falseFn
 end})
end
function T.group(items,optimized,header)
 local members={}
 if not optimized then members[1]=header or items[1] end
 for _,v in ipairs(items)do members[#members+1]=v end
 return {name="好彩香烟",items=members,cleanUILargeStackOptimized=optimized}
end
function T.context()
 local c={options={}}
 function c:addOption(name,target,fn,...)
  local o={name=name,target=target,callback=fn,args={...}};self.options[#self.options+1]=o;return o
 end
 function c:getNew()return T.context()end
 function c:addSubMenu()end
 function c:setVisible(value)self.visible=value end
 return c
end
ISContextMenu={get=function()T.contextCreated=(T.contextCreated or 0)+1;T.lastContext=T.context();return T.lastContext end}
