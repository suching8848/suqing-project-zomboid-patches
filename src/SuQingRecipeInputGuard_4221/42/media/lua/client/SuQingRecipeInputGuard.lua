-- Read-only verification. The fix itself is the early registry declaration.
SuQingRecipeInputGuard = SuQingRecipeInputGuard or {}
local G = SuQingRecipeInputGuard
local TAG = "sapphcooking:strawberry"
local RECIPE = "Base.SapphCooking PrepareStrawberryCheesecake"
local LINE = "item5tags[sapphcooking:strawberry]"
local EXPECTED = { "Base.Strewberrie", "SapphCooking.Syrup_Strawberry" }
local REJECTED = { "Base.SST_JK_clothing", "Base.556Bullets", "Base.Plank", "Base.RippedSheets" }

local function fail(reason)
    G.validationStatus = "failed"
    G.validationError = reason
    print("[SuQingRecipeInputGuard] ERROR: " .. reason)
    return false, reason
end

local function normalLine(value)
    if type(value) ~= "string" then return "" end
    return (string.gsub(string.gsub(value, "%s+", ""), ",$", ""))
end

function G.Verify()
    G.validationStatus = "pending"
    G.validationError = nil
    if G.registration ~= "registered" and G.registration ~= "existing" then
        return fail("early registry phase did not succeed; fully restart after enabling this patch")
    end
    local tag = ItemTag.get(ResourceLocation.of(TAG))
    if not tag or tag ~= G.tag then
        return fail("registered strawberry tag identity changed; input data left untouched")
    end
    local sm = getScriptManager()
    local recipe = sm and sm:getCraftRecipe(RECIPE)
    if not recipe then return fail("expected Sapph strawberry-cheesecake recipe missing or changed") end
    local inputs = recipe:getInputs()
    if not inputs then return fail("recipe has no input list") end
    local found, matching = nil, 0
    for i = 0, inputs:size() - 1 do
        local input = inputs:get(i)
        if input and normalLine(input:getOriginalLine()) == LINE then
            found, matching = input, matching + 1
        end
    end
    if matching ~= 1 then return fail("expected five-unit strawberry input missing or ambiguous") end
    local tags = found:getItemTags()
    if not tags or not tags:contains(tag) or tags:contains(nil) then
        return fail("strawberry input still contains an unresolved/incorrect tag")
    end
    local candidates = found:getPossibleInputItems()
    if not candidates or candidates:size() == 0 then return fail("strawberry candidates are empty") end
    local ids = {}
    for i = 0, candidates:size() - 1 do
        local item = candidates:get(i)
        if not item or not item:getTags():contains(tag) then
            return fail("strawberry candidates contain an unrelated item; input data left untouched")
        end
        ids[item:getFullName()] = true
    end
    for _, id in ipairs(EXPECTED) do
        if not ids[id] or not found:canUseItem(id) then
            return fail("expected strawberry source absent from resolved input: " .. id)
        end
    end
    for _, id in ipairs(REJECTED) do
        if found:canUseItem(id) then
            return fail("unrelated item is accepted as a strawberry source: " .. id)
        end
    end
    G.validationStatus = "verified"
    G.candidateCount = candidates:size()
    print("[SuQingRecipeInputGuard] verified strawberry input: " .. tostring(G.candidateCount)
        .. " tagged candidates; unrelated items rejected; quantities and fluid inputs unchanged")
    return true
end

local function onStart()
    local ok, result = pcall(G.Verify)
    if not ok then fail("verification could not complete: " .. tostring(result)) end
end

Events.OnGameStart.Add(onStart)
return G
