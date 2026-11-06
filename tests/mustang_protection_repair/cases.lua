local count = 0
local function verify(label, test)
    test()
    count = count + 1
    print("PASS " .. label)
end

local function click(fixture)
    local button = fixture.button
    assert(button.visible and button.enabled)
    button.callback(button.target)
    return queued[#queued]
end

verify("installed bullbar action, use exactly once, sync backing and leave protected condition", function()
    local f = newFixture()
    assert(#f.window.children == 1 and f.button.x == 466 and f.button.y == 330)
    assert(f.button.title:find("62 92", 1, true) and f.window.renders == 1)
    local action = click(f)
    assert(action and action:isValid() and f.window.closed and #queued == 1)
    assert(action.stopOnWalk and action.stopOnRun and action.stopOnAim)
    assert(action:getDuration() == 100)
    assert(not action:waitToStart())
    action:start()
    assert(action:complete() and f.part:getCondition() == 92 and f.part.backing.condition == 92)
    assert(f.car.transmitted == 1 and f.protected.condition == 35)
    assert(f.metal.owner == nil and f.link.owner == f.inventory and f.torch.uses == 2)
    assert(not action:complete() and f.torch.uses == 2 and f.car.transmitted == 1)
end)

verify("condition cap, zero retained part, new damage during action", function()
    local f = newFixture({ condition = 95 })
    assert(click(f):complete() and f.part.condition == 100)
    f = newFixture({ condition = 0, model = "ATABullbar3" })
    assert(click(f):complete() and f.part.condition == 30)
    f = newFixture()
    local action = click(f)
    f.part:setCondition(12)
    assert(action:complete() and f.part.condition == 42)
end)

verify("chain slot consumes chain link and supports fuel split", function()
    local f = newFixture({ slot = "ATA2ProtectionWheels", model = "ATAProtection", fuel = 1, secondFuel = 2 })
    assert(f.button.tooltip == "IGUI_SQ_MPR_LinkCost")
    assert(click(f):complete() and f.torch.uses == 0 and f.second.uses == 0)
    assert(f.link.owner == nil and f.metal.owner == f.inventory)
end)

verify("all stock models and existing NIKKE shared definitions", function()
    for _, vehicle in ipairs({ "ATAMustang", "ATAMustangClassic", "ATAMustangPolice", "ATAMustangNikkeArkRangerRed" }) do
        for _, slot in ipairs({
            "ATA2ProtectionWindowFrontLeft", "ATA2ProtectionWindowFrontRight",
            "ATA2ProtectionWindshield", "ATA2ProtectionWindshieldRear",
        }) do
            local f = newFixture({ car = vehicle, slot = slot, model = "Default" })
            assert(click(f):complete())
        end
        for _, model in ipairs({ "ATABullbar1", "ATABullbar2", "ATABullbar3" }) do
            local f = newFixture({ car = vehicle, model = model })
            assert(click(f):complete())
        end
    end
end)

verify("wrong vehicles, missing metadata, unknown model and unrelated slot are excluded", function()
    ATA2TuningTable.Other = ATA2TuningTable.ATAMustang
    assert(not newFixture({ car = "Other" }).button.visible)
    ATA2TuningTable.ATAMustangNikkeFake = { parts = {} }
    assert(not newFixture({ car = "ATAMustangNikkeFake" }).button.visible)
    assert(not newFixture({ model = "Unknown" }).button.visible)
    assert(not newFixture({ slot = "ATA2VisualSpoilerRear" }).button.visible)
    local f = newFixture()
    f.part.data.tuning2 = nil
    f.window:render()
    assert(not f.button.visible)
end)

verify("requires selected installed tab, active window and outside of vehicle", function()
    local f = newFixture()
    f.view.category = "Other"
    f.window:render()
    assert(not f.button.visible)
    f.view.category = "IGUI_TuningCategory_Installed"
    f.recipe.type = "install"
    f.window:render()
    assert(not f.button.visible)
    f.recipe.type = "uninstall"
    f.window.isCollapsed = true
    f.window:render()
    assert(not f.button.visible)
    f.window.isCollapsed = false
    f.player.inside = f.car
    f.window:render()
    assert(f.button.visible and not f.button.enabled)
    f.button.callback(f.window)
    assert(#queued == 0)
    f.player.inside = nil
    f.window.debugGiveIngredientsButton:setVisible(true)
    f.window:render()
    assert(f.button.x == 571)
end)

verify("full condition, missing material, missing fuel, skill and mask reject", function()
    assert(not newFixture({ condition = 100 }).button.visible)
    for _, options in ipairs({
        { noMetal = true }, { noMask = true }, { brokenMask = true }, { fuel = 2 },
        { skill = 1 }, { slot = "ATA2ProtectionWheels", model = "ATAProtection", noLink = true },
    }) do
        local f = newFixture(options)
        assert(not click(f) and f.player.lastLine and not f.window.closed)
        assert(f.part.condition == 62 and f.car.transmitted == 0)
    end
end)

verify("canceled action, replaced item, auto-removed item, despawned car and walk away", function()
    local f = newFixture()
    local stopped = click(f)
    stopped:stop()
    assert(stopped.stopped and not stopped:complete())
    f = newFixture()
    local canceled = click(f)
    canceled:forceCancel()
    assert(not canceled:complete())
    assert(f.part.condition == 62 and f.torch.uses == 5 and f.metal.owner == f.inventory)
    for _, change in ipairs({
        function(x) x.part.backing = {} end,
        function(x) x.part.backing = nil end,
        function(x) x.part.data.tuning2.model = "ATABullbar2" end,
        function(x) x.car.present = false end,
        function(x) x.car.near = false end,
        function(x) x.part:setCondition(100) end,
    }) do
        f = newFixture()
        local action = click(f)
        change(f)
        assert(not action:isValid() and not action:complete())
        assert(f.torch.uses == 5 and f.metal.owner == f.inventory and f.car.transmitted == 0)
    end
end)

verify("material removal at completion and path to correct install area", function()
    local f = newFixture({ slot = "ATA2ProtectionWindshield", model = "Default" })
    f.car.near = false
    local action = click(f)
    assert(queued[1].path == "TireFrontLeft" and queued[2] == action and not action:isValid())
    f.car.near = true
    assert(action:isValid())
    f.inventory:Remove(f.metal)
    assert(not action:complete() and f.torch.uses == 5 and f.car.transmitted == 0)
end)

print("PASS " .. count .. " Mustang protection repair cases")
return count
