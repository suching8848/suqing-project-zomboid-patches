require "CodexStimCompat/Source"
return CodexStimSource.Run("TarkovCombatStims","media/lua/shared/Stims/Stims_Containers.lua","reference/Stims_Containers.txt", {
    {"return string.sub(fullType, 1, 12) == \"CombatStims.\"","return string.sub(fullType, 1, 12) == \"CombatStims.\" or fullType == \"AdrenalineShot.AdrenalineShot\"",1}
},"filter")
