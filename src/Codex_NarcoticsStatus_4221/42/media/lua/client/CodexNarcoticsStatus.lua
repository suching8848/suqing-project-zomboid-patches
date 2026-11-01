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
    { key="NnCBenzoAmount",  label="IGUI_CodexNnC_Benzo",   limit=1420, decay=12 },
    { key="NnCCokeAmount",   label="IGUI_CodexNnC_Coke",    limit=1410, decay=24 },
    { key="NnCMethAmount",   label="IGUI_CodexNnC_Meth",    limit=1420, decay=12 },
    { key="NnCOpioidAmount", label="IGUI_CodexNnC_Opioid",  limit=1410, decay=12 },
    { key="NnCMDMAAmount",   label="IGUI_CodexNnC_MDMA",    limit=1420, decay=12 },
    { key="NnCSteroidAmount",label="IGUI_CodexNnC_Steroid", limit=1410, decay=12 },
}
local shortDays = {0.25, 0.5, 1, 1.5, 2}

-- Match N&C's ten-minute pass and cap, including long-day compensation.
local function dayHours()
    local index = SandboxVars and SandboxVars.DayLength
    if type(index) ~= "number" then return nil end
    if index <= 5 then return shortDays[index] end
    return index - 3
end
local function estimateMinutes(value, decay)
    local hours = dayHours()
    if not hours or hours <= 0 then return nil end
    local passes = math.max(1, math.floor(hours / 3 + 0.5))
    local ticks = 0
    local remaining = math.max(0, value)
    while remaining > 0 and ticks < 100000 do
        for _ = 1, passes do
            if remaining > 0 then remaining = remaining - decay end
            remaining = math.max(0, math.min(1440, remaining))
        end
        ticks = ticks + 1
    end
    if remaining > 0 then return nil end
    return ticks * 10 * hours / 24
end

CodexNarcoticsStatus = ISCollapsableWindow:derive("CodexNarcoticsStatus")
local instances = {}

function CodexNarcoticsStatus:new(x, y, width, height, playerNum)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.playerNum = playerNum
    o.resizable = false
    o.title = getText("IGUI_CodexNnC_Title")
    return o
end

function CodexNarcoticsStatus:close()
    self:setVisible(false)
    self:removeFromUIManager()
    instances[self.playerNum] = nil
end

function CodexNarcoticsStatus:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local player = getSpecificPlayer(self.playerNum)
    local md = player and player:getModData() or nil
    local font = UIFont.Small
    local line = getTextManager():getFontHeight(font) + 8
    local y = self:titleBarHeight() + 10
    self:drawText(getText("IGUI_CodexNnC_ColumnCategory"), 16, y, 0.82, 0.84, 0.88, 1, font)
    self:drawText(getText("IGUI_CodexNnC_ColumnAmount"), self.colAmount, y, 0.82, 0.84, 0.88, 1, font)
    self:drawText(getText("IGUI_CodexNnC_ColumnState"), self.colState, y, 0.82, 0.84, 0.88, 1, font)
    self:drawText(getText("IGUI_CodexNnC_ColumnTime"), self.colTime, y, 0.82, 0.84, 0.88, 1, font)
    y = y + line
    for _, track in ipairs(tracks) do
        local value = md and md[track.key] or nil
        local display, status, estimate
        local r, g, b = 0.75, 0.9, 0.75
        if type(value) ~= "number" then
            display = "--"
            status = getText("IGUI_CodexNnC_NoData")
            estimate = "--"
            r, g, b = 0.7, 0.7, 0.7
        else
            display = tostring(math.floor(value)) .. " / >" .. tostring(track.limit)
            if value > track.limit then
                status = getText("IGUI_CodexNnC_Overdose")
                r, g, b = 1, 0.3, 0.3
            elseif value >= 864 then
                status = getText("IGUI_CodexNnC_Warning")
                r, g, b = 1, 0.72, 0.25
            else
                status = getText("IGUI_CodexNnC_Normal")
            end
            local minutes = estimateMinutes(value, track.decay)
            estimate = minutes and string.format("%.1f", minutes) or "--"
        end
        self:drawText(getText(track.label), 16, y, 1, 1, 1, 1, font)
        self:drawText(display, self.colAmount, y, 1, 1, 1, 1, font)
        self:drawText(status, self.colState, y, r, g, b, 1, font)
        self:drawText(estimate, self.colTime, y, 0.85, 0.9, 1, 1, font)
        y = y + line
    end
    y = y + 4
    self:drawText(getText("IGUI_CodexNnC_Note1"), 16, y, 0.75, 0.78, 0.82, 1, font)
    y = y + line
    self:drawText(getText("IGUI_CodexNnC_Note2"), 16, y, 0.75, 0.78, 0.82, 1, font)
end

local function openStatus(playerNum)
    local old = instances[playerNum]
    if old then old:close() end
    local height = 90 + (getTextManager():getFontHeight(UIFont.Small) + 8) * 9
    local tm = getTextManager()
    local font = UIFont.Small
    local first = tm:MeasureStringX(font, getText("IGUI_CodexNnC_ColumnCategory"))
    for _, track in ipairs(tracks) do first = math.max(first, tm:MeasureStringX(font, getText(track.label))) end
    local amount = math.max(tm:MeasureStringX(font, getText("IGUI_CodexNnC_ColumnAmount")), tm:MeasureStringX(font, "1440 / >1420"))
    local state = math.max(tm:MeasureStringX(font, getText("IGUI_CodexNnC_ColumnState")), tm:MeasureStringX(font, getText("IGUI_CodexNnC_Overdose")), tm:MeasureStringX(font, getText("IGUI_CodexNnC_NoData")))
    local time = tm:MeasureStringX(font, getText("IGUI_CodexNnC_ColumnTime"))
    local width = 16 + first + 22 + amount + 22 + state + 22 + time + 20
    width = math.max(width, tm:MeasureStringX(font, getText("IGUI_CodexNnC_Note1")) + 32, tm:MeasureStringX(font, getText("IGUI_CodexNnC_Note2")) + 32)
    local panel = CodexNarcoticsStatus:new(120, 120, width, height, playerNum)
    panel.colAmount = 16 + first + 22
    panel.colState = panel.colAmount + amount + 22
    panel.colTime = panel.colState + state + 22
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
