require "TimedActions/ISForceOpen"

local Targets = require "SuQingVanillaPryUpgrade/Targets"
local rollSuccess = require "SuQingVanillaPryUpgrade/RollSuccess"

if Targets.enabled() and not ISForceOpen.SuQingVanillaPryUpgrade then
    ISForceOpen.SuQingVanillaPryUpgrade = true

    -- Keep the B42.22.2 attempt guards and effects. The native animation
    -- event consumes the result and handles opening or stopping.
    function ISForceOpen:attempt()
        local character = self.character
        local object = self.object
        if not instanceof(object, "IForceablePortal") then
            return "fail"
        end
        if not Targets.isCrowbar(character:getPrimaryHandItem()) or object:isNotValidForForcing()
            or not IsoGridSquare.isWithinReachOfCharacter(character, object) then
            return "fail"
        end
        if not object:isLocked() then
            return "success"
        end

        character:exertForForcing()
        object:forceStruggleDamage(character)
        if object:isNotValidForForcing() then
            return "fail"
        end

        if rollSuccess(character) then
            return "success"
        end
        object:failForceOpen(character)
        return "fail"
    end
end
