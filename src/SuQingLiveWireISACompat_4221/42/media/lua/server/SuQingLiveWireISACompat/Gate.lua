local Gate = {}
local liveWire = "batman_LiveWire"
local isa = "ISA"
local portals = "SuQingPortals"
local serverPath = "media/lua/server/"
local sharedPath = "media/lua/shared/"
local bankPath = serverPath .. "ImmersiveSolarArrays/PowerBank/"
local liveWire172Pins = {
    {liveWire, serverPath .. "LiveWire/LW_Simulation.lua", 257171299, 30098},
    {liveWire, sharedPath .. "LiveWire/LW_Physics.lua", 149450903, 8971},
    {liveWire, serverPath .. "LiveWire/LW_Backup.lua", 895829341, 10449},
    {liveWire, serverPath .. "LiveWire/LW_Batteries.lua", 676203003, 9657},
    {liveWire, serverPath .. "LiveWire/LW_Registry.lua", 798617572, 13675},
    {liveWire, serverPath .. "LiveWire/LW_Commands.lua", 156083, 16650},
    {liveWire, serverPath .. "LiveWire/LW_Demand.lua", 809510815, 14964},
    {liveWire, serverPath .. "LiveWire/LW_Circuits.lua", 514310381, 12136},
    {liveWire, serverPath .. "LiveWire/LW_Computer.lua", 694539452, 4234},
    {liveWire, serverPath .. "LiveWire/LW_Forecast.lua", 150270230, 3333},
    {liveWire, serverPath .. "LiveWire/LW_Devices.lua", 725347793, 16250},
    {liveWire, sharedPath .. "LiveWire/LW_Install.lua", 489310640, 18614},
    {liveWire, sharedPath .. "LiveWire/LW_Config.lua", 462548456, 1989},
    {liveWire, sharedPath .. "LiveWire/LW_Marks.lua", 438838086, 2582},
    {liveWire, sharedPath .. "LiveWire/LW_Defs.lua", 907124366, 7290},
}

local function liveWire20Pins(coreHash, devicesHash, devicesSize)
    return {
        {liveWire, sharedPath .. "LiveWire/LW_Core.lua", coreHash, 1405},
        {liveWire, serverPath .. "LiveWire/LW_Simulation.lua", 939714285, 37020},
        {liveWire, sharedPath .. "LiveWire/LW_Physics.lua", 260446495, 10086},
        {liveWire, serverPath .. "LiveWire/LW_Backup.lua", 785102240, 11207},
        {liveWire, serverPath .. "LiveWire/LW_Batteries.lua", 596087089, 9472},
        {liveWire, serverPath .. "LiveWire/LW_Registry.lua", 853343134, 16535},
        {liveWire, serverPath .. "LiveWire/LW_Commands.lua", 706662326, 18157},
        {liveWire, serverPath .. "LiveWire/LW_Demand.lua", 315263322, 20408},
        {liveWire, serverPath .. "LiveWire/LW_Circuits.lua", 537781718, 14992},
        {liveWire, serverPath .. "LiveWire/LW_Computer.lua", 857342161, 4588},
        {liveWire, serverPath .. "LiveWire/LW_Forecast.lua", 768981905, 3412},
        {liveWire, serverPath .. "LiveWire/LW_Devices.lua", devicesHash, devicesSize},
        {liveWire, sharedPath .. "LiveWire/LW_Install.lua", 359279382, 10905},
        {liveWire, sharedPath .. "LiveWire/LW_Config.lua", 856515902, 2014},
        {liveWire, sharedPath .. "LiveWire/LW_Marks.lua", 504051607, 2956},
        {liveWire, sharedPath .. "LiveWire/LW_Defs.lua", 814326009, 11720},
        {liveWire, serverPath .. "LiveWire/LW_Inverters.lua", 142894868, 2745},
        {liveWire, sharedPath .. "LiveWire/LW_Coverage.lua", 731328277, 7476},
        {liveWire, sharedPath .. "LiveWire/LW_CircuitProvider.lua", 495409969, 2102},
        {liveWire, sharedPath .. "LiveWire/LW_Coupling.lua", 654747021, 3743},
        {liveWire, sharedPath .. "LiveWire/LW_Extension.lua", 632319587, 2343},
    }
end

