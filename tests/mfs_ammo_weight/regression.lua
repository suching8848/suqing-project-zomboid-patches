-- These fixtures retain the proposed weights before the requested 50% reduction.
local ammo = {
    ["Base.Bullets9mm"] = 0.012,
    ["Base.Bullets44"] = 0.025,
    ["Base.Bullets45"] = 0.021,
    ["Base.545Bullets"] = 0.011,
    ["Base.556Bullets"] = 0.012,
    ["Base.A_58bullets"] = 0.013,
    ["Base.Bullets38"] = 0.022,
    ["Base.308Bullets"] = 0.025,
    ["Base.Bullets86"] = 0.045,
    ["Base.Bullets50"] = 0.115,
    ["Base.Bullets145"] = 0.190,
    ["Base.ShotgunShells"] = 0.040,
    ["Base.GrenadeAmmo"] = 0.230,
    ["Base.CrossbowBolt"] = 0.010,
    ["Base.BW_Arrow"] = 0.010,
    ["Base.MaoMaoEnergyBullet"] = 0.010,
}

local magazines = {
    ["Base.9mmClip"] = 0.09,
    ["Base.9mmSHGClip"] = 0.12,
    ["Base.9mmClip25"] = 0.16,
    ["Base.SamuraiEdgeClip"] = 0.18,
    ["Base.AdapterClip"] = 0.18,
    ["Base.9mmDrum_cat"] = 0.49,
    ["Base.9mmDrum_p_cat"] = 0.49,
    ["Base.AWMClip"] = 0.12,
    ["Base.44Clip"] = 0.15,
    ["Base.45Clip"] = 0.08,
    ["Base.45Clip20"] = 0.15,
    ["Base.45Clip30"] = 0.20,
    ["Base.45Drum_cat"] = 0.52,
    ["Base.545Clip"] = 0.20,
    ["Base.545Drum_cat"] = 0.85,
    ["Base.JS14_Clip"] = 0.11,
    ["Base.556Clip"] = 0.14,
    ["Base.AR57Drum_cat"] = 0.22,
    ["Base.556Drum_cat"] = 0.58,
    ["Base.M91Drum_cat"] = 0.85,
    ["Base.58Clip20"] = 0.13,
    ["Base.58Clip"] = 0.17,
    ["Base.95Drum_cat"] = 0.60,
    ["Base.68Clip"] = 0.24,
    ["Base.68Drum_cat"] = 0.78,
    ["Base.308Clip"] = 0.12,
    ["Base.M14Clip"] = 0.23,
    ["Base.308ClipU"] = 0.25,
    ["Base.M14Drum_cat"] = 0.78,
    ["Base.MK47Clip"] = 0.50,
    ["Base.MG42Drum_cat"] = 0.95,
    ["Base.762Drum_cat"] = 1.10,
    ["Base.M240BeltBox"] = 0.65,
    ["Base.338Clip_cat"] = 0.25,
    ["Base.338Drum_cat"] = 0.80,
    ["Base.Bullets50Clip"] = 0.50,
    ["Base.50Drum_cat"] = 0.85,
    ["Base.Bullets145Clip"] = 0.50,
    ["Base.TyphoonF12Mag"] = 0.25,
    ["Base.AA12Clip"] = 0.65,
    ["Base.GrenadeAmmoClip"] = 0.50,
    ["Base.RPGClip"] = 0.80,
    ["Base.CrossbowClip"] = 0.10,
    ["Base.IR_Repeating_Crossbow_Clip"] = 0.50,
    ["Base.MaoMaoDianLanZhuZuiMag"] = 0.50,
}

local assertions = 0
local function check(condition, message)
    assertions = assertions + 1
    assert(condition, message)
end

