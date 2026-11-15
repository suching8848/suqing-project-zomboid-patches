require "ISUI/ISCollapsableWindow"

local drugItems = {
    ["NnC.BluntAK"] = true,
    ["NnC.BluntKief"] = true,
    ["NnC.BluntNorthernLights"] = true,
    ["NnC.BluntSourDiesel"] = true,
    ["NnC.Bong1GreenAK"] = true,
    ["NnC.Bong1GreenKief"] = true,
    ["NnC.Bong1GreenNL"] = true,
    ["NnC.Bong1GreenSD"] = true,
    ["NnC.Bong1PurpleAK"] = true,
    ["NnC.Bong1PurpleKief"] = true,
    ["NnC.Bong1PurpleNL"] = true,
    ["NnC.Bong1PurpleSD"] = true,
    ["NnC.Bong1RedAK"] = true,
    ["NnC.Bong1RedKief"] = true,
    ["NnC.Bong1RedNL"] = true,
    ["NnC.Bong1RedSD"] = true,
    ["NnC.Bong2PinkAK"] = true,
    ["NnC.Bong2PinkKief"] = true,
    ["NnC.Bong2PinkNL"] = true,
    ["NnC.Bong2PinkSD"] = true,
    ["NnC.Bong2RainbowAK"] = true,
    ["NnC.Bong2RainbowKief"] = true,
    ["NnC.Bong2RainbowNL"] = true,
    ["NnC.Bong2RainbowSD"] = true,
    ["NnC.Bong2RedAK"] = true,
    ["NnC.Bong2RedKief"] = true,
    ["NnC.Bong2RedNL"] = true,
    ["NnC.Bong2RedSD"] = true,
    ["NnC.BongPokeAK"] = true,
    ["NnC.BongPokeKief"] = true,
    ["NnC.BongPokeNL"] = true,
    ["NnC.BongPokeSD"] = true,
    ["NnC.CanPipeAK"] = true,
    ["NnC.CanPipeKief"] = true,
    ["NnC.CanPipeNorthernLights"] = true,
    ["NnC.CanPipeSourDiesel"] = true,
    ["NnC.CannaButter"] = true,
    ["NnC.CannagarAK"] = true,
    ["NnC.CannagarKief"] = true,
    ["NnC.CannagarNL"] = true,
    ["NnC.CannagarSD"] = true,
    ["NnC.CocaineMirrorWith1Line"] = true,
    ["NnC.CocaineMirrorWith2Lines"] = true,
    ["NnC.CokeBaggie"] = true,
    ["NnC.CrackPipeCrack"] = true,
    ["NnC.CrackPipeMeth"] = true,
    ["NnC.CrackSpoon"] = true,
    ["NnC.CrackSpoonF"] = true,
    ["NnC.CrackSpoonG"] = true,
    ["NnC.CrackSpoonS"] = true,
    ["NnC.CrystalMeth"] = true,
    ["NnC.Fentanyl"] = true,
    ["NnC.Heroin3"] = true,
    ["NnC.Heroin4"] = true,
    ["NnC.JointAK"] = true,
    ["NnC.JointKief"] = true,
    ["NnC.JointNorthernLights"] = true,
    ["NnC.JointSourDiesel"] = true,
    ["NnC.LSD"] = true,
    ["NnC.MDMA"] = true,
    ["NnC.MShroom"] = true,
    ["NnC.MShroomBaggie"] = true,
    ["NnC.MethMirrorWith1Line"] = true,
    ["NnC.MethMirrorWith2Lines"] = true,
    ["NnC.MethSudoPackette"] = true,
    ["NnC.Methadone"] = true,
    ["NnC.Narcan"] = true,
    ["NnC.Oxycodone"] = true,
    ["NnC.Pipe1GreenAK"] = true,
    ["NnC.Pipe1GreenKief"] = true,
    ["NnC.Pipe1GreenNL"] = true,
    ["NnC.Pipe1GreenSD"] = true,
    ["NnC.Pipe1OrangeAK"] = true,
    ["NnC.Pipe1OrangeKief"] = true,
    ["NnC.Pipe1OrangeNL"] = true,
    ["NnC.Pipe1OrangeSD"] = true,
    ["NnC.Pipe1YellowAK"] = true,
    ["NnC.Pipe1YellowKief"] = true,
    ["NnC.Pipe1YellowNL"] = true,
    ["NnC.Pipe1YellowSD"] = true,
    ["NnC.Ritalin"] = true,
    ["NnC.SmokingPipeAK"] = true,
    ["NnC.SmokingPipeKief"] = true,
    ["NnC.SmokingPipeNorthernLights"] = true,
    ["NnC.SmokingPipeSourDiesel"] = true,
    ["NnC.Speed"] = true,
    ["NnC.SpliffAK"] = true,
    ["NnC.SpliffKief"] = true,
    ["NnC.SpliffNL"] = true,
    ["NnC.SpliffSD"] = true,
    ["NnC.Steroid"] = true,
    ["NnC.Valium"] = true,
    ["NnC.WeedBrownie"] = true,
    ["NnC.WeedBrowniePan"] = true,
    ["NnC.WeedChocolateBar"] = true,
    ["NnC.WeedChocolateChipCookie"] = true,
    ["NnC.WeedChocolateChipCookieDough"] = true,
    ["NnC.WeedGummies"] = true,
    ["NnC.WeedSugarCookie"] = true,
    ["NnC.WeedSugarCookieDough"] = true,
    ["NnC.Xanax"] = true,
}
local tracks = {
    { label="Benzo", amount="NnCBenzoAmount", limit=1420, decay=12,
      addiction="NnCTenMinutesBenzoAddict", trait="BenzoAddict", warning=1792, withdrawal=432, peak=864,
      effect="NnCBenzoEffect", activeMin=2, activeMax=49, effectCap=52 },
    { label="Coke", amount="NnCCokeAmount", limit=1410, decay=24,
      addiction="NnCTenMinutesCokeHead", trait="CokeHead", warning=1792, withdrawal=144, peak=720,
      effect="NnCCokeEffect", activeMin=3, activeMax=18, effectCap=18, comedown=true },
    { label="Meth", amount="NnCMethAmount", limit=1420, decay=12,
      addiction="NnCTenMinutesMethHead", trait="MethHead", warning=1792, withdrawal=144, peak=720,
      effect="NnCMethEffect", activeMin=3, activeMax=62, effectCap=65, comedown=true },
    { label="Opioid", amount="NnCOpioidAmount", limit=1410, decay=12,
      addiction="NnCTenMinutesOpioidAddict", trait="OpioidAddict", warning=1792, early=992, withdrawal=144, peak=720,
      effect="NnCOpioidEffect", activeMin=3, activeMax=62, effectCap=65, comedown=true },
    { label="MDMA", amount="NnCMDMAAmount", limit=1420, decay=12,
      addiction="NnCTenMinutesMDMAAddict", trait="MDMAAddict", warning=1792, withdrawal=432, peak=864,
      effect="NnCMDMAEffect", activeMin=3, activeMax=62, effectCap=65, comedown=true },
    { label="Steroid", amount="NnCSteroidAmount", limit=1410, decay=12,
      addiction="NnCTenMinutesSteroidAddict", trait="SteroidAddict", warning=1792, withdrawal=144, peak=720,
      effect="NnCSteroidEffect", activeMin=3, activeMax=144, effectCap=145 },
    { label="Weed", addiction="NnCTenMinutesPotHead", trait="PotHead",
      effect="NnCWeeeeedEffect", activeMin=1, activeMax=19, effectCap=21 },
    { label="Methadone", effect="NnCMethadoneEffect", activeMin=1, activeMax=145, effectCap=145 },
}

