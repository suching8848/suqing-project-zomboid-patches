-- Authority-side adapter for the reviewed LiveWire simulations.
local Bridge = {}
local hooks, active, nativeMembersByRole
local observed = {}
local EPSILON = 1e-8
local MAX_OBSERVED_INTERVAL_HOURS = 1 / 3
local runtimeVersions = {
    ["1.7.2"] = "1.7.2",
    ["2.0.0"] = "2.0.0",
    ["2.0.1"] = "2.0.0", -- This release kept the 2.0.0 runtime version.
    ["2.0.2"] = "2.0.2",
    ["2.0.3"] = "2.0.3",
    ["2.1.0"] = "2.1.0",
    ["2.1.1"] = "2.1.1",
    ["2.1.2"] = "2.1.2",
}

local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function registry()
    local r = LiveWire and LiveWire.Registry
    if r and r.ready and not r.readOnly then return r end
end

function Bridge.grid(id)
    local r = registry()
    return r and type(id) == "string" and r.grid(id) or nil
end

local function placedInverter(grid)
    if not grid or Bridge.grid(grid.id) ~= grid then return nil end
    local dev = LiveWire.Registry.device(grid.inverter)
    if not dev or dev.role ~= "inverter" or dev.coupled or dev.grid ~= grid.id then return nil end
    local sq = getCell():getGridSquare(dev.x, dev.y, dev.z)
    local obj = sq and LiveWire.Marks.findOnSquare(sq, dev.id)
    if obj and LiveWire.Defs.modelOfObject(obj) == dev.model then return dev, obj end
end

function Bridge.gridForInverter(obj)
    local r = registry()
    if not r or not obj then return nil end
    local mark = LiveWire.Marks.get(obj)
    local dev = mark and r.device(mark.id)
    local grid = dev and Bridge.grid(dev.grid)
    local inv, placed = placedInverter(grid)
    if placed == obj then return grid, inv end
end

function Bridge.ownsBackup(grid, gen)
    local r = registry()
    if not r or not grid or Bridge.grid(grid.id) ~= grid or not gen then return false end
    local mark = LiveWire.Backup.markOf(gen)
    local dev = mark and r.device(mark.id)
    return dev ~= nil and dev.role == "backup" and dev.grid == grid.id and grid.members[dev.id] == true
        and LiveWire.Backup.find(dev) == gen
end

local function powered(grid)
    local inv = placedInverter(grid)
    local anchor = inv and LiveWire.Registry.anchors[inv.id]
    return anchor ~= nil and anchor.on == true and inv.state == "on" and (inv.cond or 0) > 0
        and grid.powered == true and not grid.mainOff and not grid.equipmentOff
end

local function modernGridAt(r, object, x, y, z, radius, floors)
    local lw = LiveWire
    local owner = object and lw.Circuits.owner(object)
    if owner and owner.equipmentOff then return nil end

    local best, distance
    for id, anchor in pairs(r.anchors) do
        if anchor.on == true and lw.Coverage.covers(id, anchor, x, y, z, radius, floors) then
            local d = (x - anchor.x)^2 + (y - anchor.y)^2
            if not best or d < distance or (d == distance and id < best) then
                best, distance = id, d
            end
        end
    end
    local device = best and r.device(best)
    local grid = device and Bridge.grid(device.grid)
    if grid and powered(grid) and (not object or not lw.CircuitProvider.blocked(object, "equipment", owner or grid)) then
        return grid, r.device(grid.inverter)
    end
end

