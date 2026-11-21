local Cable = require "SuQingLiveWireLongCable/Core"
if isClient() or isServer() then return Cable end
if SQLongCableAction then return Cable end

local Source = require "SuQingLiveWireLongCable/Source"
local ok, wire = pcall(function()
    local source = Source.read(Source.actions)
    if not Source.supported(Source.actions, source) then return nil end
    local complete = assert(source:find("function LWLinkAction:complete()", 1, true))
    local first = assert(source:find("    local kind = I().linkKind(target)\n", complete, true))
    local last = assert(source:find("\nfunction LWLinkAction.linkVanilla(", first, true))
    -- Reuse the checked upstream transaction from immediately after inverter and grid resolution.
    local prefix = [[
local function I() return LiveWire.Install end
local function R() return LiveWire.Registry end
local ELECTRIC_WIRE = "Base.ElectricWire"
local function deviceOf(obj) return SQLongCable.target(obj) end
return function(ch, target, inv, grid, wires)
]]
    return assert(loadstring(prefix .. source:sub(first, last - 1), "@SQLongCable/native-wiring"))()
end)
if not ok or type(wire) ~= "function" then
    print("[SQLongCable] long wiring unavailable: " .. (ok and "upstream or game build differs" or tostring(wire)))
    return Cable
end

require "LiveWire/TimedActions/LW_TimedActions"
Cable.wire = wire
SQLongCableAction = LWLinkAction:derive("SQLongCableAction")
SQLongCableAction.partners = {}

function SQLongCableAction:isValid()
    local master = LiveWire.Registry.device(self.masterId)
    return master == self.master and Cable.check(self.character, self.target, self.masterId)
end

function SQLongCableAction:complete()
    if not self:guard() then return false end
    local character = self.character
    local allowed, reason, arg, master, grid = Cable.check(character, self.target, self.masterId)
    if not allowed then
        LiveWire.notify(character, reason, { arg, master }, true)
        return false
    end
    if master ~= self.master then return false end
    return Cable.wire(character, self.target, master, grid, arg)
end

function SQLongCableAction:new(character, target, masterId)
    return LWBaseAction.new(self, character, {
        target = target, masterId = masterId, master = LiveWire.Registry.device(masterId),
    })
end

return Cable
