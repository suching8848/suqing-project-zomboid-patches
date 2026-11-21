local function enter()
    local bridge = SuQingViewpointAimEnhancementBridge
    if bridge then bridge.enter() end
end

local function leave()
    local bridge = SuQingViewpointAimEnhancementBridge
    if bridge then bridge.leave() end
end

Events.OnGameStart.Add(enter)
Events.OnMainMenuEnter.Add(leave)