-- Both 2.0.0 and 2.0.1 ship the same base-mod Lua. 2.0.2 changes LW_Core.lua.
-- 2.0.3 also changes LW_Devices.lua to refund coupling kits on pickup.
local liveWire201Pins = liveWire20Pins(332374385, 856873108, 26484)
local liveWire203Pins = liveWire20Pins(913875995, 669748086, 26784)
-- 2.1.0 adds the registered-consumer path to demand, circuits and the monitor snapshot.
local liveWire210Changes = {
    [serverPath .. "LiveWire/LW_Circuits.lua"] = {233927848, 15051},
    [sharedPath .. "LiveWire/LW_Core.lua"] = {715394173, 1405},
    [serverPath .. "LiveWire/LW_Demand.lua"] = {916018788, 21481},
    [serverPath .. "LiveWire/LW_Simulation.lua"] = {992760352, 37277},
}
local liveWire210Pins = {
    {liveWire, sharedPath .. "LiveWire/LW_Consumers.lua", 498415584, 6555},
    {liveWire, sharedPath .. "LiveWire/LW_ApplianceFamilies.lua", 499478512, 6174},
    {liveWire, sharedPath .. "LiveWire/LW_Appliances.lua", 874896215, 10075},
    {liveWire, sharedPath .. "LiveWire/LW_Consumption.lua", 113860244, 5101},
    {liveWire, sharedPath .. "LiveWire/LW_API.lua", 356960312, 22942},
}
for _, pin in ipairs(liveWire203Pins) do
    local changes = liveWire210Changes[pin[2]]
    liveWire210Pins[#liveWire210Pins + 1] = changes and {pin[1], pin[2], changes[1], changes[2]} or pin
end
-- Later releases keep the settlement sources. 2.1.3 also adds the wreckage API.
local function withCoreVersion(coreHash, apiHash, apiLength)
    local result = {}
    for i, pin in ipairs(liveWire210Pins) do
        if pin[2] == sharedPath .. "LiveWire/LW_Core.lua" then
            result[i] = {liveWire, pin[2], coreHash, 1405}
        elseif apiHash and pin[2] == sharedPath .. "LiveWire/LW_API.lua" then
            result[i] = {liveWire, pin[2], apiHash, apiLength}
        else
            result[i] = pin
        end
    end
    return result
end

local liveWire213Pins = withCoreVersion(296895776, 329048620, 23627)
liveWire213Pins[#liveWire213Pins + 1] = {liveWire, serverPath .. "LiveWire/LW_Sturdy.lua", 419770570, 2381}
liveWire213Pins[#liveWire213Pins + 1] = {liveWire, sharedPath .. "LiveWire/LW_Wreckage.lua", 979686735, 4182}

-- 2.1.4 changes the version and the shared pump-capacity config and definitions.
local liveWire214Changes = {
    [sharedPath .. "LiveWire/LW_Core.lua"] = {490729646, 1405},
    [sharedPath .. "LiveWire/LW_Config.lua"] = {678968683, 2380},
    [sharedPath .. "LiveWire/LW_Defs.lua"] = {521510407, 11648},
}
local liveWire214Pins = {}
for i, pin in ipairs(liveWire213Pins) do
    local changes = liveWire214Changes[pin[2]]
    liveWire214Pins[i] = changes and {pin[1], pin[2], changes[1], changes[2]} or pin
end

-- 2.1.5 only changes the base-mod version and the optional Viewpoint add-on.
local liveWire215Pins = {}
for i, pin in ipairs(liveWire214Pins) do
    liveWire215Pins[i] = pin[2] == sharedPath .. "LiveWire/LW_Core.lua"
        and {liveWire, pin[2], 684563516, 1405} or pin
end

local liveWirePins = {
    ["1.7.2"] = liveWire172Pins,
    ["2.0.0"] = liveWire201Pins,
    ["2.0.1"] = liveWire201Pins,
    ["2.0.2"] = liveWire20Pins(720042125, 856873108, 26484),
    ["2.0.3"] = liveWire203Pins,
    ["2.1.0"] = liveWire210Pins,
    ["2.1.1"] = withCoreVersion(909228043),
    ["2.1.2"] = withCoreVersion(103061906),
    ["2.1.3"] = liveWire213Pins,
    ["2.1.4"] = liveWire214Pins,
    ["2.1.5"] = liveWire215Pins,
}

-- ISA 1.2.16 updates client actions only. Both releases share these server and shared sources.
local isaPins = {
    {isa, bankPath .. "PowerBankObject_Server.lua", 164324458, 19575},
    {isa, bankPath .. "PowerBankSystem_Server.lua", 595993071, 7591},
    {isa, bankPath .. "PowerBankSystem_Commands.lua", 880518164, 5084},
    {isa, sharedPath .. "ImmersiveSolarArrays/PowerBankSystem_Shared.lua", 56303664, 2265},
    {isa, sharedPath .. "ImmersiveSolarArrays/Utilities.lua", 954510266, 2071},
    {isa, sharedPath .. "ImmersiveSolarArrays/WorldUtilities.lua", 300002325, 6223},
    {isa, serverPath .. "ImmersiveSolarArrays/World/MapObjects.lua", 335874604, 5442},
    {isa, sharedPath .. "ImmersiveSolarArrays/RecipeCode.lua", 569828772, 10269},
}
local portalPins = {
    ["0.1.4"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 54921769, 10271},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 588150454, 10044},
        {portals, serverPath .. "SuQingPortals/World.lua", 73590792, 34673},
    },
    ["0.1.5"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 121141545, 11052},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 813401116, 7780},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 588150454, 10044},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
    },
    ["0.1.6-rc.1"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 124816505, 8836},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 588150454, 10044},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 641606651, 7304},
    },
    ["0.1.6-rc.2"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 907430381, 8845},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 588150454, 10044},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 934529105, 7304},
    },
    ["0.1.6-rc.3"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 766851611, 8866},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 588150454, 10044},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 227451552, 7304},
    },
    ["0.1.6-rc.4"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 934221651, 8887},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 588150454, 10044},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 520374006, 7304},
    },
    ["0.1.6-rc.5"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 524220744, 8908},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 218973082, 10110},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 813296460, 7304},
    },
    ["0.1.6-rc.6"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 513235282, 8929},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 218973082, 10110},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 106218907, 7304},
    },
    ["0.1.6-rc.7"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 631349200, 8950},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 218973082, 10110},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 399141361, 7304},
    },
    ["0.1.6-rc.8"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 688241928, 8971},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 218973082, 10110},
        {portals, serverPath .. "SuQingPortals/World.lua", 634899781, 35143},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 692063815, 7304},
    },
    ["0.1.6-rc.9"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 688241928, 8971},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 218973082, 10110},
        {portals, serverPath .. "SuQingPortals/World.lua", 882525639, 35943},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 692063815, 7304},
    },
    ["0.1.6-rc.10"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 888550327, 8992},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 218973082, 10110},
        {portals, serverPath .. "SuQingPortals/World.lua", 882525639, 35943},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 259759072, 7305},
    },
    ["0.1.6-rc.11"] = {
        {portals, serverPath .. "SuQingPortals/Power.lua", 921580269, 11060},
        {portals, serverPath .. "SuQingPortals/LiveWirePower.lua", 888550327, 8992},
        {portals, serverPath .. "SuQingPortals/ISAPower.lua", 218973082, 10110},
        {portals, serverPath .. "SuQingPortals/World.lua", 882525639, 35943},
        {portals, sharedPath .. "SuQingPortals/Core.lua", 995888543, 7400},
    },
}

