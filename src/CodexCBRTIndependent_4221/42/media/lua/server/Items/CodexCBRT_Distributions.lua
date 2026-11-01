require "Items/ProceduralDistributions"

CodexCBRTCompat = CodexCBRTCompat or {}
CodexCBRTCompat.LootTargets = {
    "GunStoreShelf",
    "PlankStashGun",
    "FirearmWeapons",
    "ArmyStorageGuns",
    "GunStoreCounter",
    "PoliceStorageGuns",
    "PawnShopGunsSpecial",
    "GunStoreDisplayCase",
    "GarageFirearms",
    "DrugLabGuns",
    "GunStoreAmmunition",
    "ArmyStorageAmmunition",
    "ArmySurplusCases",
    "LockerArmyBedroom",
    "LockerArmyBedroomHome",
    "ArmySurplusAmmoBoxes",
    "PoliceStorageAmmunition",
    "PrisonArmoryShotguns",
}

function CodexCBRTCompat.InjectLoot()
    local lists = ProceduralDistributions and ProceduralDistributions.list
    if not lists then return end
    for _, name in ipairs(CodexCBRTCompat.LootTargets) do
        local distribution = lists[name]
        if distribution and distribution.items then
            local alreadyPresent = false
            for index = 1, #distribution.items, 2 do
                if distribution.items[index] == "CodexCBRT.Box_SST02_00" then
                    alreadyPresent = true
                    break
                end
            end
            if not alreadyPresent then
                table.insert(distribution.items, "CodexCBRT.Box_SST02_00")
                table.insert(distribution.items, 1)
            end
        end
    end
end

CodexCBRTCompat.InjectLoot()
