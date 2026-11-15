-- Display the unified grid in the existing LiveWire Monitor.
if isClient() or isServer() then return end

local sourcePath = "media/lua/client/LiveWire/LW_SoftwareApp.lua"
local modId = "batman_LiveWire"
-- Fingerprints of the normalized Monitor source in each supported Workshop release.
local pins = {
    ["2.0.2"] = { hash = 518175238, length = 27696 },
    ["2.0.3"] = { hash = 518175238, length = 27696 },
    ["2.1.0"] = { hash = 713272323, length = 29028 },
    ["2.1.1"] = { hash = 713272323, length = 29028 },
    ["2.1.2"] = { hash = 713272323, length = 29028 },
}
local states = { paired = true, unloaded = true, unpaired = true }
local prefix = "IGUI_SQLWISA_Monitor_"
local installedApp

local function T(key, ...)
    return getText(prefix .. key, ...)
end

local function telemetry(snap)
    local isa = snap and snap.suqingISA
    if type(isa) == "table" and states[isa.status] then return isa end
end

local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function watts(n)
    return finite(n) and string.format("%.0f W", n) or T("Unavailable")
end

local function energy(charge, capacity)
    if not finite(charge) or not finite(capacity) then return T("Unavailable") end
    return string.format("%.2f / %.2f kWh", charge, capacity)
end

local function location(object)
    if object and finite(object.x) and finite(object.y) and finite(object.z) then
        return string.format("(%d, %d, %d)", object.x, object.y, object.z)
    end
end

local function statusLine(isa)
    local coords = location(isa.cabinet)
    local status = T(isa.status)
    return coords and (status .. " " .. coords) or status
end

local function percent(n)
    return finite(n) and string.format("%.0f%%", n) or T("Unavailable")
end

local function measure(s)
    return getTextManager():MeasureStringX(UIFont.Small, s)
end

local function drawText(ui, s, x, y, width, colour)
    if width <= 0 then return end
    if measure(s) > width then
        local dots = "..."
        if measure(dots) > width then return end
        local n = #s
        while n > 0 and measure(string.sub(s, 1, n) .. dots) > width do n = n - 1 end
        s = string.sub(s, 1, n) .. dots
    end
    ui:drawText(s, x, y, colour[1], colour[2], colour[3], 1, UIFont.Small)
end

local panel = { 0.14, 0.17, 0.20 }
local border = { 0.24, 0.30, 0.35 }
local text = { 0.88, 0.91, 0.93 }
local muted = { 0.66, 0.72, 0.76 }
local accent = { 0.30, 0.78, 0.95 }
local warning = { 0.95, 0.70, 0.33 }

local function card(ui, x, y, w, h)
    LiveWire.UIKit.rect(ui, x, y, w, h, panel)
    LiveWire.UIKit.border(ui, x, y, w, h, border)
end

local function stockFraction(charge, capacity)
    if finite(charge) and finite(capacity) and capacity > 0 then
        return percent(100 * charge / capacity)
    end
    return T("Unavailable")
end

local function batteryValue(row)
    return energy(row.chargeKWh, row.capacityKWh) .. " | " .. T("Condition", percent(row.cond))
end

local function batteryName(model)
    if type(model) ~= "string" or model == "" then return T("Battery") end
    local item = getScriptManager():FindItem(model)
    return item and item:getDisplayName() or model
end