local shortDays = {0.25, 0.5, 1, 1.5, 2}
local normalColor = {0.75, 0.9, 0.75}
local warningColor = {1, 0.72, 0.25}
local dangerColor = {1, 0.3, 0.3}
local neutralColor = {0.7, 0.7, 0.7}
local infoColor = {0.85, 0.9, 1}
local unknown = "--"
local notApplicable = "—"
local padding = 16
local gap = 20

local function label(key)
    return getText("IGUI_CodexNnC_" .. key)
end

local function formatLabel(key, ...)
    return string.format(label(key), ...)
end

local function number(md, key)
    local value = md and md[key]
    if type(value) == "number" and value - value == 0 then
        return value
    end
    return nil
end

-- N&C advances counters in batches of one or more passes per ten game minutes.
local function timing()
    local index = SandboxVars and SandboxVars.DayLength
    if type(index) ~= "number" then return nil, nil end
    local hours
    if index <= 5 then hours = shortDays[index] else hours = index - 3 end
    if not hours or hours <= 0 then return nil, nil end
    return math.max(1, math.floor(hours / 3 + 0.5)), 10 * hours / 24
end

local function minutes(steps, passesPerTick, minutesPerTick)
    if not passesPerTick then return unknown end
    return formatLabel("Minutes", math.ceil(steps / passesPerTick) * minutesPerTick)
