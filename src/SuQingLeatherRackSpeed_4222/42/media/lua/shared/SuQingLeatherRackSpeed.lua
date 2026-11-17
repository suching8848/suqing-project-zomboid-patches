SuQingLeatherRackSpeed = {}
local speed = SuQingLeatherRackSpeed
local multiplier = 2
local originalDuration = 604800
local supportedVersion = "42.22.2"
local stateKey = "SuQingLeatherRackSpeed_Tick"
local recipes = {"DrySmallLeather", "DryMediumLeather", "DryLargeLeather"}
local patched = {}

local function startTracking(data)
    local previousNative = data:getElapsedTime()
    local accumulated = previousNative
    local finishAt = data:getRecipe():getTime()

    -- The native dryer keeps its own clock and never adds this Lua bonus to it.
    -- A function in recipe modData is skipped by vanilla serialization.
    data:getModData()[stateKey] = function(nativeProgress)
        if nativeProgress < previousNative then
            -- An engine reset establishes a fresh baseline.
            accumulated = nativeProgress
        else
            accumulated = math.min(finishAt, accumulated + (nativeProgress - previousNative) * multiplier)
        end
        previousNative = nativeProgress
        return accumulated
    end
end

function speed.OnStart(data)
    startTracking(data)
end

function speed.OnUpdate(data)
    local advance = data:getModData()[stateKey]
    if not advance then
        -- A loaded batch already includes its saved bonus. Keep the first native tick as-is.
        startTracking(data)
        return
    end

    local nativeProgress = data:getElapsedTime()
    local effectiveProgress = advance(nativeProgress)
    if effectiveProgress > nativeProgress then
        data:setElapsedTime(effectiveProgress)
    end
end

function speed.isPatched(recipe)
    return recipe ~= nil and patched[recipe:getName()] == recipe
end

function speed.getDryingRate(entity)
    local temperature = math.max(0, math.min(40, CraftUtil.getEntityTemperature(entity)))
    local rate = temperature / 20
    if rate < 1 then
        rate = rate * rate
    end
    return rate * multiplier
end

local function install()
    if isClient() or isServer() or getCore():getGameAndBuildVersion() ~= supportedVersion then
        return
    end

    local manager = getScriptManager()
    local count = 0
    for _, name in ipairs(recipes) do
        local recipe = manager:getCraftRecipe(name)
        if recipe and recipe:getTime() == originalDuration then
            if patched[name] ~= recipe then
                -- In-place callback registration leaves the saved recipe version and IO intact.
                recipe:Load(name, "craftRecipe " .. name .. " { "
                    .. "OnStart = SuQingLeatherRackSpeed.OnStart, "
                    .. "OnUpdate = SuQingLeatherRackSpeed.OnUpdate, }")
                patched[name] = recipe
            end
            count = count + 1
        else
            patched[name] = nil
        end
    end
    if not speed.reported or speed.reported ~= count then
        print("[SuQingLeatherRackSpeed] Enabled 2x for " .. count .. " of 3 vanilla leather drying recipes")
        speed.reported = count
    end
end

Events.OnInitGlobalModData.Add(install)
Events.OnGameStart.Add(install)
