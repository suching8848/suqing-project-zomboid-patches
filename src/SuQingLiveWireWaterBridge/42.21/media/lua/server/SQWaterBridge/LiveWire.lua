local Adapter = {}
SQWaterBridge = SQWaterBridge or {}
local Bridge = SQWaterBridge
Bridge.LiveWire = Adapter

local UNITS_PER_LITRE = 100
-- The engine stores float amounts and discards at most 0.0001 L per fluid component.
local FLUID_EPSILON = 0.00025
local installedStep, supplies

local function registry()
    local reg = LiveWire and LiveWire.Registry
    if reg and reg.ready and not reg.readOnly then return reg end
end

function Adapter.getPump(key)
    local reg = registry()
    local dev = reg and type(key) == "string" and reg.device(key)
    if not dev or dev.role ~= "pump" then return nil end
    local cell = getCell()
    local square = cell and cell:getGridSquare(dev.x, dev.y, dev.z)
    local obj = square and LiveWire.Marks.findOnSquare(square, dev.id)
    if obj and LiveWire.Defs.modelOfObject(obj) == dev.model then return dev, obj end
end

local function hasNativeOutlet(dev)
    local pump = LiveWire.Pump
    for _, pos in pairs(dev.relays or {}) do
        local relay = pump.findRelay(pos.x, pos.y, pos.z)
        local mark = relay and relay:getModData()[LiveWire.Defs.RELAY_KEY]
        if mark and mark.pump == dev.id and pump.feedsPlumbedFixture(pos.x, pos.y, pos.z) then
            return true
        end
    end
    return false
end

function Adapter.canBind(dev)
    if not dev or Adapter.getPump(dev.id) ~= dev then return false, "pump_unavailable" end
    if hasNativeOutlet(dev) then return false, "native_outlet" end
    return true
end

local function setState(dev, state)
    if dev.state ~= state then
        dev.state = state
        LiveWire.Devices.syncMark(dev)
    end
end