end

local function overdoseCell(track, md, passesPerTick, minutesPerTick)
    if not track.amount then return notApplicable, nil, neutralColor end
    local value = number(md, track.amount)
    if not value then return label("NoData"), unknown, neutralColor end
    local status, color = "Normal", normalColor
    if value > track.limit then
        status, color = "Overdose", dangerColor
    elseif value >= 864 then
        status, color = "Warning", warningColor
    end
    -- N&C decays first, then caps the value. This also handles a dose above 1440 between passes.
    local steps = 0
    if value > 0 then
        steps = 1 + math.ceil(math.max(0, math.min(1440, value - track.decay)) / track.decay)
    end
    local amount = string.format("%d / >%d", math.floor(value), track.limit)
    return label(status), amount .. "  ·  " .. minutes(steps, passesPerTick, minutesPerTick), color
end

local function addictionCell(track, raw, dependent)
    if not track.addiction then return notApplicable, nil, neutralColor end
    if dependent then return label("Addicted"), nil, dangerColor end
    if dependent == nil or raw == nil then return label("NoData"), unknown, neutralColor end
    local points = math.floor(math.max(0, -raw))
    local status, color = "NoWarning", normalColor
    if track.warning and points >= track.warning then
        status, color = "AddictionWarning", warningColor
    elseif track.early and points >= track.early then
        status, color = "AddictionEarly", warningColor
    elseif not track.warning then
        status, color = points > 0 and "Accumulating" or "NoAccumulation", neutralColor
    end
    local threshold = "2592–2879"
    if track.early then
        threshold = track.early .. " / " .. track.warning
    elseif track.warning then
        threshold = tostring(track.warning)
    end
    return label(status), points .. " / " .. threshold, color
end

local function effectCell(track, md, passesPerTick, minutesPerTick)
    local value = number(md, track.effect)
    if not value then return label("NoData"), unknown, neutralColor end
    local status, steps, color
    if value > track.activeMax then
        status, steps, color = "Onset", math.max(1, math.min(value - 1, track.effectCap) - track.activeMax + 1), warningColor
    elseif value >= track.activeMin then
        status, steps, color = "Active", value - track.activeMin + 1, normalColor
        if track.label == "Methadone" then status = "Suppressed" end
    elseif track.comedown and value > 0 then
        status, steps, color = "Comedown", value, warningColor
    else
        return label("Off"), nil, neutralColor
    end
    return label(status), minutes(steps, passesPerTick, minutesPerTick), color
end