local function modInfo(id)
    return getModInfoByID(id) or getModInfoByID("\\" .. id)
end

local function version(id)
    local info = modInfo(id)
    return info and info.getModVersion and tostring(info:getModVersion())
end

local function active(mods, id)
    return mods:contains(id) or mods:contains("\\" .. id)
end

local function fingerprint(modId, path)
    local reader = getModFileReader(modId, path, false)
    if not reader then return nil end
    local hash, count, previousCR, openLine = 0, 0, false, false
    local function feed(unit)
        hash = (hash * 131 + unit) % 1000000007
        count = count + 1
    end
    local ok, reason = pcall(function()
        while true do
            -- Read Java character units consistently on stock and optimized Kahlua.
            local unit = reader:read()
            if unit == -1 then break end
            if unit == 13 then
                feed(10)
                previousCR, openLine = true, false
            elseif unit == 10 then
                if not previousCR then feed(10) end
                previousCR, openLine = false, false
            else
                previousCR, openLine = false, true
                if unit > 0 and unit < 128 then feed(unit) end
            end
        end
        if openLine then feed(10) end
    end)
    reader:close()
    if not ok then error(reason) end
    return hash, count
end

local function verify(entries)
    for _, pin in ipairs(entries) do
        local hash, count = fingerprint(pin[1], pin[2])
        if hash ~= pin[3] or count ~= pin[4] then
            return false, "source differs: " .. pin[1] .. "/" .. pin[2]
        end
    end
    return true
end

