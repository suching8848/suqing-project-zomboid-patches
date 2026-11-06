-- Respect the Legacy controller master/HUD switches before every prompt path.
-- In the audited upstream build, context menus bypass hudVisible().
SQViewpointLegacyPromptGuard = SQViewpointLegacyPromptGuard or {}
local Patch = SQViewpointLegacyPromptGuard
Patch.version = "1.0.0"

local function shouldRender()
    local options = ViewpointControllerOptions
    if type(options) ~= "table" or options.enabled ~= true
        or options.promptHud == false then
        return false
    end

    -- Upstream intentionally shows a resume hint after switching to keyboard.
    -- Keep that path even though the controller is no longer marked active.
    local controller = ViewpointController
    if controller and controller.hotswapDetached
        and type(vpcIsCaptured) == "function" and vpcIsCaptured()
        and type(getGameSpeed) == "function" and getGameSpeed() > 0
        and not (getJoypadFocus and getJoypadFocus(0)) then
        return true
    end

    local pad = getJoypadData and getJoypadData(0)
    return pad ~= nil and pad.isActive == true
end

function Patch.install()
    local hud = VPC_PromptHUD
    if type(hud) ~= "table" or type(hud.renderPrompts) ~= "function" then
        return false
    end
    if hud.renderPrompts == hud.SQ_LegacyPromptGuardWrapper then
        return true
    end

    local original = hud.renderPrompts
    local wrapper = function(self, ...)
        if not shouldRender() then return end
        return original(self, ...)
    end
    hud.SQ_LegacyPromptGuardOriginal = original
    hud.SQ_LegacyPromptGuardWrapper = wrapper
    hud.renderPrompts = wrapper
    Patch.installed = true
    return true
end

local function installAfterLoad()
    if not Patch.install() and not Patch.warnedMissingHud then
        Patch.warnedMissingHud = true
        print("[SQViewpointLegacyPromptGuard] Legacy prompt HUD unavailable; upstream behavior retained.")
    end
end

Patch.install()
if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(installAfterLoad) end
    if Events.OnGameStart then Events.OnGameStart.Add(installAfterLoad) end
    if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(installAfterLoad) end
end
