require "ISUI/ISPanel"

local Core = require "SuQingPortableVirusDetector/Core"
local Panel = ISPanel:derive("SuQingPortableVirusDetectorPanel")
local Radar = {}
local TEXT = "UI_SuQingPortableVirusDetector_"
local RANGE = 50
local INTERVAL_MS = 500
local WIDTH, HEIGHT = 198, 222
local GRID_SIZE = 158
local GRID_TOP = 28
local LEVELS = { "above", "same", "below" }
local LEVEL_COLORS = {
    above = { 0, 0, 1 },
    same = { 1, 0, 0 },
    below = { 0, 1, 1 },
}
local activePanel

function Radar.close()
    if not activePanel then return end
    local panel = activePanel
    activePanel = nil
    panel:setVisible(false)
    panel:removeFromUIManager()
end

function Radar.isOpen(watch)
    return activePanel ~= nil and activePanel.watch == watch
end

local function scan(character, cell)
    local contacts = {}
    local zombies = cell and cell:getZombieList()
    if not zombies then return contacts end

    local x, y, z = character:getX(), character:getY(), character:getZ()
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local dx, dy = zombie:getX() - x, zombie:getY() - y
            if dx * dx + dy * dy < RANGE * RANGE then
                local dz = zombie:getZ() - z
                local level = dz > 0 and "above" or dz < 0 and "below" or "same"
                contacts[#contacts + 1] = { x = dx, y = dy, color = LEVEL_COLORS[level] }
            end
        end
    end
    return contacts
end

function Panel:update()
    if activePanel ~= self then return end
    local now = getTimestampMs()
    if self.lastScan and now >= self.lastScan and now - self.lastScan < INTERVAL_MS then return end
    if self.character:isDead() or not Core.isCarried(self.character, self.watch)
            or not Core.isInstalled(self.watch) then
        Radar.close()
        return
    end
    self.contacts = scan(self.character, getCell())
    self.lastScan = now
end

local function plot(panel, x, y, color)
    panel:drawRect(x - 2, y - 2, 4, 4, 1, color[1], color[2], color[3])
end

function Panel:render()
    local font = UIFont.NewSmall
    local half = GRID_SIZE / 2
    local left, centerX, centerY = (self.width - GRID_SIZE) / 2, self.width / 2, GRID_TOP + half

    self:drawTextCentre(self.title, centerX, 7, 0.79, 0.91, 0.89, 1, font)
    self:drawRectBorder(left, GRID_TOP, GRID_SIZE, GRID_SIZE, 0.8, 0.26, 0.46, 0.43)
    self:drawRectBorder(centerX - half / 2, centerY - half / 2, half, half, 0.6, 0.20, 0.36, 0.33)
    self:drawRect(centerX, GRID_TOP, 1, GRID_SIZE, 0.65, 0.24, 0.42, 0.38)
    self:drawRect(left, centerY, GRID_SIZE, 1, 0.65, 0.24, 0.42, 0.38)

    local scale = half / RANGE
    for _, contact in ipairs(self.contacts) do
        plot(self, centerX + contact.x * scale, centerY + contact.y * scale, contact.color)
    end
    self:drawRect(centerX - 2, centerY - 2, 5, 5, 1, 0.81, 0.98, 0.91)

    for index, level in ipairs(LEVELS) do
        local x = 14 + (index - 1) * 60
        plot(self, x, HEIGHT - 20, LEVEL_COLORS[level])
        self:drawText(self.legend[level], x + 7, HEIGHT - 28, 0.80, 0.85, 0.84, 1, font)
    end
end

function Radar.open(character, watch)
    if not character or character:isDead() or not Core.isInstalled(watch)
            or not Core.isCarried(character, watch) then
        return false
    end
    if Radar.isOpen(watch) then return true end
    Radar.close()

    local panel = ISPanel.new(Panel, 20, 58, WIDTH, HEIGHT)
    panel.character = character
    panel.watch = watch
    panel.contacts = {}
    panel.title = getText(TEXT .. "Title")
    panel.legend = {}
    for _, level in ipairs(LEVELS) do
        panel.legend[level] = getText(TEXT .. level)
    end
    panel.moveWithMouse = true
    panel.backgroundColor = { r = 0.05, g = 0.09, b = 0.10, a = 0.92 }
    panel.borderColor = { r = 0.27, g = 0.44, b = 0.43, a = 1 }
    panel:initialise()
    panel:addToUIManager()
    activePanel = panel
    panel:update()
    return true
end

return Radar
