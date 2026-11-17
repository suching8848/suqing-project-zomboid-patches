SQWaterBridge = SQWaterBridge or {}
local Bridge = SQWaterBridge
local Native = {}
Bridge.Native = Native

local linked = {}

local function loadUsefulBarrels()
    local mods = type(getActivatedMods) == "function" and getActivatedMods()
    if not mods or not mods:contains("UsefulBarrelsMP") then return nil end
    local ok, api = pcall(require, "UB_Barrel")
    if ok and type(api) == "table" and type(api.validate) == "function" then return api end
end

local usefulBarrels = loadUsefulBarrels()


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

local function addWater(fc, medium, units)
    if not fc or type(units) ~= "number" or units <= 0 then return 0 end
    if medium ~= "Water" and medium ~= "TaintedWater" then return 0 end
    local before = fc:getAmount()
    local requested = math.min(units / 100, fc:getCapacity() - before)
    if requested <= 0 then return 0 end
    fc:addFluid(Fluid[medium], requested)
    local accepted = (fc:getAmount() - before) * 100
    if accepted <= 0 then return 0 end
    return accepted, before
end

local function addToCollector(barrel, medium, units)
    if not barrel or LiveWire.Install.barrelState(barrel) ~= "ok" then return 0 end
    return addWater(barrel:getFluidContainer(), medium, units)
end

local function poweredPump(cell, pump)
    local square = pump and cell:getGridSquare(pump.x, pump.y, pump.z)
    return square and square:haveElectricity() and WPIso.GetPump(square)
end

local function usefulBarrelAt(square)
    local objects = square:getObjects()
    local barrel, container
    for index = 0, objects:size() - 1 do
        local obj = objects:get(index)
        if not instanceof(obj, "IsoWorldInventoryObject") and usefulBarrels.validate(obj)
            and not obj:getUsesExternalWaterSource() then
            local fc = obj:getFluidContainer()
            if fc and fc:getCapacity() > 0 then
                if barrel then return nil end
                barrel, container = obj, fc
            end
        end
    end
    return barrel, container
end

-- A Waterpipes outlet can reach an opened Useful Barrels object on the next tile.
-- The fixture owns its water. Waterpipes keeps no virtual barrel row for it.
function Native.pourUsefulBarrel(x, y, z, direction, medium, units, pump)
    local settings = SandboxVars and SandboxVars.UsefulBarrels
    if not usefulBarrels or not settings or settings.AllowWater ~= true
        or (medium ~= "Water" and medium ~= "TaintedWater") then return false end
    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    if not square or WPIso.GetBarrel(square) then return false end
    local barrel, fc = usefulBarrelAt(square)
    if not barrel then return false end
    local inlet
    for _, step in ipairs(Bridge.directions) do
        if step.dir == direction then
            inlet = cell:getGridSquare(x - step.dx, y - step.dy, z)
            break
        end
    end
    if not inlet or not WPIso.GetPipe(inlet) or not poweredPump(cell, pump) then return false end

    local water = fc:getSpecificFluidAmount(Fluid.Water) + fc:getSpecificFluidAmount(Fluid.TaintedWater)
    if fc:getAmount() - water > 0.001 or not fc:canAddFluid(Fluid[medium]) then return false end
    local accepted, before = addWater(fc, medium, units)
    if accepted <= 0 then return false end
    LuaEventManager.triggerEvent("OnWaterAmountChange", barrel, before)
    barrel:sync()
    return true
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
    if not poweredPump(getCell(), pump) then return 0 end
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
