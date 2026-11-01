require "CodexStimCompat/Source"
return CodexStimSource.Run("AdrenalineShot","media/lua/client/AdrenalineInject.lua","reference/AdrenalineInject.txt", {
    {"\"Inject Adrenaline\"","getText(\"IGUI_CodexStim_Inject\")",2},
    {"\"It's not a good idea...\"","getText(\"IGUI_CodexStim_BadIdea\")",3},
    {"\"My body won't handle another dose...\"","getText(\"IGUI_CodexStim_CannotHandle\")",1}
},"inject")
