local Source = {}
local MOD = "batman_LiveWire"
local CORE = "media/lua/shared/LiveWire/LW_Core.lua"
local INSTALL = "media/lua/shared/LiveWire/LW_Install.lua"
Source.actions = "media/lua/shared/LiveWire/TimedActions/LW_TimedActions.lua"
Source.devices = "media/lua/server/LiveWire/LW_Devices.lua"

local pins = {
    [CORE] = { [103061906] = 1405, [296895776] = 1405, [490729646] = 1405, [684563516] = 1405, [878397386] = 1405, [266065119] = 1405 },
    [INSTALL] = { [359279382] = 10905 },
    [Source.actions] = { [502756714] = 33759 },
    [Source.devices] = { [669748086] = 26784 },
}

local pins220 = {
    [CORE] = { [98413954] = 1405 },
    [INSTALL] = { [264614203] = 13255 },
    [Source.actions] = { [845849046] = 33759 },
    [Source.devices] = { [989138579] = 26653 },
}

function Source.read(path)
    local reader = getModFileReader(MOD, path, false)
    if not reader then return nil end
    local lines = {}
    local ok, message = pcall(function()
        while true do
            local line = reader:readLine()
            if line == nil then break end
            lines[#lines + 1] = line
        end
    end)
    reader:close()
    if not ok then error(message) end
    return table.concat(lines, "\n") .. "\n"
end

local function matches(expected, text)
    local pin = expected
    if not text or not pin then return false end
    local hash, count = 0, 0
    for i = 1, #text do
        local byte = string.byte(text, i)
        if byte > 0 and byte < 128 then
            hash = (hash * 131 + byte) % 1000000007
            count = count + 1
        end
    end
    return pin[hash] == count
end

function Source.supported(path, text)
    if isClient() or isServer() then return false end
    local core = getCore()
    local build = core and core:getGameAndBuildVersion()
    if build ~= "42.21.0" and build ~= "42.22.2" then return false end
    local coreSource = path == CORE and text or Source.read(CORE)
    local reviewed = matches(pins220[CORE], coreSource) and pins220 or pins
    if not matches(reviewed[CORE], coreSource) then return false end
    for file, expected in pairs(reviewed) do
        if file ~= CORE and not matches(expected, file == path and text or Source.read(file)) then return false end
    end
    return true
end

function Source.filename(path)
    local info = getModInfoByID(MOD) or getModInfoByID("\\" .. MOD)
    if info and info.getVersionDir then
        return "@" .. tostring(info:getVersionDir()):gsub("\\", "/") .. "/" .. path
    end
    return "@" .. MOD .. "/" .. path
end

return Source
