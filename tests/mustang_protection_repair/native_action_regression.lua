for _, instant in ipairs({ false, true }) do
    local f = newFixture()
    f.player.isTimedActionInstant = function() return instant end
    f.player.setTimedActionToRetrigger = function(_, previous) assert(previous == nil) end
    f.player.getMoodles = function()
        return { getMoodleLevel = function() return 0 end }
    end
    f.player.getBodyDamage = function()
        return { getBodyPart = function() return { getPain = function() return 0 end } end }
    end
    f.player.getTimedActionTimeModifier = function() return 1 end
    f.player.StartAction = function(self, nativeAction) self.started = nativeAction end

    f.button.callback(f.window)
    local action = assert(queued[1])
    action:begin()
    local expected = instant and 1 or 100
    assert(f.player.started.duration == expected,
        "B42.21 constructor saw maxTime " .. tostring(f.player.started.duration) .. ", expected " .. expected)
    action:start()
    assert(f.player.started.animation == "Loot")
    assert(action:complete() and f.part.condition == 92 and f.torch.uses == 2)
end
