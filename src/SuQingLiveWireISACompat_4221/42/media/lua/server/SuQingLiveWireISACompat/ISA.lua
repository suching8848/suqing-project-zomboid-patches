-- The cabinet remains an ISA object. Its inventory items are the storage authority.
local ISA = {}
local namespace
local installed = false
local enrolled
local batteries
local nominalVolts = 12
local kWhPerAh = nominalVolts / 1000
local epsilon = 1e-9

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function ISA.ratedAh(item)
    local ah = item:getModData().ISA_maxCapacity
    if finite(ah) and ah > 0 and instanceof(item, "DrainableComboItem") then return ah end
end

function ISA.effectiveCapacityKWh(ah, condition)
    condition = math.max(0, math.min(100, condition))
    return ah * (1 - math.pow(1 - condition / 100, 6)) * kWhPerAh
end

local function capacityKWh(item)
    local ah = ISA.ratedAh(item)
    return ah and ISA.effectiveCapacityKWh(ah, item:getCondition()) or 0
end
ISA.capacityKWh = capacityKWh

local function readBatteries(container)
    local result = {}
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local capacity = capacityKWh(item)
        if capacity > 0 then
            local charge = batteries.energy(item, capacity)
            if not finite(charge) or charge < 0 or charge > capacity + epsilon then return nil end
            result[#result + 1] = {
                item = item,
                capacityKWh = capacity,
                chargeKWh = math.min(capacity, charge),
                initialKWh = math.min(capacity, charge),
            }
        end
    end
    return result
end

local function uniqueGenerator(square)
    local generator = square and square:getGenerator()
    if not generator then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object ~= generator and instanceof(object, "IsoGenerator") then return nil end
    end
    return generator
end

function ISA.resolve(x, y, z)
    local system = namespace and namespace.PBSystem_Server
    local bank = system and system:getLuaObjectAt(x, y, z)
    local object = bank and bank:getIsoObject()
    local square = object and object:getSquare()
    if not square or bank.luaSystem ~= system or uniqueGenerator(square) ~= object
        or not object:getContainer() or not system:isValidIsoObject(object) then
        return nil
    end
    return bank, object
end

local function backupSquare(bank)
    local link = bank and bank.conGenerator
    if type(link) ~= "table" or not finite(link.x) or not finite(link.y) or not finite(link.z) then return nil end
    return getCell():getGridSquare(link.x, link.y, link.z)
end

function ISA.backup(bank)
    if not namespace then return nil end
    local square = backupSquare(bank)
    local generator = uniqueGenerator(square)
    if not generator or namespace.WorldUtil.getType(generator) == "PowerBank"
        or generator:getModData().generatorFullType == "ISA.PowerBank_test" then
        return nil
    end
    return generator, square
end

function ISA.projectOff(bank, object)
    if not object or bank:getIsoObject() ~= object or not bank.luaSystem:isValidIsoObject(object) then
        return false
    end
    if object:isActivated() then object:setActivated(false) end
    return not object:isActivated()
end

local function refresh(bank, container)
    bank:calculateBatteryStats(container)
    bank:updateSprite()
    bank:saveData(true)
end

function ISA.resume(bank)
    local object = bank:getIsoObject()
    local container = object and object:getContainer()
    if not container or enrolled(bank, object) then return false end
    bank:calculateBatteryStats(container)
    bank:updateDrain()
    bank:updateGenerator()
    bank:updateSprite()
    bank:saveData(true)
    return true
end

function ISA.snapshot(bank)
    if not installed or not bank then return nil end
    local actual, object = ISA.resolve(bank.x, bank.y, bank.z)
    if actual ~= bank then return nil end
    local container = object:getContainer()
    local rows = readBatteries(container)
    local panels = bank.npanels or 0
    if not rows or not finite(panels) or panels < 0 then return nil end
    -- Native ISA output adds Ah each game hour. At 12 V this keeps its
    -- ideal recharge time, including the existing climate and sandbox factors.
    local watts = bank.luaSystem:getModifiedSolarOutput(panels) * nominalVolts
    if not finite(watts) then return nil end
    return {
        bank = bank,
        object = object,
        container = container,
        batteries = rows,
        watts = math.max(0, watts),
    }
end

function ISA.watts(snapshot, _, hours)
    if hours > 0 and finite(snapshot.previousWatts) then
        return (snapshot.previousWatts + snapshot.watts) / 2
    end
    return snapshot.watts
end

