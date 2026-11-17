local function localizeKnoxwaveSliders()
    local modOptions = PZAPI and PZAPI.ModOptions
    local options = modOptions and modOptions:getOptions("Knoxwave")
    if not options then return end

    -- MainOptions resolves slider names with getText when constructing the panel.
    local echo = options:getOption("echoWet")
    if echo and echo.type == "slider" then
        echo.name = "UI_SQKnoxwave_EchoLevel"
    end
    local reverb = options:getOption("roomReverbWet")
    if reverb and reverb.type == "slider" then
        reverb.name = "UI_SQKnoxwave_ReverbLevel"
    end
end

Events.OnGameBoot.Add(localizeKnoxwaveSliders)
