require "Codex_ErikaFurnitureTypes"

-- The furniture repair remains active when the optional debug menu is disabled.
if not getActivatedMods():contains("QNWDebugMenuB42") then
    return
end

require "IS/ISItemGenerateUI"
require "IS/ISItemGenerateTable"

Codex_DebugMenuGenerator = Codex_DebugMenuGenerator or {}
local compat = Codex_DebugMenuGenerator
compat.reported = compat.reported or {}
compat.originalInitList = compat.originalInitList or QNW_DMItemGenerateUI.initList

-- These are the creation branches in the installed 42.21 Item.InstanceItem.
-- Other registered ItemTypes can represent templates without an InventoryItem.
local supported = {
    [ItemType.KEY] = true, [ItemType.WEAPON_PART] = true,
    [ItemType.CONTAINER] = true, [ItemType.FOOD] = true,
    [ItemType.LITERATURE] = true, [ItemType.ALARM_CLOCK] = true,
    [ItemType.ALARM_CLOCK_CLOTHING] = true, [ItemType.WEAPON] = true,
    [ItemType.NORMAL] = true, [ItemType.CLOTHING] = true,
    [ItemType.DRAINABLE] = true, [ItemType.RADIO] = true,
    [ItemType.MOVEABLE] = true, [ItemType.MAP] = true,
    [ItemType.ANIMAL] = true,
}

function compat.isSpawnableType(itemType)
    return itemType ~= nil and supported[itemType] == true
end

local function reportSkipped(fullType, reason)
    if not compat.reported[fullType] then
        compat.reported[fullType] = true
        print("[CodexDebugMenuGenerator] skipped " .. tostring(fullType) .. " | " .. tostring(reason))
    end
end

function QNW_DMItemGenerateUI:initList()
    local allItems, modMap, mods = {}, {}, {}
    local scan = {total = 0, filtered = 0, unsupported = 0, failed = 0, accepted = 0, acceptedTypes = {}}
    local scripts = getScriptManager():getAllItems()
    scan.total = scripts:size()
    for i = 0, scripts:size() - 1 do
        local script = scripts:get(i)
        local fullType = script:getFullName()
        if script:getObsolete() or script:isHidden() then
            scan.filtered = scan.filtered + 1
        elseif not fullType or fullType == "" or not ScriptManager.instance:getItem(fullType) then
            scan.failed = scan.failed + 1
            reportSkipped(fullType or ("script-index-" .. i), "missing script name")
        elseif not compat.isSpawnableType(script:getItemType()) then
            scan.unsupported = scan.unsupported + 1
            reportSkipped(fullType, "unsupported ItemType " .. tostring(script:getItemType()))
        else
            local ok, item = pcall(instanceItem, fullType)
            if ok and item then
                local modName = item:getModName() or "Project Zomboid"
                if not modMap[modName] then
                    modMap[modName] = {}
                    table.insert(mods, modName)
                end
                table.insert(modMap[modName], item)
                table.insert(allItems, item)
                scan.accepted = scan.accepted + 1
                scan.acceptedTypes[fullType] = true
            else
                scan.failed = scan.failed + 1
                reportSkipped(fullType, ok and "instanceItem returned nil" or tostring(item))
            end
        end
    end
    table.sort(mods, function(a, b) return not string.sort(a, b) end)

    local function addTab(label, items)
        local tab = QNW_DMItemGenerateTable:new(0, 0, self.panel.width, self.panel.height - self.panel.tabHeight, self)
        tab:initialise()
        self.panel:addView(label, tab)
        tab:initList(items or {})
    end
    addTab(getText("IGUI_QNW_DebugMenu_All"), allItems)
    addTab("Project Zomboid", modMap["Project Zomboid"])
    for _, modName in ipairs(mods) do
        if modName ~= "Project Zomboid" then addTab(modName, modMap[modName]) end
    end
    self.panel:activateView(getText("IGUI_QNW_DebugMenu_All"))
    compat.lastScan = scan
    print("[CodexDebugMenuGenerator] list ready total=" .. scan.total .. " accepted=" .. scan.accepted
        .. " filtered=" .. scan.filtered .. " unsupported=" .. scan.unsupported .. " failed=" .. scan.failed)
end

print("[CodexDebugMenuGenerator] 1.1.0 loaded")
