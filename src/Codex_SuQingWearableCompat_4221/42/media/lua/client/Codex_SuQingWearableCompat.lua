-- Exact-ID adapter for the installed 1.0.0 SuQing ordinary container upgrade.
-- Preserve the original recipe IDs, guard, same-item record, materials and refunds.
if isServer() then return end
require "SuQingContainerUpgrade/Core"
local C = SuQingContainerUpgrade
local Compat = { installed = {} }
local function log(s) print("[SuQingWearableCompat] " .. tostring(s)) end
local function copy(list)
    local t = {}
    for i = 0, list:size() - 1 do t[#t + 1] = list:get(i) end
    return t
end
local function restore(list, old)
    list:clear()
    for _, item in ipairs(old) do list:add(item) end
end
local function contains(list, value)
    for i = 0, list:size() - 1 do if list:get(i) == value then return true end end
    return false
end
local function validExtra(script, wanted)
    local extras = script:getClothingItemExtra()
    if not extras or extras:size() ~= 1 then return false end
    local s = tostring(extras:get(0))
    return s == wanted or s == string.match(wanted, "%.([^%.]+)$")
end
local function installGroup(name, entries, pairsById)
    if Compat.installed[name] then return true end
    if not C.IsSinglePlayer() or C.version ~= "1.0.0" then return false end
    local sm = type(getScriptManager) == "function" and getScriptManager()
    if not sm or not ItemType or not ItemType.CONTAINER or not C.compatibility
        or C.compatibility.schema ~= 1 or not C.compatibility.positionPairs or not C.compatibility.profiles then return false end
    local scripts = {}
    for _, entry in ipairs(entries) do
        local script = sm:getItem(entry.id)
        if not script or script:getFullName() ~= entry.id or not script:isItemType(ItemType.CONTAINER)
            or script:getObsolete() or script:isHidden() then return false end
        if entry.pair and not validExtra(script, entry.pair) then
            log(name .. " source pair changed: " .. entry.id); return false
        end
        if entry.maxSize and math.abs(script:getMaxItemSize() - entry.maxSize) > 0.001 then
            log(name .. " source item-size limit changed: " .. entry.id); return false
        end
        if C.supported[entry.id] or C.retired[entry.id] or C.compatibility.profiles[entry.id]
            or C.compatibility.positionPairs[entry.id] then
            log(name .. " already registered; refusing to override: " .. entry.id); return false
        end
        scripts[entry.id] = script
    end
    local stages = {}
    for i = 1, 6 do
        local short = i == 6 and "SuQingRestore" or ("SuQingUpgrade" .. i)
        local recipe = sm:getCraftRecipe("SuQingContainerUpgrade." .. short)
        if not recipe or not recipe:getInputs() or recipe:getInputs():size() == 0 then return false end
        local input = recipe:getInputs():get(0)
        if not input or not input:isKeep() or not input:isItemCount() then return false end
        local ids, cache = input:getItems(), input:getPossibleInputItems()
        if not ids or not cache then return false end
        for _, entry in ipairs(entries) do
            if contains(ids, entry.id) or contains(cache, scripts[entry.id]) then
                log(name .. " recipe already contains target; refusing partial merge"); return false
            end
        end
        stages[#stages + 1] = {ids=ids, cache=cache, oldIds=copy(ids), oldCache=copy(cache)}
    end
    local ok, err = pcall(function()
        for _, stage in ipairs(stages) do
            for _, entry in ipairs(entries) do
                stage.ids:add(entry.id); stage.cache:add(scripts[entry.id])
            end
        end
        for _, entry in ipairs(entries) do
            C.supported[entry.id] = true
            C.compatibility.profiles[entry.id] = "mod_container"
            if pairsById then C.compatibility.positionPairs[entry.id] = pairsById[entry.id] end
        end
    end)
    if not ok then
        for _, stage in ipairs(stages) do
            pcall(restore, stage.ids, stage.oldIds); pcall(restore, stage.cache, stage.oldCache)
        end
        for _, entry in ipairs(entries) do
            C.supported[entry.id]=nil; C.compatibility.profiles[entry.id]=nil
            if pairsById then C.compatibility.positionPairs[entry.id]=nil end
        end
        log(name .. " could not install; rolled back: " .. tostring(err)); return false
    end
    Compat.installed[name]=true; log(name .. " ready (" .. #entries .. " types)"); return true
end
function Compat.Install()
    installGroup("injector case", {{id="CombatStims.InjectorCase", maxSize=10}}, nil)
    installGroup("chemical chest rig", {{id="CodexCBRT.SST02_ChestRig"}}, nil)
    installGroup("HavenFall waist pair", {
        {id="ESHF.Qwe_Backpack", pair="ESHF.Qwe_BackpackFront"},
        {id="ESHF.Qwe_BackpackFront", pair="ESHF.Qwe_Backpack"},
    }, { ["ESHF.Qwe_Backpack"]="ESHF.Qwe_BackpackFront", ["ESHF.Qwe_BackpackFront"]="ESHF.Qwe_Backpack" })
end
Events.OnGameStart.Add(function()
    local ok, err = pcall(Compat.Install)
    if not ok then log("install error: " .. tostring(err)) end
end)
CodexSuQingWearableCompat = Compat
