SQWaterBridge = SQWaterBridge or {}
local Bridge = SQWaterBridge
local SAVE_KEY = "SuQingLiveWireWaterBridge"
local SCHEMA = 1

Bridge.directions = {
    { dx = 1, dy = 0, dir = "w", label = "East" },
    { dx = -1, dy = 0, dir = "e", label = "West" },
    { dx = 0, dy = 1, dir = "n", label = "South" },
    { dx = 0, dy = -1, dir = "s", label = "North" },
}

function Bridge.ensureReady()
    local lw = LiveWire
    if not Bridge.sourceVersion or not lw or lw.VERSION ~= Bridge.sourceVersion
        or not lw.Registry or not lw.Registry.ready or lw.Registry.readOnly
        or not lw.Circuits or not lw.Pump then return false end
    if not Bridge.installed then
        Bridge.installed = Bridge.LiveWire.install(Bridge) == true
    end
    return Bridge.installed
end

local function validCoord(value)
    return type(value) == "number" and math.abs(value) < 1000000 and value % 1 == 0
end

function Bridge.getConnection()
    local data = ModData.get(SAVE_KEY)
    local c = data and data.schema == SCHEMA and data.connection
    if type(c) ~= "table" or type(c.pumpKey) ~= "string" or not string.match(c.pumpKey, "^d%d+$")
        or not validCoord(c.x) or not validCoord(c.y) or not validCoord(c.z)
        or not validCoord(c.pumpX) or not validCoord(c.pumpY) then return nil end
    for _, direction in ipairs(Bridge.directions) do
        if c.dir == direction.dir and c.x == c.pumpX + direction.dx and c.y == c.pumpY + direction.dy then
            return c
        end
    end
end

function Bridge.getBinding(dev)
    local c = Bridge.getConnection()
    if c and dev.id == c.pumpKey and dev.x == c.pumpX and dev.y == c.pumpY and dev.z == c.z then return c end
end

function Bridge.connect(pumpKey, direction)
    if not Bridge.ensureReady() then return false, "Unavailable" end
    local data = ModData.get(SAVE_KEY)
    if data and data.schema ~= SCHEMA then return false, "Unavailable" end
    local current = Bridge.getConnection()
    -- Do not replace a persisted binding just because its pump is temporarily unloaded.
    if current and current.pumpKey ~= pumpKey and LiveWire.Registry.device(current.pumpKey) then
        return false, "OnePump"
    end
    local dev = Bridge.LiveWire.getPump(pumpKey)
    if not dev or not Bridge.LiveWire.canBind(dev) then return false, "PumpInUse" end
    local binding = {
        pumpKey = dev.id, pumpX = dev.x, pumpY = dev.y,
        x = dev.x + direction.dx, y = dev.y + direction.dy, z = dev.z, dir = direction.dir,
    }
    local allowed, reason = Bridge.Waterpipes.canConnect(binding)
    if not allowed then return false, reason end
    data = ModData.getOrCreate(SAVE_KEY)
    data.schema = SCHEMA
    data.connection = binding
    return true, "Connected"
end

function Bridge.disconnect(pumpKey)
    local data = ModData.get(SAVE_KEY)
    local c = Bridge.getConnection()
    if not data or not c or c.pumpKey ~= pumpKey then return false, "Unavailable" end
    data.connection = nil
    return true, "Disconnected"
end
