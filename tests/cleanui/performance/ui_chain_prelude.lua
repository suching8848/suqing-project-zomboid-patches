-- Model the observed lifecycle: Pinyin captures at file load and assigns at
-- OnGameStart, while Neat wraps renderer at OnGameBoot. This is a call-chain
-- regression, not a replacement for gameplay validation of either mod.
local captured=ISInventoryPane.refreshContainer
Events.OnGameStart.Add(function()
    ISInventoryPane.refreshContainer=function(self,...)
        PerfTest.pinyinCalls=(PerfTest.pinyinCalls or 0)+1
        return captured(self,...)
    end
end)
Events.OnGameBoot.Add(function()
    local render=ISInventoryPane.renderdetails
    ISInventoryPane.renderdetails=function(self,...)
        PerfTest.neatCalls=(PerfTest.neatCalls or 0)+1
        return render(self,...)
    end
end)
