-- Only repair the reviewed Lucky Strike mixed-stack context-menu input.
-- Never replace item definitions, Food methods, transfers or upstream files.
if isServer() then return end
require "ISUI/ISInventoryPaneContextMenu"

SuQingLuckyStrikeMenuFix = SuQingLuckyStrikeMenuFix or {}
local M = SuQingLuckyStrikeMenuFix
if M.loaded then return end
M.loaded = true
M.version = "0.1.1-rc.2"
M.normalizedMenus = 0

-- Both reviewed versions and branches have the same entry instruction lines.
local reviewedBranches = {
    ["42.21.0"] = "/42.19",
    ["42.22.2"] = "/42.22",
}

local function normalized(path)
    if type(path) ~= "string" then return nil end
    return (path:gsub("\\", "/"):gsub("^@", ""):gsub("/+$", ""):lower())
end

local function isLuckyStrike(item)
    if not instanceof(item, "InventoryItem") then return false end
    local fullType = item:getFullType()
    return fullType == "MR.lucky_strike" or fullType == "MR.lucky_strike_Pack"
end

local function needsNormalization(items)
    if type(items) ~= "table" then return false end
    for _, entry in ipairs(items) do
        if not instanceof(entry, "InventoryItem") and type(entry) == "table"
            and type(entry.items) == "table" and instanceof(entry.items[1], "Food") then
            local target = false
            for _, item in ipairs(entry.items) do
                if isLuckyStrike(item) then target = true; break end
            end
            if target then
                -- Use CleanUI's own sentinel/large-stack rules. A stale Food
                -- header may describe actual members that are all drainable.
                for _, item in ipairs(ISInventoryPane.getActualItems({entry})) do
                    if not instanceof(item, "Food") then return true end
                end
            end
        end
    end
    return false
end

local function reviewedClosure(fn, expectedPath, firstLine)
    if type(fn) ~= "function" then return false end
    local ok, path = pcall(getFilenameOfClosure, fn)
    if not ok or normalized(path) ~= expectedPath then return false end
    local lineOk, line = pcall(getFirstLineOfClosure, fn)
    return lineOk and line == firstLine
end

local function install()
    if M.installed then return end
    local reason, cleanVersion
    if type(getModInfoByID) ~= "function" or type(getCore) ~= "function"
        or type(getFilenameOfClosure) ~= "function" or type(getFirstLineOfClosure) ~= "function" then
        reason = "source or metadata APIs unavailable"
    else
        local ok, info, gameVersion = pcall(function()
            return getModInfoByID("CleanUI") or getModInfoByID("\\CleanUI"), getCore():getGameAndBuildVersion()
        end)
        if not ok or not info or not info.getModVersion or not info.getVersionDir then
            reason = "CleanUI metadata unavailable"
        elseif not reviewedBranches[gameVersion] then
            reason = "unsupported game version"
        else
            cleanVersion = tostring(info:getModVersion())
            local dir = normalized(info:getVersionDir())
            if cleanVersion ~= "2.10.4" and cleanVersion ~= "2.10.5" then
                reason = "reviewed CleanUI 2.10.4 or 2.10.5 required"
            elseif not dir or dir:sub(-6) ~= reviewedBranches[gameVersion] then
                reason = "unreviewed CleanUI branch"
            elseif not ISInventoryPane or not ISInventoryPaneContextMenu
                or not reviewedClosure(ISInventoryPaneContextMenu.createMenu,
                    dir .. "/media/lua/client/isui/isinventorypanecontextmenu.lua", 327)
                or not reviewedClosure(ISInventoryPane.getActualItems,
                    dir .. "/media/lua/client/isui/isinventorypane.lua", 4014) then
                reason = "unreviewed context-menu or stack-expansion owner"
            end
        end
    end
    if reason then
        M.inactiveReason = reason
        print("[SuQing LuckyStrike] menu guard inactive: " .. reason .. "; CN name fix remains available")
        return
    end

    local original = ISInventoryPaneContextMenu.createMenu
    ISInventoryPaneContextMenu.createMenu = function(player, isInPlayerInventory, items, ...)
        if needsNormalization(items) then
            -- Flatten the complete selected set once so a selected group plus
            -- explicit children remains deduplicated by the original helper.
            -- All real members reach the original menu; no objects are edited.
            items = ISInventoryPane.getActualItems(items)
            M.normalizedMenus = M.normalizedMenus + 1
        end
        return original(player, isInPlayerInventory, items, ...)
    end
    M.installed = true
    M.inactiveReason = nil
    print("[SuQing LuckyStrike] " .. M.version .. " ready; CleanUI=" .. cleanVersion .. "; targeted mixed-stack menu guard")
end

Events.OnGameStart.Add(install)