function Bridge.gridAt(square, object)
    local r = registry()
    if not r or not square or not square:haveElectricity() then return nil end
    local opts = getSandboxOptions()
    local exterior = opts and opts:getOptionByName("AllowExteriorGenerator")
    if exterior and not exterior:getValue() and square:getProperties():has(IsoFlagType.exterior) then return nil end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local radius, floors = LiveWire.Config.tileRange(), LiveWire.Config.verticalRange()
    if nativeMembersByRole then
        return modernGridAt(r, object, x, y, z, radius, floors)
    end
    if not IsoGenerator or not IsoGenerator.isPoweringSquare then return nil end
    local best, distance, owner, ownerDistance
    for _, inv in ipairs(r.invertersNear(x, y, radius)) do
        local grid = Bridge.grid(inv.grid)
        if grid and math.abs(z - inv.z) <= floors then
            local d = (x - inv.x)^2 + (y - inv.y)^2
            if not owner or d < ownerDistance or (d == ownerDistance and inv.id < owner.inverter) then
                owner, ownerDistance = grid, d
            end
            local anchor = r.anchors[inv.id]
            if anchor and anchor.on and IsoGenerator.isPoweringSquare(inv.x, inv.y, inv.z, x, y, z)
                and (not best or d < distance or (d == distance and inv.id < best.inverter)) then
                best, distance = grid, d
            end
        end
    end
    if owner and owner.equipmentOff then return nil end
    if best and powered(best) then return best, r.device(best.inverter) end
end

local function isaSnapshot(grid)
    local bank, link = hooks.bankForGrid(grid)
    return bank and hooks.snapshot(bank) or nil, link
end

local function coordinates(object)
    return { x = object.x, y = object.y, z = object.z }
end

