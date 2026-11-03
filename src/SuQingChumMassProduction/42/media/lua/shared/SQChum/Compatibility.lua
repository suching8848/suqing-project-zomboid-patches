-- B42 merges same-ID recipe IO. Keep the MakeChum knowledge identity, remove
-- only the verified vanilla IO after parsing; native post-processing still runs.
SQChumCompatibility = SQChumCompatibility or {}
local M = SQChumCompatibility

local function line(value)
    return (value:getOriginalLine():gsub("%s+", ""))
end

local function near(a, b)
    return math.abs(a - b) < 0.00001
end

local function isSand(value, full)
    return line(value) == (full and "item4[Base.Sandbag]flags[IsFull]" or "item1[Base.Sandbag]")
        and near(value:getAmount(), full and 4 or 1)
        and value:isFull() == full
        and not value:isDestroy() and not value:isItemCount() and not value:isKeep()
end

local function isWater(value)
    if line(value) ~= "item1[*]" or not value:isAcceptsAnyItem()
        or not value:hasConsumeFromItem() then return false end
    local fluid = value:getConsumeFromItemScript()
    return line(fluid) == "fluid0.1[Water;TaintedWater]mode:mixture"
        and near(fluid:getAmount(), 0.1) and fluid:isFluidMixture()
end

local function isChum(value, count)
    return line(value) == "item" .. tostring(count) .. "Base.Chum"
        and near(value:getAmount(), count)
end

local function containsOnce(list, wanted)
    local found = 0
    for i = 0, list:size() - 1 do
        if list:get(i) == wanted then found = found + 1 end
    end
    return found == 1
end

local function removeIO(lines, first, second, third, fourth)
    for i = lines:size() - 1, 0, -1 do
        local value = lines:get(i)
        if value == first or value == second or (third and value == third)
            or (fourth and value == fourth) then
            -- Java ArrayList.remove(number) can bind remove(Object) in Kahlua.
            -- Pass the native IO object so the intended overload is unambiguous.
            lines:remove(value)
        end
    end
end

function M.apply(recipe)
    if not recipe then error("[SuQingChum] MakeChum is missing; patch not applied.") end
    local inputs, outputs, lines = recipe:getInputs(), recipe:getOutputs(), recipe:getIoLines()
    if inputs:size() == 2 and outputs:size() == 1 and isSand(inputs:get(0), true)
        and isWater(inputs:get(1)) and isChum(outputs:get(0), 5) then
        return true -- Idempotent for an extra OnGameBoot/OnGameStart callback.
    end
    local ni, no = inputs:size(), outputs:size()
    if ni >= 2 and no >= 1 then
        local bag, water, result = inputs:get(ni - 2), inputs:get(ni - 1), outputs:get(no - 1)
        if isSand(bag, true) and isWater(water) and isChum(result, 5)
            and containsOnce(lines, bag) and containsOnce(lines, water)
            and containsOnce(lines, water:getConsumeFromItemScript()) and containsOnce(lines, result) then
            if ni == 3 and no == 2 and isSand(inputs:get(0), false) and isChum(outputs:get(0), 1)
                and containsOnce(lines, inputs:get(0)) and containsOnce(lines, outputs:get(0)) then
                local oldInput, oldOutput = inputs:get(0), outputs:get(0)
                removeIO(lines, oldInput, oldOutput)
                inputs:remove(oldInput)
                outputs:remove(oldOutput)
                return true
            end
            -- An upstream recipe differs. Remove only our verified tail instead
            -- of guessing which upstream inputs/outputs should be overwritten.
            removeIO(lines, bag, water, result, water:getConsumeFromItemScript())
            inputs:remove(water)
            inputs:remove(bag)
            outputs:remove(result)
            recipe:overrideTranslationName(getText("UI_SQChum_UpstreamRecipe"))
            print("[SuQingChum] WARNING: upstream MakeChum IO changed; batch sand additions removed. Review compatibility before using the sand recipe.")
            return false
        end
    end
    recipe:overrideTranslationName(getText("UI_SQChum_UpstreamRecipe"))
    error("[SuQingChum] Unrecognized MakeChum IO; no entries removed. Disable this patch and review compatibility.")
end

local blockedRecipe
local function install()
    local recipe = getScriptManager():getCraftRecipe("Base.MakeChum")
    if recipe and recipe == blockedRecipe then return end
    if M.apply(recipe) then
        print("[SuQingChum] v1.0.0: full sand bag + 0.1 L water -> 5 vanilla chum bases.")
    else
        blockedRecipe = recipe
    end
end

Events.OnGameBoot.Add(install)
Events.OnGameStart.Add(install)
