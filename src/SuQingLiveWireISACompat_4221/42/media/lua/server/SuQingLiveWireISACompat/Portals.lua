local Portals = {}
local mixed = {}
local COST_KWH = 0.30

local function finite(number)
    return type(number) == "number" and number - number == 0
end

local function loadedSquare(object)
    local square = object and object:getSquare()
    if square and getCell():getGridSquare(square:getX(), square:getY(), square:getZ()) == square then
        return square
    end
end

local function stamp(log)
    local last = log and log[#log]
    return last and tostring(last.t) or "-"
end

function Portals.install(power, adapter, gridLink, managedBackup, version, verify)
    if not power or (version ~= "0.1.4" and version ~= "0.1.5"
        and version ~= "0.1.6-rc.1" and version ~= "0.1.6-rc.2"
        and version ~= "0.1.6-rc.3" and version ~= "0.1.6-rc.4" and version ~= "0.1.6-rc.5" and version ~= "0.1.6-rc.6") then return false end
    local original = {}
    for _, key in ipairs({"provider", "begin", "finish", "rollback"}) do
        local fn = power[key]
        if not verify(fn, "SuQingPortals", "media/lua/server/SuQingPortals/Power.lua") then return false end
        original[key] = fn
    end

    function power.provider(object)
        local native, reason = original.provider(object)
        if native and native.kind == "grid" then return native end
        local square = loadedSquare(object)
        local grid, inverter
        if square then grid, inverter = adapter.gridAt(square, object) end
        local link = grid and gridLink(grid)
        if link and inverter and finite(inverter.eff) and inverter.eff >= 0.05 and inverter.eff <= 1 then
            local history = LiveWire.Registry.data.powerHistory
            local timeline = history and history[inverter.id]
            if timeline then
                return {kind = "livewire", bridge = mixed, grid = grid, cost = COST_KWH / inverter.eff,
                    maxInterval = 2 * LiveWire.STEP_HOURS,
                    key = table.concat({"sqlwisa", link.token, tostring(inverter.eff),
                        stamp(timeline.log), stamp(timeline.panelLog)}, ":")}
            end
        end
        if native and native.generator and managedBackup(native.generator) then
            return nil, "power_disconnected"
        end
        -- A newer portal's ordinary Live Wire adapter must not meter a mixed grid by itself.
        if native and native.kind == "livewire" then
            local id = type(native.key) == "string" and native.key:match("^livewire:([^:]+):")
            if id and gridLink(adapter.grid(id)) then return nil, "power_livewire_unavailable" end
        end
        return native, reason
    end

    function power.begin(object, requested, expectedKey)
        local ok, source, reason = pcall(power.provider, object)
        if not ok then return nil, 0, "power_query_failed" end
        if not source then return nil, 0, reason end
        if source.bridge ~= mixed then
            return original.begin(object, requested, expectedKey)
        end
        if not finite(requested) or requested <= 0 then return nil, 0, "power_invalid_amount" end
        if expectedKey and source.key ~= expectedKey then return nil, 0, "power_source_changed" end
        local cap = power.chargeRate() * source.maxInterval
        local prepared, available, receipt = pcall(adapter.prepareDraw, source.grid, math.min(requested, cap) * source.cost)
        if not prepared then return nil, 0, "power_query_failed" end
        if not receipt or not finite(available) or available <= 0 then return nil, 0, "power_insufficient" end
        local approved = math.min(requested, cap, available / source.cost)
        return {bridge = mixed, source = source, payment = receipt, approved = approved}, approved
    end

    function power.finish(receipt, amount)
        if receipt.bridge ~= mixed then return original.finish(receipt, amount) end
        if receipt.finished then return receipt.actual == amount, "power_receipt_closed" end
        if receipt.rolledBack or receipt.failed or not finite(amount) or amount < 0 or amount > receipt.approved + 0.00000001 then
            return false, "power_invalid_amount"
        end
        local ran, ok, reason = pcall(adapter.finishDraw, receipt.payment,
            math.min(amount, receipt.approved) * receipt.source.cost)
        if not ran then
            receipt.failed = "power_rollback_failed"
            return false, receipt.failed
        end
        if not ok then
            receipt.failed = reason == "power_rollback_failed" and reason or "power_write_failed"
            return false, receipt.failed
        end
        receipt.finished, receipt.actual = true, amount
        return true
    end

    function power.rollback(receipt)
        if not receipt or receipt.bridge ~= mixed then return original.rollback(receipt) end
        if receipt.finished then return false, "power_receipt_closed" end
        if receipt.failed == "power_rollback_failed" then return false, receipt.failed end
        receipt.rolledBack = true
        return true
    end
    return true
end

return Portals
