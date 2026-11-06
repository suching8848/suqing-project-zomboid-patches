ISCollapsableWindow = ISVehicleTuning2
function ISCollapsableWindow:render() end
Keyboard = { KEY_LEFT = 1, KEY_RIGHT = 2, KEY_UP = 3, KEY_DOWN = 4 }
function UI_FONT:getFontHeight(font) return 18 end
function getTexture() return nil end
function getAllRecipes() return nil end
function getTimestampMs() return 0 end
function getDebug() return debugButtons end
JoypadState = { players = {} }
ATA2TuningSpecialSpawnCount = {}
-- B42.21-selected Tsar 42.17 UI now creates a Java tag scratch list.
-- This is the Java collection boundary, not replacement tuning logic.
ArrayList = { new = function()
    local values = {}
    return {
        clear = function() values = {} end,
        add = function(_, value) values[#values + 1] = value end,
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end,
    }
end }
ISVehicleMechanics = { getConditionRGB = function() return { r = 1, g = 1, b = 1 } end }
function Perks.FromString(name) return { getName = function() return name end } end
