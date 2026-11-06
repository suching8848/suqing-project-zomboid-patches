-- Only the native no-pretransfer flag changes; inputs, outputs and weight stay upstream.
SuQingBoatCraftFromFloor = SuQingBoatCraftFromFloor or {}
local G = SuQingBoatCraftFromFloor
local FLAG = "CanBeDoneFromFloor"
local IDS = {"Base.BoteBR_ConstruirBote", "Base.BoteBR_ConstruirTrawler", "Base.BoteBR_ConstruirMetal"}
local EXPECTED_HASH = 607375425
local EXPECTED_COUNT = 2224

local function sourceMatches()
    local reader = getModFileReader("BoteBR", "media/scripts/botebr_recipes.txt", false)
    if not reader then return false end
    local h, count = 0, 0
    local ok, err = pcall(function()
        while true do
            local line = reader:readLine()
            if line == nil then break end
            for i = 1, #line do h = (h * 131 + string.byte(line, i)) % 1000000007; count = count + 1 end
            h = (h * 131 + 10) % 1000000007; count = count + 1
        end
    end)
    reader:close()
    if not ok then error(err) end
    return h == EXPECTED_HASH and count == EXPECTED_COUNT
end

function G.apply()
    G.status = "checking"
    if (isClient and isClient()) or (isServer and isServer()) or (isMultiplayer and isMultiplayer()) then
        G.status, G.error = "blocked", "single_player_only"
        return false
    end
    local added = {}
    local ok, reason = pcall(function()
        assert(sourceMatches(), "upstream_recipe_source_changed_or_unreadable")
        local sm = getScriptManager()
        local recipes = {}
        -- Validate all targets before changing any of them.
        for _, id in ipairs(IDS) do
            local recipe = sm:getCraftRecipe(id)
            assert(recipe and recipe.getModID and recipe:getModID() == "BoteBR"
                and recipe.getModTags and recipe.isCanBeDoneFromFloor
                and recipe.isAnySurfaceCraft and recipe:isAnySurfaceCraft(), "recipe_contract_changed: " .. id)
            local tags = recipe:getModTags()
            assert(tags and tags.contains and tags.add and tags.remove, "tag_list_unavailable: " .. id)
            recipes[#recipes + 1] = recipe
        end
        for _, recipe in ipairs(recipes) do
            local tags = recipe:getModTags()
            if not tags:contains(FLAG) then
                added[#added + 1] = tags
                tags:add(FLAG)
            end
            assert(recipe:isCanBeDoneFromFloor() and recipe:isAnySurfaceCraft(), "flag_readback_failed")
        end
    end)
    if not ok then
        for _, tags in ipairs(added) do
            local restored, err = pcall(function() tags:remove(FLAG) end)
            if not restored then print("[SuQingBoatCraftFromFloor] rollback warning: " .. tostring(err)) end
        end
        G.status, G.error = "blocked", tostring(reason)
        print("[SuQingBoatCraftFromFloor] not applied: " .. tostring(reason))
        return false
    end
    G.status, G.error, G.recipeCount = "applied", nil, #IDS
    print("[SuQingBoatCraftFromFloor] three boat recipes use native nearby inputs; quantities/surface/weight retained")
    return true
end

Events.OnGameBoot.Add(G.apply)
Events.OnGameStart.Add(function()
    if G.apply() then return end
    local ok, err = pcall(function()
        local player = getSpecificPlayer(0)
        if player and HaloTextHelper then HaloTextHelper.addBadText(player, getText("IGUI_SQBoatCraftFromFloor_Blocked")) end
    end)
    if not ok then print("[SuQingBoatCraftFromFloor] notification failed: " .. tostring(err)) end
end)
