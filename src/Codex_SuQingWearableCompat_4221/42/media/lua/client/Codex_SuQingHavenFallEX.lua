-- Narrow bridge for HavenFall's native 60/80/100/120 capacity bags and EX rc.2.
-- Never changes an item definition, native fluid component, or physical capacity.
if isServer() then return end
require "ExSuQingBackpackSuperUpgrade/Core"
require "ExSuQingBackpackSuperUpgrade/Capacity"
local X = ExSuQingBackpackSuperUpgrade
local B = { enabled=false, baseline={}, bridge=nil, oldModes={} }
local function log(s) print("[SuQingHavenFallEX] " .. tostring(s)) end
if not X or X.version ~= "1.0.0-rc.2" or not X.Capacity then
    log("unsupported EX version; no compatibility installed"); return
end
local C = X.Capacity
local originals = {"EsBackpack", "SeanBackpack", "SeanragBackpack", "ZhiziBackpack", "GugaBackpack"}
local suffix = {"", "_T1", "_T2", "_T3"}
local capacity = {60, 80, 100, 120}
for _, name in ipairs(originals) do
    for i, ext in ipairs(suffix) do B.baseline["ESHF." .. name .. ext] = capacity[i] end
end
local function authorBase(id)
    if not B.baseline[id] or type(ESHF_getEffectiveCapacity) ~= "function" then return nil end
    local name = string.match(id, "^ESHF%.(.+)$")
    local probe = {getType=function() return name end}
    local ok, value = pcall(function()
        local fn = ESHF_getEffectiveCapacity(function() return nil end)
        return fn(probe, nil)
    end)
    if ok and value == B.baseline[id] then return value end
    return nil
end
local priorBase, priorValid, priorCanUpgrade = X.GetNativeBase, X.IsValidRecord, X.CanUpgrade
X.CanUpgrade = function(item, ...)
    local id = item and item.getFullType and item:getFullType()
    if id and B.baseline[id] and (not B.enabled or not B.craftGuard
        or not ISHandcraftAction or ISHandcraftAction.performRecipe ~= B.craftGuard) then
        return false, "havenfall_native_conversion_guard_not_ready"
    end
    return priorCanUpgrade(item, ...)
end
X.GetNativeBase = function(item, ...)
    local id = item and item.getFullType and item:getFullType()
    if id and B.baseline[id] then
        if not B.enabled or not X.IsSupported(item) then return nil, "havenfall_not_ready" end
        local value=authorBase(id)
        if not value then return nil, "havenfall_native_capacity_changed" end
        return value
    end
    return priorBase(item, ...)
end
X.IsValidRecord = function(record, item, ...)
    local id = item and item.getFullType and item:getFullType()
    local rid = type(record)=="table" and record.fullType or nil
    if (id and B.baseline[id]) or (rid and B.baseline[rid]) then
        if not rid or not B.baseline[rid] or (id and id ~= rid)
            or record.nativeBase ~= B.baseline[rid] or record.targetCapacity ~= B.baseline[rid]*2 then return false end
    end
    return priorValid(record, item, ...)
end
local function indexTable()
    local meta=__classmetatables and ItemContainer and __classmetatables[ItemContainer.class]
    return meta and meta.__index
end
-- Preserve the existing MaoMao bridge's hook identity contract while allowing
-- a verified outer layer after HavenFall and repeated startup callbacks.
local previousReady=C.IsReady
local previousCompat=CodexNekomataEXCompat_4221
local readyHook=function(...)
    if previousReady(...) then return true end
    local index=indexTable(); local layer=B.bridge
    return B.enabled and X.IsSinglePlayer() and layer and index
        and index.getEffectiveCapacity==layer.effective and index.hasRoomFor==layer.room
        and C.installedEffective and C.installedRoom and C.installedTransfer
        and javaTransferItems==C.installedTransfer or false
end
C.IsReady=readyHook
if previousCompat and previousCompat.hookedCapacity==C and previousCompat.readyHook==previousReady then
    previousCompat.readyHook=readyHook
end
local function owned(container)
    local item=container and container.getContainingItem and container:getContainingItem()
    return item and X.IsSupported(item) and X.IsValidRecord(X.GetRecord(item),item)
end
local function installBridge()
    if not B.enabled or not X.IsSinglePlayer() then return false end
    local index=indexTable()
    if not index or not C.installedEffective or not C.installedRoom or not C.installedTransfer
        or javaTransferItems~=C.installedTransfer then return false end
    if B.bridge and index.getEffectiveCapacity==B.bridge.effective and index.hasRoomFor==B.bridge.room then return true end
    local oldEffective, oldRoom=index.getEffectiveCapacity,index.hasRoomFor
    if type(oldEffective)~="function" or type(oldRoom)~="function" then return false end
    -- MaoMao's author retries installation on every clothing change. If its
    -- audited EX bridge exists, synchronize its own idempotence record before
    -- exposing this layer; otherwise each clothing event would stack wrappers.
    local w=rawget(index, "__maomao_backpack_capacity_wrappers_v1")
    local nekoPatch
    if w then
        nekoPatch=rawget(w, "__codex_nekomata_ex_room_forward_v1")
        local s=CodexNekomataEXCompat_4221
        local direct=w.sourceGetEffectiveCapacity==C.installedEffective
            and w.sourceHasRoomFor==C.installedRoom
        local normal=SuQingContainerUpgrade and SuQingContainerUpgrade.Dynamic
        local repeated=B.bridge and normal and normal.installedFunction
            and w.sourceGetEffectiveCapacity==normal.installedFunction
        if not s or type(nekoPatch)~="table" or nekoPatch.owner~=s
            or index.getCapacity~=w.getCapacity or not (direct or repeated)
            or nekoPatch.sourceRoom~=w.sourceHasRoomFor
            or nekoPatch.sourceEffective~=w.sourceGetEffectiveCapacity
            or nekoPatch.forwarded~=w.hasRoomFor
            or nekoPatch.forwardedEffective~=w.getEffectiveCapacity then
            log("unknown MaoMao wrapper chain; EX bridge refused"); return false
        end
    end
    local layer={}
    layer.effective=function(container, ...)
        if owned(container) then return C.installedEffective(container, ...) end
        return oldEffective(container, ...)
    end
    layer.room=function(container, ...)
        if owned(container) then return C.installedRoom(container, ...) end
        return oldRoom(container, ...)
    end
    if w then
        w.getEffectiveCapacity,w.hasRoomFor=layer.effective,layer.room
        nekoPatch.forwardedEffective,nekoPatch.forwarded=layer.effective,layer.room
    end
    index.getEffectiveCapacity,index.hasRoomFor=layer.effective,layer.room
    B.bridge=layer
    return true
