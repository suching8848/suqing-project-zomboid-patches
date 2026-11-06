local V=PerfTest
local M=CodexInventoryTransferPerformance
V.emit("OnGameStart")
V.eq(M.installed==true,V.guardExpected,"runtime guard install decision")
V.eq(M.enabled,V.guardExpected,"runtime guard enabled decision")
if V.guardExpected then
    V.check(ISInventoryPane.refreshContainer~=V.beforeRefresh,"known compatible refresh wrapped")
else
    V.eq(ISInventoryPane.refreshContainer,V.beforeRefresh,"unsupported interface leaves refresh untouched")
    V.eq(ISInventoryPane.renderdetails,V.beforeRender,"unsupported interface leaves renderer untouched")
    V.eq(M.stats.failOpen,1,"fail-open diagnostic emitted")
end
return "guard case passed; assertions="..V.assertions
