local B = require "SuQingProteinTrainingBoost/Core"
require "SuQingProteinTrainingBoost/XP"
require "SuQingProteinTrainingBoost/Iron"
require "SuQingProteinTrainingBoost/Drinking"
require "SuQingProteinTrainingBoost/StatusUI"

local function install()
    if not B.IsSinglePlayer() then
        B.Iron.RestoreHooks()
        B.Log("Single-player only; training boost is inactive in multiplayer.")
        return
    end
    B.RuntimeReady = false
    local xpReady = B.XP.Install()
    local drinkingReady = B.Drinking.Install()
    if not xpReady or not drinkingReady then
        B.Iron.RestoreHooks()
        B.Log("Bridge installation failed; no training boost is granted. Check preceding errors.")
        return
    end
    local ironReady, ironStatus = B.Iron.Install()
    if not ironReady then return end
    B.RuntimeReady = true
    B.UI.Install()
    B.Log("v" .. B.VERSION .. " installed: 0.5 L = 3 game hours; final Strength/Fitness XP x10.")
    if ironStatus == "installed" then
        B.Log("Project Iron 0.6.0 XP compatibility active; supplement multipliers stack once.")
    end
end

Events.OnGameStart.Add(install)
