local T=LuckyTest
function T.ten(kind)
 local values={};for i=1,10 do values[i]=T.item(kind)end;return values
end
T.case("unpatched ten single cigarettes retain Food smoke menu",function()
 local values=T.ten("Food");local selection={T.group(values)}
 T.call(selection)
 T.eq(T.lastItems,selection);T.eq(#T.foodMenuItems,10);T.eq(T.hungerCalls,10);T.eq(T.pillsMenuItems,nil)
end)
T.case("unpatched ten packs retain consumable smoke menu",function()
 local values=T.ten("DrainableComboItem");local selection={T.group(values)}
 T.call(selection)
 T.eq(T.lastItems,selection);T.eq(#T.pillsMenuItems,10);T.eq(T.hungerCalls,0);T.eq(T.foodMenuItems,nil)
end)
T.case("unpatched mixed group reproduces reported nil at actual Food branch",function()
 local values=T.ten("Food");values[7]=T.item("DrainableComboItem")
 local ok,err=pcall(T.call,{T.group(values)})
 T.eq(ok,false);T.check(tostring(err):find("Object tried to call nil",1,true)~=nil,tostring(err))
 T.check(T.hungerCalls>0,"actual Food branch reached before Drainable failed")
end)