end
local function copy(list)
    local t={}; for i=0,list:size()-1 do t[#t+1]=list:get(i) end; return t
end
local function restore(list, old)
    list:clear(); for _,value in ipairs(old) do list:add(value) end
end
local function contains(list, value)
    for i=0,list:size()-1 do if list:get(i)==value then return true end end
    return false
end
local function registerRecipes()
    if B.enabled then return true end
    local sm=type(getScriptManager)=="function" and getScriptManager()
    if not sm or not ItemType or not ItemType.CONTAINER or not X.IsSinglePlayer() then return false end
    local ids,scripts={},{}
    for id in pairs(B.baseline) do
        local script=sm:getItem(id)
        if not script or script:getFullName()~=id or not script:isItemType(ItemType.CONTAINER)
            or script:getObsolete() or script:isHidden() or not authorBase(id)
            or X.types[id]~=nil or X.supported[id]~=nil then
            log("source changed or missing: " .. id); return false
        end
        ids[#ids+1]=id; scripts[id]=script
    end
    table.sort(ids)
    local stages={}
    for _,name in ipairs({"ExSuQingSuperUpgrade","ExSuQingRestore"}) do
        local recipe=sm:getCraftRecipe("ExSuQingBackpackSuperUpgrade."..name)
        if not recipe or not recipe:getInputs() or recipe:getInputs():size()==0 then return false end
        local input=recipe:getInputs():get(0)
        if not input or not input:isKeep() or not input:isItemCount() then return false end
        local values, cache=input:getItems(),input:getPossibleInputItems()
        if not values or not cache then return false end
        for _,id in ipairs(ids) do if contains(values,id) or contains(cache,scripts[id]) then return false end end
        stages[#stages+1]={ids=values,cache=cache,oldIds=copy(values),oldCache=copy(cache)}
    end
    local ok,err=pcall(function()
        for _,stage in ipairs(stages) do for _,id in ipairs(ids) do stage.ids:add(id);stage.cache:add(scripts[id]) end end
        for _,id in ipairs(ids) do X.types[id]="codex_havenfall";X.supported[id]=true end
    end)
    if not ok then
        for _,stage in ipairs(stages) do pcall(restore,stage.ids,stage.oldIds);pcall(restore,stage.cache,stage.oldCache) end
        for _,id in ipairs(ids) do X.types[id]=nil;X.supported[id]=nil end
        log("recipe installation failed; rolled back: " .. tostring(err));return false
    end
    B.enabled=true;log("registered 20 native-capacity variants");return true
end
-- Guard the entire source recipe module rather than relying on a guessed
-- spaced recipe ID: B42.21's native parser can shorten those identifiers.
local function isHavenFallRecipe(name)
    return type(name)=="string" and string.sub(name,1,#"ESHFUpgrade.")=="ESHFUpgrade."
end
local function installConversionGuard()
    if B.craftGuard then return ISHandcraftAction and ISHandcraftAction.performRecipe == B.craftGuard end
    if not ISHandcraftAction or not ISHandcraftAction.performRecipe then return false end
    local old=ISHandcraftAction.performRecipe
    local guard=function(self, ...)
        local recipe=self.craftRecipe
        local name=recipe and recipe.getScriptObjectFullType and recipe:getScriptObjectFullType()
        if isHavenFallRecipe(name) then
            local ok,blocked=pcall(function()
                local data=self.logic and self.logic:getRecipeData()
                local items=data and data:getAllInputItems()
                if not items then return true end
                for i=0,items:size()-1 do
                    local item=items:get(i)
                    if item and item.getFullType and B.baseline[item:getFullType()] then
                        local md=item:getModData()
                        if not md or md[X.modDataKey]~=nil then return true end
                    end
                end
                return false
            end)
            if not ok or blocked then log("restore EX before native HavenFall upgrade");return end
        end
        return old(self, ...)
    end
    B.craftGuard=guard
    ISHandcraftAction.performRecipe=guard
    return true
end
function B.Install()
    if not installConversionGuard() then return false end
    if not registerRecipes() then return false end
    return installBridge()
end
Events.OnGameStart.Add(function()
    local ok,err=pcall(B.Install);if not ok then log("install error: "..tostring(err)) end
end)
Events.OnServerStarted.Add(function()
    local ok,err=pcall(B.Install);if not ok then log("install error: "..tostring(err)) end
end)
CodexSuQingHavenFallEX=B
