require "ISUI/ISPanel"
local B = require "SuQingProteinTrainingBoost/Core"
local UI = B.UI or {}
B.UI = UI
UI.panels = UI.panels or {}
UI.faultNotified = UI.faultNotified or setmetatable({}, { __mode = "k" })

local StatusPanel = ISPanel:derive("SuQingProteinTrainingBoostStatus")

function StatusPanel:prerender()
    ISPanel.prerender(self)
end

function StatusPanel:render()
    if not B.IsActive(self.player) then return end
    local multiplier = B.XP.GetMultiplier(self.player)
    if not multiplier then return end
    self:drawText(getText("IGUI_SuQingProteinTrainingBoost_Active", string.format("%.12g", multiplier)), 10, 5,
        0.65, 1, 0.65, 1, UIFont.Small)
    self:drawText(getText("IGUI_SuQingProteinTrainingBoost_Remaining", B.FormatRemaining(self.player)),
        10, 6 + getTextManager():getFontHeight(UIFont.Small), 1, 1, 1, 1, UIFont.Small)
end

local function showPanel(player)
    local index = player:getPlayerNum()
    local panel = UI.panels[index]
    if not panel then
        local left = getPlayerScreenLeft and getPlayerScreenLeft(index) or 0
        local top = getPlayerScreenTop and getPlayerScreenTop(index) or 0
        local width = getPlayerScreenWidth and getPlayerScreenWidth(index) or getCore():getScreenWidth()
        local panelWidth = math.max(280, getTextManager():MeasureStringX(UIFont.Small,
            getText("IGUI_SuQingProteinTrainingBoost_Active", "110.0")) + 24)
        local height = getTextManager():getFontHeight(UIFont.Small) * 2 + 16
        panel = StatusPanel:new(left + math.max(0, (width - panelWidth) / 2), top + 18, panelWidth, height)
        panel:initialise()
        panel.backgroundColor = { r = 0.04, g = 0.07, b = 0.04, a = 0.78 }
        panel.borderColor = { r = 0.35, g = 0.65, b = 0.35, a = 0.7 }
        panel.moveWithMouse = true
        panel.player = player
        panel:addToUIManager()
        UI.panels[index] = panel
    end
    panel.player = player
    panel:setVisible(true)
end

function UI.Update(player)
    if not B.IsSinglePlayer() or not player then return end
    if player.isLocalPlayer and not player:isLocalPlayer() then return end
    local index = player:getPlayerNum()
    local panel = UI.panels[index]
    if B.XP.HasFault(player) then
        if panel then panel:setVisible(false) end
        if not UI.faultNotified[player] then
            UI.faultNotified[player] = true
            if HaloTextHelper then
                HaloTextHelper.addText(player, getText("IGUI_SuQingProteinTrainingBoost_Failed"))
            end
        end
        return
    end
    if B.IsActive(player) then
        if B.XP.GetMultiplier(player) then
            showPanel(player)
        elseif panel then
            panel:setVisible(false)
        end
    elseif panel and panel:isVisible() then
        panel:setVisible(false)
        if HaloTextHelper then
            HaloTextHelper.addText(player, getText("IGUI_SuQingProteinTrainingBoost_Expired"))
        end
    end
end

function UI.Install()
    if UI.installed or not B.IsSinglePlayer() then return false end
    Events.OnPlayerUpdate.Add(UI.Update)
    UI.installed = true
    return true
end

return UI
