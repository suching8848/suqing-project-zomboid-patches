local Bridge = {}
local KEY = "SuQingLiveWireISACompat_4221"
local ISA, LW, store, byPosition

local function position(x, y, z)
    return LiveWire.posKey(x, y, z)
end

local function marker(object)
    return object and object:getModData()[KEY]
end

local function gridLink(grid)
    local link = Bridge.ready and grid and store.links[grid.id]
    if link and link.inverter == grid.inverter then return link end
end

local function enrolled(bank, object)
    if not Bridge.ready then return false end
    local link = byPosition[position(bank.x, bank.y, bank.z)]
    if not link or (object and marker(object) ~= link.token) then return false end
    return gridLink(LW.grid(link.grid)) == link
end

local function bankForGrid(grid)
    local link = gridLink(grid)
    if not link then return nil end
    local bank, object = ISA.resolve(link.x, link.y, link.z)
    if bank and marker(object) == link.token then return bank, link end
    return nil, link
end

local function managedBackup(generator)
    if not Bridge.ready then return false end
    local mark = LiveWire.Backup.markOf(generator)
    local device = mark and LiveWire.Registry.device(mark.id)
    local grid = device and LW.grid(device.grid)
    return gridLink(grid) ~= nil and LW.ownsBackup(grid, generator)
end

function Bridge.install(isa, lw, gate, portalAdapter, portalVersion, wireVersion)
    ISA, LW = isa, lw
    if not Bridge.installed then
        local recipes = require "SuQingLiveWireISACompat/BatteryRecipes"
        local ready, reason = LW.install({
            bankForGrid = bankForGrid,
            snapshot = ISA.snapshot,
            commit = ISA.commit,
            watts = ISA.watts,
            markBattery = recipes.mark,
            verify = gate.fromMod,
        }, wireVersion)
        assert(ready, "Live Wire adapter refused initialization: " .. tostring(reason))
        ready, reason = ISA.install(enrolled, managedBackup, gate.fromMod)
        assert(ready, "ISA adapter refused initialization: " .. tostring(reason))
        ready, reason = recipes.install(ISA.capacityKWh, gate.fromMod, function() return Bridge.ready end)
        assert(ready, "ISA battery recipes refused initialization: " .. tostring(reason))
        if portalVersion then
            assert(portalAdapter.install(SuQingPortals.Power, LW, gridLink, managedBackup, portalVersion,
                gate.fromMod), "portal adapter refused initialization")
        end
        Bridge.installed = true
    end

    local saved = ModData.getOrCreate(KEY)
    if saved.schema == nil then
        for _ in pairs(saved) do error("unsupported bridge save data") end
        saved.schema, saved.links, saved.nextId = 1, {}, 1
    end
    assert(saved.schema == 1 and type(saved.links) == "table" and type(saved.nextId) == "number"
        and saved.nextId >= 1 and saved.nextId < 1000000000 and saved.nextId % 1 == 0,
        "unsupported bridge save data")
    local positions = {}
    for id, link in pairs(saved.links) do
        assert(type(link) == "table" and type(id) == "string" and id == link.grid
            and type(link.token) == "string" and type(link.inverter) == "string"
            and type(link.x) == "number" and type(link.y) == "number" and type(link.z) == "number",
            "invalid bridge association")
        local key = position(link.x, link.y, link.z)
        assert(not positions[key], "duplicate bridge association")
        positions[key] = link
    end
    store, byPosition = saved, positions
    Bridge.ready = true
end

function Bridge.bankAt(square)
    if not Bridge.ready or not square then return nil end
    return ISA.resolve(square:getX(), square:getY(), square:getZ())
end

function Bridge.inverterGrid(object)
    return Bridge.ready and LW.gridForInverter(object) or nil
end

function Bridge.linkFor(bank, object)
    if not Bridge.ready then return nil end
    local link = byPosition[position(bank.x, bank.y, bank.z)]
    if link and marker(object) == link.token then return link end
end

local function nearby(player, square)
    local commands = LiveWire.Commands
    return player and not player:isDead() and not player:getVehicle() and square
        and commands.isNear(player, square:getX(), square:getY(), square:getZ(), commands.ACT_RANGE)
end

