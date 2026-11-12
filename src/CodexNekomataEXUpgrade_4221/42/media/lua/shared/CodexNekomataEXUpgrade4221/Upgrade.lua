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
    or type(S.ReadAuthorCapacity) ~= "function"
    or (X.types[FULL_TYPE] ~= nil and X.types[FULL_TYPE] ~= KIND) then return U end
U.loaded, U.enabled = true, true
U.fullType = FULL_TYPE

-- Stock inventory items cap physical capacity at 50 minus item weight.
-- The verified author's ItemContainer wrapper supplies the 120 baseline.
function U.ReadNativeBase(item)
    local container = item:getInventory()
    if not container or container:getContainingItem() ~= item then
        return nil, "maomao_container_unavailable"
    end
    local ok, base = pcall(S.ReadAuthorCapacity, container)
    if not ok or not X.IsInteger(base, 120, 120) then
        return nil, "maomao_native_capacity_changed"
    end
    return base
end

U.originalNativeBase, U.originalValidRecord, U.originalRecipeMode = X.GetNativeBase, X.IsValidRecord, X.GetRecipeMode
X.types[FULL_TYPE], X.supported[FULL_TYPE] = KIND, true
X.GetNativeBase = function(item, ...)
    if item and item.getFullType and item:getFullType() == FULL_TYPE then
        if not X.IsSupported(item) then return nil, "unsupported" end
        return U.ReadNativeBase(item)
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
