require "ExSuQingBackpackSuperUpgrade/Core"
require "ExSuQingBackpackSuperUpgrade/Capacity"
require "CodexNekomataEXCompat4221/Compat"

CodexNekomataEXUpgrade_4221 = CodexNekomataEXUpgrade_4221 or {}
local U = CodexNekomataEXUpgrade_4221
local X = ExSuQingBackpackSuperUpgrade
local S = CodexNekomataEXCompat_4221
local FULL_TYPE = "Base.MaoMaoBackpack"
local KIND = "codex_maomao"
-- Recipe scripts load even when a dependency version/whitelist is refused.
-- Define these before every early return so that those recipes stay disabled.
function U.TestUpgrade(item, character)
    if not U.enabled or not X or X.version ~= "1.0.0-rc.2" then return false end
    return X.TestUpgrade(item, character)
end
function U.TestRestore(item, character)
    if not U.enabled or not X or X.version ~= "1.0.0-rc.2" then return false end
    return X.TestRestore(item, character)
end
if U.loaded then return U end
if not X or X.version ~= "1.0.0-rc.2" or not S or not S.hookedCapacity
    or (X.types[FULL_TYPE] ~= nil and X.types[FULL_TYPE] ~= KIND) then return U end
U.loaded, U.enabled = true, true
U.fullType = FULL_TYPE

-- Script Item has no getCapacity accessor in 42.21. InstanceItem(false) reads
-- the script's native InventoryContainer capacity without adding it anywhere.
-- Cache one detached prototype result per script definition, never per frame.
function U.ReadNativeBase()
    local manager = ScriptManager and ScriptManager.instance
    local script = manager and manager:FindItem(FULL_TYPE)
    if not script or not script.InstanceItem then return nil, "maomao_script_unavailable" end
    if U.script == script and U.nativeBase == 120 then return U.nativeBase end
    local ok, prototype = pcall(script.InstanceItem, script, nil, false)
    if not ok or not prototype or not instanceof(prototype, "InventoryContainer")
        or prototype:getFullType() ~= FULL_TYPE or prototype:getContainer() ~= nil then
        return nil, "maomao_native_prototype"
    end
    local base = prototype:getCapacity()
    if not X.IsInteger(base, 120, 120) then return nil, "maomao_native_capacity_changed" end
    U.script, U.nativeBase = script, base
    return base
end

U.originalNativeBase, U.originalValidRecord, U.originalRecipeMode = X.GetNativeBase, X.IsValidRecord, X.GetRecipeMode
X.types[FULL_TYPE], X.supported[FULL_TYPE] = KIND, true
X.GetNativeBase = function(item, ...)
    if item and item.getFullType and item:getFullType() == FULL_TYPE then
        if not X.IsSupported(item) then return nil, "unsupported" end
        return U.ReadNativeBase()
    end
    return U.originalNativeBase(item, ...)
end
X.IsValidRecord = function(record, item, ...)
    if type(record) == "table" and record.fullType == FULL_TYPE then
        if record.nativeBase ~= 120 or record.targetCapacity ~= 240 then return false end
        if item and (not item.getFullType or item:getFullType() ~= FULL_TYPE) then return false end
    elseif item and item.getFullType and item:getFullType() == FULL_TYPE then return false end
    return U.originalValidRecord(record, item, ...)
end
X.GetRecipeMode = function(recipe, ...)
    local name = recipe and (recipe.getScriptObjectFullType and recipe:getScriptObjectFullType() or recipe:getName())
    if name == "CodexNekomataEXUpgrade.MaoMaoEXUpgrade" then return "upgrade" end
    if name == "CodexNekomataEXUpgrade.MaoMaoEXRestore" then return "restore" end
    return U.originalRecipeMode(recipe, ...)
end

-- Register before EX's first startup event; the inner captured source remains
-- an author/native baseline while only the verified outer source reaches EX.
S.Refresh()
return U
