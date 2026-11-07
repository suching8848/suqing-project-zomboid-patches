-- Runs the installed Project Iron supplement script against the compatibility
-- bridge. Only the native engine objects and event dispatcher are modeled here.
local ironSource = assert(IRON_SUPPLEMENTS_SOURCE_PATH or (arg and arg[3]),
    "the Iron suite needs the installed SweatWorkz_Supplements.lua")
local uiSource = assert(IRON_UI_SOURCE_PATH or (arg and arg[4]),
    "the Iron suite needs the installed SweatWorkz_BoostUI.lua")
local versionDir = assert(ironSource:match("^(.*)/media/lua/shared/SweatWorkz_Supplements%.lua$"),
    "the Iron suite needs an absolute, forward-slash source path")
local xpSource = (arg and arg[1]) or
    "src/SuQingProteinTrainingBoost/42/media/lua/shared/SuQingProteinTrainingBoost/XP.lua"
local adapterSource = (arg and arg[2]) or
    "src/SuQingProteinTrainingBoost/42/media/lua/shared/SuQingProteinTrainingBoost/Iron.lua"
local B = require "SuQingProteinTrainingBoost/Core"

local now, client, players
function getGameTime() return { getWorldAgeHours = function() return now end } end
function isClient() return client end
function isServer() return false end
function getNumActivePlayers() return #players end
function getSpecificPlayer(index) return players[index + 1] end
function getTextOrNull(key) return key end
function getText(key, value) return key .. " " .. tostring(value) end
function getTexture(name) return name end
function instanceof(player, kind) return player ~= nil and kind == "IsoPlayer" end

CharacterStat = { ENDURANCE = "endurance", FATIGUE = "fatigue", STRESS = "stress" }
local MAX_XP = 487500
local function perk(id)
    return { getId = function() return id end,
        getTotalXpForLevel = function() return MAX_XP end }
end
Perks = { Strength = perk("Strength"), Fitness = perk("Fitness"), Sprinting = perk("Sprinting") }

local function newEvent()
    local handlers = {}
    return {
        handlers = handlers,
        Add = function(handler) handlers[#handlers + 1] = handler end,
        Remove = function(handler)
            for i = #handlers, 1, -1 do
                if handlers[i] == handler then table.remove(handlers, i) end
            end
        end,
        fire = function(...)
            for i = 1, #handlers do handlers[i](...) end
        end,
    }
end

local checks = 0
local function check(condition, label)
    assert(condition, label)
    checks = checks + 1
end

local function near(actual, expected, label)
    check(math.abs(actual - expected) < 0.00001,
        label .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected))
end