local function nativeBatteryGroups(nativeBanks, batteries)
    local groups, charge, capacity, index = {}, 0, 0, 1
    for _, bank in ipairs(nativeBanks) do
        local group = coordinates(bank)
        group.id, group.chargeKWh, group.capacityKWh, group.batteries = bank.id, 0, 0, {}
        for _ = 1, #(bank.slots or {}) do
            local row = batteries[index]
            index = index + 1
            if row then
                local stored = row.charge * row.capacity
                group.batteries[#group.batteries + 1] = {
                    model = row.model, cond = row.cond, chargeKWh = stored, capacityKWh = row.capacity,
                }
                group.chargeKWh = group.chargeKWh + stored
                group.capacityKWh = group.capacityKWh + row.capacity
            end
        end
        charge = charge + group.chargeKWh
        capacity = capacity + group.capacityKWh
        groups[#groups + 1] = group
    end
    return groups, charge, capacity
end

local function monitorSnapshot(grid, state, link, nativeBanks, out)
    if not state then
        if link then return { status = "unloaded", cabinet = coordinates(link) } end
        return { status = "unpaired" }
    end

    local bank = state.bank
    local info = {
        status = "paired", cabinet = coordinates(bank), panelCount = bank.npanels or 0,
        panels = {}, batteries = {}, chargeKWh = 0, capacityKWh = 0,
    }
    for _, panel in ipairs(bank.panels or {}) do
        info.panels[#info.panels + 1] = coordinates(panel)
    end
    info.liveWireBanks, info.liveWireChargeKWh, info.liveWireCapacityKWh =
        nativeBatteryGroups(nativeBanks, out.batteries)

    local seen = observed[grid.id]
    local power = seen and seen.power
    if power and power.rev == grid.rev and seen.bank == bank and seen.object == state.object then
        info.productionW = power.isa
        info.liveWireProductionW = power.native
        info.backupProductionW = power.backup
    end
    for _, row in ipairs(state.batteries) do
        local model, cond = row.item:getFullType(), row.item:getCondition()
        info.chargeKWh = info.chargeKWh + row.chargeKWh
        info.capacityKWh = info.capacityKWh + row.capacityKWh
        info.batteries[#info.batteries + 1] = {
            model = model, cond = cond, chargeKWh = row.chargeKWh, capacityKWh = row.capacityKWh,
        }
        out.batteries[#out.batteries + 1] = {
            model = model, cond = cond, origin = "ISA",
            charge = row.capacityKWh > 0 and row.chargeKWh / row.capacityKWh or 0,
            capacity = row.capacityKWh, reserve = 0, cycles = 0,
        }
    end
    return info
end

local function collectISA(snapshot)
    local entries = {}
    for i, row in ipairs(snapshot.batteries) do
        if not finite(row.capacityKWh) or not finite(row.chargeKWh) or row.capacityKWh < 0
            or row.chargeKWh < 0 or row.chargeKWh > row.capacityKWh + EPSILON then
            error("invalid ISA battery energy")
        end
        -- No native model: Live Wire skips its own battery wear on these items.
        entries[i] = { capacity = row.capacityKWh, charge = row.chargeKWh }
    end
    return entries
end

local function restoreISA(snapshot, charges)
    local current = hooks.snapshot(snapshot.bank)
    if not current or current.container ~= snapshot.container or #current.batteries ~= #snapshot.batteries then
        return false
    end
    for i, row in ipairs(current.batteries) do
        local old = snapshot.batteries[i]
        if old.item ~= row.item or old.capacityKWh ~= row.capacityKWh then return false end
        row.chargeKWh = charges[i]
    end
    return hooks.commit(current)
end

local function writeExact(write, bank, rows)
    local expected = {}
    for i, row in ipairs(rows) do expected[i] = row.charge + row.reserve end
    write(bank, rows)
    for i, row in ipairs(rows) do
        local actual = row.charge + row.reserve
        if row.item then actual = LiveWire.Batteries.energy(row.item, row.warmCapacity) end
        if not finite(actual) or math.abs(actual - expected[i]) > EPSILON then
            error("native battery energy readback differs")
        end
    end
end

local function restoreNative(write, rows)
    local restored = true
    for i = #rows, 1, -1 do
        local before = rows[i]
        local ok = pcall(writeExact, write, before.bank, before.rows)
        if ok then before.bank.slots = before.slots else restored = false end
    end
    return restored
end

local function step(native, grid, now, weather, evaluate, snapshot)
    local previous = active
    local dt = math.max(0, math.min(LiveWire.Sim.MAX_CATCHUP_HOURS, now - (grid.lastTick or now)))
    active = {
        grid = grid, bank = { slots = {} }, snapshot = snapshot,
        entries = collectISA(snapshot), t0 = getGameTime():getTimeOfDay() - dt, weather = weather,
        nativeBefore = {},
    }
    local ok, err = pcall(native, grid, now, weather, evaluate)
    active = previous
    if not ok then error(err) end
end

function Bridge.install(adapter, wireVersion)
    if hooks then return hooks == adapter end
    if type(adapter) ~= "table" or type(adapter.bankForGrid) ~= "function"
        or type(adapter.snapshot) ~= "function" or type(adapter.commit) ~= "function" then return false end
    local lw = LiveWire
    if isClient() or isServer() or not lw then return false end
    local runtimeVersion = runtimeVersions[wireVersion]
    if not runtimeVersion or lw.VERSION ~= runtimeVersion then return false end
    local grouped = wireVersion ~= "1.7.2"
    local r, sim, physics, bat = lw.Registry, lw.Sim, lw.Physics, lw.Batteries
    if not r or not sim or not physics or not bat or not lw.Computer or not lw.Backup
        or not lw.Marks or not lw.Defs or not lw.Config or not lw.Demand or not lw.Circuits
        or not lw.Forecast or not lw.Devices or type(adapter.verify) ~= "function" then return false end
    local members, read, write = r.members, bat.read, bat.write
    local simulate, settle, snapshot, publish = sim.stepGrid, physics.stepGrid, sim.snapshot, sim.publish
    local record = lw.Computer.record
    local dropGrid = r.dropGrid
    local server, shared = "media/lua/server/LiveWire/", "media/lua/shared/LiveWire/"
    local checks = {
        { server .. "LW_Simulation.lua", { n = 4, simulate, sim.refresh, snapshot, publish } },
        { server .. "LW_Registry.lua", { n = 3, members, dropGrid, r.invertersNear } },
        { server .. "LW_Batteries.lua", { n = 5, read, write, bat.container, bat.energy, bat.setEnergy } },
        { server .. "LW_Computer.lua", { n = 1, record } },
        { server .. "LW_Backup.lua", { n = 3, lw.Backup.step, lw.Backup.find, lw.Backup.markOf } },
        { server .. "LW_Demand.lua", { n = 1, lw.Demand.measure } },
        { server .. "LW_Circuits.lua", { n = 1, lw.Circuits.owner } },
        { server .. "LW_Forecast.lua", { n = 1, lw.Forecast.build } },
        { server .. "LW_Devices.lua", { n = 1, lw.Devices.find } },
        { shared .. "LW_Physics.lua", { n = 1, settle } },
        { shared .. "LW_Config.lua", { n = 2, lw.Config.tileRange, lw.Config.verticalRange } },
        { shared .. "LW_Defs.lua", { n = 1, lw.Defs.modelOfObject } },
        { shared .. "LW_Marks.lua", { n = 2, lw.Marks.get, lw.Marks.findOnSquare } },
    }
    if grouped then
        if not lw.Inverters or not lw.Coverage or not lw.CircuitProvider then return false end
        checks[#checks + 1] = { server .. "LW_Registry.lua", { n = 1, r.membersByRole } }
        checks[#checks + 1] = { server .. "LW_Inverters.lua", { n = 1, lw.Inverters.idleW } }
        checks[#checks + 1] = { server .. "LW_Demand.lua", { n = 1, lw.Demand.measureGrid } }
        checks[#checks + 1] = { shared .. "LW_Coverage.lua", { n = 1, lw.Coverage.covers } }
        checks[#checks + 1] = { shared .. "LW_CircuitProvider.lua", { n = 1, lw.CircuitProvider.blocked } }
    end
    for _, check in ipairs(checks) do
        for i = 1, check[2].n do
            if not adapter.verify(check[2][i], "batman_LiveWire", check[1]) then return false, check[1] end
        end
    end

    hooks = adapter
    if grouped then nativeMembersByRole = r.membersByRole end
    r.dropGrid = function(grid)
        Bridge.forget(grid)
        return dropGrid(grid)
    end
    local function addBank(grid, banks)
        if active and active.grid == grid then table.insert(banks, 1, active.bank) end
    end
    if grouped then
        r.members = function(grid)
            local byRole = members(grid)
            addBank(grid, byRole.storage)
            return byRole
        end
    else
        r.members = function(grid)
            local sources, banks, options, backups, computers, pumps = members(grid)
            addBank(grid, banks)
            return sources, banks, options, backups, computers, pumps
        end
    end

    local function mark(rows)
        if not hooks.markBattery then return end
        for _, row in ipairs(rows) do
            if row.item then hooks.markBattery(row.item) end
        end
    end

    bat.read = function(bank)
        if not active then return read(bank) end
        if active.bank == bank then
            active.settling = true
            mark(active.snapshot.batteries)
            return active.entries
        end
        local rows = read(bank)
        if active.settling then mark(rows) end
        return rows
    end

    bat.write = function(bank, entries)
        if not active then return write(bank, entries) end
        if active.bank == bank then
            active.settling = false
            local changed, before = false, {}
            for i, row in ipairs(active.snapshot.batteries) do
                before[i] = row.chargeKWh
                changed = changed or math.abs(row.chargeKWh - entries[i].charge) > EPSILON
                row.chargeKWh = entries[i].charge
            end
            if changed then
                if not hooks.commit(active.snapshot) then error("ISA battery write rejected") end
                active.isaBefore = before
            end
            return
        end

        local ok, reason = pcall(function()
            active.nativeBefore[#active.nativeBefore + 1] = { bank = bank, rows = read(bank), slots = bank.slots }
            write(bank, entries)
        end)
        if not ok then
            local restored = restoreNative(write, active.nativeBefore)
            if active.isaBefore then
                local isaOK, isaRestored = pcall(restoreISA, active.snapshot, active.isaBefore)
                restored = restored and isaOK and isaRestored
            end
            -- Leave the elapsed clock advanced. Repeating this interval would
            -- bill a native backup generator and power history a second time.
            if not restored then error("mixed grid battery rollback failed: " .. tostring(reason)) end
            error(reason)
        end
    end

    physics.stepGrid = function(params)
        if active and active.settling then
            local watts = hooks.watts and hooks.watts(active.snapshot, active.t0 % 24, params.dt,
                active.weather) or active.snapshot.watts
            if not finite(watts) or watts < 0 then error("invalid ISA solar output") end
            active.t0 = active.t0 + params.dt
            active.watts = watts
            params.productionW = params.productionW + watts
        end
        return settle(params)
    end

    sim.stepGrid = function(grid, now, weather, evaluate)
        local state = isaSnapshot(grid)
        if not state or not placedInverter(grid) then
            observed[grid.id] = nil
            return simulate(grid, now, weather, evaluate)
        end
        local previous = observed[grid.id]
        observed[grid.id] = { bank = state.bank, object = state.object, at = now, watts = state.watts }
        local elapsed = now - (grid.lastTick or now)
        -- No ISA settlement while absent. A first observation and long gaps
        -- process elapsed native time first, then re-evaluate with ISA at dt=0.
        if elapsed > 0 and (not previous or previous.bank ~= state.bank or previous.object ~= state.object
            or previous.at ~= grid.lastTick or elapsed > MAX_OBSERVED_INTERVAL_HOURS) then
            simulate(grid, now, weather, evaluate)
            return step(simulate, grid, now, weather, true, state)
        end
        if previous and elapsed > 0 then state.previousWatts = previous.watts end
        return step(simulate, grid, now, weather, evaluate, state)
    end

    lw.Computer.record = function(grid, now, production, demand, fraction)
        local extra = active and active.grid == grid and active.watts or 0
        return record(grid, now, production + extra, demand, fraction)
    end

    sim.publish = function(grid)
        if active and active.grid == grid and active.watts then
            local production = grid.production or 0
            local backup = grid.backupW or 0
            local seen = observed[grid.id]
            if seen then
                -- Capture the same final step as the native totals before mixing.
                seen.power = {
                    rev = grid.rev, isa = active.watts, native = math.max(0, production - backup), backup = backup,
                }
            end
            grid.production = production + active.watts
            active.watts = nil
        end
        return publish(grid)
    end

    sim.snapshot = function(grid)
        local out = snapshot(grid)
        if not out then return nil end
        local inStep = active and active.grid == grid
        local state, link
        if inStep then
            state = active.snapshot
        else
            state, link = isaSnapshot(grid)
        end
        if not state then
            out.suqingISA = monitorSnapshot(grid, nil, link, nil, out)
            return out
        end
        if not inStep then out.banks = out.banks + 1 end
        -- The unwrapped membership order is the order of the native snapshot rows.
        local _, nativeBanks = members(grid)
        if grouped then nativeBanks = nativeMembersByRole(grid, "storage") end
        out.suqingISA = monitorSnapshot(grid, state, link, nativeBanks, out)
        return out
    end
    return true
end

function Bridge.refresh(grid)
    if not hooks or not placedInverter(grid) then return false end
    local sim = LiveWire.Sim
    local before = grid.rev
    sim.refresh(grid)
    return grid.rev ~= before
end

function Bridge.forget(grid)
    if grid then observed[grid.id] = nil end
end

function Bridge.backups(grid)
    local registry = LiveWire.Registry
    if nativeMembersByRole then return nativeMembersByRole(grid, "backup") end
    local _, _, _, backups = registry.members(grid)
    return backups
end

local function loadedNative(grid)
    local registry = LiveWire.Registry
    local _, banks
    if nativeMembersByRole then
        banks = nativeMembersByRole(grid, "storage")
    else
        _, banks = registry.members(grid)
    end
    local loaded = {}
    for _, bank in ipairs(banks) do
        local container = LiveWire.Batteries.container(bank)
        if container then
            loaded[#loaded + 1] = {
                bank = bank, container = container, rows = LiveWire.Batteries.read(bank), slots = bank.slots,
            }
        end
    end
    return loaded
end

-- Prepare and finish must run in one synchronous Lua call. Preparing does not
-- move energy. Finishing validates actual item identity and pre-debit energy.
function Bridge.prepareDraw(grid, requestedKWh)
    if not finite(requestedKWh) or requestedKWh <= 0 or not hooks or active or not placedInverter(grid)
        or not Bridge.refresh(grid) or not powered(grid) then return 0 end
    local isa = isaSnapshot(grid)
    if not isa then return 0 end
    local native = loadedNative(grid)
    local total = 0
    for _, row in ipairs(isa.batteries) do total = total + row.chargeKWh end
    for _, bank in ipairs(native) do
        for _, row in ipairs(bank.rows) do total = total + row.charge end
    end
    if not finite(total) or total <= EPSILON then return 0 end
    local available = math.min(requestedKWh, total)
    return available, { grid = grid, rev = grid.rev, isa = isa, native = native, total = total, available = available }
end

local function sameNative(prior, current)
    if #prior ~= #current then return false end
    for i, bank in ipairs(current) do
        local old = prior[i]
        if bank.bank ~= old.bank or bank.container ~= old.container or #bank.rows ~= #old.rows then return false end
        for j, row in ipairs(bank.rows) do
            local prev = old.rows[j]
            if row.item ~= prev.item or row.cond ~= prev.cond or row.capacity ~= prev.capacity
                or math.abs(row.charge - prev.charge) > EPSILON or math.abs(row.reserve - prev.reserve) > EPSILON then
                return false
            end
        end
    end
    return true
end

function Bridge.finishDraw(receipt, actualKWh)
    if type(receipt) ~= "table" or receipt.used then return false end
    receipt.used = true
    if not finite(actualKWh) or actualKWh < 0 or actualKWh > receipt.available + EPSILON then return false end
    actualKWh = math.min(actualKWh, receipt.available)
    if actualKWh == 0 then return true end
    local grid = receipt.grid
    if active or grid.rev ~= receipt.rev or not powered(grid) or hooks.bankForGrid(grid) ~= receipt.isa.bank then
        return false
    end
    local banks = loadedNative(grid)
    if not sameNative(receipt.native, banks) then return false end

    local share = 1 - actualKWh / receipt.total
    local charges = {}
    for i, row in ipairs(receipt.isa.batteries) do
        charges[i] = row.chargeKWh
        row.chargeKWh = row.chargeKWh * share
    end
    local ok, committed = pcall(hooks.commit, receipt.isa)
    if not ok then
        local checked, restored = pcall(restoreISA, receipt.isa, charges)
        if not checked or not restored then return false, "power_rollback_failed" end
        return false
    end
    if not committed then return false end

    local written = {}
    for i, bank in ipairs(banks) do
        for _, row in ipairs(bank.rows) do row.charge = row.charge * share end
        written[i] = receipt.native[i]
        local write = LiveWire.Batteries.write
        local wrote = pcall(writeExact, write, bank.bank, bank.rows)
        if not wrote then
            local restored = restoreNative(write, written)
            local isaOK, isaRestored = pcall(restoreISA, receipt.isa, charges)
            pcall(Bridge.refresh, grid)
            if not restored or not isaOK or not isaRestored then return false, "power_rollback_failed" end
            return false
        end
    end
    pcall(Bridge.refresh, grid)
    return true
end

return Bridge