local function availableSources(dev)
    local sources = {}
    for key, pos in pairs(dev.barrels or {}) do
        local obj = LiveWire.Pump.findBarrel(dev, key)
        if obj and LiveWire.Install.barrelState(obj) == "ok" then
            local fc = obj:getFluidContainer()
            local amount = fc:getAmount()
            local clean = fc:getSpecificFluidAmount(Fluid.Water)
            local tainted = fc:getSpecificFluidAmount(Fluid.TaintedWater)
            if amount >= 1 / UNITS_PER_LITRE and fc:isWaterOnlySource()
                and math.abs(amount - clean - tainted) <= 0.0001
                and (clean <= 0 or fc:canAddFluid(Fluid.Water))
                and (tainted <= 0 or fc:canAddFluid(Fluid.TaintedWater)) then
                -- Waterpipes represents a mixture by its tainted medium.
                local medium = tainted > 0 and "TaintedWater" or "Water"
                sources[#sources + 1] = { key = key, pos = pos, obj = obj, fc = fc, amount = amount, medium = medium }
            end
        end
    end
    table.sort(sources, function(a, b)
        if a.amount == b.amount then return a.key < b.key end
        return a.amount > b.amount
    end)
    return sources
end

local function addWater(fc, clean, tainted)
    if clean > 0 then fc:addFluid(Fluid.Water, clean) end
    if tainted > 0 then fc:addFluid(Fluid.TaintedWater, tainted) end
end

local function transferSource(binding, source, budget, deliver)
    local fc = source.fc
    local available = math.min(budget, math.floor(fc:getAmount() * UNITS_PER_LITRE))
    local drawn, lastUnits, cleanPerUnit, taintedPerUnit = 0, 0, 0, 0

    local function withdraw(units)
        if type(units) ~= "number" or units <= 0 or units ~= math.floor(units) or units > available - drawn then
            return 0
        end
        local litres = units / UNITS_PER_LITRE
        local before = fc:getAmount()
        if before + FLUID_EPSILON < litres then return 0 end
        local clean = fc:getSpecificFluidAmount(Fluid.Water)
        local tainted = fc:getSpecificFluidAmount(Fluid.TaintedWater)
        fc:removeFluid(litres)
        local removed = before - fc:getAmount()
        local cleanRemoved = clean - fc:getSpecificFluidAmount(Fluid.Water)
        local taintedRemoved = tainted - fc:getSpecificFluidAmount(Fluid.TaintedWater)
        if math.abs(removed - litres) > FLUID_EPSILON then
            addWater(fc, cleanRemoved, taintedRemoved)
            if math.abs(fc:getAmount() - before) > FLUID_EPSILON then
                error("collector rejected withdrawal rollback")
            end
            return 0
        end
        drawn = drawn + units
        lastUnits = units
        cleanPerUnit = cleanRemoved / units
        taintedPerUnit = taintedRemoved / units
        return units
    end

    local function refund(units)
        if type(units) ~= "number" or units <= 0 or units ~= math.floor(units) or units > lastUnits then
            error("invalid collector refund")
        end
        local clean, tainted = units * cleanPerUnit, units * taintedPerUnit
        local before = fc:getAmount()
        addWater(fc, clean, tainted)
        if math.abs(fc:getAmount() - before - clean - tainted) > FLUID_EPSILON then
            error("collector rejected refund")
        end
        drawn = drawn - units
        lastUnits = lastUnits - units
    end

    local ok, accepted = pcall(deliver, binding, source.medium, available, source.pos, withdraw, refund)
    if not ok then
        LiveWire.warn("Waterpipes transfer failed: " .. tostring(accepted))
    elseif accepted ~= drawn then
        LiveWire.warn("Waterpipes transfer reported a volume different from the collector withdrawal")
    end
    return drawn, ok and accepted == drawn
end

-- Called once by the Waterpipes authority cycle before native sprinkler watering.
function Adapter.feed(dev, binding, deliver)
    if not Adapter.canBind(dev) then return 0 end
    local pump, defs = LiveWire.Pump, LiveWire.Defs
    if pump.disabled() then return 0 end
    dev.budget = 0
    if (dev.cond or 0) <= 0 then
        setState(dev, "broken")
        return 0
    end
    local reg = registry()
    local grid = dev.grid and reg.grid(dev.grid)
    local inverter = grid and reg.device(grid.inverter)
    local provider = Bridge.circuitProvider
    local powered = inverter and inverter.state == "on" and (inverter.cond or 0) > 0
    if powered then
        if supplies then
            powered = supplies(grid, dev, "equipment")
        else
            powered = grid.powered == true and not grid.mainOff and not grid.equipmentOff
                and not (provider and provider.deviceBlocked(dev))
        end
    end
    if not powered then
        setState(dev, "nopower")
        return 0
    end
    local sources = availableSources(dev)
    if #sources == 0 then
        setState(dev, "nobarrel")
        return 0
    end

    local budget = math.floor(math.min(defs.PUMP_BUDGET_MAX, defs.PUMP_LITRES_PER_MINUTE) * UNITS_PER_LITRE)
    local moved = 0
    for _, source in ipairs(sources) do
        if moved >= budget then break end
        local drawn, complete = transferSource(binding, source, budget - moved, deliver)
        if drawn > 0 then
            moved = moved + drawn
            dev.pumped = (dev.pumped or 0) + drawn / UNITS_PER_LITRE
            source.obj:sync()
        end
        if not complete then break end
    end
    if moved > 0 then
        setState(dev, "running")
        local radius = defs.PUMP_NOISE_RADIUS
        if radius > 0 then addSound(nil, dev.x, dev.y, dev.z, radius, 1) end
    else
        setState(dev, "idle")
    end
    return moved
end

function Adapter.install(bridge)
    if not LiveWire or not bridge.sourceVersion or LiveWire.VERSION ~= bridge.sourceVersion then return false end
    local pump = LiveWire.Pump
    if not pump or type(pump.step) ~= "function" or type(pump.findBarrel) ~= "function"
        or type(pump.findRelay) ~= "function" or type(pump.feedsPlumbedFixture) ~= "function"
        or type(pump.disabled) ~= "function" or type(pump.demandW) ~= "function"
        or not LiveWire.Registry or not LiveWire.Marks or not LiveWire.Install or not LiveWire.Devices then
        return false
    end
    if (bridge.sourceVersion == "2.1.4" or bridge.sourceVersion == "2.1.5" or bridge.sourceVersion == "2.1.6" or bridge.sourceVersion == "2.1.8" or bridge.sourceVersion == "2.2.0")
        and (not LiveWire.Config or type(LiveWire.Config.pumpTankLitres) ~= "function") then return false end
    if installedStep then return pump.step == installedStep end
    local provider
    if bridge.sourceVersion == "2.0.0" or bridge.sourceVersion == "2.0.2"
        or bridge.sourceVersion == "2.0.3" or bridge.sourceVersion == "2.1.0"
        or bridge.sourceVersion == "2.1.1" or bridge.sourceVersion == "2.1.2"
        or bridge.sourceVersion == "2.1.3" or bridge.sourceVersion == "2.1.4" or bridge.sourceVersion == "2.1.5" or bridge.sourceVersion == "2.1.6" or bridge.sourceVersion == "2.1.8" or bridge.sourceVersion == "2.2.0" then
        provider = LiveWire.CircuitProvider
        if not provider or type(provider.deviceBlocked) ~= "function" or type(provider.blocked) ~= "function"
            or type(pump.checkBarrels) ~= "function" then return false end
    end
    if bridge.sourceVersion == "2.2.0" then
        local inverters = LiveWire.Inverters
        if not inverters or type(inverters.supplies) ~= "function" then return false end
        supplies = inverters.supplies
    end
    local previousStep = pump.step
    installedStep = function(dev)
        -- Live Wire owns native outlets and resizes their relay tanks during its original step.
        if not bridge.getBinding(dev) or hasNativeOutlet(dev) then return previousStep(dev) end
        if provider and not pump.disabled() and getCell():getGridSquare(dev.x, dev.y, dev.z)
            and pump.checkBarrels(dev) then LiveWire.Devices.syncMark(dev) end
    end
    pump.step = installedStep
    bridge.circuitProvider = provider
    return true
end

return Adapter