function ISA.commit(snapshot)
    if not snapshot then return false end
    local bank, object = ISA.resolve(snapshot.bank.x, snapshot.bank.y, snapshot.bank.z)
    if bank ~= snapshot.bank or object ~= snapshot.object or not enrolled(bank, object)
        or object:getContainer() ~= snapshot.container then
        return false
    end
    local current = readBatteries(snapshot.container)
    if not current or #current ~= #snapshot.batteries then return false end
    local changes = {}
    for i, row in ipairs(snapshot.batteries) do
        local now = current[i]
        if row.item ~= now.item or row.capacityKWh ~= now.capacityKWh
            or math.abs(row.initialKWh - now.chargeKWh) > epsilon
            or not finite(row.chargeKWh) or row.chargeKWh < -epsilon
            or row.chargeKWh > row.capacityKWh + epsilon then
            return false
        end
        if row.chargeKWh ~= now.chargeKWh then
            changes[#changes + 1] = {
                row = row,
                uses = row.item:getCurrentUses(),
                remainder = row.item:getModData()[batteries.ENERGY_KEY],
            }
        end
    end

    local applied = 0
    local ok, reason = pcall(function()
        for i, change in ipairs(changes) do
            applied = i
            local row = change.row
            batteries.setEnergy(row.item, row.chargeKWh, row.capacityKWh)
            if math.abs(batteries.energy(row.item, row.capacityKWh) - row.chargeKWh) > epsilon then
                error("battery energy readback differs")
            end
        end
    end)
    if not ok then
        local rollbackFailed = false
        for i = applied, 1, -1 do
            local change = changes[i]
            local restored = pcall(function()
                change.row.item:setCurrentUses(change.uses)
                change.row.item:getModData()[batteries.ENERGY_KEY] = change.remainder
                if change.row.item:getCurrentUses() ~= change.uses then
                    error("battery uses rollback readback differs")
                end
            end)
            if not restored then rollbackFailed = true end
        end
        if rollbackFailed then error("ISA battery write rollback failed: " .. tostring(reason)) end
        return false
    end
    for _, change in ipairs(changes) do change.row.initialKWh = change.row.chargeKWh end
    if #changes > 0 then
        local refreshed, err = pcall(function()
            snapshot.container:setDrawDirty(true)
            refresh(bank, snapshot.container)
        end)
        if not refreshed then
            print("[SuQingLiveWireISACompat] ISA display refresh failed: " .. tostring(err))
        end
    end
    return true
end

