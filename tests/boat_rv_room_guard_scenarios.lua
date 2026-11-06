local checks = 0
local originalStringByte = string.byte
local function expect(value, label)
    checks = checks + 1
    assert(value, 'check ' .. checks .. ': ' .. label)
end
local function clone(v)
    if type(v) ~= 'table' then return v end
    local out = {}; for k, x in pairs(v) do out[k] = clone(x) end; return out
end
local data, target, player, menu, teleports, lastRoom, lookups, notices, sourceMode
local NativeEntry, NativeMenu
local function vehicle(script, id)
    local md = {projectRV_uniqueId = id}
    return {
        getScript = function() return {getFullName=function() return script end} end,
        getModData = function() return md end,
        getSeat = function() return 0 end,
        getX = function() return 1 end, getY = function() return 1 end, getZ = function() return 0 end,
        getBatteryCharge = function() return 1 end,
        getVehicleTowing = function(self) return self end,
        getUseablePart = function() return nil end,
    }
end
local function setup(saved, guard, mode)
    data, target, teleports, lastRoom, lookups, notices = saved or {}, nil, 0, nil, 0, 0
    sourceMode = mode
    string.byte = originalStringByte
    if mode == 'unicode_byte' then
        string.byte = function(value, index)
            local character = string.sub(value, index, index)
            return NON_ASCII_CODEPOINTS[character] or originalStringByte(value, index)
        end
    end
    SQBoatRVRoomGuardCore = nil; SuQingBoatRVRoomGuard = nil; RVHooks = nil
    VehicleTypes = nil
    local counter = 10000
    ZombRand = function(a, b) if b then counter=counter+1; return counter end; return 0 end
    getActivatedMods = function() return {} end
    isClient = function() return mode == 'mp' end
    isServer = function() return false end
    isMultiplayer = isClient
    ModData = {getOrCreate=function() if sourceMode=='throw_moddata' then error('mock read failure') end; return data end}
    Events = {OnGameStart={Add=function() end}}
    local pmd = {}
    player = {getModData=function() return pmd end,getPlayerNum=function() return 0 end,isSeatedInVehicle=function() return true end}
    menu = {slices={},addSlice=function(self,...) self.slices[#self.slices+1]={...} end}
    getPlayerRadialMenu = function() return menu end
    getSpecificPlayer = function() return player end
    getTexture = function(path) return path end
    getText = function(key) return 'localized:' .. key end
    HaloTextHelper = {addBadText=function() notices=notices+1 end}
    ISVehicleMenu = {getVehicleToInteractWith=function(p) expect(p==player,'lookup receives original player');lookups=lookups+1;return target end}
    getModFileReader = function(mod, path, create)
        expect(create==false,'source guard never creates files')
        if sourceMode == 'missing' then return nil end
        local rows = PIN_LINES[mod .. '|' .. path]
        assert(rows,mod .. '/' .. path)
        local index, charIndex, sentBOM = 0, 0, false
        local units = PIN_CHARS[mod .. '|' .. path]()
        return {read=function()
            if sourceMode=='bom' and not sentBOM then sentBOM=true;return 65279 end
            charIndex=charIndex+1
            if sourceMode=='changed' and charIndex==1 then return 32 end
            return units[charIndex] or -1
        end,readLine=function()
            index=index+1
            if sourceMode=='bom' and index==1 then return BOM_CHARACTER .. rows[1] end
            if sourceMode=='changed' and index==1 then return rows[1] .. ' ' end
            return rows[index]
        end,close=function() end}
    end
    require = function(name)
        if name=='RVVehicleTypes' then return {VehicleTypes=VehicleTypes} end
        if name=='RVHooks' then return RVHooks end
        if name=='SQBoatRVRoomGuard/Core' then return SQBoatRVRoomGuardCore end
        if name=='SQBoatRVRoomGuard/SourcePins' then return SQBoatRVRoomGuardPins end
        error('unexpected require ' .. name)
    end
    LOAD_NATIVE_TYPES()
    LOAD_ADDON_REGISTRATION()
    LOAD_NATIVE_HOOKS()
    NativeEntry, NativeMenu = BUILD_NATIVE_FUNCTIONS(function(_,room) teleports=teleports+1;lastRoom=room end)
    ISVehicleMenu.showRadialMenu = NativeMenu
    check = true
    if guard then
        LOAD_PATCH_CORE(); LOAD_PATCH_PINS(); LOAD_PATCH_CLIENT()
        local before = ISVehicleMenu.getVehicleToInteractWith
        SuQingBoatRVRoomGuard.install()
        return before
    end
end
local RV = 'Base.86bounder'
local BOAT = 'Base.CabineFantasmaBR'
local function enter(script,id)
    target=vehicle(script,id); NativeEntry(player); return target
end
local function key(room) return tostring(room.x)..':'..tostring(room.y)..':'..tostring(room.z or 0) end

-- First reproduce the real upstream collision without the patch.
setup(nil,false)
enter(RV,1);local originalRoom=lastRoom
enter(BOAT,2)
expect(key(originalRoom)==key(lastRoom),'unpatched live allocator reproduces cross-type collision')

-- Pinned source checks and native callback/menu integration.
setup(nil,true)
local G=SuQingBoatRVRoomGuard
expect(G.ready,'reviewed live sources pass runtime fingerprints: '..tostring(G.error))
local lookup=ISVehicleMenu.getVehicleToInteractWith
expect(G.install() and lookup==ISVehicleMenu.getVehicleToInteractWith,'installation is idempotent')
expect(#RVHooks.handlers.preEnter==1,'one pre-entry safety handler')
LOAD_PATCH_CLIENT();G.install()
expect(lookup==ISVehicleMenu.getVehicleToInteractWith and #RVHooks.handlers.preEnter==1,'reloading client glue does not stack wrappers or hooks')
expect(RVHooks.emit('preExit',{typeKey='3x6caravan'})==true,'existing exit hooks remain untouched')
local oldCoords=key(VehicleTypes['3x6caravan'].rooms[1])
enter(RV,11);originalRoom=lastRoom
enter(BOAT,12)
expect(key(originalRoom)~=key(lastRoom),'RV then boat receive different physical rooms')
expect(key(originalRoom)==oldCoords,'old RV coordinates retained')
expect(data.AssignedRooms3x6caravan['11']==originalRoom,'original assignment object retained')

setup(nil,true)
enter(BOAT,1);originalRoom=lastRoom;enter(RV,2)
expect(key(originalRoom)~=key(lastRoom),'boat then RV also receive different rooms')

-- Fill the actual 38-slot pool through the REAL native menu and entry functions.
setup(nil,true)
local used, vehicles = {}, {}
for i=1,38 do
    local script=i%2==1 and RV or BOAT
    target=vehicle(script,i);vehicles[i]=target;menu.slices={}
    NativeMenu(player)
    expect(#menu.slices==1,'native menu remains available while a room is free, slot '..i)
    local before=teleports;NativeEntry(player)
    expect(teleports==before+1,'native entry succeeds, slot '..i)
    expect(not used[key(lastRoom)],'physical room never reused, slot '..i)
    used[key(lastRoom)]=true
end
target=vehicle(RV,100);menu.slices={};NativeMenu(player)
expect(#menu.slices==0,'full native pool hides new entry at correct capacity')
local before=teleports;NativeEntry(player)
expect(teleports==before,'full pool blocks new assignment before teleport')
target=vehicles[1];menu.slices={};NativeMenu(player)
expect(#menu.slices==1,'existing RV still has a menu when pool is full')
NativeEntry(player);expect(teleports==before+1,'existing RV still enters when pool is full')
local persisted=clone(data)
setup(persisted,true)
target=vehicle(BOAT,2);NativeEntry(player)
expect(teleports==1 and key(lastRoom)==key(persisted.AssignedRoomsfrotabr_cabine['2']),'save/reload preserves boat assignment')
expect(SuQingBoatRVRoomGuard.ready,'reloaded source pools reinstall without extra persistent patch data')

-- Production reported full Unicode byte values while offline Kahlua masked them.
-- Both must accept the SAME canonical, reviewed source without disabling drift checks.
setup(nil,true,'unicode_byte')
expect(SuQingBoatRVRoomGuard.ready,'full-Unicode byte semantics accept unchanged source')
enter(BOAT,31);expect(teleports==1,'portable guard allows a valid boat cabin entry')
setup(nil,true,'bom')
expect(SuQingBoatRVRoomGuard.ready,'UTF-8 BOM on reader lines does not cause a false drift warning')

-- Existing occupants are never moved, including pre-existing bad assignments.
setup(nil,false)
local r=clone(VehicleTypes['3x6caravan'].rooms[1])
local collision={AssignedRooms3x6caravan={oldRV=r},AssignedRoomsfrotabr_cabine={oldBoat=clone(r)}}
setup(collision,true)
enter(RV,'oldRV');expect(teleports==0,'pre-existing RV collision blocked')
enter(BOAT,'oldBoat');expect(teleports==0,'pre-existing boat collision blocked')
expect(key(collision.AssignedRooms3x6caravan.oldRV)==key(r),'RV belongings/location not migrated')
expect(key(collision.AssignedRoomsfrotabr_cabine.oldBoat)==key(r),'boat belongings/location not migrated')
local notified=notices;enter(BOAT,'oldBoat');expect(notices==notified,'same collision notification is not spammed')
enter(BOAT,'newBoat');expect(teleports==1 and key(lastRoom)~=key(r),'unrelated free rooms remain usable after a legacy collision')

-- Other registered groups are included in the occupancy scan.
local foreign={AssignedRoomsOtherAddon={occupied=clone(r)}}
setup(foreign,true);enter(BOAT,90)
expect(key(lastRoom)~=key(r),'foreign interior group cannot be overwritten')
expect(foreign.AssignedRoomsOtherAddon.occupied.x==r.x,'foreign assignment untouched')

-- The pool-filter rule must retain OWN occupied slots for native menu accounting.
setup(nil,false)
local saved={AssignedRooms3x6caravan={}}
for i=1,21 do saved.AssignedRooms3x6caravan[tostring(i)]=clone(VehicleTypes['3x6caravan'].rooms[i]) end
setup(saved,true);target=vehicle(RV,99);menu.slices={};NativeMenu(player)
expect(#menu.slices==1,'21 occupied RVs do not prematurely hide entry with 17 free rooms')
NativeEntry(player);expect(teleports==1,'native allocator can use the remaining free room')

-- Unknown upstream sources, invalid data and runtime replacement fail closed.
setup(nil,true,'changed')
expect(not SuQingBoatRVRoomGuard.ready,'changed upstream source rejected')
enter(BOAT,1);expect(teleports==0,'changed source blocks boat entry')
target=vehicle('Base.Van',2);expect(ISVehicleMenu.getVehicleToInteractWith(player)==target,'unrelated RV lookup retained during source rejection')
setup(nil,true,'missing');expect(not SuQingBoatRVRoomGuard.ready,'unreadable source rejected')
setup({AssignedRooms3x6caravan='broken'},true)
expect(not SuQingBoatRVRoomGuard.ready,'malformed assignment map rejected without overwriting it')
expect(data.AssignedRooms3x6caravan=='broken','malformed data retained for recovery')
setup(nil,true)
VehicleTypes['frotabr_cabine'].rooms={};target=vehicle(BOAT,3)
expect(ISVehicleMenu.getVehicleToInteractWith(player)==nil,'runtime room-definition replacement blocked')
setup(nil,true);sourceMode='throw_moddata';target=vehicle(BOAT,4)
expect(ISVehicleMenu.getVehicleToInteractWith(player)==nil,'lookup checker failure blocks target')
expect(not SuQingBoatRVRoomGuard.ready,'checker failure is visible in status')
setup(nil,true)
getText=function() error('mock broken translator') end
local badCtx={typeKey='frotabr_cabine',side='SP',vehicle=vehicle(BOAT,999),player=player,room=r}
expect(RVHooks.emit('preEnter',badCtx)==false,'translation/notification failures cannot turn a rejected entry into permission')
expect(SuQingBoatRVRoomGuard.lastNotificationError~=nil,'notification failure is recorded')
expect(RVHooks.emit('preEnter',nil)==false,'malformed hook context fails closed')
setup(nil,true);sourceMode='throw_moddata'
local allowed=RVHooks.emit('preEnter',{typeKey='frotabr_cabine',side='SP',vehicle=vehicle(BOAT,4),player=player,room=r})
expect(allowed==false,'entry checker errors cannot be swallowed into permission by RVHooks')
setup(nil,true,'mp')
expect(not SuQingBoatRVRoomGuard.ready and #RVHooks.handlers.preEnter==0,'multiplayer is not silently claimed or modified')

-- No persistent reservation maps, no mutation of assigned room positions.
setup(nil,false)
saved={AssignedRooms3x6caravan={a=clone(VehicleTypes['3x6caravan'].rooms[1])},OtherMod={sentinel=true}}
setup(saved,true)
expect(saved.OtherMod.sentinel and saved.AssignedRooms3x6caravan.a.x==22560,'other state and original positions preserved')
expect(saved.SuQingBoatRVRoomGuard==nil,'patch creates no extra persistent allocation database')

return 'PASS assertions=' .. checks .. '; live native allocator/menu/hooks; mock world only; no game/save writes'
