if isClient() or isServer() then return end

require "MaoMaoGlowConfig"
require "MaoMaoDianLanZhuZuiFireVFXConfig"

local rifleType = "Base.MaoMaoDianLanZhuZui"
local rifle = MaoMaoGlowConfig and MaoMaoGlowConfig.Items and MaoMaoGlowConfig.Items[rifleType]
local overload = rifle and rifle.overload
local vfx = MaoMaoDianLanZhuZuiFireVFX and MaoMaoDianLanZhuZuiFireVFX.Config
if not overload or overload.enabledSwingSound ~= "MaoMaoDianLanZhuZuiSilent"
    or overload.disabledSwingSound ~= "M16Shoot"
    or not vfx or vfx.WEAPON_FULL_TYPE ~= rifleType or vfx.SHOT_SOUND ~= "MaoMaoDianLanZhuZuiShoot" then
    return
end

-- The shot callback is dispatched in the same native call as the muzzle flash and bullet.
-- Mute the separate animation and visual-effect playback paths.
overload.disabledSwingSound = overload.enabledSwingSound
vfx.SHOT_SOUND = false

Events.OnWeaponSwingHitPoint.Add(function(player, weapon)
    if not player or not weapon or weapon:getFullType() ~= rifleType or not player:isLocalPlayer()
        or player:isRangedWeaponEmpty() or player:isDoShove() or player:isDoGrapple() then return end
    local shot = vfx.isOverloadEnabled(weapon) and "SuQingMaoMaoOverloadShot" or "SuQingMaoMaoNormalShot"
    player:playRangedWeaponShootSound(shot)
end)