local function newPlayer(proteins)
    local player = {
        proteins = proteins or 0,
        modData = { strengthUpTimer = 30000, fitnessUpTimer = 30000 },
        totals = {}, nativeCalls = 0, flatRecorded = 0,
        stats = { endurance = 0.5, fatigue = 0.5, stress = 0.1 }, stiffness = 10,
        messages = {},
    }
    players[#players + 1] = player
    function player:getModData() return self.modData end
    function player:getFitness() return { getCurrentExe = function() return nil end } end
    function player:getNutrition() return { getProteins = function() return self.proteins end } end
    function player:isDead() return false end
    function player:Say(text) self.messages[#self.messages + 1] = text end
    function player:getStats()
        return {
            get = function(_, stat) return self.stats[stat] end,
            set = function(_, stat, value) self.stats[stat] = value end,
        }
    end
    function player:getBodyDamage()
        local part = {
            getStiffness = function() return self.stiffness end,
            setStiffness = function(_, value) self.stiffness = value end,
        }
        return { getBodyParts = function()
            return { size = function() return 1 end, get = function() return part end }
        end }
    end
    local xp = {}
    function player:getXp() return xp end
    function xp:getXP(skill) return player.totals[skill] or 0 end
    function xp:AddXP(skill, amount, callLua, doBoost)
        local old = self:getXP(skill)
        if amount >= 0 and old >= MAX_XP then return end
        player.nativeCalls = player.nativeCalls + 1
        if skill == Perks.Strength then
            if player.proteins > 50 and player.proteins < 300 then amount = amount * 1.5 end
            if player.proteins < -300 then amount = amount * 0.7 end
        end
        if doBoost ~= false then amount = amount * 5 end
        local total = math.min(MAX_XP, math.max(0, old + amount))
        player.totals[skill] = total
        -- B42.21 emits AddXP synchronously even when callLua is false.
        Events.AddXP.fire(player, skill, total - old)
    end
    return player
end

local function trainingTimer(player, skill, amount)
    if amount <= 0 then return end
    local data = player:getModData()
    if skill == Perks.Strength then data.strengthUpTimer = data.strengthUpTimer - 3000 end
    if skill == Perks.Fitness then data.fitnessUpTimer = data.fitnessUpTimer - 3000 end
end

local function setup(ironFirst, version, active, foreignOrigin)
    now, client, players = 100, false, {}
    B.XP, B.Iron, B.RuntimeReady, SweatWorkzSupps, SweatWorkz_BoostUI = nil, nil, nil, nil, nil
    SandboxVars = { SweatWorkz = { PreWorkoutXPBoost = 100, PreWorkoutMinutes = 120 } }
    getActivatedMods = function()
        return { contains = function(_, id)
            return active and (id == "SweatWorkz" or id == "\SweatWorkz")
        end }
    end
    getModInfoByID = function(id)
        if not active or (id ~= "SweatWorkz" and id ~= "\SweatWorkz") then return nil end
        return {
            getModVersion = function() return version end,
            getVersionDir = function() return versionDir end,
        }
    end
    Events = { AddXP = newEvent(), OnGameStart = newEvent(), OnServerStarted = newEvent(),
        EveryOneMinute = newEvent(), OnServerCommand = newEvent() }
    ISDrinkFluidAction = { updateEat = function() end }
    package.loaded["TimedActions/ISDrinkFluidAction"] = ISDrinkFluidAction
    SweatWorkzGym = { giveXp = function(p, skill, amount) p:getXp():AddXP(skill, amount) end }
    ISUIElement = { derive = function() return {} end }
    package.loaded["ISUI/ISUIElement"] = ISUIElement
    package.loaded["SweatWorkz_Supplements"] = nil
    local files, lines = {}, {}
    getFilenameOfClosure = function(fn) return files[fn] end
    getFirstLineOfClosure = function(fn) return lines[fn] end
    local function loadIron()
        dofile(ironSource)
        package.loaded["SweatWorkz_Supplements"] = true
        dofile(uiSource)
        local S = SweatWorkzSupps
        files[S.xpBoost] = foreignOrigin and "/other/SweatWorkz_Supplements.lua" or ironSource
        files[S.boostActive] = ironSource
        files[SweatWorkz_BoostUI.prerender] = uiSource
        lines[S.xpBoost], lines[S.boostActive], lines[SweatWorkz_BoostUI.prerender] = 46, 121, 138
    end
    -- Model the installed SRJ wrapper's dispatch to the native flat grant.
    addXpNoMultiplier = function(p, skill, amount)
        p.flatRecorded = p.flatRecorded + amount
        p:getXp():AddXP(skill, amount, true, false, false)
        return "flat result"
    end
    if ironFirst then Events.AddXP.Add(trainingTimer) end
    if active and ironFirst then loadIron() end
    local X = dofile(xpSource)
    check(X.Install(), "XP listener installs")
    if active and not ironFirst then loadIron() end
    if not ironFirst then Events.AddXP.Add(trainingTimer) end
    local I = dofile(adapterSource)
    return X, I
end

local function award(player, skill, amount, expected, nativeCalls, label)
    local xp = player:getXp()
    local before = xp:getXP(skill)
    local callsBefore = player.nativeCalls
    SweatWorkzGym.giveXp(player, skill, amount)
    near(xp:getXP(skill) - before, expected, label)
    near(player.nativeCalls - callsBefore, nativeCalls, label .. " native XP calls")
end

local function exerciseSequence(ironFirst)
    local X, I = setup(ironFirst, "0.6.0", true)
    local S = SweatWorkzSupps
    check(I.Install(), "Iron bridge installs with supported upstream")
    check(I.Install(), "Iron bridge reinstalls safely")
    check(X.Install(), "XP listener reinstalls safely")
    near(#Events.AddXP.handlers, 3, "one Iron, one protein bridge and one native listener")
    local player = newPlayer(100)
    local unbuffed = newPlayer(0)

    award(player, Perks.Strength, 1, 7.5, 1, "no supplement")
    check(player.modData.SWZSupp.lastRep == now, "Iron still records a gym repetition")
    S.onPreWorkout(player, 1, true)
    near(I.GetMultiplier(player), 2, "Iron active multiplier")
    near(player.stats.endurance, 0.7, "Iron energy recovery")
    near(player.stats.fatigue, 0.4, "Iron alertness")
    near(S.xpBoost(), 0, "the original Iron listener can no longer add XP")
    local panel = { place = function() end }
    SweatWorkz_BoostUI.prerender(panel)
    check(panel.list[1].lines[2][1]:find("100%", 1, true) ~= nil,
        "upstream UI still shows its configured XP bonus")
    near(S.xpBoost(), 0, "UI does not leave the original bonus enabled")
    panel.place = function() error("intentional UI failure") end
    pcall(SweatWorkz_BoostUI.prerender, panel)
    near(S.xpBoost(), 0, "render failure also restores original-listener suppression")
    award(player, Perks.Strength, 1, 15, 2, "Iron once after native protein bonus")
    near(player.modData.strengthUpTimer, 24000, "one decay update for each base award")
    S.onPreWorkout(player, 1, true)
    near(player.stats.endurance, 0.7, "repeat Iron drink does not reapply energy")
    near(player.modData.SWZSupp.boostUntil, 102, "repeat Iron drink keeps original expiry")

    check(B.AddDose(player, 0.5), "VFX protein activates independently")
    near(X.GetMultiplier(player), 20, "both active expose a single combined multiplier")
    award(player, Perks.Strength, 1, 150, 2, "both supplements multiply once")
    award(player, Perks.Fitness, 1, 100, 2, "both supplements, Fitness")
    SandboxVars.SweatWorkz.PreWorkoutXPBoost = 50
    award(player, Perks.Fitness, 1, 75, 2, "live custom Iron percentage")
    SandboxVars.SweatWorkz.PreWorkoutXPBoost = 0
    award(player, Perks.Fitness, 1, 50, 2, "zero Iron XP leaves VFX active")
    SandboxVars.SweatWorkz.PreWorkoutXPBoost = 100
    award(player, Perks.Sprinting, 1, 5, 1, "other skill unchanged")
    award(unbuffed, Perks.Fitness, 1, 5, 1, "another character has no supplement")
    check(not X.HasFault(player), "dual-active award does not latch a fault")

    local lowProtein = newPlayer(-400)
    S.onPreWorkout(lowProtein, 1, true)
    check(B.AddDose(lowProtein, 0.125), "short protein duration for reverse expiry")
    award(lowProtein, Perks.Strength, 1, 70, 2, "both supplements with native nutrition penalty")

    local before = player:getXp():getXP(Perks.Strength)
    local callsBefore = player.nativeCalls
    check(addXpNoMultiplier(player, Perks.Strength, 10) == "flat result",
        "flat grant wrapper preserves result")
    near(player:getXp():getXP(Perks.Strength) - before, 15, "restoration gets only native nutrition")
    near(player.nativeCalls - callsBefore, 1, "restoration has no extra native XP call")
    near(player.flatRecorded, 10, "flat accounting remains intact")
    award(player, Perks.Fitness, -1, -5, 1, "negative XP unchanged")

    player.totals[Perks.Strength] = MAX_XP - 10
    award(player, Perks.Strength, 1, 10, 2, "native maximum clips the unified award")
    check(not X.HasFault(player), "clipping does not latch a fault")

    now = 100.75
    award(lowProtein, Perks.Strength, 1, 7, 2, "Iron continues after VFX expires")
    now = 102
    near(I.GetMultiplier(player), 1, "Iron ends at its own expiry")
    Events.EveryOneMinute.fire()
    near(player.stats.fatigue, 0.52, "Iron crash still applies once")
    near(player.stats.stress, 0.25, "Iron crash retains stress")
    award(player, Perks.Fitness, 1, 50, 2, "protein continues after Iron expires")
    now = 103
    award(player, Perks.Fitness, 1, 5, 1, "both expired")

    local whey = newPlayer(0)
    award(whey, Perks.Strength, 1, 5, 1, "workout records for whey test")
    now = now + 2 / 60
    Events.EveryOneMinute.fire()
    near(whey.modData.SWZSupp.lastWorkout, 103, "Iron still opens the recovery window")
    S.onProtein(whey, 1, true)
    near(whey.stiffness, 6.5, "Iron whey still relieves soreness")
    near(whey.stats.endurance, 0.65, "Iron whey still restores endurance")
    check(not B.IsActive(whey), "Iron whey does not activate VFX protein")
end

exerciseSequence(true)
exerciseSequence(false)

local function checkRejected(version, foreignOrigin)
    local X, I = setup(true, version, true, foreignOrigin)
    local S = SweatWorkzSupps
    local original = S.xpBoost
    local prerender = SweatWorkz_BoostUI.prerender
    check(not I.Install(), "unsupported Iron does not install")
    check(S.xpBoost == original and SweatWorkz_BoostUI.prerender == prerender,
        "rejected bridge leaves upstream callback and UI intact")
    local player = newPlayer(0)
    S.onPreWorkout(player, 1, true)
    check(B.AddDose(player, 0.5), "test a stored VFX boost despite the rejected bridge")
    check(I.GetMultiplier(player) == nil and X.GetMultiplier(player) == nil,
        "unknown Iron fails closed for the unified XP multiplier")
    award(player, Perks.Fitness, 1, 10, 2, "unmodified upstream Iron retains its own award")
    check(not X.HasFault(player), "rejection happens before an uncertain award")
end

checkRejected("0.7.0", false)
checkRejected("0.6.0", true)

local function checkRuntimeReplacement()
    local X, I = setup(false, "0.6.0", true)
    local S = SweatWorkzSupps
    local original = S.xpBoost
    check(I.Install(), "Iron bridge installs before a runtime replacement")
    local player = newPlayer(0)
    S.onPreWorkout(player, 1, true)
    check(B.AddDose(player, 0.5), "both supplements active before replacement")
    local foreignRender = function() end
    SweatWorkz_BoostUI.prerender = foreignRender
    check(X.GetMultiplier(player) == nil, "runtime replacement pauses unified awards")
    check(S.xpBoost == original, "runtime replacement restores the stock XP getter")
    check(SweatWorkz_BoostUI.prerender == foreignRender, "foreign renderer is preserved")
    award(player, Perks.Fitness, 1, 10, 2, "runtime fallback allows the stock Iron XP path")
end

checkRuntimeReplacement()

local X, I = setup(true, "0.6.0", false)
check(I.Install(), "Iron is an optional dependency")
local player = newPlayer(0)
near(I.GetMultiplier(player), 1, "absent Iron has no multiplier")
check(B.AddDose(player, 0.5), "protein remains available without Iron")
near(X.GetMultiplier(player), 10, "protein-only public multiplier")
award(player, Perks.Fitness, 1, 50, 2, "protein-only settlement")
client = true
award(player, Perks.Fitness, 1, 5, 1, "client receives no single-player supplement")

print("protein_training_boost Iron tests passed (" .. tostring(checks) .. " checks)")
return { suite = "protein_training_boost/iron", checks = checks }