local function addBattery(rows, row)
    rows[#rows + 1] = { batteryName(row.model), batteryValue(row) }
end

local function addNativeBatteries(rows, snap, isa)
    if type(isa.liveWireBanks) == "table" then
        for i, bank in ipairs(isa.liveWireBanks) do
            local title = T("Bank", i)
            local coords = location(bank)
            rows[#rows + 1] = {
                coords and title .. " " .. coords or title,
                energy(bank.chargeKWh, bank.capacityKWh), true,
            }
            for _, row in ipairs(bank.batteries or {}) do addBattery(rows, row) end
        end
        if #isa.liveWireBanks == 0 then rows[#rows + 1] = { getText("IGUI_LW_NoBattery") } end
        return
    end

    local count = 0
    for _, row in ipairs(snap.batteries or {}) do
        if row.origin ~= "ISA" then
            local charge = finite(row.charge) and finite(row.capacity) and row.charge * row.capacity or nil
            addBattery(rows, { model = row.model, chargeKWh = charge, capacityKWh = row.capacity, cond = row.cond })
            count = count + 1
        end
    end
    if count == 0 then rows[#rows + 1] = { getText("IGUI_LW_NoBattery") } end
end

local function nativeEnergy(snap, isa)
    if finite(isa.liveWireChargeKWh) and finite(isa.liveWireCapacityKWh) then
        return energy(isa.liveWireChargeKWh, isa.liveWireCapacityKWh)
    end
    if isa.status ~= "paired" then
        local charge, capacity = 0, 0
        for _, row in ipairs(snap.batteries or {}) do
            if row.origin ~= "ISA" then
                if not finite(row.capacity) or not finite(row.charge) then return T("Unavailable") end
                charge = charge + row.capacity * row.charge
                capacity = capacity + row.capacity
            end
        end
        return energy(charge, capacity)
    end
    return T("Unavailable")
end

local function batteryRows(snap, isa)
    local rows = {
        { T("TotalStorage"), energy(snap.stock, snap.capacity), true },
        { "LiveWire", nativeEnergy(snap, isa), true },
    }
    addNativeBatteries(rows, snap, isa)
    if (snap.extra or 0) > 0 then rows[#rows + 1] = { getText("IGUI_LW_TooManyBatteries", snap.extra) } end
    if finite(snap.lost) and snap.lost > 0.0005 then
        rows[#rows + 1] = { getText("IGUI_LW_Lost", string.format("%.2f", snap.lost)) }
    end
    rows[#rows + 1] = { "ISA", statusLine(isa), true }
    if isa.status == "paired" then
        rows[#rows + 1] = {
            T("AvailableStorage"), energy(isa.chargeKWh, isa.capacityKWh) .. " | "
                .. stockFraction(isa.chargeKWh, isa.capacityKWh),
        }
        for _, row in ipairs(isa.batteries or {}) do addBattery(rows, row) end
        if #(isa.batteries or {}) == 0 then rows[#rows + 1] = { getText("IGUI_LW_NoBattery") } end
    end
    return rows
end

local function sourceRows(snap, isa)
    local rows = { { "LiveWire", watts(isa.liveWireProductionW), true } }
    for _, family in ipairs(LiveWire.SnapshotView.familyTotals(snap)) do
        if family.n > 0 then
            rows[#rows + 1] = { getText(family.key), getText("IGUI_LW_App_FamilyTotal", family.n, family.w) }
            for _, source in ipairs(snap.sources) do
                if source.kind == family.kind then
                    local name = getText("IGUI_LW_Model_" .. source.model)
                    for _, field in ipairs(LiveWire.Defs.SOURCE_FIELDS[source.kind] or {}) do
                        if field.badge and (source[field.field] or 0) > field.badgeAbove then
                            name = name .. " " .. getText(field.badge, math.floor(source[field.field] * 100 + 0.5))
                        end
                    end
                    rows[#rows + 1] = { name, getText("IGUI_LW_App_SourceState", source.w, source.cond) }
                end
            end
        end
    end
    if #(snap.sources or {}) == 0 then rows[#rows + 1] = { T("NoSources") } end
    rows[#rows + 1] = { "ISA", statusLine(isa), true }
    if isa.status == "paired" then
        rows[#rows + 1] = { T("SolarProduction"), watts(isa.productionW) }
        rows[#rows + 1] = { T("LinkedPanels"), finite(isa.panelCount) and tostring(isa.panelCount) or T("Unavailable") }
        for i, pos in ipairs(isa.panels or {}) do
            rows[#rows + 1] = { T("Panel", i), location(pos) or T("Unavailable") }
        end
    end
    if snap.backup then rows[#rows + 1] = { T("Backup"), watts(isa.backupProductionW), true } end
    if finite(snap.gridW) then rows[#rows + 1] = { T("Mains"), watts(snap.gridW), true } end
    return rows
end

local function layoutRow(ui, row, x, y, w, lineHeight, narrow)
    local colour = row[3] and accent or text
    if not row[2] then
        drawText(ui, row[1], x, y, w, colour)
    elseif narrow then
        drawText(ui, row[1], x, y, w, colour)
        drawText(ui, row[2], x + 8, y + lineHeight, w - 8, muted)
    else
        local right = math.min(measure(row[2]), math.floor(w * 0.63))
        drawText(ui, row[1], x, y, w - right - 8, colour)
        drawText(ui, row[2], x + w - right, y, right, muted)
    end
end

local function rowsFor(app, tab, snap, isa)
    if app.suqingISASnapshot ~= snap then
        app.suqingISASnapshot = snap
        app.suqingISARows = {}
    end
    local rows = app.suqingISARows[tab]
    if not rows then
        if tab == "sources" then rows = sourceRows(snap, isa) else rows = batteryRows(snap, isa) end
        app.suqingISARows[tab] = rows
    end
    return rows
end

local function detailPage(app, ui, x, y, w, h, tab, title, rows)
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    local narrow = w < 390
    local rowHeight = (narrow and 2 or 1) * lineHeight + 4
    local buttonHeight = lineHeight + 8
    local first = y + lineHeight + 12
    local footer = y + h - buttonHeight - 6
    local pageSize = math.floor((footer - 5 - first) / rowHeight)
    if pageSize < 1 or w < 120 then return false end

    card(ui, x, y, w, h)
    drawText(ui, title, x + 8, y + 5, w - 16, accent)
    local pages = math.ceil(#rows / pageSize)
    app.suqingISAPages = app.suqingISAPages or {}
    local page = math.min(app.suqingISAPages[tab] or 1, pages)
    app.suqingISAPages[tab] = page
    local last = math.min(page * pageSize, #rows)
    for i = (page - 1) * pageSize + 1, last do
        layoutRow(ui, rows[i], x + 8, first, w - 16, lineHeight, narrow)
        first = first + rowHeight
    end
    if pages > 1 then
        drawText(ui, string.format("%d / %d", page, pages), x + 84, footer + 4, w - 94, muted)
        if page > 1 then app:button(ui, x + 8, footer, 32, buttonHeight, "<", "suqingISA:prev") end
        if page < pages then app:button(ui, x + 46, footer, 32, buttonHeight, ">", "suqingISA:next") end
    end
    return true
end

local function overviewStrip(ui, x, y, w, h, snap, isa)
    local line = getTextManager():getFontHeight(UIFont.Small) + 4
    local tall = w < 470
    local strip = (tall and 4 or 3) * line + 10
    -- Keep the upstream summary and inverter buttons usable on smaller host windows.
    if w < 240 or h - strip - 6 < 12 * (line - 4) + 47 then return h end

    local start = y + h - strip
    card(ui, x, start, w, strip)
    local split = math.floor(w * 0.54)
    drawText(ui, "ISA " .. statusLine(isa), x + 8, start + 5, w - 16, isa.status == "paired" and accent or warning)
    local yy = start + 5 + line
    if tall then
        drawText(ui, "LiveWire  " .. watts(isa.liveWireProductionW), x + 8, yy, w - 16, text)
        drawText(ui, "ISA  " .. watts(isa.productionW), x + 8, yy + line, w - 16, text)
        drawText(ui, T("AvailableStorage") .. "  " .. energy(snap.stock, snap.capacity), x + 8, yy + 2 * line, w - 16, muted)
    else
        drawText(ui, "LiveWire  " .. watts(isa.liveWireProductionW), x + 8, yy, split - 14, text)
        drawText(ui, nativeEnergy(snap, isa), x + split, yy, w - split - 8, muted)
        drawText(ui, "ISA  " .. watts(isa.productionW), x + 8, yy + line, split - 14, text)
        drawText(ui, energy(isa.chargeKWh, isa.capacityKWh), x + split, yy + line, w - split - 8, muted)
    end
    return h - strip - 6
end

local function normalize(path)
    return tostring(path):gsub("\\", "/"):gsub("^@", ""):gsub("/+$", ""):lower()
end

local function sourceMatches(pin)
    if not getModFileReader then return false end
    local reader = getModFileReader(modId, sourcePath, false)
    if not reader then return false end
    local hash, length, previousCR, openLine = 0, 0, false, false
    local function feed(unit)
        hash = (hash * 131 + unit) % 1000000007
        length = length + 1
    end
    local ok = pcall(function()
        while true do
            local unit = reader:read()
            if unit == -1 then break end
            if unit == 13 then
                feed(10)
                previousCR, openLine = true, false
            elseif unit == 10 then
                if not previousCR then feed(10) end
                previousCR, openLine = false, false
            else
                feed(unit)
                previousCR, openLine = false, true
            end
            if length > pin.length then break end
        end
        if openLine then feed(10) end
    end)
    reader:close()
    return ok and hash == pin.hash and length == pin.length
end

local function hook()
    local lw = LiveWire
    local app = lw and lw.SoftwareApp
    local pin = lw and pins[lw.VERSION]
    if not app or app == installedApp or not pin then return end
    local info = getModInfoByID(modId) or getModInfoByID("\\" .. modId)
    local version = info and info.getModVersion and tostring(info:getModVersion())
    if version ~= lw.VERSION or not getFilenameOfClosure or not info.getVersionDir then return end
    local file = normalize(info:getVersionDir() .. "/" .. sourcePath)
    local methods = { app.drawOverview, app.drawSources, app.drawBatteries, app.details, app.act, app.button }
    for i = 1, 6 do
        local fn = methods[i]
        if type(fn) ~= "function" or normalize(getFilenameOfClosure(fn)) ~= file then return end
    end
    if not sourceMatches(pin) then return end

    local overview, sources, batteries, details, act = app.drawOverview, app.drawSources, app.drawBatteries, app.details, app.act
    function app:drawOverview(ui, x, y, w, h, snap)
        local isa = telemetry(snap)
        if isa then h = overviewStrip(ui, x, y, w, h, snap, isa) end
        return overview(self, ui, x, y, w, h, snap)
    end
    function app:drawSources(ui, x, y, w, h, snap)
        local isa = telemetry(snap)
        if isa and detailPage(self, ui, x, y, w, h, "sources", getText("IGUI_LW_Sources"), rowsFor(self, "sources", snap, isa)) then return end
        return sources(self, ui, x, y, w, h, snap)
    end
    function app:drawBatteries(ui, x, y, w, h, snap)
        local isa = telemetry(snap)
        if isa and detailPage(self, ui, x, y, w, h, "batteries", T("BatteryPage"), rowsFor(self, "batteries", snap, isa)) then return end
        return batteries(self, ui, x, y, w, h, snap)
    end
    function app:details(snap)
        local rows = details(self, snap)
        local isa = telemetry(snap)
        if self.tab ~= "forecast" or not isa or isa.status == "unpaired" then return rows end
        if self.suqingISAForecastSource ~= rows then
            local labelled = { T("ForecastScope") }
            for _, row in ipairs(rows) do labelled[#labelled + 1] = row end
            self.suqingISAForecastSource, self.suqingISAForecastRows = rows, labelled
        end
        return self.suqingISAForecastRows
    end
    function app:act(action)
        if self.suqingISAPages and (self.tab == "sources" or self.tab == "batteries")
            and (action == "suqingISA:prev" or action == "suqingISA:next") then
            local page = self.suqingISAPages[self.tab] or 1
            self.suqingISAPages[self.tab] = math.max(1, page + (action == "suqingISA:next" and 1 or -1))
            getSoundManager():playUISound("UIActivateButton")
            return
        end
        return act(self, action)
    end
    installedApp = app
end

Events.OnGameStart.Add(function()
    local ok, reason = pcall(hook)
    if not ok then print("[SuQingLiveWireISACompat] Monitor UI inactive: " .. tostring(reason)) end
end)
