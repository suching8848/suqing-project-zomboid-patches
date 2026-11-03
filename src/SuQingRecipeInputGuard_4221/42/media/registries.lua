-- Registries load BEFORE item/recipe scripts. Do not move this into OnGameStart.
SuQingRecipeInputGuard = SuQingRecipeInputGuard or {}
local G = SuQingRecipeInputGuard
G.VERSION = "1.0.0"
G.tagId = "sapphcooking:strawberry"

local ok, result = pcall(function()
    if not ResourceLocation or not ResourceLocation.of or not ItemTag or not ItemTag.get
        or not ItemTag.register then error("required B42 registry API unavailable") end
    local tag = ItemTag.get(ResourceLocation.of(G.tagId))
    if tag then
        G.registration = "existing"
        return tag
    end
    -- Never try to register an existing tag: native duplicate registration can
    -- mutate registry mappings before reporting its error.
    tag = ItemTag.register(G.tagId)
    if not tag then error("strawberry tag registration returned nil") end
    G.registration = "registered"
    return tag
end)

if ok then
    G.tag = result
    G.error = nil
    print("[SuQingRecipeInputGuard] " .. G.registration .. " " .. G.tagId
        .. " before item and recipe parsing")
else
    G.tag = nil
    G.registration = "registration-failed"
    G.error = tostring(result)
    print("[SuQingRecipeInputGuard] ERROR: early registration failed: " .. G.error)
end

return G
