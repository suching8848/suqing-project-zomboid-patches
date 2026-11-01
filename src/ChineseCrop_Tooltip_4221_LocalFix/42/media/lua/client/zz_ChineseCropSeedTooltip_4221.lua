require "ItemInfo"

-- Some seed packets use names that More Item Information cannot map to seeds.
-- Map only known Chinesecuisine and N&C packet IDs; all others retain upstream behavior.
-- Resolve against live farming properties without changing learning or farming.
if not INFO or type(INFO.SetSeedInfo) ~= "function" then return end
if INFO._codexChineseSeedTooltip4221 then return end
INFO._codexChineseSeedTooltip4221 = true

local previousSetSeedInfo = INFO.SetSeedInfo
local packetSeeds = {
    ["Chinesecuisine.HamiMelon_BagSeed"] = "Chinesecuisine.HamiMelon_seeds",
    ["Chinesecuisine.Paddy_BagSeed"] = "Chinesecuisine.Paddy_seeds",
    ["Chinesecuisine.Grape_BagSeed"] = "Chinesecuisine.Grape_seeds",
    ["Chinesecuisine.kiwifruit_BagSeed"] = "Chinesecuisine.kiwifruit_seeds",
    ["Chinesecuisine.Sorghum_BagSeed"] = "Chinesecuisine.Sorghum_seeds",
    ["NnC.AKBagSeed"] = "NnC.SeedsAK",
    ["NnC.NorthernLightsBagSeed"] = "NnC.SeedsNorthernLights",
    ["NnC.SourDieselBagSeed"] = "NnC.SeedsSourDiesel",
    ["NnC.CocaBagSeed"] = "NnC.SeedsCoca",
    ["NnC.OpiumBagSeed"] = "NnC.SeedsOpium",
}

local function findPlant(seed)
    local props = farming_vegetableconf and farming_vegetableconf.props
    if not props then return nil end
    for _, plant in pairs(props) do
        if plant.seedName == seed then return plant end
        if type(plant.seedTypes) == "table" then
            for _, seedType in ipairs(plant.seedTypes) do
                if seedType == seed then return plant end
            end
        end
    end
end

function INFO:SetSeedInfo(item)
    local fullType = item and item:getFullType()
    local packetType = fullType and fullType:gsub("_[Ee][Mm][Pp][Tt][Yy]$", "")
    local seed = packetType and packetSeeds[packetType]
    if not fullType or (not seed and fullType:sub(1, 15) ~= "Chinesecuisine.") then
        return previousSetSeedInfo(self, item)
    end
    if not seed and item:hasTag(ItemTag.IS_SEED) then seed = fullType end
    local plant = seed and findPlant(seed)
    if not plant then return previousSetSeedInfo(self, item) end
    if not self.Options:getOption("SeedInfo"):getValue() then return end

    local player = getPlayer()
    local seasonKnown = player and plant.seasonRecipe
        and player:isRecipeActuallyKnown(plant.seasonRecipe)
    local seasons = getText("IGUI_ItemCat_Unknown")
    if seasonKnown then
        local labels = {}
        for _, month in ipairs(plant.sowMonth or {}) do
            -- Farming months are 1..12. Use the same keys as ISFarmingMenu.
            if type(month) == "number" and month >= 1 and month <= 12 then
                labels[#labels + 1] = getText("Farming_Month_" .. month)
            end
        end
        if #labels > 0 then seasons = table.concat(labels, ", ") end
    end
    self:InsertText(getText("Tooltip_MII_GrowingSeasons") .. ":", seasons)

    -- Preserve More Item Information's existing growth-time calculation.
    local speed = SandboxVars and SandboxVars.FarmingSpeedNew
    if seasonKnown and type(plant.timeToGrow) == "number"
        and type(speed) == "number" and speed > 0 then
        local days = math.floor(self:Round((plant.timeToGrow * 0.20833333) / speed, 4))
        self:InsertText(getText("Tooltip_MII_GrowthTime") .. ":",
            days .. " " .. getText("IGUI_Gametime_days"))
    end
end

print("[ChineseCropSeedTooltip4221] Seed packet display compatibility 1.1 loaded")
