-- Disable unrelated menu builders, retaining the complete actual createMenu
-- function, actual classification loop, Food branch and getActualItems.
local T=LuckyTest
T.originalMenu=ISInventoryPaneContextMenu.createMenu
T.originalActual=ISInventoryPane.getActualItems
T.metadata={}
T.metadata[T.originalMenu]={source=T.cleanDir.."/media/lua/client/ISUI/ISInventoryPaneContextMenu.lua",line=327}
T.metadata[T.originalActual]={source=T.cleanDir.."/media/lua/client/ISUI/ISInventoryPane.lua",line=4014}
local noop=function()end
for _,name in ipairs({"removeToolTip","doDebugContextMenu","checkConsolidate","doEquipOption","doGrabMenu","doDrinkFluidMenu","doPrintMediaMenu","doLiteratureMenu","doWearClothingMenu","doClothingItemExtraMenu","doDismantleOption","doBuildMenu","doWeaponEditMenu","doMagazineMenu","doContextConfigOptions"})do ISInventoryPaneContextMenu[name]=noop end
function ISInventoryPaneContextMenu.getContainers()return T.list()end
function ISInventoryPaneContextMenu.canReplaceStoreWater()return false end
function ISInventoryPaneContextMenu.isAllFav()return false end
function ISInventoryPaneContextMenu.canUnpack()return nil end
function ISInventoryPaneContextMenu.canMoveTo()return nil end
function ISInventoryPaneContextMenu.doEatOption(context,cmd,items,player,playerObj,foods)
 T.foodMenuItems=foods
 context:addOption(cmd,items)
end
function ISInventoryPaneContextMenu.doPillsMenu(context,items,player,cmd)
 T.pillsMenuItems=ISInventoryPane.getActualItems(items)
 context:addOption(cmd,items)
end
function ISInventoryPaneContextMenu.doMoreContextMenu(context,tests,moveItems,playerObj,items,c)
 T.lastItems=items;T.lastActual=moveItems;T.lastTests=tests;T.lastC=c
end
function T.reset()
 T.foodMenuItems=nil;T.pillsMenuItems=nil;T.hungerCalls=0;T.lastItems=nil;T.lastActual=nil;T.lastTests=nil;T.lastC=nil;T.contextCreated=0
end
function T.call(items,...)
 T.reset()
 return ISInventoryPaneContextMenu.createMenu(0,true,items,17,29,"offline-origin",...)
end
