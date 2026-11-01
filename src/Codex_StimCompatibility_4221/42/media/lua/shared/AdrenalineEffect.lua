require "CodexStimCompat/Source"
return CodexStimSource.Run("AdrenalineShot","media/lua/shared/AdrenalineEffect.lua","reference/AdrenalineEffect.txt", {
    {"local DURATION_MINUTES = 10","local DURATION_MINUTES = 240",1},
    {"\"It's not a good idea...\"","getText(\"IGUI_CodexStim_BadIdea\")",2},
    {"\"My body won't handle another dose...\"","getText(\"IGUI_CodexStim_CannotHandle\")",1},
    {"\"Okay... just gotta wait for this to kick in.\"","getText(\"IGUI_CodexStim_Wait1\")",1},
    {"\"Come on... kick in already.\"","getText(\"IGUI_CodexStim_Wait2\")",1},
    {"\"Here goes nothing...\"","getText(\"IGUI_CodexStim_Wait3\")",1},
    {"\"I'm feeling down...\"","getText(\"IGUI_CodexStim_End1\")",1},
    {"\"It's wearing off...\"","getText(\"IGUI_CodexStim_End2\")",1},
    {"\"Strength enough for one more time...\"","getText(\"IGUI_CodexStim_End3\")",1},
    {"\"Here we go...\"","getText(\"IGUI_CodexStim_Start1\")",2},
    {"\"I can feel it kicking in.\"","getText(\"IGUI_CodexStim_Start2\")",1},
    {"\"Alright... let's do this.\"","getText(\"IGUI_CodexStim_Start3\")",1}
},"effect", {{"AdrenalineShot","media/lua/client/AdrenalineMoodleUI.lua","reference/AdrenalineMoodleUI.txt"}})
