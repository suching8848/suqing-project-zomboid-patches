-- Hide only the map's standalone construction context-menu callback.
-- Keep RaccoonCityBuildMenu, its recipes/assets and BuildingCraft integration intact.
CodexRaccoonMenuHide4221 = CodexRaccoonMenuHide4221 or {}
local R = CodexRaccoonMenuHide4221
if R.loaded then return R end
R.loaded = true

function R.UnregisterBuildMenu()
    local event = Events and Events.OnFillWorldObjectContextMenu
    local callback = RaccoonCityBuildMenu and RaccoonCityBuildMenu.CreateBuildMenu
    if not event or not event.Remove or type(callback) ~= "function" then
        return false
    end
    event.Remove(callback)
    return true
end

-- Normal ordered load removes it now; startup also covers a late map script.
R.UnregisterBuildMenu()
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(R.UnregisterBuildMenu)
end
return R
