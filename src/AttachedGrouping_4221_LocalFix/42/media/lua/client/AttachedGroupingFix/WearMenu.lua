if isServer() then return end

CodexAttachedGroupingFix = CodexAttachedGroupingFix or {}
CodexAttachedGroupingFix.WearMenu = CodexAttachedGroupingFix.WearMenu or {}
local W = CodexAttachedGroupingFix.WearMenu

-- B42.21 uses ItemBodyLocation objects; older/modded getters may return strings.
-- Keep valid objects intact, and never use nil/empty locations as dedup keys.
local function validLocation(location)
    if location == nil or location == false or location == "" then return nil end
    return location
end

local function wearableLocation(item)
    if not item or not instanceof(item, "InventoryItem") then return nil end
    if instanceof(item, "HandWeapon") or item:isBroken() then return nil end

    if item:IsClothing() then
        return validLocation(item:getBodyLocation())
    end

    local wearableTag = ItemTag and ItemTag.WEARABLE
    if item:IsInventoryContainer() or (wearableTag and item:hasTag(wearableTag)) then
        return validLocation(item:canBeEquipped())
    end
    return nil
end

local function wearableSelection(items, player)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return {} end

    local ok, actualItems = pcall(ISInventoryPane.getActualItems, items)
    if not ok or type(actualItems) ~= "table" then return {} end

    local filtered = {}
    local seen = {}
    for _, item in ipairs(actualItems) do
        if not seen[item] and wearableLocation(item)
            and not playerObj:isEquippedClothing(item) then
            seen[item] = true
            filtered[#filtered + 1] = item
        end
    end
    return filtered
end

function W.install()
    local menu = ISInventoryPaneContextMenu
    if type(menu) ~= "table" or menu._codexAttachedGroupingWearMenuInstalled then return end
    if type(menu.doWearClothingMenu) ~= "function" or type(menu.onWearItems) ~= "function" then return end
    if not ISInventoryPane or type(ISInventoryPane.getActualItems) ~= "function" then return end

    local originalMenu = menu.doWearClothingMenu
    local originalWear = menu.onWearItems

    menu.doWearClothingMenu = function(player, clothing, items, context)
        local filtered = wearableSelection(items, player)
        if #filtered == 0 then return end
        -- The original menu takes its icon from items[1] and its tooltip from
        -- clothing. Give both the same wearable, never a mixed-in weapon.
        return originalMenu(player, filtered[1], filtered, context)
    end

    menu.onWearItems = function(items, player)
        local filtered = wearableSelection(items, player)
        local locationsDone = {}
        for _, item in ipairs(filtered) do
            local body = validLocation(item:getBodyLocation())
            local equipped = validLocation(item:canBeEquipped())
            if not (body and locationsDone[body])
                and not (equipped and locationsDone[equipped]) then
                -- Keep vanilla/CleanUI hat, hood and transfer handling. Passing
                -- one item at a time also avoids its typeDone[""] collision.
                originalWear({ item }, player)
                if body then locationsDone[body] = true end
                if equipped then locationsDone[equipped] = true end
            end
        end
    end

    menu._codexAttachedGroupingWearMenuInstalled = true
end

Events.OnGameStart.Add(W.install)
