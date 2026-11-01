require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISLiteratureUI"

-- The tab is registered with a translated name. Vanilla and CleanUI still
-- request the English name, which leaves the skills tab selected in Chinese.
local function activateGrowingTab(literatureUI)
    local tabs = literatureUI and literatureUI.tabs
    if tabs and type(tabs.activateView) == "function" then
        tabs:activateView(getText("IGUI_LiteratureUI_Growing"))
    end
end

if ISInventoryPaneContextMenu and not ISInventoryPaneContextMenu._codexGrowingTab4221
    and type(ISInventoryPaneContextMenu.showGrowingSeasons) == "function" then
    ISInventoryPaneContextMenu._codexGrowingTab4221 = true
    local previousShowGrowingSeasons = ISInventoryPaneContextMenu.showGrowingSeasons
    function ISInventoryPaneContextMenu.showGrowingSeasons(playerObj, ...)
        local result = previousShowGrowingSeasons(playerObj, ...)
        local data = playerObj and ISPlayerData and ISPlayerData[playerObj:getPlayerNum() + 1]
        local screen = data and data.characterInfo and data.characterInfo.charScreen
        activateGrowingTab(screen and screen.literatureUI)
        return result
    end
end

if ISLiteratureUI and not ISLiteratureUI._codexGrowingTab4221
    and type(ISLiteratureUI.onRecipeSelected) == "function" then
    ISLiteratureUI._codexGrowingTab4221 = true
    local previousOnRecipeSelected = ISLiteratureUI.onRecipeSelected
    function ISLiteratureUI:onRecipeSelected(recipe, ...)
        local result = previousOnRecipeSelected(self, recipe, ...)
        if self.character and self.character:isRecipeActuallyKnown(recipe)
            and doesSeasonRecipeExist(recipe) then
            activateGrowingTab(self)
        end
        return result
    end
end

print("[ChineseCropSeedTooltip4221] Localized agriculture tab navigation loaded")
