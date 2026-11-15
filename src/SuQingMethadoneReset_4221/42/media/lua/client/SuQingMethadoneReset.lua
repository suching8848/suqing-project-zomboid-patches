if isClient() or isServer() then return end

require "TimedActions/ISTakePillAction"

local overdoseCounters = {
    "NnCBenzoAmount", "NnCCokeAmount", "NnCMethAmount",
    "NnCOpioidAmount", "NnCMDMAAmount", "NnCSteroidAmount",
}
local addictionCounters = {
    "NnCTenMinutesBenzoAddict", "NnCTenMinutesCokeHead", "NnCTenMinutesMethHead",
    "NnCTenMinutesOpioidAddict", "NnCTenMinutesMDMAAddict", "NnCTenMinutesPotHead",
    "NnCTenMinutesSteroidAddict",
}
local warnedTracks = { "Benzo", "Coke", "Meth", "Opioid", "MDMA", "Steroid" }

local function clearBuildup(data)
    for _, key in ipairs(overdoseCounters) do
        if type(data[key]) == "number" then data[key] = 0 end
    end
    for _, key in ipairs(addictionCounters) do
        -- The same key stores positive withdrawal and recovery progress once dependent.
        if type(data[key]) == "number" and data[key] < 0 then data[key] = 0 end
    end
    for _, track in ipairs(warnedTracks) do
        local prefix = "NnCWarned" .. track
        if data[prefix .. "OD"] then data[prefix .. "OD"] = false end
        if data[prefix .. "Addict"] then data[prefix .. "Addict"] = false end
    end
end

local function install()
    if ISTakePillAction.suqingMethadoneResetInstalled then return end
    local complete = ISTakePillAction.complete
    if type(complete) ~= "function" or type(OnEat_Methadone) ~= "function" then
        print("[SuQingMethadoneReset] Compatible N&C pill action unavailable")
        return
    end

    -- Keep JustTookPill, including its cached OnEat lookup and dose consumption, intact.
    ISTakePillAction.complete = function(action)
        local item = action.item
        local uses = nil
        if item and item:getFullType() == "NnC.Methadone" and item:getOnEat() == "OnEat_Methadone" then
            uses = item:getCurrentUsesFloat()
        end
        local completed = complete(action)
        if completed and uses and uses > 0 and item:getCurrentUsesFloat() < uses then
            clearBuildup(action.character:getModData())
        end
        return completed
    end
    ISTakePillAction.suqingMethadoneResetInstalled = true
end

Events.OnGameStart.Add(install)
