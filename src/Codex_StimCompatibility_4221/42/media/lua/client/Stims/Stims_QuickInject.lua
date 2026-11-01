require "CodexStimCompat/Source"
return CodexStimSource.Run("TarkovCombatStims","media/lua/client/Stims/Stims_QuickInject.lua","reference/Stims_QuickInject.txt", {
    {[=[    if anyStim and StimsSettingsUI and StimsSettingsUI.open then
        local settingsLabel = getText("IGUI_CombatStims_InjectorSettings") or "Injector Settings"
        local settingsOption = context:addOption(settingsLabel, player,
            function() StimsSettingsUI.open() end)
        -- Attach the vanilla gears icon so the option stands out from
        -- the "Inject <Name>" rows above it. media/ui/gears.png ships
        -- with every PZ install so no bundled texture needed.
        -- ISContextMenu renders option.iconTexture at the left of the
        -- row when set.
        if settingsOption then
            settingsOption.iconTexture = getTexture("media/ui/gears.png")
        end
    end]=], "", 1}
},"hide-injector-settings")
