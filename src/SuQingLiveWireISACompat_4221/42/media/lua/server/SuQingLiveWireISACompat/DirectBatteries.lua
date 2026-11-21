-- Keep ISA's item-specific amp-hour capacity through the native LiveWire rack.
local Direct = {}
local models = {
    ["ISA.DeepCycleBattery"] = true,
    ["ISA.SuperBattery"] = true,
    ["ISA.WiredCarBattery"] = true,
    ["ISA.DIYBattery"] = true,
}

local function replaceOnce(source, before, after)
    local first, last = source:find(before, 1, true)
    assert(first and not source:find(before, last + 1, true), "unexpected LiveWire battery source")
    return source:sub(1, first - 1) .. after .. source:sub(last + 1)
end

function Direct.patch(native, version, gate, isa, mark, ready)
    if version ~= "2.1.4" and version ~= "2.1.5" and version ~= "2.1.6" and version ~= "2.1.8" and version ~= "2.2.0" then return native end

    local source, path = gate.batterySource(version)
    local mod = "batman_LiveWire"
    assert(source and gate.fromMod(native.entry, mod, path)
        and gate.fromMod(native.restore, mod, path)
        and gate.fromMod(native.snapshot, mod, path), "unreviewed LiveWire battery entry points")
    local adapter = { capacity = isa.effectiveCapacityKWh, mark = mark }

    function adapter.ah(item)
        if ready() and models[item:getFullType()] then return isa.ratedAh(item) end
    end

    function adapter.id(item)
        local id = item:getID()
        -- Native restores match numeric item IDs. Older patch versions must
        -- leave these ISA snapshots alone, even if they have saved zero stock.
        if models[item:getFullType()] then return "SuQingISA:" .. tostring(id) end
        return id
    end

    function adapter.cachedAh(bank, model, id)
        if not models[model] or not ready() then return nil end
        for _, slot in ipairs(bank.slots or {}) do
            if slot.id == id and slot.model == model then return slot.isaAh end
        end
    end

    source = replaceOnce(source, "LiveWire.Batteries = Batteries\n", "")
    source = replaceOnce(source, [[id, cond, fraction, cycles, item)
    local warm = Batteries.capacity(model, cond)
    local factor = Batteries.coldFactor(bank)]], [[id, cond, fraction, cycles, item, isaAh)
    if not item then isaAh = Direct.cachedAh(bank, model, id) end
    local warm = isaAh and Direct.capacity(isaAh, cond) or Batteries.capacity(model, cond)
    local factor = isaAh and 1 or Batteries.coldFactor(bank)]])
    source = replaceOnce(source, "item = item, cond = cond,", "item = item, cond = cond, isaAh = isaAh,")
    source = replaceOnce(source, "Batteries.def(it:getFullType()) then",
        "(Batteries.def(it:getFullType()) or Direct.ah(it)) then")
    source = replaceOnce(source, [[local cond = Batteries.condition(it)
            local cap = Batteries.capacity(it:getFullType(), cond)
            entries[#entries + 1] = Batteries.entry(bank, it:getFullType(), it:getID(), cond,
                cap > 0 and Batteries.energy(it, cap) / cap or 0, it:getModData()[Batteries.CYCLES_KEY], it)]],
        [[local isaAh = Direct.ah(it)
            local cond = isaAh and it:getCondition() or Batteries.condition(it)
            local cap = isaAh and Direct.capacity(isaAh, cond) or Batteries.capacity(it:getFullType(), cond)
            entries[#entries + 1] = Batteries.entry(bank, it:getFullType(), Direct.id(it), cond,
                cap > 0 and Batteries.energy(it, cap) / cap or 0,
                not isaAh and it:getModData()[Batteries.CYCLES_KEY] or nil, it, isaAh)]])
    source = replaceOnce(source, [[local it = e.item
        if it then]], [[local it = e.item
        if e.isaAh then
            slots[#slots].isaAh = e.isaAh
            if it and warm > 0 then
                local oldFraction = it:getCurrentUsesFloat()
                Batteries.setEnergy(it, e.charge, warm)
                Direct.mark(it)
                if math.abs(it:getCurrentUsesFloat() - oldFraction) >= 0.005 then sendItemStats(it) end
            end
        elseif it then]])
    source = replaceOnce(source, [[local s = it and byId[it:getID()]
        if s then]], [[local s = it and byId[Direct.id(it)]
        if s and s.isaAh then
            if s.model == it:getFullType() and Direct.ah(it) == s.isaAh and it:getCondition() == s.cond then
                local cap = Direct.capacity(s.isaAh, s.cond)
                if cap > 0 then
                    Batteries.setEnergy(it, LiveWire.clamp(s.charge or 0, 0, 1) * cap, cap)
                    Direct.mark(it)
                    sendItemStats(it)
                end
            end
        elseif s and Direct.id(it) == it:getID() then]])

    -- This file only defines the battery table. Its native event registrations
    -- and the existing gameplay Lua functions continue to use LiveWire.Batteries.
    local chunk = assert(loadstring("return function(Direct)\n" .. source
        .. "\nreturn Batteries\nend", "@SuQingLiveWireISACompat/direct-batteries"))
    return chunk()(adapter)
end

return Direct
