local V=PerfTest
V.emit("OnGameBoot")
V.emit("OnGameStart")
local M=CodexInventoryTransferPerformance
local left=V.pane(V.player.inventory,true)
local p=V.pane(V.container(3000),false)
V.transfer(p)
p.parent:refreshBackpacks()
V.eq(V.pinyinCalls,1,"Pinyin assigned OnGameStart wrapper preserved")
V.change(p)
p:renderdetails(false)
V.eq(V.neatCalls,1,"Neat OnGameBoot renderer wrapper preserved")
V.eq(V.pinyinCalls,1,"performance gate remains after Pinyin install")
V.check(M.stats.paneDeferred>0,"batch deferral active in wrapped chain")
V.noAction()
V.emit("OnPlayerUpdate",V.player)
V.eq(p.lastReadCount,p.inventory.count,"wrapped chain final exact view")
V.eq(V.pinyinCalls,2,"final flush uses wrapped original")
return "UI modeled lifecycle chain passed; assertions="..V.assertions
