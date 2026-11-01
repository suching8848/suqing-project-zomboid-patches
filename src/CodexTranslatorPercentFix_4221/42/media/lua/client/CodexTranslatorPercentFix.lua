-- True 3D Items: defer this tooltip's translation until MainOptions renders it.
-- ProjectFullHD registered getText(key), then vanilla MainOptions called getText
-- again on the resulting percent-bearing sentence. Only this metadata changes.
require "ProjectFullHD/ProjectFullHD"

local modOptions = PZAPI and PZAPI.ModOptions
local options = modOptions and modOptions:getOptions("ProjectFullHD")
if options then
    for _, id in ipairs({ "zoom", "zoomPlus" }) do
        local option = options:getOption(id)
        if option and option.type == "multipletickbox" then
            option.tooltip = "UI_ProjectFullHD_Zoom_tooltip"
        end
    end
end
