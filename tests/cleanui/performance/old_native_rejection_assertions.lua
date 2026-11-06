local V,M=PerfTest,CodexInventoryTransferPerformance
V.emit("OnGameBoot");V.emit("OnGameStart")
V.eq(M.installed==true,false,"old patch refuses current actual CleanUI 2.10.3")
V.eq(M.enabled,false,"old patch disables optimization")
V.eq(M.stats.failOpen,1,"old patch emits fail-open diagnostic")
V.eq(ISInventoryPage.refreshBackpacks,V.beforePageRefresh,"old patch leaves Page refresh untouched")
-- Pinyin and Neat legitimately wrap pane methods during their own startup events;
-- compare native behavior instead of mistaking those wrapper identities for patch effects.
local p=V.nativePane({V.item("Wood")})
V.deferNative(p,V.item("Copper"))
V.eq(#p.items,2,"native renderer still rebuilds immediately after refusal")
V.eq(M.stats.paneDeferred,0,"old rejected patch never coalesces pane refresh")
V.eq(M.stats.pageDeferred,0,"old rejected patch never coalesces page refresh")
return "old native rejection passed; cases=1; assertions="..V.assertions
