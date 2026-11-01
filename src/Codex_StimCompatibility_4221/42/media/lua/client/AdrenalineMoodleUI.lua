require "CodexStimCompat/Source"
return CodexStimSource.Run("AdrenalineShot","media/lua/client/AdrenalineMoodleUI.lua","reference/AdrenalineMoodleUI.txt", {
    {"local totalDuration =\n        10","local totalDuration = type(data.effectStartsAt) == \"number\" and math.max(1, data.expiresAt - data.effectStartsAt) or 10",1}
},"moodle", {{"AdrenalineShot","media/lua/shared/AdrenalineEffect.lua","reference/AdrenalineEffect.txt"}})
