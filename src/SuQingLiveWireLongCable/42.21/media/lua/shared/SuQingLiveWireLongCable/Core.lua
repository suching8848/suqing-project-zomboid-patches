SQLongCable = SQLongCable or {}
local Cable = SQLongCable
local OPTION = "SuQingLiveWireLongCable.DeviceRange"
local WIRE = "Base.ElectricWire"

function Cable.ready()
    local lw = LiveWire
    return Cable.wire ~= nil and Cable.recoveryReady == true
        and lw and (lw.VERSION == "2.1.2" or lw.VERSION == "2.1.3" or lw.VERSION == "2.1.4" or lw.VERSION == "2.1.5" or lw.VERSION == "2.1.6" or lw.VERSION == "2.1.8" or lw.VERSION == "2.2.0")
        and lw.Registry and lw.Registry.ready and not lw.Registry.readOnly
end

function Cable.rangeForModel(model)
    local base = LiveWire.Config.get("LinkRange")
    local definition = model and LiveWire.Defs.devices[model]
    if not definition or definition.role == "inverter" then return base end
    local opts = getSandboxOptions()
    local opt = opts and opts:getOptionByName(OPTION)
    local configured = opt and tonumber(opt:getValue()) or 0
    return math.max(base, math.min(100, math.max(0, math.floor(configured))))
end

function Cable.target(obj)
    if not LWBaseAction.objectStillThere(obj) then return nil end
    local square = obj:getSquare()
    local mark = LiveWire.Marks.get(obj)
    local model = mark and LiveWire.Defs.modelOfObject(obj)
    local def = model and LiveWire.Defs.devices[model]
    if not def or def.role == "inverter" or mark.model ~= model then return nil end
    local dev = LiveWire.Registry.device(mark.id)
    if dev and dev.model == model and dev.x == square:getX() and dev.y == square:getY() and dev.z == square:getZ() then
        return dev
    end
end

local function masterGrid(master)
    if not master or master.role ~= "inverter" or master.coupled or LiveWire.Devices.pending[master.id] then return nil end
    local def = LiveWire.Defs.devices[master.model]
    local g = master.grid and LiveWire.Registry.grid(master.grid)
    if def and def.role == "inverter" and g and g.inverter == master.id then return g end
end

local function distance(dev, master)
    return LiveWire.Install.distance(dev.x, dev.y, dev.z, master.x, master.y, master.z)
end

local function checkMasterSquare(character, master)
    local cell = getCell()
    local square = cell:getGridSquare(master.x, master.y, master.z)
    if not square then
        -- A missing square inside a loaded chunk is not an unloaded inverter.
        return cell:getChunkForGridSquare(master.x, master.y, master.z) == nil
    end
    local obj = LiveWire.Marks.findOnSquare(square, master.id)
    return LWBaseAction.objectStillThere(obj) and LiveWire.Defs.modelOfObject(obj) == master.model
        and (not character or LiveWire.canTouch(character, square))
end

function Cable.candidates(dev)
    local out = {}
    local original = LiveWire.Config.get("LinkRange")
    local range = Cable.rangeForModel(dev.model)
    if range <= original then return out end
    local floors = LiveWire.Config.get("LinkVerticalRange")
    for _, master in ipairs(LiveWire.Registry.invertersNear(dev.x, dev.y, range)) do
        if masterGrid(master) then
            local dist, dz = distance(dev, master)
            if dist > original and dist <= range and dz <= floors and checkMasterSquare(nil, master) then
                out[#out + 1] = { master = master, distance = dist }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.distance == b.distance then return a.master.id < b.master.id end
        return a.distance < b.distance
    end)
    return out
end

function Cable.check(character, obj, masterId)
    if not Cable.ready() or not character or character:isDead() then return false, "Tooltip_LW_Invalid" end
    local install = LiveWire.Install
    local dev = Cable.target(obj)
    local master = LiveWire.Registry.device(masterId)
    local grid = masterGrid(master)
    if not dev or not grid or not checkMasterSquare(character, master) then return false, "Tooltip_LW_Invalid" end
    if not LiveWire.canTouch(character, obj:getSquare()) then return false, "Tooltip_LW_Safehouse" end
    if dev.grid == grid.id then return false, "Tooltip_LW_AlreadyLinked" end

    local dist, dz = distance(dev, master)
    local floors = LiveWire.Config.get("LinkVerticalRange")
    if dz > floors then return false, "Tooltip_LW_TooManyFloors", tostring(dz), tostring(floors) end
    local range = Cable.rangeForModel(dev.model)
    if dist > range then return false, "Tooltip_LW_TooFarForCable", tostring(math.ceil(dist - 1e-9)), tostring(range) end
    if dist <= LiveWire.Config.get("LinkRange") then return false, "Tooltip_LW_Invalid" end
    if not install.screwdriver(character) then return false, "Tooltip_LW_NeedScrewdriver" end

    local required = LiveWire.Defs.devices[dev.model].level or 0
    if not master.svc then required = math.max(required, LiveWire.Defs.devices[master.model].level or 0) end
    if not install.hasLevel(character, required) then
        return false, "Tooltip_LW_NeedLevel", LiveWire.Config.requiredLevel(required)
    end
    local wires = install.wiresFor(dist)
    if install.countType(character, WIRE) < wires then return false, "Tooltip_LW_NeedWire", wires end
    return true, nil, wires, master, grid
end

return Cable
