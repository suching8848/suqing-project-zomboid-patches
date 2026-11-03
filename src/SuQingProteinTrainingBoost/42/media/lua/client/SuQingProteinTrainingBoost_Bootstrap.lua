local B = require "SuQingProteinTrainingBoost/Core"
require "SuQingProteinTrainingBoost/XP"
require "SuQingProteinTrainingBoost/Drinking"
require "SuQingProteinTrainingBoost/StatusUI"

local function install()
    if not B.IsSinglePlayer() then
        B.Log("Single-player only; training boost is inactive in multiplayer.")
        return
    end
    B.RuntimeReady = false
    local xpReady = B.XP.Install()
    local drinkingReady = B.Drinking.Install()
    B.RuntimeReady = xpReady and drinkingReady or false
    if not B.RuntimeReady then
        B.Log("Bridge installation failed; no training boost is granted. Check preceding errors.")
        return
    end
    B.UI.Install()
    B.Log("v" .. B.VERSION .. " installed: 0.5 L = 3 game hours; final Strength/Fitness XP x10.")
end

Events.OnGameStart.Add(install)