function ISA.install(isEnrolled, isManagedBackup, fromMod)
    if installed then return true end
    local system = require "ImmersiveSolarArrays/PowerBank/PowerBankSystem_Server"
    local object = require "ImmersiveSolarArrays/PowerBank/PowerBankObject_Server"
    require "ImmersiveSolarArrays/PowerBank/PowerBankSystem_Commands"
    local upstream = require "ImmersiveSolarArrays/Utilities"
    local energy = LiveWire and LiveWire.Batteries
    if type(isEnrolled) ~= "function" or type(system) ~= "table" or type(object) ~= "table"
        or type(system.Commands) ~= "table" or type(system.Commands.moveBattery) ~= "function"
        or type(system.updatePowerbanks) ~= "function" or type(system.getModifiedSolarOutput) ~= "function"
        or type(upstream) ~= "table" or not upstream.WorldUtil or type(upstream.WorldUtil.getType) ~= "function"
        or not energy or type(energy.energy) ~= "function" or type(energy.setEnergy) ~= "function"
        or type(energy.ENERGY_KEY) ~= "string" then
        return false, "isa_interface_missing"
    end
    local folder = "media/lua/server/ImmersiveSolarArrays/PowerBank/"
    local shared = "media/lua/shared/ImmersiveSolarArrays/PowerBankSystem_Shared.lua"
    local function native(fn, path)
        return type(fn) == "function" and (not fromMod or fromMod(fn, "ISA", path))
    end
    if not native(system.updatePowerbanks, folder .. "PowerBankSystem_Server.lua")
        or not native(system.Commands.moveBattery, folder .. "PowerBankSystem_Commands.lua")
        or not native(system.getModifiedSolarOutput, shared) or not native(system.getValidBackupOnSquare, shared)
        or not native(system.isValidIsoObject, shared) then
        return false, "isa_system_source_changed"
    end
    for _, method in ipairs({ "shouldDrain", "updateBatteries", "updateGenerator", "loadGenerator",
        "updateDrain", "updateSprite", "updateConGenerator", "autoConnectBackup",
        "connectBackupGenerator", "saveData", "calculateBatteryStats" }) do
        if not native(object[method], folder .. "PowerBankObject_Server.lua") then
            return false, "isa_object_source_changed_" .. method
        end
    end
    namespace, enrolled, batteries = upstream, isEnrolled, energy

    local function linked(bank)
        local iso = bank:getIsoObject()
        return isEnrolled(bank, iso), iso
    end

    local function observeBackup(bank)
        if not isManagedBackup then return false end
        -- Observe the object the native ISA code actually selects. Enrollment
        -- remains stricter and requires an unambiguous generator on the square.
        local square = backupSquare(bank)
        local generator = square and square:getGenerator()
        if not generator or not isManagedBackup(generator, square) then return false end
        bank.conGenerator.ison = generator:isActivated()
        return true
    end

    -- Keep the pinned native loop and unrelated banks intact. For enrolled banks
    -- ignore its proposed write and restore the last real charge before any save.
    local pending
    local update = system.updatePowerbanks
    system.updatePowerbanks = function(...)
        if pending then return end
        pending = {}
        local ok, err = pcall(update, ...)
        for bank, charge in pairs(pending) do bank.charge = charge end
        pending = nil
        if not ok then error(err) end
    end

    local shouldDrain = object.shouldDrain
    object.shouldDrain = function(bank, iso)
        if isEnrolled(bank, iso) then
            if pending then pending[bank] = bank.charge end
            return false
        end
        observeBackup(bank)
        return shouldDrain(bank, iso)
    end

    local function restoreCharge(bank)
        if pending and pending[bank] ~= nil then bank.charge = pending[bank] end
    end

    local updateBatteries = object.updateBatteries
    object.updateBatteries = function(bank, ...)
        if linked(bank) then
            restoreCharge(bank)
            return
        end
        return updateBatteries(bank, ...)
    end

    local updateGenerator = object.updateGenerator
    object.updateGenerator = function(bank, ...)
        local active, iso = linked(bank)
        if active then return ISA.projectOff(bank, iso) end
        return updateGenerator(bank, ...)
    end

    local loadGenerator = object.loadGenerator
    object.loadGenerator = function(bank, ...)
        local active, iso = linked(bank)
        if not active then return loadGenerator(bank, ...) end
        if iso then
            ISA.projectOff(bank, iso)
            iso:getCell():addToProcessIsoObjectRemove(iso)
        end
    end

    local updateDrain = object.updateDrain
    object.updateDrain = function(bank, ...)
        if linked(bank) then
            bank.drain = 0
            return
        end
        return updateDrain(bank, ...)
    end

    local updateSprite = object.updateSprite
    object.updateSprite = function(bank, ...)
        if linked(bank) then
            restoreCharge(bank)
            return updateSprite(bank)
        end
        return updateSprite(bank, ...)
    end

    local updateConGenerator = object.updateConGenerator
    object.updateConGenerator = function(bank, ...)
        if linked(bank) or observeBackup(bank) then return end
        return updateConGenerator(bank, ...)
    end

    local autoConnectBackup = object.autoConnectBackup
    object.autoConnectBackup = function(bank, ...)
        if linked(bank) then return end
        return autoConnectBackup(bank, ...)
    end

    local connectBackupGenerator = object.connectBackupGenerator
    object.connectBackupGenerator = function(bank, generator, ...)
        if linked(bank) or (isManagedBackup and isManagedBackup(generator, generator:getSquare())) then return end
        return connectBackupGenerator(bank, generator, ...)
    end

    local validBackup = system.getValidBackupOnSquare
    system.getValidBackupOnSquare = function(instance, square)
        local generator = validBackup(instance, square)
        if generator and isManagedBackup and isManagedBackup(generator, square) then return nil end
        return generator
    end

    local saveData = object.saveData
    object.saveData = function(bank, ...)
        restoreCharge(bank)
        return saveData(bank, ...)
    end

    local moveBattery = system.Commands.moveBattery
    system.Commands.moveBattery = function(player, args)
        local pos = args[1]
        local bank = system.instance and system.instance:getLuaObjectAt(pos.x, pos.y, pos.z)
        if bank then
            local active, iso = linked(bank)
            if active then
                local container = iso and iso:getContainer()
                if container then refresh(bank, container) end
                return
            end
        end
        return moveBattery(player, args)
    end

    -- Normally hooked before ISA registers its callback. A late install during
    -- startup must replace the already registered function as well as the method.
    if system.instance then
        local event = system.instance.updateEveryTenMinutes and Events.EveryTenMinutes or Events.EveryHours
        event.Remove(update)
        event.Add(system.updatePowerbanks)
    end
    installed = true
    return true
end

return ISA
