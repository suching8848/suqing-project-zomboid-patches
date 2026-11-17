-- CleanUI's drag move supplies screen-relative coordinates to a scrolled rail.
-- Correct the floating button before the original code computes the drop index.
if isServer() then return end
require "ISUI/ISInventoryPage_DragSort"

local installed

local function install()
    if installed or not ISInventoryPage then return end
    local calculate = ISInventoryPage.calculateInsertPosition
    if type(calculate) ~= "function" or type(getModInfoByID) ~= "function"
        or type(getFilenameOfClosure) ~= "function" then return end

    local info = getModInfoByID("CleanUI") or getModInfoByID("\\CleanUI")
    local directory = info and info:getVersionDir()
    if type(directory) ~= "string" then return end
    local version = tostring(info:getModVersion())
    if version ~= "2.10.6" and version ~= "2.10.7" then return end
    local expected = directory:gsub("\\", "/"):gsub("/$", ""):lower()
        .. "/media/lua/client/isui/isinventorypage_dragsort.lua"
    local source = getFilenameOfClosure(calculate)
    if type(source) ~= "string" or source:gsub("^@", ""):gsub("\\", "/"):lower() ~= expected then return end

    ISInventoryPage.calculateInsertPosition = function(page, button, ...)
        local panel = page.containerButtonPanel
        if panel and button and button.isDragging and button.page == page
            and button:getParent() == panel and panel:getYScroll() ~= 0
            and panel:getScrollChildren() and button:getScrollWithParent() then
            local height = button:getHeight()
            local viewportHeight = panel:getHeight()
            local contentHeight = panel:getScrollHeight() or viewportHeight
            local maximum = math.max(0, math.max(viewportHeight, contentHeight) - height)
            button:setY(math.max(0, math.min(maximum, panel:getMouseY() - height / 2)))
        end
        return calculate(page, button, ...)
    end
    installed = true
    print("[SuQingCleanUIContainerDrag] Scroll-aware container reordering installed")
end

Events.OnGameBoot.Add(install)
Events.OnGameStart.Add(install)
