SQWaterBridge = SQWaterBridge or {}
local bridge = SQWaterBridge
local adapter = {}
bridge.Waterpipes = adapter

local unitsPerLiter = 100
local maxPipes = 128
local horizontal = {
    n = {x = 0, y = -1},
    e = {x = 1, y = 0},
    s = {x = 0, y = 1},
    w = {x = -1, y = 0},
}
local routeVectors

function adapter.setRouting(getVectors)
    routeVectors = getVectors
end

local function key(x, y, z)
    return WPUtils.Coords2Id(x, y, z)
end

local function hasNativePump(gmd, x, y, z)
    if gmd.Pumps[key(x, y, z)] then return true end
    for _, step in pairs(horizontal) do
        if gmd.Pumps[key(x + step.x, y + step.y, z)] then return true end
    end
    return false
end

local function directFixture(gmd, cell, x, y, z, parentId)
    local id = key(x, y, z)
    local barrel = gmd.Barrels[id]
    if not barrel or gmd.Buildings[id] then return nil end

    -- An entire building or a second pipe can otherwise refill the same fixture.
    if barrel.bid then
        for _, inlet in pairs(gmd.Buildings) do
            if inlet.bid == barrel.bid then return nil end
        end
    end
    for _, step in pairs(horizontal) do
        local otherId = key(x + step.x, y + step.y, z)
        if otherId ~= parentId and gmd.Pipes[otherId] then return nil end
    end
    for dz = -1, 1, 2 do
        local otherId = key(x, y, z + dz)
        if otherId ~= parentId and gmd.Pipes[otherId] then return nil end
    end
    if hasNativePump(gmd, x, y, z) then return nil end

    local square = cell:getGridSquare(x, y, z)
    local object = square and WPIso.GetBarrel(square)
    if not object or object:getUsesExternalWaterSource() or not object:getFluidContainer() then return nil end
    local sprite = object:getSprite()
    local props = sprite and sprite:getProperties()
    -- Waterpipes also calls its physical rain collectors "Barrels". They are
    -- excluded from the reverse leg so water cannot return to an LW source.
    if not props or not props:has(IsoFlagType.waterPiped) then return nil end
    return object
end

