local B = require "SuQingProteinTrainingBoost/Core"

B.Iron = B.Iron or {}
local Iron = B.Iron

local function normalized(path)
    if type(path) ~= "string" then return nil end
    return (path:gsub("\\", "/"):gsub("^@", ""):gsub("/+$", ""):lower())
end

local function reviewed(fn, path, line)
    return type(fn) == "function"
        and normalized(getFilenameOfClosure(fn)) == path
        and getFirstLineOfClosure(fn) == line
end

local function ownsHooks(bridge)
    return SweatWorkzSupps == bridge.supplements and SweatWorkz_BoostUI == bridge.ui
        and bridge.supplements.xpBoost == bridge.xpHook
        and bridge.supplements.boostActive == bridge.boostActive
        and bridge.ui.prerender == bridge.renderHook
end

function Iron.RestoreHooks()
    local bridge = Iron.bridge
    if not bridge then return end
    if bridge.supplements.xpBoost == bridge.xpHook then
        bridge.supplements.xpBoost = bridge.xpBoost
    end
    if bridge.ui.prerender == bridge.renderHook then
        bridge.ui.prerender = bridge.prerender
    end
    Iron.bridge = nil
end

local function refuse(reason)
    Iron.RestoreHooks()
    Iron.blocked = true
    B.Log("Project Iron XP compatibility paused; SuQing XP bonuses are inactive: " .. reason)
    return false, reason
end

local function checkProjectIron()
    local id = "SweatWorkz"
    local active = type(getActivatedMods) == "function" and getActivatedMods() or nil
    if active and not active:contains(id) then
        id = "\\SweatWorkz"
        if not active:contains(id) then return nil, "absent" end
    elseif not active and not SweatWorkzSupps then
        return nil, "absent"
    end
    if not active or type(getModInfoByID) ~= "function"
        or type(getFilenameOfClosure) ~= "function" or type(getFirstLineOfClosure) ~= "function" then
        return nil, "mod metadata or Lua source API unavailable"
    end
    local info = getModInfoByID(id)
    if not info or not info.getModVersion or not info.getVersionDir
        or tostring(info:getModVersion()) ~= "0.6.0" then
        return nil, "reviewed Project Iron 0.6.0 required"
    end
    local dir = normalized(info:getVersionDir())
    local supplements = SweatWorkzSupps
    local ui = SweatWorkz_BoostUI
    local script = dir and dir .. "/media/lua/shared/sweatworkz_supplements.lua"
    if not dir or dir:sub(-3) ~= "/42" or not supplements or not ui
        or not reviewed(supplements.xpBoost, script, 46)
        or not reviewed(supplements.boostActive, script, 121)
        or not reviewed(ui.prerender, dir .. "/media/lua/client/sweatworkz_boostui.lua", 138) then
        return nil, "unreviewed Project Iron supplement or UI hooks"
    end
    return {
        supplements = supplements,
        ui = ui,
        xpBoost = supplements.xpBoost,
        boostActive = supplements.boostActive,
        prerender = ui.prerender,
    }
end

function Iron.Install()
    if not B.IsSinglePlayer() then
        Iron.RestoreHooks()
        return false, "multiplayer"
    end
    if Iron.bridge and ownsHooks(Iron.bridge) then return true, "installed" end
    Iron.RestoreHooks()
    Iron.blocked = nil
    local ok, bridge, reason = pcall(checkProjectIron)
    if not ok then return refuse(tostring(bridge)) end
    if not bridge then
        if reason == "absent" then return true, reason end
        return refuse(reason)
    end

    -- In 0.6.0, the private XP callback reads this getter after recording
    -- the workout. The only other caller is the stock status tooltip.
    local rendering = false
    bridge.xpHook = function()
        if rendering or Iron.bridge ~= bridge then return bridge.xpBoost() end
        return 0
    end
    bridge.renderHook = function(self)
        local wasRendering = rendering
        rendering = true
        local rendered, err = pcall(bridge.prerender, self)
        rendering = wasRendering
        if not rendered then error(err, 0) end
    end
    bridge.supplements.xpBoost = bridge.xpHook
    bridge.ui.prerender = bridge.renderHook
    Iron.bridge = bridge
    return true, "installed"
end

function Iron.GetMultiplier(player)
    if Iron.blocked then return nil end
    local bridge = Iron.bridge
    if not bridge then return 1 end
    if not ownsHooks(bridge) then
        refuse("Project Iron hooks changed after installation")
        return nil
    end
    if not bridge.boostActive(player) then return 1 end
    local extra = bridge.xpBoost()
    if not B.IsFinite(extra) or extra <= 0 then return 1 end
    return 1 + extra
end

return Iron
