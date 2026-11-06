local count=0
local function check(value,label) count=count+1;assert(value,label) end
local ids={'Base.BoteBR_ConstruirBote','Base.BoteBR_ConstruirTrawler','Base.BoteBR_ConstruirMetal'}
local recipes,mode
local function list(values)
    local l={values=values or {}}
    function l:size() return #self.values end
    function l:get(i) return self.values[i+1] end
    function l:contains(v) for _,x in ipairs(self.values) do if x==v then return true end end;return false end
    function l:add(v) self.values[#self.values+1]=v end
    function l:remove(v) for i,x in ipairs(self.values) do if x==v then table.remove(self.values,i);return true end end;return false end
    return l
end
local function setup(which)
    mode=which;SuQingBoatCraftFromFloor=nil;recipes={};transfers=0
    Events={OnGameBoot={Add=function() end},OnGameStart={Add=function() end}}
    isClient=function() return mode=='mp' end;isServer=function() return false end
    getModFileReader=function(_,_,create)
        check(create==false,'file creation disabled')
        if mode=='missing_source' then return nil end
        local i=0
        return {readLine=function() i=i+1;if mode=='changed_source' and i==1 then return 'changed' end;return SOURCE_LINES[i] end,close=function() end}
    end
    for _,id in ipairs(ids) do
        local tags=list({'AnySurfaceCraft'})
        local r={inputs={},outputs={},skills={},weight=123,tags=tags}
        function r:getModID() return (mode=='foreign' and id==ids[2]) and 'OtherMod' or 'BoteBR' end
        function r:getModTags() return tags end
        function r:isAnySurfaceCraft() return tags:contains('AnySurfaceCraft') end
        function r:isCanBeDoneFromFloor() return tags:contains('CanBeDoneFromFloor') end
        recipes[id]=r
    end
    if mode=='missing_recipe' then recipes[ids[3]]=nil end
    if mode=='failed_readback' then recipes[ids[3]].isCanBeDoneFromFloor=function() return false end end
    getScriptManager=function() return {getCraftRecipe=function(_,id) return recipes[id] end} end
    LOAD_PATCH()
end
local function panel(recipe)
    local inv={};local ground={};local items=list({{getContainer=function() return ground end},{getContainer=function() return ground end}})
    local data={getAllInputItems=function() return items end,getAllPutBackInputItems=function() return list() end}
    local logic={getRecipe=function() return recipe end,getRecipeData=function() return data end,isCraftActionInProgress=function() return false end,isUsingRecipeAtHandBenefit=function() return false end,updateManualInputAllowedItemTypes=function() end}
    local p={logic=logic,player={getInventory=function() return inv end}}
    ISInventoryPaneContextMenu={transferIfNeeded=function() transfers=transfers+1 end}
    ISCraftingUI={ReturnItemsToOriginalContainer=function() end}
    ISEntityUI={HandcraftStartMultiple=function() return {} end};ISTimedActionQueue={add=function() end};DebugType={CraftLogic=0};log=function() end
    NC_VanillaInputTransfer.captureIterationInputs=function() return true end
    NC_VanillaInputTransfer.isDirectCraftEnabled=function() return false end
    return p
end

setup()
local r=recipes[ids[1]];local p=panel(r)
ISWidgetHandCraftControl.startHandcraft(p,false);check(transfers==2,'unpatched native function tries to carry all inputs')
transfers=0;NC_VanillaInputTransfer.queueCurrentInputsThenReady(p);check(transfers==2,'unpatched Neat function tries to carry all inputs')
local oldInputs,oldOutputs,oldSkills=r.inputs,r.outputs,r.skills
check(SuQingBoatCraftFromFloor.apply(),'patch applies to reviewed three recipes')
for _,id in ipairs(ids) do check(recipes[id]:isCanBeDoneFromFloor(),'target can use nearby inputs');check(recipes[id]:isAnySurfaceCraft(),'work surface retained') end
check(r.inputs==oldInputs and r.outputs==oldOutputs and r.skills==oldSkills and r.weight==123,'other recipe fields untouched')
for _,id in ipairs(ids) do
    transfers=0;p=panel(recipes[id]);ISWidgetHandCraftControl.startHandcraft(p,false);check(transfers==0,'native branch skips pretransfer')
    transfers=0;check(NC_VanillaInputTransfer.queueCurrentInputsThenReady(p),'Neat preparation succeeds');check(transfers==0,'Neat branch skips pretransfer')
end
check(SuQingBoatCraftFromFloor.apply(),'repeat event remains valid')
check(r.tags:size()==2,'flag never duplicated')
for _,failure in ipairs({'changed_source','missing_source','missing_recipe','foreign','failed_readback','mp'}) do
    setup(failure);check(not SuQingBoatCraftFromFloor.apply(),'unsafe contract rejected: '..failure)
    for _,id in ipairs(ids) do if recipes[id] then check(not recipes[id].tags:contains('CanBeDoneFromFloor'),'no partial changes left: '..failure) end end
end
setup();recipes[ids[1]].tags:add('CanBeDoneFromFloor');check(SuQingBoatCraftFromFloor.apply(),'preexisting flag accepted');check(recipes[ids[1]].tags:size()==2,'preexisting flag retained without duplication')
return 'PASS assertions='..count..'; actual native and Neat transfer functions, mock recipe objects; no game/save writes'
