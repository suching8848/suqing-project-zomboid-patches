-- Load the installed LiveWire module once, extending its equipment recovery check when reviewed.
local Source = require "SuQingLiveWireLongCable/Source"
local Cable = require "SuQingLiveWireLongCable/Core"
if LiveWire and LiveWire.Devices then return end

local original = assert(Source.read(Source.devices), "[SQLongCable] could not read installed LiveWire devices")
local filename = Source.filename(Source.devices)
local ok, patched = pcall(function()
    if not Source.supported(Source.devices, original) then return nil end
    local anchor = 'if dist > LiveWire.Config.get("LinkRange") or dz > LiveWire.Config.get("LinkVerticalRange") then'
    local first, last = original:find(anchor, 1, true)
    assert(first and not original:find(anchor, last + 1, true), "unexpected recovery condition")
    local line = 'if dist > SQLongCable.rangeForModel(dev.model) or dz > LiveWire.Config.get("LinkVerticalRange") then'
    return assert(loadstring(original:sub(1, first - 1) .. line .. original:sub(last + 1), filename))
end)
if ok and patched then
    patched()
    Cable.recoveryFind = LiveWire.Devices.find
    Cable.recoveryReady = true
    print("[SQLongCable] verified LiveWire device recovery")
else
    assert(loadstring(original, filename))()
    print("[SQLongCable] original LiveWire device recovery: " .. (ok and "upstream or game build differs" or tostring(patched)))
end
