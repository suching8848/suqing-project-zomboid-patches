-- Load Waterpipes' own minute callback, with exact-source guards around the bridge.
require "SQWaterBridge/State"
local Bridge = SQWaterBridge
if Bridge.nativeLoaded then return end

local function readSource(mod, path)
    local reader = getModFileReader(mod, path, false)
    if not reader then return nil end
    local lines = {}
    local ok, problem = pcall(function()
        while true do
            local line = reader:readLine()
            if line == nil then break end
            lines[#lines + 1] = line
        end
    end)
    reader:close()
    if not ok then error(problem) end
    return table.concat(lines, "\n")
end

local function matches(source, adler, rolling)
    if not source then return false end
    local a, b, h = 1, 0, 5381
    for i = 1, #source do
        local byte = string.byte(source, i)
        if byte < 128 then
            a = (a + byte) % 65521
            b = (b + a) % 65521
            h = (h * 33 + byte) % 4294967296
        end
    end
    return b * 65536 + a == adler and h == rolling
end

local function replaceOnce(source, anchor, replacement)
    local first, last = string.find(source, anchor, 1, true)
    if not first or string.find(source, anchor, last + 1, true) then
        error("Waterpipes callback anchor changed: " .. anchor)
    end
    return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local path = "media/lua/server/WPServer.lua"
local source = readSource("Waterpipes", path)
if not source then error("[SQWaterBridge] Waterpipes WPServer.lua could not be read") end

local function verifiedLiveWireVersion()
    local core = readSource("batman_LiveWire", "media/lua/shared/LiveWire/LW_Core.lua")
    local version, pins
    if matches(core, 274956743, 3536347388) then
        version = "1.7.2"
        pins = {
            { "server/LiveWire/LW_Pump.lua", 551541570, 3826043270 },
            { "server/LiveWire/LW_Circuits.lua", 3447202187, 2070311534 },
        }
    elseif matches(core, 730712702, 3025217651) then
        version = "2.2.0"
        pins = {
            { "server/LiveWire/LW_Pump.lua", 3990370844, 2797203769 },
            { "server/LiveWire/LW_Circuits.lua", 1808216330, 2625074705 },
            { "server/LiveWire/LW_Inverters.lua", 2801967639, 1718027455 },
            { "server/LiveWire/LW_LinkedConsumers.lua", 857888139, 2853443016 },
            { "shared/LiveWire/LW_Defs.lua", 410795613, 2704159727 },
            { "shared/LiveWire/LW_Consumers.lua", 69168622, 1891233052 },
            { "server/LiveWire/LW_PumpRelays.lua", 2906207381, 1814353210 },
            { "server/LiveWire/LW_PumpTransfer.lua", 1772141096, 1206972376 },
            { "shared/LiveWire/LW_CircuitProvider.lua", 165980985, 3342867999 },
            { "shared/LiveWire/LW_Coverage.lua", 1084570187, 2158006856 },
            { "shared/LiveWire/LW_Config.lua", 3886809174, 543404205 },
            { "shared/LiveWire/LW_ApplianceFamilies.lua", 854645148, 1351327607 },
        }
    else
        -- Workshop 2.0.0 and 2.0.1 share a core. Live Wire 2.1.4 adds configurable native relay tanks.
        local circuitAdler, circuitRolling = 1986253812, 2313228458
        if matches(core, 578931324, 2663626545) then
            version = "2.0.0"
        elseif matches(core, 730450558, 3697274867) then
            version = "2.0.2"
        elseif matches(core, 806210175, 2066615380) then
            version = "2.0.3"
        elseif matches(core, 654822013, 696938450) then
            version = "2.1.0"
        elseif matches(core, 730581630, 3361246259) then
            version = "2.1.1"
        elseif matches(core, 806341247, 1730586772) then
            version = "2.1.2"
        elseif matches(core, 882100864, 99927285) then
            version = "2.1.3"
        elseif matches(core, 957860481, 2764235094) then
            version = "2.1.4"
        elseif matches(core, 1033620098, 1133575607) then
            version = "2.1.5"
        elseif matches(core, 1109379715, 3797883416) then
            version = "2.1.6"
        elseif matches(core, 1260898949, 536564442) then
            version = "2.1.8"
        else
            return nil
        end
        local usesConsumerFamilies = version == "2.1.0" or version == "2.1.1"
            or version == "2.1.2" or version == "2.1.3" or version == "2.1.4" or version == "2.1.5" or version == "2.1.6" or version == "2.1.8"
        if usesConsumerFamilies then
            circuitAdler, circuitRolling = 4197378089, 726854015
        end
        local configurableRelayTank = version == "2.1.4" or version == "2.1.5" or version == "2.1.6" or version == "2.1.8"
        local relayAdler, relayRolling = 4211289607, 1786054732
        local transferAdler, transferRolling = 639289267, 2049862322
        if configurableRelayTank then
            relayAdler, relayRolling = 2906207381, 1814353210
            transferAdler, transferRolling = 1772141096, 1206972376
        end
        pins = {
            { "server/LiveWire/LW_Pump.lua", 4054543926, 2236479571 },
            { "server/LiveWire/LW_Circuits.lua", circuitAdler, circuitRolling },
            { "server/LiveWire/LW_PumpRelays.lua", relayAdler, relayRolling },
            { "server/LiveWire/LW_PumpTransfer.lua", transferAdler, transferRolling },
            { "shared/LiveWire/LW_CircuitProvider.lua", 165980985, 3342867999 },
            { "shared/LiveWire/LW_Coverage.lua", 1084570187, 2158006856 },
        }
        if configurableRelayTank then
            pins[#pins + 1] = { "shared/LiveWire/LW_Config.lua", 3886809174, 543404205 }
            pins[#pins + 1] = { "shared/LiveWire/LW_Defs.lua", 784931141, 2575647255 }
        end
        if usesConsumerFamilies then
            pins[#pins + 1] = { "shared/LiveWire/LW_ApplianceFamilies.lua", 854645148, 1351327607 }
            pins[#pins + 1] = { "shared/LiveWire/LW_Consumers.lua", 654919684, 4118434416 }
        end
    end
    for _, pin in ipairs(pins) do
        if not matches(readSource("batman_LiveWire", "media/lua/" .. pin[1]), pin[2], pin[3]) then return nil end
    end
    return version
end

local function adapt()
    if isClient() or isServer() then return nil end
    local core = getCore()
    local gameVersion = core and core.getGameAndBuildVersion and core:getGameAndBuildVersion()
    if gameVersion ~= "42.21.0" and gameVersion ~= "42.22.2" then return nil end
    if not matches(source, 1608318257, 609381302) then return nil end
    local pins = {
        { "media/lua/shared/WPIso.lua", 3158132023, 4040386577 },
        { "media/lua/shared/WPVirtual.lua", 2135286222, 1751274569 },
    }
    for _, pin in ipairs(pins) do
        if not matches(readSource("Waterpipes", pin[1]), pin[2], pin[3]) then return nil end
    end
    local version = verifiedLiveWireVersion()
    if not version then return nil end

    require "SQWaterBridge/Native"
    require "SQWaterBridge/Waterpipes"
    require "SQWaterBridge/LiveWire"
    local edits = {
        { "local matrix = {", "local bridge, feedingPump\nlocal matrix = {" },
        { "local function hasClosedValve",
            "SQWaterBridge.Waterpipes.setRouting(getVectors)\nlocal function hasClosedValve" },
        { "elseif barrel then",
            "elseif bridge and bridge.Native.pourUsefulBarrel(x, y, z, dir, medium, amount, feedingPump) then\n"
            .. "            pipeTraversed[traverseId] = true\n"
            .. "        elseif barrel then" },
        { "WPVirtual.BarrelPourIn(x, y, z, medium, amount)",
            "if bridge then bridge.Native.pourBarrel(x, y, z, medium, amount, feedingPump)\n"
            .. "            else WPVirtual.BarrelPourIn(x, y, z, medium, amount) end" },
        { "local gmdCopy = deepcopy(gmd)",
            "local gmdCopy = deepcopy(gmd)\n"
            .. "    bridge = SQWaterBridge.ensureReady() and SQWaterBridge or nil\n"
            .. "    local blocked = {}\n"
            .. "    if bridge then bridge.Native.prepare(gmd) end" },
        { "WPIso.SyncBarrel(barrel)",
            "if bridge then bridge.Native.syncBarrel(barrel) else WPIso.SyncBarrel(barrel) end" },
        { "WPIso.SyncPump(pump)",
            "if bridge then blocked[pump] = bridge.Native.syncPump(pump) else WPIso.SyncPump(pump) end" },
        { "if pump.active then\n            -- usage logic",
            "if pump.active and not blocked[pump] then\n            -- usage logic" },
        { "if pump.active and pump.source then",
            "if pump.active and pump.source and not blocked[pump] then\n            feedingPump = pump" },
        { "    -- sprinkler watering",
            "    if bridge then\n"
            .. "        local routed, problem = pcall(bridge.Waterpipes.dispatch, gmd, getVectors)\n"
            .. "        if not routed then print('[SQWaterBridge] inlet dispatch failed: ' .. tostring(problem)) end\n"
            .. "    end\n    -- sprinkler watering" },
    }
    local transformed = source
    for _, edit in ipairs(edits) do
        transformed = replaceOnce(transformed, edit[1], edit[2])
    end
    local chunk, problem = loadstring(transformed, "@Waterpipes/" .. path)
    if not chunk then error(problem) end
    return chunk, version
end

local ok, chunk, version = pcall(adapt)
if ok and chunk then
    chunk()
    Bridge.sourceVersion = version
    print("[SQWaterBridge] verified Waterpipes minute integration")
else
    local original, problem = loadstring(source, "@Waterpipes/" .. path)
    if not original then error(problem) end
    original()
    print("[SQWaterBridge] original Waterpipes callback: " .. (ok and "unsupported game build, upstream or mode" or tostring(chunk)))
end
Bridge.nativeLoaded = true
