-- The native light hotkey returns after selecting a held light even when that
-- light cannot be activated. MFS weapon parts can trigger that early return.
-- Wrap the existing handler; do not add another keyboard-event listener.
CodexMFSAttachedLightHotkey = CodexMFSAttachedLightHotkey or {}
local State = CodexMFSAttachedLightHotkey

local function eligibleHeldLight(item)
    return item ~= nil and item:canEmitLight()
        and item:getType() ~= "CandleLit"
        and item:getType() ~= "Lantern_HurricaneLit"
end

local function blockedHeldWeapon(player)
    -- Match the native secondary-hand-before-primary-hand selection exactly.
    local selected = player:getSecondaryHandItem()
    if not eligibleHeldLight(selected) then
        selected = player:getPrimaryHandItem()
    end
    if eligibleHeldLight(selected) and instanceof(selected, "HandWeapon")
        and selected:isRanged() and not selected:canBeActivated() then
        return selected
    end
    return nil
end

local function findAttachedSwitchableLight(player)
    local attached = player:getAttachedItems()
    for i = 0, attached:size() - 1 do
        local item = attached:getItemByIndex(i)
        if eligibleHeldLight(item) and not instanceof(item, "HandWeapon") then
            -- Preserve the native first-attached-light priority, including its
            -- no-op behavior when that first light cannot be activated.
            if item:canBeActivated() then return item end
            return nil
        end
    end
    return nil
end

local function install()
    if State.installed then return end
    if not ItemBindingHandler or type(ItemBindingHandler.toggleLight) ~= "function" then
        print("[CodexAttachedLightHotkey] not installed: native light handler unavailable")
        return
    end
    -- Capture here, after shared OnGameStart wrappers (including VFE candles).
    local original = ItemBindingHandler.toggleLight
    local function toggleLight(key)
        local core = getCore()
        if not core:isKey(KeybindId.LIGHT_SOURCE, key) then
            return original(key)
        end
        local player = getSpecificPlayer(0)
        if not player then return original(key) end
        if core:isKey(KeybindId.TOGGLE_VEHICLE_HEADLIGHTS, key) then
            local vehicle = player:getVehicle()
            if vehicle and vehicle:isDriver(player) and not player:isAiming() then
                -- Native handling also returns for vehicles without headlights.
                return original(key)
            end
        end
        local blocker = blockedHeldWeapon(player)
        if not blocker then return original(key) end
        local light = findAttachedSwitchableLight(player)
        if not light then return original(key) end

        light:setActivated(not light:isActivated())
        syncItemActivated(player, light)
        light:playActivateDeactivateSound()
        if not State.loggedRedirect then
            print("[CodexAttachedLightHotkey] redirected held " .. tostring(blocker:getFullType())
                .. " to attached " .. tostring(light:getFullType()))
            State.loggedRedirect = true
        end
        -- The existing handler must not run again after we toggle this light.
        return
    end
    State.original = original
    State.wrapper = toggleLight
    ItemBindingHandler.toggleLight = toggleLight
    State.installed = true
    print("[CodexAttachedLightHotkey] v1.0.0 installed")
end

Events.OnGameStart.Add(install)
