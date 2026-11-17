local weights = require "SuQingMFSAmmoWeight/Weights"

local function applyWeights()
    local scriptManager = getScriptManager()

    for fullType, weight in pairs(weights) do
        local item = scriptManager:FindItem(fullType, false)
        if item and item:getFullName() == fullType then
            item:setActualWeight(weight)
        end
    end
end

-- TrueWeight runs during OnLoadedTileDefinitions. Map zones load before saved items.
Events.OnLoadMapZones.Add(applyWeights)
