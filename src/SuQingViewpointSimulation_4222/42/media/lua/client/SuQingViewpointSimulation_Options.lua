if not PZAPI or not PZAPI.ModOptions then
    return
end

local options = PZAPI.ModOptions:create(
    "SuQingViewpointSimulation_4222", "UI_SQViewpointSimulation_Title")
options:addDescription("UI_SQViewpointSimulation_Unavailable")
local status = options.data[#options.data]
local mode = options:addComboBox(
    "mode", "UI_SQViewpointSimulation_Mode", "UI_SQViewpointSimulation_ModeTooltip")
mode:addItem("UI_SQViewpointSimulation_30Hz")
mode:addItem("UI_SQViewpointSimulation_60Hz", true)
mode:addItem("UI_SQViewpointSimulation_Off")

local previousSelection

local function validMode(value)
    return value == 1 or value == 2 or value == 3
end

local function currentMode()
    local bridge = SuQingViewpointSimulationBridge
    if not bridge or not bridge.available or not bridge.currentMode then
        return nil
    end

    local availableOk, available = pcall(bridge.available)
    if not availableOk or available ~= true then
        return nil
    end

    local modeOk, selected = pcall(bridge.currentMode)
    selected = modeOk and tonumber(selected)
    if validMode(selected) then
        return selected
    end
    return nil
end

local function refresh()
    local selected = currentMode()
    mode:setEnabled(selected ~= nil)
    if selected then
        mode:setValue(selected)
        status.text = getText("UI_SQViewpointSimulation_Ready")
    else
        status.text = getText("UI_SQViewpointSimulation_Unavailable")
    end
end

function mode:onChangeApply(index)
    local bridge = SuQingViewpointSimulationBridge
    if validMode(index) and bridge and bridge.apply then
        local ok, applied = pcall(bridge.apply, index)
        if ok and applied == true then
            return
        end
    end
    previousSelection = self:getValue()
end

function options:apply()
    -- MainOptions assigns the chosen index after onChangeApply, then saves.
    -- Restore the prior choice here if the Java bridge declined the change.
    if previousSelection ~= nil then
        mode:setValue(previousSelection)
        previousSelection = nil
        refresh()
    end
end

refresh()
Events.OnGameBoot.Add(refresh)
Events.OnMainMenuEnter.Add(refresh)
Events.OnGameStart.Add(refresh)
