-- Presentation-only relocation of the existing XFACTION progress entry.
if isServer() then return end
require 'XpSystem/ISUI/ISCharacterScreen'
require 'ISUI/ISButton'
if not XFDynamic or not XFDynamic.Client then require 'XFDynamic/Client' end
local C=XFDynamic and XFDynamic.Client
local Screen=ISCharacterScreen
if not C or type(C.open)~='function' or not Screen or type(Screen.create)~='function' or type(Screen.render)~='function' then
    print('[Codex Character Menu] XFACTION/character-screen API unavailable; original entry retained.')
    return
end
CodexCharacterMenuTweaks4221=CodexCharacterMenuTweaks4221 or {}
if CodexCharacterMenuTweaks4221.XFACTION then return end
local M={version=1,field='codexXFACTIONProgressButton'}
CodexCharacterMenuTweaks4221.XFACTION=M
local GAP=10
local function label() return getText('UI_CodexCharacterMenu_XFACTION') end
local function playerNumber(screen)
    if screen.char and screen.char.getPlayerNum then return screen.char:getPlayerNum() end
    return screen.playerNum
end
function M.open(screen)
    local number=playerNumber(screen)
    if type(number)~='number' then return end
    local player=getSpecificPlayer(number)
    if not player or player:isDead() then return end
    return C.open(number)
end
function M.ensure(screen)
    if screen[M.field] then return screen[M.field] end
    if not screen.literatureButton then return end
    local h=screen.literatureButton:getHeight()
    local w=math.max(100,getTextManager():MeasureStringX(UIFont.Small,label())+20)
    local button=ISButton:new(0,0,w,h,label(),screen,M.open)
    button:initialise();button:instantiate()
    button.background=false
    button.tooltip=getText('UI_CodexCharacterMenu_XFACTION_Tooltip')
    button:setVisible(false)
    screen:addChild(button)
    screen[M.field]=button
    return button
end
local function overlaps(x,y,w,h,other)
    if not other then return false end
    return x<other:getRight() and x+w>other:getX() and y<other:getBottom() and y+h>other:getY()
end
function M.layout(screen)
    local button=M.ensure(screen)
    local literature=screen.literatureButton
    if not button or not literature then return end
    local w=math.max(100,getTextManager():MeasureStringX(UIFont.Small,label())+20)
    local h=literature:getHeight()
    local x,y=literature:getRight()+GAP,literature:getY()
    local baseHeight=screen:getHeight()
    local stacked=x+w+GAP>screen:getWidth() or overlaps(x,y,w,h,screen.resetTransmogButton)
    if stacked then
        x=literature:getX()
        if x+w+GAP>screen:getWidth() then x=GAP end
        if x+w+GAP>screen:getWidth() then screen:setWidthAndParentWidth(x+w+GAP) end
        y=baseHeight
        if screen.resetTransmogButton then y=math.max(y,screen.resetTransmogButton:getBottom()+GAP) end
        screen:setHeightAndParentHeight(y+h+GAP)
    end
    button:setTitle(label());button:setWidth(w);button:setHeight(h)
    button:setX(x);button:setY(y);button:setVisible(true)
    button.enable=true
    screen.codexXFACTIONProgressLayout={stacked=stacked,baseHeight=baseHeight,finalHeight=screen:getHeight()}
end
M.originalCreate=Screen.create
local function afterCreate(screen,...)
    M.ensure(screen)
    return ...
end
Screen.create=function(self,...)
    return afterCreate(self,M.originalCreate(self,...))
end
M.originalRender=Screen.render
local function afterRender(screen,...)
    M.layout(screen)
    return ...
end
Screen.render=function(self,...)
    return afterRender(self,M.originalRender(self,...))
end
if type(Screen.initJoypadButtons)=='function' then
    M.originalJoypad=Screen.initJoypadButtons
    local function afterJoypad(screen,...)
        local button=screen[M.field]
        if button and screen.insertNewLineOfButtons then screen:insertNewLineOfButtons(button) end
        return ...
    end
    Screen.initJoypadButtons=function(self,...)
        return afterJoypad(self,M.originalJoypad(self,...))
    end
end

-- Native removeOptionByName deletes the first matching name. Remove this exact
-- callback/target by index instead, retaining foreign options with equal names.
function M.hideWorldEntry(number,context,objects,test)
    if test or not context or not context.options then return end
    local changed=false
    for i=#context.options,1,-1 do
        local option=context.options[i]
        if option and option.onSelect==C.open and option.target==number then
            if context.optionPool then table.insert(context.optionPool,option) end
            table.remove(context.options,i)
            changed=true
        end
    end
    if changed then
        for i,option in ipairs(context.options) do option.id=i end
        context.numOptions=#context.options+1
        if context.calcHeight then context:calcHeight() end
        if context.calcWidth and context.setWidth then context:setWidth(context:calcWidth()) end
    end
end
Events.OnFillWorldObjectContextMenu.Add(M.hideWorldEntry)
return M
