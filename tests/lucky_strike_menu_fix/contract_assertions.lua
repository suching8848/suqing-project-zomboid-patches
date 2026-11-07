local T=LuckyTest
T.start()
T.case("all argument positions and multiple returns are preserved",function()
 local values={T.item("Food"),T.item("DrainableComboItem")};local selection={T.group(values)};local origin={};local extra={}
 local a,b,c,d,e=ISInventoryPaneContextMenu.createMenu(3,false,selection,17,29,origin,extra)
 T.eq(a,T.spyMarker);T.eq(b,nil);T.eq(c,"third");T.eq(d,false);T.eq(e,5)
 T.eq(T.spyCalls,1);T.eq(T.spyArgs[1],3);T.eq(T.spyArgs[2],false);T.eq(#T.spyArgs[3],2)
 T.eq(T.spyArgs[3][1],values[1]);T.eq(T.spyArgs[3][2],values[2]);T.eq(T.spyArgs[4],17);T.eq(T.spyArgs[5],29);T.eq(T.spyArgs[6],origin);T.eq(T.spyArgs[7],extra)
end)
return "cases="..T.cases.."; assertions="..T.assertions.."; tests="..table.concat(T.names," | ")
