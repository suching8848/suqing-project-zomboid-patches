ISBaseObject = ISBaseTimedAction
MoodleType = { UNHAPPY = "unhappy", DRUNK = "drunk" }
BodyPartType = { Hand_L = 1, ForeArm_R = 4 }
BodyPartType.ToIndex = function(part) return part end
BodyPartType.FromIndex = function(index) return index end
LuaTimedActionNew = {
    new = function(action, character)
        return {
            duration = action.maxTime,
            setActionAnim = function(self, name) self.animation = name end,
        }
    end,
}
