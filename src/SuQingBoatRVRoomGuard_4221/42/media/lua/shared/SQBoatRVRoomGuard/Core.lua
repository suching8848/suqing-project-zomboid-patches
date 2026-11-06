-- Pure allocation checks. Existing assignments and room coordinates are read-only.
SQBoatRVRoomGuardCore = {}
local M = SQBoatRVRoomGuardCore
M.nativeKey = "3x6caravan"
M.boatKey = "frotabr_cabine"

function M.assignmentKey(typeKey)
    return typeKey == "normal" and "AssignedRooms" or "AssignedRooms" .. typeKey
end

function M.roomKey(room)
    if type(room) ~= "table" then return nil end
    local x, y, z = room.x, room.y, room.z or 0
    for _, value in ipairs({x, y, z}) do
        if type(value) ~= "number" or value ~= value or value == math.huge
            or value == -math.huge or value ~= math.floor(value) then return nil end
    end
    if x == nil or y == nil then return nil end
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

function M.occupancy(data)
    if type(data) ~= "table" then return nil, "invalid_mod_data" end
    local result = {}
    for name, assignments in pairs(data) do
        if type(name) == "string" and string.sub(name, 1, 13) == "AssignedRooms" then
            if type(assignments) ~= "table" then return nil, "invalid_assignment_table" end
            for owner, room in pairs(assignments) do
                local key = M.roomKey(room)
                if not key then return nil, "invalid_assigned_room" end
                result[key] = result[key] or {}
                local owners = result[key]
                owners[#owners + 1] = { group = name, id = tostring(owner) }
            end
        end
    end
    return result
end

local function copyPool(rooms)
    if type(rooms) ~= "table" or #rooms ~= 38 then return nil end
    local pool, keys, seen = {}, {}, {}
    for i, room in ipairs(rooms) do
        local key = M.roomKey(room)
        if not key or seen[key] then return nil end
        pool[i], keys[i], seen[key] = room, key, true
    end
    return pool, keys, seen
end

function M.new(types)
    if type(types) ~= "table" then return nil, "missing_vehicle_types" end
    local native, boat = types[M.nativeKey], types[M.boatKey]
    if type(native) ~= "table" or type(boat) ~= "table"
        or native.roomWidth ~= 3 or native.roomHeight ~= 6
        or boat.roomWidth ~= 3 or boat.roomHeight ~= 6 then return nil, "changed_room_types" end
    local pool, keys, seen = copyPool(native.rooms)
    local boatPool, boatKeys = copyPool(boat.rooms)
    if not pool or not boatPool then return nil, "changed_room_pool" end
    for _, key in ipairs(boatKeys) do if not seen[key] then return nil, "different_room_pools" end end
    local self = { types = types, pool = pool, keys = keys, definitions = {}, managed = {}, count = #pool }
    self.definitions[M.nativeKey], self.definitions[M.boatKey] = native, boat
    self.managed[M.nativeKey], self.managed[M.boatKey] = native.rooms, boat.rooms

    function self:sync(data)
        local occupied, reason = M.occupancy(data)
        if not occupied then return nil, reason end
        for i, room in ipairs(self.pool) do
            if M.roomKey(room) ~= self.keys[i] then return nil, "changed_room_coordinates" end
        end
        local pools = {}
        for _, typeKey in ipairs({M.nativeKey, M.boatKey}) do
            local def = self.types[typeKey]
            if def ~= self.definitions[typeKey] or def.rooms ~= self.managed[typeKey] then
                return nil, "replaced_room_definition"
            end
            local ownGroup, available = M.assignmentKey(typeKey), {}
            for i, room in ipairs(self.pool) do
                local foreign = false
                for _, owner in ipairs(occupied[self.keys[i]] or {}) do
                    if owner.group ~= ownGroup then foreign = true; break end
                end
                -- Retain this category's OWN used rooms: native menu compares
                -- its assignment count with #rooms, then selectFreeRoom filters them.
                if not foreign then available[#available + 1] = room end
            end
            pools[typeKey] = available
        end
        for typeKey, rooms in pairs(pools) do
            self.definitions[typeKey].rooms = rooms
            self.managed[typeKey] = rooms
        end
        return { occupancy = occupied, pools = pools }
    end

    function self:checkEntry(ctx, data)
        if type(ctx) ~= "table" then return false, "invalid_context" end
        if ctx.typeKey ~= M.nativeKey and ctx.typeKey ~= M.boatKey then return true end
        if ctx.side ~= "SP" then return false, "multiplayer" end
        if not ctx.room then return false, "full" end
        local key = M.roomKey(ctx.room)
        if not key or not ctx.vehicle or not ctx.vehicle.getModData then return false, "invalid_context" end
        local md = ctx.vehicle:getModData()
        if type(md) ~= "table" or not md.projectRV_uniqueId then return false, "missing_vehicle_id" end
        local group, id = M.assignmentKey(ctx.typeKey), tostring(md.projectRV_uniqueId)
        if type(data[group]) ~= "table" or M.roomKey(data[group][id]) ~= key then return false, "assignment_mismatch" end
        local occupied, reason = M.occupancy(data)
        if not occupied then return false, reason end
        for _, owner in ipairs(occupied[key] or {}) do
            if owner.group ~= group or owner.id ~= id then return false, "collision" end
        end
        return true
    end
    return self
end

return M