local function removeLink(link)
    store.links[link.grid] = nil
    byPosition[position(link.x, link.y, link.z)] = nil
end

local function syncGrid(grid)
    LW.forget(grid)
    LW.refresh(grid)
end

function Bridge.attach(player, bankObject, inverterObject)
    if not Bridge.ready then return false, "Unavailable" end
    local bankSquare = bankObject and bankObject:getSquare()
    local invSquare = inverterObject and inverterObject:getSquare()
    local bank, object = Bridge.bankAt(bankSquare)
    local grid = Bridge.inverterGrid(inverterObject)
    if not bank or object ~= bankObject or not grid or bankSquare == invSquare or not nearby(player, invSquare) then
        return false, "InvalidTarget"
    end
    local distance, floors = LiveWire.Install.distance(
        bank.x, bank.y, bank.z, invSquare:getX(), invSquare:getY(), invSquare:getZ())
    if distance > LiveWire.Config.get("LinkRange") or floors > LiveWire.Config.get("LinkVerticalRange") then
        return false, "OutOfRange"
    end
    local key = position(bank.x, bank.y, bank.z)
    local old = byPosition[key]
    if old and marker(object) ~= old.token then
        -- The exact resolved object is a replacement at this tile.
        removeLink(old)
    end
    if byPosition[key] or store.links[grid.id] then return false, "AlreadyLinked" end
    if bank.conGenerator then
        local generator = ISA.backup(bank)
        if not generator or generator:isActivated() or not generator:isConnected() then
            return false, "StopBackup"
        end
    end
    if not ISA.snapshot(bank) then return false, "InvalidTarget" end

    if not LW.refresh(grid) then return false, "Unavailable" end
    local link = { grid = grid.id, inverter = grid.inverter, x = bank.x, y = bank.y, z = bank.z,
        token = grid.id .. ":" .. tostring(store.nextId) }
    store.nextId = store.nextId + 1
    if not ISA.projectOff(bank, object) then return false, "Unavailable" end
    object:getModData()[KEY] = link.token
    store.links[grid.id], byPosition[key] = link, link
    syncGrid(grid)
    return true, "Joined"
end

function Bridge.selectable(player, object)
    if not Bridge.ready or not object then return false end
    local square = object:getSquare()
    if not nearby(player, square) then return false end
    local bank, current = Bridge.bankAt(square)
    return bank ~= nil and current == object
end

function Bridge.detach(player, object)
    if not Bridge.selectable(player, object) then return false, "InvalidTarget" end
    local bank = Bridge.bankAt(object:getSquare())
    local link = Bridge.linkFor(bank, object)
    if not link then return false, "InvalidTarget" end
    local grid = LW.grid(link.grid)
    if grid and bank.conGenerator then
        local generator = ISA.backup(bank)
        if generator then
            if LW.ownsBackup(grid, generator) then return false, "UnlinkBackup" end
        else
            local ref = bank.conGenerator
            for _, backup in ipairs(LW.backups(grid)) do
                if backup.x == ref.x and backup.y == ref.y and backup.z == ref.z then
                    return false, "UnlinkBackup"
                end
            end
        end
    end
    if grid then LW.refresh(grid) end
    removeLink(link)
    object:getModData()[KEY] = nil
    local ok, restored = pcall(ISA.resume, bank)
    if not ok or not restored then
        object:getModData()[KEY] = link.token
        store.links[link.grid], byPosition[position(link.x, link.y, link.z)] = link, link
        ISA.projectOff(bank, object)
        return false, "Unavailable"
    end
    if grid then syncGrid(grid) end
    return true, "Detached"
end

function Bridge.onObjectRemoved(object)
    if not Bridge.ready or not object:getSquare() or not object:hasModData() then return end
    local square = object:getSquare()
    local link = byPosition[position(square:getX(), square:getY(), square:getZ())]
    if not link or marker(object) ~= link.token then return end
    removeLink(link)
    object:getModData()[KEY] = nil
    local grid = LW.grid(link.grid)
    if grid then LW.forget(grid) end
end

function Bridge.restoreProjection()
    if not Bridge.ready then return end
    for id in pairs(store.links) do
        local bank = bankForGrid(LW.grid(id))
        if bank then ISA.projectOff(bank, bank:getIsoObject()) end
    end
end

return Bridge
