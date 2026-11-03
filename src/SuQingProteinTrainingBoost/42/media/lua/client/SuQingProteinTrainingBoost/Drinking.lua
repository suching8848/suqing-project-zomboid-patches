local B = require "SuQingProteinTrainingBoost/Core"
require "TimedActions/ISDrinkFluidAction"

B.Drinking = B.Drinking or {}
local D = B.Drinking
-- Fluid volumes originate as Java floats. Ignore sub-microlitre rounding noise.
local EPSILON = 0.000001

local function pack(...)
    return { n = select("#", ...), ... }
end

local function isAmount(value)
    return type(value) == "number" and value == value
        and value >= 0 and value < math.huge
end

local function snapshot(container)
    local ok, result = pcall(function()
        if not container then error("missing fluid container") end
        if not Fluid or not Fluid.Get then error("fluid registry unavailable") end

        local total = container:getAmount()
        if not isAmount(total) then error("invalid total fluid amount") end

        local protein = 0
        for _, id in ipairs(B.FLUID_IDS) do
            local fluid = Fluid.Get(id)
            if not fluid then error("protein fluid not registered: " .. tostring(id)) end
            local amount = container:getSpecificFluidAmount(fluid)
            if not isAmount(amount) then
                error("invalid protein fluid amount: " .. tostring(id))
            end
            protein = protein + amount
        end
        if not isAmount(protein) or protein > total + EPSILON then
            error("protein fluid amount exceeds total volume")
        end
        return { total = total, protein = protein }
    end)
    if not ok then
        B.Log("Drink dose skipped: " .. tostring(result))
        return nil
    end
    return result
end

local function recordDose(player, before, after)
    local removed = before.total - after.total
    local protein = before.protein - after.protein
    if removed < -EPSILON or protein < -EPSILON then
        B.Log("Drink dose skipped: fluid amount increased during drinking")
        return
    end
    if protein > removed + EPSILON then
        B.Log("Drink dose skipped: protein consumption exceeds total consumption")
        return
    end
    if removed <= EPSILON or protein <= EPSILON then return end
    B.AddDose(player, protein)
end

function D.Install()
    if D.installed then return true end
    if not ISDrinkFluidAction or type(ISDrinkFluidAction.updateEat) ~= "function" then
        B.Log("Drinking hook unavailable: ISDrinkFluidAction.updateEat is missing")
        return false
    end
    local registryOK, registryError = pcall(function()
        if not Fluid or not Fluid.Get then error("fluid registry unavailable") end
        for _, id in ipairs(B.FLUID_IDS) do
            if not Fluid.Get(id) then error("protein fluid not registered: " .. tostring(id)) end
        end
    end)
    if not registryOK then
        B.Log("Drinking hook not installed: " .. tostring(registryError))
        return false
    end

    local original = ISDrinkFluidAction.updateEat
    local inFlight = {}
    local function wrapped(action, ...)
        if not B.IsSinglePlayer() or inFlight[action] then
            return original(action, ...)
        end

        local container = action.fluidContainer
        local before = snapshot(container)
        inFlight[action] = true
        -- Clear the guard even when the original action fails, then rethrow its
        -- original error. The buff must not turn a failed drink into a success.
        local result = pack(pcall(original, action, ...))
        inFlight[action] = nil
        if not result[1] then error(result[2], 0) end

        if before then
            if action.fluidContainer ~= container then
                B.Log("Drink dose skipped: fluid container changed during drinking")
            else
                local after = snapshot(container)
                if after then recordDose(action.character, before, after) end
            end
        end
        return unpack(result, 2, result.n)
    end

    D.original = original
    D.wrapper = wrapped
    ISDrinkFluidAction.updateEat = wrapped
    D.installed = true
    return true
end

return D
