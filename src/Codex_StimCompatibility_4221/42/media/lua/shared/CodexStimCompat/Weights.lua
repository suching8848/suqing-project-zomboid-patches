-- Exact script definitions only; no world traversal or save mutation.
if isServer() then return end
local ids={"SJ6","Propital","Zagustin","MULE","Adrenaline","SJ12", "Morphine","XTG12","Trimadol","Meldonin","AHF1M","ETGc","Obdolbos","EmptyInjector","AdrenalineShot.AdrenalineShot"}
local function apply()
    local sm=type(getScriptManager)=="function" and getScriptManager()
    if not sm then print("[CodexStimCompat] script manager unavailable");return false end
    local targets={}
    for _,name in ipairs(ids) do
        local id=name=="AdrenalineShot.AdrenalineShot" and name or "CombatStims."..name
        local item=sm:getItem(id)
        local ok,old=pcall(function() return item and item:getActualWeight() end)
        local original=name=="EmptyInjector" and 0.3 or (name=="AdrenalineShot.AdrenalineShot" and 0.03 or 0.5)
        local desired=name=="EmptyInjector" and 0.03 or 0.05
        if not item or not ok or type(old)~="number" or (math.abs(old-original)>0.0001 and math.abs(old-desired)>0.0001) then
            print("[CodexStimCompat] unexpected item/weight; no weight changes: "..id);return false
        end
        targets[#targets+1]={item=item,old=old,value=desired}
    end
    local ok,err=pcall(function()
        for _,v in ipairs(targets) do
            v.item:setActualWeight(v.value)
            if math.abs(v.item:getActualWeight()-v.value)>0.0001 then error("setter verification") end
        end
    end)
    if not ok then
        for _,v in ipairs(targets) do pcall(function() v.item:setActualWeight(v.old) end) end
        print("[CodexStimCompat] weight initialization failed; rollback attempted: "..tostring(err));return false
    end
    print("[CodexStimCompat] 14 filled stims=0.05; empty injector=0.03")
    return true
end
Events.OnGameBoot.Add(apply)
