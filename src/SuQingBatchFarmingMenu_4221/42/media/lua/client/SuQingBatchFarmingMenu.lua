require "Farming/ISUI/ISFarmingMenu"
SuQingBatchFarmingMenu=SuQingBatchFarmingMenu or {}
local M=SuQingBatchFarmingMenu
function M.allowed(player,worldobjects)
    if not player or not CFarmingSystem or not CFarmingSystem.instance then return false end
    local seen={}
    for _,object in ipairs(worldobjects or {}) do
        local sq=object and object:getSquare()
        if sq and not seen[sq] and sq:getZ()==player:getZ() then
            seen[sq]=true
            if not sq:hasGrave() then
                -- Native digging excludes occupied crop plots, so retain those
                -- explicitly: watering, treatment and harvesting need this menu.
                if CFarmingSystem.instance:getLuaObjectOnSquare(sq)
                    or ISFarmingMenu.canDigHereSquare(sq) then return true end
            end
        end
    end
    return false
end
function M.filter(playerIndex,context,worldobjects,test)
    if test or not context or not VacMod23 then return end
    if not M.allowed(getSpecificPlayer(playerIndex),worldobjects) then
        context:removeOptionByName(getText("ContextMenu_Vac23_BatchFarming"))
    end
end
-- The engine builds vanilla/farming entries before this event. Remove only the
-- Batch Farming root; preserve all other context entries and upstream actions.
Events.OnFillWorldObjectContextMenu.Add(M.filter)