local function near(actual, expected, label)
    check(type(actual) == "number" and math.abs(actual - expected) < 1e-8,
        label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function makeEvent()
    local callbacks = {}
    return {
        Add = function(callback)
            callbacks[#callbacks + 1] = callback
        end,
        Remove = function(callback)
            for index, registered in ipairs(callbacks) do
                if registered == callback then
                    table.remove(callbacks, index)
                    return
                end
            end
        end,
        fire = function()
            for _, callback in ipairs(callbacks) do
                callback()
            end
        end,
        count = function()
            return #callbacks
        end,
    }
end

Events = {
    OnLoadedTileDefinitions = makeEvent(),
    OnLoadMapZones = makeEvent(),
}
SandboxVars = {
    TrueWeight = {
        UseModPreset = true,
        GeneralMultiplier = 1,
        Ammo = 1,
        CustomWeights = "",
    },
}

local items = {}
local all = {}
local function addItem(fullType, category, weight)
    local item = {
        getFullName = function()
            return fullType
        end,
        getName = function()
            return string.match(fullType, "%.(.+)$")
        end,
        getDisplayCategory = function()
            return category
        end,
        getActualWeight = function()
            return weight
        end,
        setActualWeight = function(_, value)
            weight = value
        end,
    }
    items[fullType] = item
    all[#all + 1] = item
    return item
end

-- Both modules use Java-facing methods of the ScriptManager and its script items.
local lookups = {}
local manager = {
    FindItem = function(_, fullType, allowFallback)
        check(allowFallback == false, "Loose ScriptManager lookup for " .. fullType)
        lookups[fullType] = true
        return items[fullType]
    end,
    getAllItems = function()
        return {
            size = function()
                return #all
            end,
            get = function(_, index)
                return all[index + 1]
            end,
        }
    end,
}
ScriptManager = { instance = manager }
getScriptManager = function()
    return manager
end
getFileWriter = function()
    return nil
end

local weights = require("SuQingMFSAmmoWeight/Weights")
local function checkBalance(expected, count)
    local seen = 0
    for fullType, proposed in pairs(expected) do
        near(weights[fullType], proposed / 2, fullType .. " configured weight")
        seen = seen + 1
    end
    check(seen == count, "Expected " .. count .. " balance entries")
end

checkBalance(ammo, 16)
checkBalance(magazines, 45)

-- Counts come from the current unpacking recipes. The carton includes its
-- packed boxes, each of which has its own packaging allowance.
local packageCount = 0
local function checkPackage(packageType, containedType, units, allowance)
    near(weights[packageType], weights[containedType] * units + allowance, packageType .. " packed weight")
    packageCount = packageCount + 1
end

local function checkBoxes(ammoType, boxType, cartonType, perBox, perCarton, heavy)
    checkPackage("Base." .. boxType, "Base." .. ammoType, perBox, heavy and 0.04 or 0.025)
    checkPackage("Base." .. cartonType, "Base." .. boxType, perCarton, heavy and 0.40 or 0.25)
end

checkBoxes("Bullets9mm", "Bullets9mmBox", "Bullets9mmCarton", 50, 12)
checkBoxes("Bullets44", "Bullets44Box", "Bullets44Carton", 50, 12)
checkBoxes("Bullets45", "Bullets45Box", "Bullets45Carton", 50, 12)
checkBoxes("545Bullets", "545Box", "545Carton", 50, 12)
checkBoxes("556Bullets", "556Box", "556Carton", 50, 12)
checkBoxes("A_58bullets", "58Box", "58Carton", 50, 12)
checkBoxes("Bullets38", "Bullets38Box", "Bullets38Carton", 50, 12)
checkBoxes("308Bullets", "308Box", "308Carton", 50, 12)
checkBoxes("Bullets86", "Bullets86Box", "86Carton", 50, 12, true)
checkBoxes("Bullets50", "Bullets50Box", "50Carton", 20, 12, true)
checkBoxes("Bullets145", "Bullets145Box", "145Carton", 20, 10, true)
checkBoxes("ShotgunShells", "ShotgunShellsBox", "ShotgunShellsCarton", 25, 12)
checkBoxes("MaoMaoEnergyBullet", "MaoMaoEnergyBulletBox", "MaoMaoEnergyBulletCarton", 100, 6)
checkPackage("Base.CrossbowBoltBox", "Base.CrossbowBolt", 50, 0.025)
checkPackage("Base.BW_ArrowBolts", "Base.BW_Arrow", 15, 0.005)
check(packageCount == 28, "Expected 28 packaged items")
near(weights["Base.50Carton"], 14.68, ".50 BMG carton")
near(weights["Base.145Carton"], 19.80, "14.5 mm carton")

local totalTargets = 0
for _ in pairs(weights) do
    totalTargets = totalTargets + 1
end
check(totalTargets == 89, "Unexpected total number of weighted items")

local missing = "Base.MaoMaoDianLanZhuZuiMag"
local falseMatch = "Base.SamuraiEdgeClip"
for fullType, _ in pairs(weights) do
    if fullType ~= missing and fullType ~= falseMatch then
        addItem(fullType, "Ammo", 2)
    end
end

local unrelated = addItem("Base.ToiletPaper", "Junk", 0.5)
local appearance = addItem("Gunpart.Clip_9mmDrum_cat", "WeaponPart", 0.4)
local afterFallback = addItem("Other.SamuraiEdgeClip", "Ammo", 1.1)
items[falseMatch] = afterFallback
local sharedName = addItem("Other.9mmClip", "Ammo", 0.4)

-- Register the candidate before TrueWeight. Their separate engine events still
-- apply TrueWeight first, even with this reversed registration order.
require("SuQingMFSAmmoWeight/Apply")
require("true-weight-source")
check(Events.OnLoadedTileDefinitions.count() == 1, "Unexpected tile-definition callbacks")
check(Events.OnLoadMapZones.count() == 1, "Expected one weight callback")

local function verifyTargetWeights()
    for fullType, weight in pairs(weights) do
        check(lookups[fullType] == true, "No script lookup for " .. fullType)
        if fullType ~= missing and fullType ~= falseMatch then
            near(items[fullType]:getActualWeight(), weight, fullType .. " applied weight")
        end
    end
    near(afterFallback:getActualWeight(), 1.1, "Rejected fallback item")
    near(sharedName:getActualWeight(), 0.09, "Other namespace keeps TrueWeight result")
    near(unrelated:getActualWeight(), 0.1, "Unrelated TrueWeight result")
    near(appearance:getActualWeight(), 0.4, "Visual weapon part excluded")
end

Events.OnLoadedTileDefinitions.fire()
near(items["Base.9mmClip"]:getActualWeight(), 0.09, "TrueWeight 9mm preset")
near(items["Base.556Bullets"]:getActualWeight(), 0.012, "TrueWeight 5.56 preset")
near(items["Base.Bullets38"]:getActualWeight(), 0.0158, "TrueWeight repurposed .38 preset")
Events.OnLoadMapZones.fire()
verifyTargetWeights()

Events.OnLoadMapZones.fire()
verifyTargetWeights()

local function checkLoaded(magazineType, ammoType, rounds, expected)
    local emptyWeight = items[magazineType]:getActualWeight()
    local roundWeight = items[ammoType]:getActualWeight()
    near(emptyWeight + rounds * roundWeight, expected, magazineType .. " loaded weight")
end

checkLoaded("Base.Bullets50Clip", "Base.Bullets50", 10, 0.825)
checkLoaded("Base.50Drum_cat", "Base.Bullets50", 20, 1.575)
checkLoaded("Base.338Drum_cat", "Base.Bullets86", 100, 2.65)
checkLoaded("Base.762Drum_cat", "Base.308Bullets", 100, 1.80)
checkLoaded("Base.M240BeltBox", "Base.308Bullets", 100, 1.575)
checkLoaded("Base.556Drum_cat", "Base.556Bullets", 60, 0.65)
checkLoaded("Base.9mmDrum_cat", "Base.Bullets9mm", 50, 0.545)
checkLoaded("Base.RPGClip", "Base.GrenadeAmmo", 15, 2.125)
checkLoaded("Base.IR_Repeating_Crossbow_Clip", "Base.BW_Arrow", 40, 0.45)

return "PASS: " .. tostring(assertions) .. " assertions"