local function buildRoute(gmd, getVectors, binding)
    if not gmd or type(getVectors) ~= "function" or type(binding) ~= "table" then
        return nil, "Unsupported"
    end
    local x, y, z = binding.x, binding.y, binding.z
    local port = horizontal[binding.dir]
    if not port or type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return nil, "NoInlet"
    end
    if not gmd.Pipes[key(x, y, z)] or gmd.Pipes[key(x + port.x, y + port.y, z)] then
        return nil, "NoInlet"
    end

    local cell = getCell()
    local visited, count, outlets, alreadyWatered = {}, 0, 0, false
    local function visit(px, py, pz, dir, parentId)
        local id = key(px, py, pz)
        local pipe = gmd.Pipes[id]
        if not pipe then
            local fixture = directFixture(gmd, cell, px, py, pz, parentId)
            if not fixture then return nil end
            if visited[id] then return nil, "MixedFeed" end
            visited[id] = true
            outlets = outlets + 1
            return {fixture = fixture}
        end
        local vectors = getVectors(pipe.s, dir)
        if #vectors == 0 then return nil end
        if hasNativePump(gmd, px, py, pz) then return nil, "MixedFeed" end
        if visited[id] then return nil, "ReturnFlow" end
        count = count + 1
        if count > maxPipes then return nil, "Unsupported" end
        visited[id] = true

        local square = cell:getGridSquare(px, py, pz)
        local object = square and WPIso.GetPipe(square)
        local sprite = object and object:getSprite()
        if not sprite or sprite:getName() ~= WPIso.pipeSprites[pipe.s] then
            return nil, "NoInlet"
        end

        local valve = gmd.Valves[id]
        local node = {
            closed = (valve and valve.c) or (not valve and WPIso.GetValve(square) ~= nil),
            meter = gmd.Flowmeters[id],
            children = {},
        }
        local sprinkler = gmd.Sprinklers[id]
        if sprinkler and WPIso.GetSprinkler(square) then
            -- The native pass checks an immediate downstream valve before the
            -- sprinkler. Keep that behavior and also stop at a same-tile valve.
            local allBlocked = true
            local connected = {[dir] = true}
            for _, step in ipairs(vectors) do
                local nextValve = gmd.Valves[key(px + step.x, py + step.y, pz + step.z)]
                if not (nextValve and nextValve.c) then allBlocked = false end
                if step.x == 1 then connected.e = true end
                if step.x == -1 then connected.w = true end
                if step.y == 1 then connected.s = true end
                if step.y == -1 then connected.n = true end
                if step.z == 1 then connected.u = true end
                if step.z == -1 then connected.d = true end
            end
            -- Native sprinklers can accept water before checking the incoming
            -- pipe direction. An adjacent pipe on an unused side is ambiguous.
            for side, step in pairs(horizontal) do
                if not connected[side] and gmd.Pipes[key(px + step.x, py + step.y, pz)] then
                    return nil, "MixedFeed"
                end
            end
            if (not connected.u and gmd.Pipes[key(px, py, pz + 1)])
                or (not connected.d and gmd.Pipes[key(px, py, pz - 1)]) then
                return nil, "MixedFeed"
            end
            node.sprinkler = sprinkler
            node.sprinklerBlocked = allBlocked
            if (sprinkler.w or 0) > 0 then alreadyWatered = true end
            outlets = outlets + 1
        end

        -- Inspect closed branches too so opening a valve cannot join two feeds.
        for _, step in ipairs(vectors) do
            local child, reason = visit(px + step.x, py + step.y, pz + step.z, step.d, id)
            if reason then return nil, reason end
            if child then node.children[#node.children + 1] = child end
        end
        return node
    end

    local root, reason = visit(x, y, z, binding.dir)
    if reason then return nil, reason end
    if not root then return nil, "NoInlet" end
    if outlets == 0 then return nil, "NoOutlet" end
    return {root = root, visited = visited, alreadyWatered = alreadyWatered}
end

function adapter.canConnect(binding)
    local route, reason = buildRoute(GetWPModData(), routeVectors, binding)
    return route ~= nil, reason
end

local function fixtureCapacity(fixture, fluid)
    if fixture:getUsesExternalWaterSource() then return 0 end
    local container = fixture:getFluidContainer()
    if not container or not container:canAddFluid(fluid) then return 0 end
    local amount = container:getAmount()
    -- A vanilla mains or legacy reserve amount is not this container's water.
    if math.abs(fixture:getFluidAmount() - amount) > 0.00025 then return 0 end
    local water = container:getSpecificFluidAmount(Fluid.Water) + container:getSpecificFluidAmount(Fluid.TaintedWater)
    if amount - water > 0.001 then return 0 end
    return math.max(0, math.floor((container:getCapacity() - amount) * unitsPerLiter + 0.0001))
end

local function capacity(node, fluid)
    if node.closed then return 0 end
    if node.fixture then
        node.capacity = fixtureCapacity(node.fixture, fluid)
        return node.capacity
    end
    local sprinkler = node.sprinkler
    node.sprinklerCapacity = sprinkler and not node.sprinklerBlocked
        and math.max(0, math.floor(sprinkler.wmax - (sprinkler.w or 0))) or 0
    local total = node.sprinklerCapacity
    for _, child in ipairs(node.children) do
        total = total + capacity(child, fluid)
    end
    node.capacity = total
    return total
end

local function accept(amount, withdraw, refund, write, measure)
    if amount <= 0 then return 0 end
    local withdrawn = withdraw(amount)
    if withdrawn <= 0 then return 0 end
    local ok, err = pcall(write, withdrawn)
    local accepted = math.max(0, math.min(withdrawn, measure()))
    if accepted < withdrawn then refund(withdrawn - accepted) end
    if not ok then print("[SQWaterBridge] Waterpipes outlet write failed: " .. tostring(err)) end
    return accepted
end

local function deliverNode(node, amount, fluid, withdraw, refund)
    amount = math.min(amount, node.capacity or 0)
    if amount <= 0 then return 0 end
    local fixture = node.fixture
    if fixture then
        amount = math.min(amount, fixtureCapacity(fixture, fluid))
        if amount <= 0 then return 0 end
        local container = fixture:getFluidContainer()
        local before = container:getAmount()
        local accepted = accept(amount, withdraw, refund, function(units)
            container:addFluid(fluid, units / unitsPerLiter)
        end, function()
            return math.floor((container:getAmount() - before) * unitsPerLiter + 0.5)
        end)
        if accepted > 0 then
            fixture:sync()
            triggerEvent("OnWaterAmountChange", fixture, before)
        end
        return accepted
    end

    local used = 0
    local sprinkler = node.sprinkler
    if node.sprinklerCapacity > 0 then
        local before = sprinkler.w or 0
        used = accept(math.min(amount, node.sprinklerCapacity), withdraw, refund, function(units)
            WPVirtual.SprinklerPourIn(sprinkler.x, sprinkler.y, sprinkler.z, units)
        end, function()
            return math.floor((sprinkler.w or 0) - before + 0.5)
        end)
    end

    local remaining = amount - used
    local shares = {}
    -- Divide one budget across open branches. Reallocate shares a full outlet
    -- cannot use while leaving any volume beyond the combined capacity at source.
    while remaining > 0 do
        local open = {}
        for i, child in ipairs(node.children) do
            if (child.capacity or 0) > (shares[i] or 0) then open[#open + 1] = i end
        end
        if #open == 0 then break end
        local parts = WPUtils.SplitIntToParts(remaining, #open)
        for part, i in ipairs(open) do
            local allocated = shares[i] or 0
            local share = math.min(parts[part], node.children[i].capacity - allocated)
            shares[i] = allocated + share
            remaining = remaining - share
        end
    end
    local downstream = 0
    for i, child in ipairs(node.children) do
        downstream = downstream + deliverNode(child, shares[i] or 0, fluid, withdraw, refund)
    end
    if node.meter then node.meter.f = (node.meter.f or 0) + downstream end
    return used + downstream
end

-- Called inside Waterpipes' real minute pass after native pump distribution and
-- before native sprinklers water plants, increment gen and synchronize.
function adapter.dispatch(gmd, getVectors)
    local binding = bridge.getConnection()
    if not binding or not bridge.LiveWire then return end
    local pump = bridge.LiveWire.getPump(binding.pumpKey)
    if not pump or bridge.getBinding(pump) ~= binding then return end
    local route = buildRoute(gmd, getVectors, binding)

    bridge.LiveWire.feed(pump, binding, function(_, medium, units, source, withdraw, refund)
        if not route or route.alreadyWatered then return 0 end
        if medium ~= "Water" and medium ~= "TaintedWater" then return 0 end
        if not source or route.visited[key(source.x, source.y, source.z)] then return 0 end
        local fluid = Fluid[medium]
        if units <= 0 or capacity(route.root, fluid) <= 0 then return 0 end
        return deliverNode(route.root, math.floor(units), fluid, withdraw, refund)
    end)
end

return adapter
