-- Independent Simplified Chinese presentation adapter for XFACTION 0.1.3 / B42.21.
-- Native trait identifiers, progress rules, state snapshots and stat methods stay untouched.
if isServer() then return end
if getText('UI_CodexXFCN_Enabled')~='1' then return end
if CodexXFACTION_CN_4221 then return end
if not XFDynamic or not XFDynamic.Client then require 'XFDynamic/Client' end
local T=XFDynamic
local C=T and T.Client
if not C or not C.Panel or not T.Catalog or not T.Runtime then
    print('[Codex XFACTION CN] Target client API unavailable; translation adapter skipped.')
    return
end
local D=require 'CodexXFACTIONCN4221/Presentation'
local L={version=2,targetVersion='0.1.3'}
CodexXFACTION_CN_4221=L

-- Missing local keys must leave the author's display text intact. Never pass an
-- already translated sentence through getText again (percent signs may occur).
local function translated(key,fallback)
    local value
    if type(getTextOrNull)=='function' then value=getTextOrNull(key)
    else value=getText(key) end
    if type(value)=='string' and value~='' and value~=key then return value end
    return fallback
end

local function replacePlain(text,needle,replacement)
    local parts,pos={},1
    while true do
        local first,last=string.find(text,needle,pos,true)
        if not first then parts[#parts+1]=string.sub(text,pos);break end
        parts[#parts+1]=string.sub(text,pos,first-1)
        parts[#parts+1]=replacement
        pos=last+1
    end
    return table.concat(parts)
end
function L.text(text)
    if type(text)~='string' then return text end
    local key=D.exact[text]
    if key then return translated(key,text) end
    local count=string.match(text,'^(%d+) traits$')
    if count then return count..translated('UI_CodexXFCN_CountSuffix',' traits') end
    for _,pair in ipairs(D.fragments) do
        text=replacePlain(text,pair[1],translated(pair[2],pair[1]))
    end
    return text
end

-- Only these two catalog fields are display/search/sort text. No rules or keys are changed.
L.originalCatalog={}
for _,d in ipairs(T.Catalog) do
    L.originalCatalog[d.key]={name=d.name,effect=d.effect}
    d.name=translated('UI_XFDT_'..d.key,d.name)
    d.effect=translated('UI_CodexXFCN_Effect_'..d.key,d.effect)
end

local function bindTextMethod(object,name)
    if not object or type(object[name])~='function' then return end
    object.__CodexXFACTIONCN4221=object.__CodexXFACTIONCN4221 or {}
    if object.__CodexXFACTIONCN4221[name] then return end
    local original=object[name]
    local wrapped=function(self,text,...)
        return original(self,L.text(text),...)
    end
    object[name]=wrapped
    object.__CodexXFACTIONCN4221[name]={original=original,wrapped=wrapped}
end
function L.bind(panel)
    bindTextMethod(panel,'drawText')
    bindTextMethod(panel,'drawTextRight')
    bindTextMethod(panel.list,'drawText')
    bindTextMethod(panel.list,'drawTextRight')
    bindTextMethod(panel.details,'setText')
    for _,name in ipairs({'filter','refresh','sortButton','closeButton'}) do
        local button=panel[name]
        bindTextMethod(button,'setTitle')
        if button and type(button.setTitle)=='function' then button:setTitle(button.title) end
    end
    if panel.search and panel.search.setTooltip then
        panel.search:setTooltip(L.text('Search trait names. Clear to show all matching traits.'))
    end
end
local originalCreate=C.Panel.createChildren
L.originalCreate=originalCreate
local function afterCreate(panel,...)
    L.bind(panel)
    return ...
end
C.Panel.createChildren=function(self,...)
    return afterCreate(self,originalCreate(self,...))
end
for _,panel in pairs(C.windows) do L.bind(panel) end

-- Keep the author's callback and target intact; only rename that exact context-menu entry.
Events.OnFillWorldObjectContextMenu.Add(function(number,context,objects,test)
    if test or not context or not context.options then return end
    local changed=false
    for _,option in pairs(context.options) do
        if option.name=='XFACTION Trait Progress' and option.onSelect==C.open then
            option.name=L.text(option.name);changed=true
        end
    end
    if changed and context.calcWidth and context.setWidth then context:setWidth(context:calcWidth()) end
end)

-- This original function is notification-only; retain the same option check and good-text call.
L.originalNotify=T.Runtime.notify
T.Runtime.notify=function(player,changes)
    if not T.Model.option('Notifications',true) then return end
    for _,change in ipairs(changes or {}) do
        local prefix=translated(change.added and 'UI_CodexXFCN_Gained' or 'UI_CodexXFCN_Overcome',change.added and 'Trait gained: ' or 'Trait overcome: ')
        local original=L.originalCatalog[change.key]
        local name=translated('UI_XFDT_'..change.key,original and original.name or tostring(change.key))
        HaloTextHelper.addGoodText(player,prefix..name)
    end
end
return L
