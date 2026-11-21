if isClient() or isServer() then return end

local Bridge = require "SuQingLiveWireISACompat/Bridge"
local Gate = require "SuQingLiveWireISACompat/Gate"
SuQingLiveWireISACompatBridge = Bridge

local function initialize()
    Bridge.ready = false
    local ok, reason = pcall(function()
        local allowed, portalVersion, wireVersion = Gate.check()
        if not allowed then error(portalVersion) end
        Bridge.install(
            require "SuQingLiveWireISACompat/ISA",
            require "SuQingLiveWireISACompat/LiveWire",
            Gate,
            require "SuQingLiveWireISACompat/Portals",
            portalVersion, wireVersion)
    end)
    if not ok then
        print("[SuQingLiveWireISACompat] inactive: " .. tostring(reason))
        return
    end
    print("[SuQingLiveWireISACompat] 0.1.3-rc.15 ready")
end

Events.OnInitGlobalModData.Add(initialize)
Events.OnGameStart.Add(Bridge.restoreProjection)
Events.OnObjectAboutToBeRemoved.Add(Bridge.onObjectRemoved)