local function withdrawalDetails(details, track, raw, paused, passesPerTick, minutesPerTick)
    local category = label(track.label)
    local stage, nextStage, target
    local progress = unknown
    if raw ~= nil then
        raw = math.max(0, raw)
        progress = formatLabel("RecoveryValue", math.floor(raw))
    end

    if not track.withdrawal then
        stage = "WithdrawalNone"
    elseif paused then
        stage = "WithdrawalPaused"
    elseif raw == nil then
        stage = "NoData"
    elseif raw < track.withdrawal then
        stage, nextStage, target = "WithdrawalPending", "WithdrawalModerate", track.withdrawal
    elseif raw < track.peak then
        stage, nextStage, target = "WithdrawalModerate", "WithdrawalSevere", track.peak
    elseif raw <= 1440 then
        stage, nextStage, target = "WithdrawalSevere", "WithdrawalMild", 1441
    else
        stage, nextStage = "WithdrawalMild", "RecoveryWindow"
    end
    details[#details + 1] = formatLabel("WithdrawalProgress", category, label(stage), progress)
    if target then
        details[#details + 1] = formatLabel("WithdrawalNext", label(nextStage), minutes(target - raw, passesPerTick, minutesPerTick))
    elseif nextStage then
        details[#details + 1] = label(nextStage)
    end
end

local function interactionDetails(details, player, md, opioidDependent)
    if not player or not md then return end
    local benzo = number(md, "NnCBenzoEffect")
    local opioid = number(md, "NnCOpioidEffect")
    local benzoAmount = number(md, "NnCBenzoAmount")
    local opioidAmount = number(md, "NnCOpioidAmount")
    local opioidOverdose = opioidAmount and opioidAmount > 1410
    local methadone = number(md, "NnCMethadoneEffect")

    if not player:isAsleep() then
        local stats = player:getStats()
        local intoxication = stats and stats:get(CharacterStat.INTOXICATION)
        local drinking = type(intoxication) == "number" and intoxication > 0
        -- Match the order of the individual N&C effect branches, including the narrower opioid
        -- window in the benzo interaction and separate overdose overrides.
        if benzo and benzo >= 2 and benzo <= 49 and not (benzoAmount and benzoAmount > 1420) then
            if opioid and opioid >= 2 and opioid <= 37 then
                details[#details + 1] = label("MixedBenzoOpioid")
            elseif drinking then
                details[#details + 1] = label("MixedBenzoAlcohol")
            end
        end
        if drinking and opioid and opioid >= 3 and opioid <= 62 and not opioidOverdose then
            details[#details + 1] = label("MixedOpioidAlcohol")
        end
    end

    if methadone and methadone > 0 then
        details[#details + 1] = label("MethadonePause")
    end
    if opioidOverdose then
        details[#details + 1] = label("Narcan")
        if opioidDependent then details[#details + 1] = label("NarcanDependent") end
    end
end

CodexNarcoticsStatus = ISCollapsableWindow:derive("CodexNarcoticsStatus")
local instances = {}

function CodexNarcoticsStatus:new(x, y, width, height, playerNum)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.playerNum = playerNum
    o.resizable = false
    o.title = label("Title")
    return o
end

function CodexNarcoticsStatus:close()
    self:setVisible(false)
    self:removeFromUIManager()
    instances[self.playerNum] = nil
end

local function drawCell(panel, x, y, line, font, status, value, color)
    panel:drawText(status, x, y, color[1], color[2], color[3], 1, font)
    if value then
        panel:drawText(value, x, y + line, infoColor[1], infoColor[2], infoColor[3], 1, font)
    end
end

function CodexNarcoticsStatus:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local player = getSpecificPlayer(self.playerNum)
    local md = player and player:getModData() or nil
    local font = UIFont.Small
    local tm = getTextManager()
    local line = tm:getFontHeight(font) + 2
    local passesPerTick, minutesPerTick = timing()
    local methadone = number(md, "NnCMethadoneEffect")
    local opioidDependent
    local details = {}
    local y = self:titleBarHeight() + 10

    self:drawText(label("ColumnCategory"), padding, y, 0.82, 0.84, 0.88, 1, font)
    self:drawText(label("ColumnOverdose"), self.colOverdose, y, 0.82, 0.84, 0.88, 1, font)
    self:drawText(label("ColumnAddiction"), self.colAddiction, y, 0.82, 0.84, 0.88, 1, font)
    self:drawText(label("ColumnEffect"), self.colEffect, y, 0.82, 0.84, 0.88, 1, font)
    y = y + line + 4

    for _, track in ipairs(tracks) do
        local raw = number(md, track.addiction)
        local trait = track.trait and NnCReg and NnCReg[track.trait]
        local dependent
        if player and trait then dependent = player:hasTrait(trait) end
        if track.label == "Opioid" then opioidDependent = dependent end
        if dependent then
            local paused = track.label == "Opioid" and methadone and methadone > 0
            withdrawalDetails(details, track, raw, paused, passesPerTick, minutesPerTick)
        end

        self:drawText(label(track.label), padding, y, 1, 1, 1, 1, font)
        drawCell(self, self.colOverdose, y, line, font, overdoseCell(track, md, passesPerTick, minutesPerTick))
        drawCell(self, self.colAddiction, y, line, font, addictionCell(track, raw, dependent))
        drawCell(self, self.colEffect, y, line, font, effectCell(track, md, passesPerTick, minutesPerTick))
        y = y + 2 * line + 4
    end

    if (number(md, "NnCMethEffect") or 0) > 0 then details[#details + 1] = label("SharedMeth") end
    if (number(md, "NnCMDMAEffect") or 0) > 0 then details[#details + 1] = label("SharedMDMA") end
    interactionDetails(details, player, md, opioidDependent)
    local width = self.tableWidth
    if #details > 0 then
        y = y + 4
        self:drawText(label("Details"), padding, y, 1, 1, 1, 1, font)
        y = y + line
        for _, detail in ipairs(details) do
            width = math.max(width, tm:MeasureStringX(font, detail) + 2 * padding)
            self:drawText(detail, padding, y, infoColor[1], infoColor[2], infoColor[3], 1, font)
            y = y + line
        end
    end
    y = y + 6
    for _, key in ipairs({"Note1", "Note2", "NoteOpioids"}) do
        self:drawText(label(key), padding, y, 0.75, 0.78, 0.82, 1, font)
        y = y + line
    end

    local height = y + 8
    if width ~= self:getWidth() then self:setWidth(width) end
    if height ~= self:getHeight() then self:setHeight(height) end
end

local function widest(tm, font, ...)
    local width = 0
    for _, value in ipairs({...}) do width = math.max(width, tm:MeasureStringX(font, value)) end
    return width
end

local function openStatus(playerNum)
    local old = instances[playerNum]
    if old then old:close() end
    local tm = getTextManager()
    local font = UIFont.Small
    local category = tm:MeasureStringX(font, label("ColumnCategory"))
    for _, track in ipairs(tracks) do category = math.max(category, tm:MeasureStringX(font, label(track.label))) end
    local overdose = widest(tm, font, label("ColumnOverdose"), label("Warning"), label("Overdose"), label("NoData"),
        "1728 / >1420  ·  " .. formatLabel("Minutes", 999.9))
    local addiction = widest(tm, font, label("ColumnAddiction"), label("AddictionWarning"), label("AddictionEarly"),
        label("Addicted"), label("Accumulating"), label("NoWarning"), label("NoData"), "2880 / 2592–2879")
    local effect = widest(tm, font, label("ColumnEffect"), label("Onset"), label("Active"), label("Comedown"),
        label("Off"), label("Suppressed"), label("NoData"), formatLabel("Minutes", 999.9))
    local width = 2 * padding + category + overdose + addiction + effect + 3 * gap
    width = math.max(width, 2 * padding + widest(tm, font, label("Note1"), label("Note2"), label("NoteOpioids")))
    local line = tm:getFontHeight(font) + 2
    local height = 58 + (2 * line + 4) * #tracks + 4 * line
    local panel = CodexNarcoticsStatus:new(120, 120, width, height, playerNum)
    panel.tableWidth = width
    panel.colOverdose = padding + category + gap
    panel.colAddiction = panel.colOverdose + overdose + gap
    panel.colEffect = panel.colAddiction + addiction + gap
    panel:initialise()
    panel:instantiate()
    panel:addToUIManager()
    panel:setVisible(true)
    instances[playerNum] = panel
end

local function onFill(playerNum, context, items)
    if not getSpecificPlayer(playerNum) then return end
    for _, entry in ipairs(items) do
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items and entry.items[1] or nil
        end
        if item and instanceof(item, "InventoryItem") and drugItems[item:getFullType()] then
            context:addOption(getText("IGUI_CodexNnC_Open"), playerNum, openStatus)
            return
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Add(onFill)