function Gate.check()
    if isClient() or isServer() then return false, "single-player only" end
    local core = getCore()
    local gameVersion = core and core.getGameAndBuildVersion and core:getGameAndBuildVersion()
    if gameVersion ~= "42.21.0" and gameVersion ~= "42.22.2" then
        return false, "requires Project Zomboid 42.21.0 or 42.22.2"
    end
    local mods = getActivatedMods()
    if not mods or not active(mods, liveWire) or not active(mods, isa) or active(mods, "ISA-Fix") then
        return false, "requires Live Wire and ISA without ISA-Fix"
    end
    if active(mods, "batman_LiveWireExtended") then
        return false, "LiveWire Extended is not supported by the unified grid"
    end
    local wireVersion = version(liveWire)
    local pins = liveWirePins[wireVersion]
    local isaVersion = version(isa)
    if not pins or (isaVersion ~= "1.2.15" and isaVersion ~= "1.2.16") then
        return false, "requires LiveWire 1.7.2, 2.0.0–2.0.3 or 2.1.0–2.1.5 and ISA 1.2.15–1.2.16"
    end
    local ok, reason = verify(pins)
    if not ok then return false, reason end
    ok, reason = verify(isaPins)
    if not ok then return false, reason end
    if not active(mods, portals) then return true, nil, wireVersion end
    local portalVersion = version(portals)
    local entries = portalPins[portalVersion]
    if not entries then return false, "unsupported SuQingPortals version: " .. tostring(portalVersion) end
    ok, reason = verify(entries)
    if not ok then return false, reason end
    return true, portalVersion, wireVersion
end

function Gate.fromMod(fn, id, path)
    if type(fn) ~= "function" or not getFilenameOfClosure then return false end
    local info = modInfo(id)
    if not info or not info.getVersionDir then return false end
    local function normalize(value) return tostring(value):gsub("\\", "/"):gsub("^@", ""):gsub("/+$", ""):lower() end
    return normalize(getFilenameOfClosure(fn)) == normalize(info:getVersionDir() .. "/" .. path)
end

local longCable = "SuQingLiveWireLongCable"
local devicesPath = "media/lua/server/LiveWire/LW_Devices.lua"
local longCableRc2Pins = {
    {longCable, devicesPath, 578184432, 1385},
    {longCable, "media/lua/shared/SuQingLiveWireLongCable/Source.lua", 553745507, 2028},
    {longCable, "media/lua/shared/SuQingLiveWireLongCable/Core.lua", 333069933, 4987},
}
local longCableRc3Pins = {
    {longCable, devicesPath, 578184432, 1385},
    {longCable, "media/lua/shared/SuQingLiveWireLongCable/Source.lua", 279139674, 2044},
    {longCable, "media/lua/shared/SuQingLiveWireLongCable/Core.lua", 256597448, 5022},
}
local longCableRc4Pins = {
    {longCable, devicesPath, 578184432, 1385},
    {longCable, "media/lua/shared/SuQingLiveWireLongCable/Source.lua", 742196827, 2064},
    {longCable, "media/lua/shared/SuQingLiveWireLongCable/Core.lua", 588643376, 5047},
}
local longCableRc5Pins = {
    {longCable, devicesPath, 578184432, 1385},
    {longCable, "media/lua/shared/SuQingLiveWireLongCable/Source.lua", 206394123, 2084},
    {longCable, "media/lua/shared/SuQingLiveWireLongCable/Core.lua", 292695532, 5072},
}
local longCableVersions = {
    ["2.1.2"] = { ["0.1.0-rc.2"] = longCableRc2Pins, ["0.1.0-rc.3"] = longCableRc3Pins,
        ["0.1.0-rc.4"] = longCableRc4Pins, ["0.1.0-rc.5"] = longCableRc5Pins },
    ["2.1.3"] = { ["0.1.0-rc.3"] = longCableRc3Pins, ["0.1.0-rc.4"] = longCableRc4Pins,
        ["0.1.0-rc.5"] = longCableRc5Pins },
    ["2.1.4"] = { ["0.1.0-rc.4"] = longCableRc4Pins, ["0.1.0-rc.5"] = longCableRc5Pins },
    ["2.1.5"] = { ["0.1.0-rc.5"] = longCableRc5Pins },
}

function Gate.fromLiveWireDevices(fn)
    if Gate.fromMod(fn, liveWire, devicesPath) then return true end
    local lw, cable = LiveWire, SQLongCable
    local allowedCableVersions = lw and longCableVersions[lw.VERSION]
    if not allowedCableVersions or not lw.Devices or lw.Devices.find ~= fn
        or type(fn) ~= "function" or type(cable) ~= "table" or cable.recoveryReady ~= true
        or cable.recoveryFind ~= fn then return false end

    local mods = getActivatedMods()
    if not mods or not active(mods, longCable)
        or not Gate.fromMod(fn, longCable, devicesPath) then return false end
    local pins = allowedCableVersions[version(longCable)]
    if not pins then return false end

    -- Gate.check still verifies the Workshop original. Only this reviewed proxy may
    -- provide Devices.find, whose function body is unchanged by the recovery patch.
    local ok = verify(pins)
    return ok
end

return Gate
