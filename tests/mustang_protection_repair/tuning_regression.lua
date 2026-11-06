for _, options in ipairs({ {}, { car = "ATAMustangNikkeArkRangerRed", slot = "ATA2ProtectionWheels", model = "ATAProtection" } }) do
    local f = newFixture(options)
    local recipe = f.window:getRecipeListBox().items[1].item
    assert(recipe.category == "IGUI_TuningCategory_Installed")
    assert(recipe.partName == (options.slot or "ATA2Bullbar"))
    assert(recipe.modelName == (options.model or "ATABullbar1"))
    assert(recipe.type == "uninstall" and recipe.condition == 62)
    assert(f.button.visible and f.button.enabled and f.button.y == f.window.craftOneButton.y)
    assert(f.button.x > f.window.craftOneButton.x + f.window.craftOneButton.width)
    debugButtons = true
    f.window:render()
    assert(f.button.x > f.window.debugGiveIngredientsButton.x + f.window.debugGiveIngredientsButton.width)
    assert(f.button.x + f.button.width <= f.window.width)
    debugButtons = false
    f.window.isCollapsed = true
    f.window:render()
    assert(not f.button.visible)
    f.window.isCollapsed = false
    f.window:render()
    f.button.callback(f.window)
    assert(f.window.closed and queued[1]:complete() and f.part.condition == 92)
end
