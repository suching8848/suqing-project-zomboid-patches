SQWaterBridge = SQWaterBridge or {}
local Bridge = SQWaterBridge
local Native = {}
Bridge.Native = Native

local linked = {}

function Native.prepare(gmd)
    linked = {}
    for _, dev in pairs(LiveWire.Registry.devices()) do
        if dev.role == "pump" then
            for key, pos in pairs(dev.barrels or {}) do
                local id = WPUtils.Coords2Id(pos.x, pos.y, pos.z)
                if gmd.Barrels[id] then
                    local refs = linked[id] or {}
                    refs[#refs + 1] = { dev = dev, key = key }
                    linked[id] = refs
                end
            end
        end
    end
end

local function sharedBarrel(x, y, z)
    local refs = linked[WPUtils.Coords2Id(x, y, z)]
    if not refs then return nil, false end
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return nil, true end
    local rain = SRainBarrelSystem and SRainBarrelSystem.instance
    if rain and rain:getLuaObjectAt(x, y, z) then return nil, false end
    local wpBarrel = WPIso.GetBarrel(sq)
    local sprite = wpBarrel and wpBarrel:getSprite()
    if not sprite or not string.match(sprite:getName(), "^carpentry_02_12[0-7]$")
        or not LiveWire.Install.isBarrelObject(wpBarrel) then return nil, false end
    for _, ref in ipairs(refs) do
        if LiveWire.Pump.findBarrel(ref.dev, ref.key) == wpBarrel then return wpBarrel, true end
    end
    -- A missing or mismatched link must not hydrate another object on the tile.
    return nil, true
end

local function addToCollector(barrel, medium, units)
    if not barrel or type(units) ~= "number" or units <= 0 then return 0 end
    if medium ~= "Water" and medium ~= "TaintedWater" then return 0 end
    if LiveWire.Install.barrelState(barrel) ~= "ok" then return 0 end
    local fc = barrel:getFluidContainer()
    local before = fc:getAmount()
    local requested = math.min(units / 100, fc:getCapacity() - before)
    if requested <= 0 then return 0 end
    fc:addFluid(Fluid[medium], requested)
    local accepted = (fc:getAmount() - before) * 100
    if accepted <= 0 then return 0 end
    return accepted
end

function Native.syncBarrel(barrel)
    local obj, managed = sharedBarrel(barrel.x, barrel.y, barrel.z)
    if not managed then return WPIso.SyncBarrel(barrel) end
    -- Drain any pre-existing Waterpipes buffer only by the physical amount received.
    local accepted = addToCollector(obj, barrel.m, barrel.w)
    if accepted > 0 then
        barrel.w = math.max(0, barrel.w - accepted)
        obj:sync()
    end
end

function Native.pourBarrel(x, y, z, medium, units, pump)
    local obj, managed = sharedBarrel(x, y, z)
    if not managed then return WPVirtual.BarrelPourIn(x, y, z, medium, units) end
    local square = pump and getCell():getGridSquare(pump.x, pump.y, pump.z)
    if not square or not square:haveElectricity() or not WPIso.GetPump(square) then return 0 end
    local accepted = addToCollector(obj, medium, units)
    if accepted > 0 then obj:sync() end
    return accepted
end

function Native.syncPump(pump)
    local sq = getCell():getGridSquare(pump.x, pump.y, pump.z)
    local obj = sq and WPIso.GetPump(sq)
    local grid = obj and LiveWire.Circuits.owner(obj)
    local provider = Bridge.circuitProvider
    local panelBlocked = grid and (grid.mainOff or grid.equipmentOff or (not grid.powered and not sq:haveElectricity()))
    if panelBlocked or (obj and provider and provider.blocked(obj, "equipment", grid)) then
        if obj:isActivated() then
            obj:setActivated(false)
            obj:sendObjectChange(IsoObjectChange.DRYER_STATE)
        end
        -- Keep the Waterpipes switch setting while skipping wear and flow this minute.
        return true
    end
    if grid then
        -- A source removed from a loaded, controlled pump cannot keep feeding the line.
        pump.source = nil
    end
    WPIso.SyncPump(pump)
    return false
end
