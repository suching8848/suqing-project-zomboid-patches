# 蘇清的提示框与融合物品栏修复

SuQing's Tooltip and Proximity Selection Fixes 1.0.3

## 中文

依赖 CleanUI 和 ProximityInventory，适用 B42.21.0 和 B42.22.2 单人。修复鼠标跟随文字提示的坐标竞争，按实际可见行恢复融合物品栏所选物品与 Shift 起点，涵盖大堆叠展开、搜索和 Ctrl+A。选中保持只接受已审查的 CleanUI 2.10.3/2.10.4/2.10.5。2.10.5 限 42.19 和 42.22 分支。启用 Snake Utils 时保留原渲染器。不改物品、转移、伤害或存档结构。

无需单独设置。先满足原作依赖，再按需启用本补丁，保留原相对顺序。正常退出、停用、重启可撤销本补丁；没有新增需迁移的物品。CleanUI 2.10.5 实装 Lua 在两个游戏版本各通过 89 条离线断言。游戏内表现和帧率待验证。

验收：展开50件以上堆叠，Shift连选、Ctrl+A、搜索/清空后刷新及转移；检查鼠标提示，正常保存重进。与库存刷新补丁是不同职责，可按需同时使用。

## English

Requires CleanUI and ProximityInventory. B42.21.0 and B42.22.2 single-player. Fixes competing tooltip coordinates and restores visible-row selections and the Shift anchor during Proximity Inventory refreshes, including expanded stacks, searches and Ctrl+A. Selection preservation accepts only reviewed CleanUI 2.10.3/2.10.4/2.10.5. Version 2.10.5 uses the 42.19 and 42.22 branches and leaves the renderer alone when Snake Utils is enabled. Items, transfer rules and save structures remain unchanged.

No separate settings are needed. Keep upstream dependencies and relative order. Exit normally, disable and restart to remove it; no custom items require migration. The installed CleanUI 2.10.5 Lua passed 89 offline assertions on each game version. In-game behavior and FPS await user testing.

Acceptance: expand a stack of over 50 items, Shift-select, Ctrl+A, search/clear, refresh and transfer; check tooltips and save/reload. Bulk Inventory Refresh is a separate optional fix.
