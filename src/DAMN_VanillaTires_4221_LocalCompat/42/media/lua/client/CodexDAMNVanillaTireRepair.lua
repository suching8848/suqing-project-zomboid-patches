-- Optional integration through VRO's public recipe API. No menu overrides.
-- Crafting remains available when VRO is disabled or uses vanilla fixing recipes.
local recipeName = "Codex DAMN Vanilla Tire Repair"

local function registerVRORecipe()
    if not getActivatedMods():contains("VehicleRepairOverhaul") then return end

    local ok, module = pcall(require, "zzz_VRO_Fixing")
    local vro = VRO or (ok and type(module) == "table" and module)
    if not ok or type(vro) ~= "table" or type(vro.Recipes) ~= "table"
        or type(vro.API) ~= "table" or type(vro.API.addRecipe) ~= "function" then
        print("[Codex DAMN Vanilla Tires] VRO recipe API unavailable; crafting recipe remains available.")
        return
    end

    if type(vro.UseVanillaFixingRecipes) == "function" and vro.UseVanillaFixingRecipes() then
        print("[Codex DAMN Vanilla Tires] VRO uses vanilla fixing recipes; use the crafting recipe.")
        return
    end

    for _, recipe in ipairs(vro.Recipes) do
        if recipe.name == recipeName then return end
    end

    vro.API.addRecipe({
        name = recipeName,
        require = {
            "Base.OldTire1", "Base.NormalTire1", "Base.ModernTire1",
            "Base.OldTire2", "Base.NormalTire2", "Base.ModernTire2",
            "Base.OldTire3", "Base.NormalTire3", "Base.ModernTire3",
        },
        globalItems = {
            { item = "damnCraft.TireRepairTools", consume = false },
            { item = "damnCraft.TireRepairRubberSolution", uses = 1, consume = true },
        },
        conditionModifier = 0.3,
        anim = "VehicleWorkOnTire",
        time = 100,
        fixers = {
            { item = "damnCraft.TireRepairStrips", uses = 1, skills = { Mechanics = 1 } },
        },
    })
    print("[Codex DAMN Vanilla Tires] Registered VRO repair recipe for nine vanilla tire types.")
end

Events.OnGameStart.Add(registerVRORecipe)
