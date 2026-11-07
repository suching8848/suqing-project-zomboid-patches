local T=LuckyTest
T.spyCalls=0;T.spyMarker={}
function T.spy(...)
 T.spyCalls=T.spyCalls+1;T.spyArgs={...}
 return T.spyMarker,nil,"third",false,5
end
ISInventoryPaneContextMenu.createMenu=T.spy
T.metadata[T.spy]={source=T.cleanDir.."/media/lua/client/ISUI/ISInventoryPaneContextMenu.lua",line=327}
