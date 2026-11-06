-- Keep ordinary mouse-following text tooltips in screen coordinates.
-- Several stock widgets position their top-level tooltip with widget-local
-- mouse coordinates.  ISToolTip.render later moves it to the screen cursor;
-- retained UI drawing can otherwise replay the same tooltip at both origins.
if isServer() then return end
require "ISUI/ISToolTip"

SuQingTooltipPositionFix = SuQingTooltipPositionFix or {}
local M = SuQingTooltipPositionFix
if M.loaded then return end
M.loaded = true
M.version = "1.0.0"
M.enabled = true

local wrapped = setmetatable({}, { __mode = "k" })

local function positionMouseTooltip(tooltip)
    if not M.enabled or not tooltip or not tooltip.followMouse
        or tooltip.contextMenu ~= nil or tooltip.desiredX ~= nil
        or tooltip.desiredY ~= nil or not tooltip:getIsVisible() then return end
    -- Those owners have native overlap placement in ISToolTip.render.  None of
    -- the local-coordinate producers below are buttons or skill progress bars.
    local owner = tooltip.owner
    if owner and (owner.isButton or owner.Type == "ISSkillProgressBar") then return end
    tooltip:setX(getMouseX() + 32)
    tooltip:setY(getMouseY() + 10)
end

local producers = {
    { "ISTextEntryBox", "prerender", "tooltipUI" },
    { "ISComboBox", "prerender", "tooltipUI" },
    { "ISGameSoundVolumeControl", "prerender", "tooltipUI" },
    { "ISMegaVolumeControl", "prerender", "tooltipUI" },
    { "ISSpinBox", "prerender", "tooltipUI" },
    { "ISVolumeControl", "prerender", "tooltipUI" },
    { "ISRadioButtons", "render", "tooltipUI" },
    { "ISTickBox", "render", "tooltipUI" },
    { "ISScrollingListBox", "updateTooltip", "tooltipUI" },
    { "ISZoneDisplay", "updateTooltip", "tooltip" },
}

local function wrapProducer(class, method, field)
    if type(class) ~= "table" or type(class[method]) ~= "function" then return end
    local installed = wrapped[class]
    if not installed then installed = {}; wrapped[class] = installed end
    if installed[method] then return end
    local original = class[method]
    -- Keep all native return values without allocating a table on every frame.
    local function finish(owner, ...)
        positionMouseTooltip(owner[field])
        return ...
    end
    class[method] = function(self, ...)
        return finish(self, original(self, ...))
    end
    installed[method] = true
end

function M.install()
    for _, producer in ipairs(producers) do
        wrapProducer(_G[producer[1]], producer[2], producer[3])
    end
end

-- Layout runs in prerender before the background is drawn.  Reposition after
-- native sizing too, so first display and changed text agree with render.
local originalLayout = ISToolTip.doLayout
local function finishLayout(self, ...)
    positionMouseTooltip(self)
    return ...
end
function ISToolTip:doLayout(...)
    return finishLayout(self, originalLayout(self, ...))
end

M.install()
Events.OnGameBoot.Add(M.install)
Events.OnGameStart.Add(M.install)
