if isClient() or isServer() then return end
local A = {ready=false}
local wanted = {"ATA2.ATAMustangHood2Item3", "ATA2.ATAMustangHood3Item3", "ATA2.ATAMustangHood4Item3"}
local function copy(list)
    local t={}; for i=0,list:size()-1 do t[#t+1]=list:get(i) end; return t
end
local function replace(list, values)
    list:clear(); for _,v in ipairs(values) do list:add(v) end
end
function A.install()
    if A.ready then return true end
    local sm=getScriptManager()
    local recipe=sm and sm:getCraftRecipe("ATA2.ATAMustangHoodItem")
    if not recipe or not recipe:getInputs() or recipe:getInputs():size() ~= 3 then
        print("[MustangRecipeGuard] WARNING: recipe missing or changed; guard not installed"); return false
    end
    local input=recipe:getInputs():get(0)
    local line=input and input:getOriginalLine()
    if not line or not string.find(string.gsub(line,"%s+",""), "item1tags[ATA_Mustang_Hood]",1,true) then
        print("[MustangRecipeGuard] WARNING: recipe input changed; guard not installed"); return false
    end
    local ids,cache=input:getItems(),input:getPossibleInputItems()
    if not ids or not cache then print("[MustangRecipeGuard] WARNING: input cache unavailable"); return false end
    local scripts={}
    for _,id in ipairs(wanted) do
        local script=sm:getItem(id)
        if not script or script:getFullName() ~= id then
            print("[MustangRecipeGuard] WARNING: intended item missing: "..id); return false
        end
        scripts[#scripts+1]=script
    end
    local oldIds,oldCache=copy(ids),copy(cache)
    local ok,err=pcall(function() replace(ids,wanted); replace(cache,scripts) end)
    if not ok then
        pcall(replace,ids,oldIds); pcall(replace,cache,oldCache)
        print("[MustangRecipeGuard] WARNING: cache update failed: "..tostring(err));return false
    end
    A.ready=true
    print("[MustangRecipeGuard] Restricted hood input to 3 intended items")
    return true
end
Events.OnGameStart.Add(A.install)
Events.OnMainMenuEnter.Add(function() A.ready=false end)
CodexMustangRecipeGuard=A
