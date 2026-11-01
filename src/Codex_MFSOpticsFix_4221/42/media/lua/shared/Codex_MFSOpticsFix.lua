-- Fix only audited MFS non-sight attachments with erroneous base:optics.
-- Script tags are shared by existing/new WeaponPart instances.
local candidates = {
    { "Base.AmmoStraps", "Sling" },
    { "Base.ChokeTubeFull", "Canon" },
    { "Base.ChokeTubeImproved", "Canon" },
    { "Base.GunLight", "Canon" },
    { "Base.Laser", "Canon" },
    { "Base.RecoilPad", "RecoilPad" },
    { "Gunpart.AFG_Blk", "Grip" },
    { "Gunpart.SE-5Grip", "Grip" },
    { "Gunpart.ASh-12_Grip", "Grip" },
    { "Gunpart.AK12Stock", "Stock" },
    { "Gunpart.AKSStock", "Stock" },
    { "Gunpart.AmmoPD", "L_Scope" },
    { "Gunpart.AmmoShellDish_cat", "Sling" },
    { "Gunpart.AmmoStraps_cat", "Sling" },
    { "Gunpart.ArmytekPredator_Bottom", "Light" },
    { "Gunpart.ArmytekPredator_Bottom1", "Light" },
    { "Gunpart.ArmytekPredator_Bottom2", "Light" },
    { "Gunpart.ArmytekPredator_Bottom3", "Light" },
    { "Gunpart.CobraGrip", "Grip" },
    { "Gunpart.CombatOps_Stock_blk", "Stock" },
    { "Gunpart.DBAL77Laser_cat", "Laser" },
    { "Gunpart.DBAL_9021_Bottom", "Laser" },
    { "Gunpart.Flamethrower", "Stool" },
    { "Gunpart.G33_cat", "R_Scope" },
    { "Gunpart.GP25_cat", "Stool" },
    { "Gunpart.Harris_Open", "Stool" },
    { "Gunpart.Harris_Open1", "Stool" },
    { "Gunpart.HeartbeatSensor", "L_Scope" },
    { "Gunpart.HeartbeatSensorPlus", "L_Scope" },
    { "Gunpart.HeraCQR_Grip", "Grip" },
    { "Gunpart.HeraCQR_Stock", "Stock" },
    { "Gunpart.M203_cat", "Stool" },
    { "Gunpart.M28_cat", "Stool" },
    { "Gunpart.MagpulStock", "Stock" },
    { "Gunpart.Misc_13", "Misc" },
    { "Gunpart.Misc_WTigerTw", "Misc" },
    { "Gunpart.Misc_baizhi", "Misc" },
    { "Gunpart.Misc_cat", "Misc" },
    { "Gunpart.Misc_es", "Misc" },
    { "Gunpart.Misc_maosha", "Misc" },
    { "Gunpart.Misc_nannan", "Misc" },
    { "Gunpart.Misc_subieli", "Misc" },
    { "Gunpart.Misc_zhizi", "Misc" },
    { "Gunpart.Mk18Stock", "Stock" },
    { "Gunpart.PEQ_cat", "Laser" },
    { "Gunpart.QT_F93", "Stock" },
    { "Gunpart.QT_Gen3", "Stock" },
    { "Gunpart.QT_LDT416", "Stock" },
    { "Gunpart.QT_lugerP80", "Stock" },
    { "Gunpart.QT_sr", "Stock" },
    { "Gunpart.Recoilpad_cat", "Recoilpad" },
    { "Gunpart.Sling_cat", "Sling" },
    { "Gunpart.ThermalImaging_cat", "L_Scope" },
    { "Gunpart.TroyM7_Blk", "Stock" },
    { "Gunpart.TshiftGrip", "Grip" },
    { "Gunpart.ViperStock", "Stock" },
    { "Gunpart.VltorEmod_Blk_Stock", "Stock" },
    { "Gunpart.WB_SST", "Grip" },
    { "Gunpart.WB_xie", "Grip" },
    { "Gunpart.ar15Stock", "Stock" },
    { "Gunpart.ar15_ddStock", "Stock" },
    { "Gunpart.leupold", "R_Scope" },
}
local done = {}
local reported = false
local function apply()
    local manager = getScriptManager()
    if not manager then return end
    local optics = ItemTag.get(ResourceLocation.of("base:optics"))
    if not optics then print("[MFSCorrectOptics] optics tag unavailable"); return end
    local fixed, skipped = 0, 0
    for _, entry in ipairs(candidates) do
        local id, expectedSlot = entry[1], entry[2]
        if not done[id] then
            local script = manager:getItem(id)
            if script then
                local tags = script:getTags()
                if not tags:contains(optics) then
                    done[id] = true
                else
                    local part = instanceItem(id)
                    if part and instanceof(part, "WeaponPart") and part:getPartType() == expectedSlot
                       and part:getMinSightRange() == 0 and part:getMaxSightRange() == 0 then
                        tags:remove(optics)
                        if tags:contains(optics) then
                            print("[MFSCorrectOptics] unable to remove tag: " .. id)
                        else
                            done[id] = true
                            fixed = fixed + 1
                        end
                    else
                        skipped = skipped + 1
                        print("[MFSCorrectOptics] skipped changed or invalid part: " .. id)
                    end
                end
            else
                skipped = skipped + 1
                print("[MFSCorrectOptics] missing definition: " .. id)
            end
        end
    end
    if fixed > 0 or skipped > 0 or not reported then
        print("[MFSCorrectOptics] fixed=" .. fixed .. " skipped=" .. skipped)
        reported = true
    end
end
apply()
Events.OnGameBoot.Add(apply)
Events.OnInitGlobalModData.Add(apply)

