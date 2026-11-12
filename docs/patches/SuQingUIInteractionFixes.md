# 蘇清的提示框与融合物品栏修复

SuQing's Tooltip and Proximity Selection Fixes 1.0.1

## 中文

依赖 CleanUI 和 ProximityInventory，适用 B42.21 单人。修复鼠标跟随文字提示的坐标竞争，按实际可见行恢复融合物品栏所选物品与 Shift 起点，涵盖大堆叠展开、搜索和 Ctrl+A。选中保持只接受已审查的 CleanUI 2.10.3/2.10.4；未知版本拒绝安装此功能。不改物品、转移、伤害或存档结构。

无需单独设置。先满足原作依赖，再按需启用本补丁，保留原相对顺序。正常退出、停用、重启可撤销本补丁；没有新增需迁移的物品。离线原生Lua受控对象回归已记录30场景89断言，2.10.3/2.10.4接受及2.10.5拒绝检查通过；本轮导入后重跑结果另记，游戏内及FPS待用户验证。

验收：展开50件以上堆叠，Shift连选、Ctrl+A、搜索/清空后刷新及转移；检查鼠标提示，正常保存重进。与库存刷新补丁是不同职责，可按需同时使用。

## English

Requires CleanUI and ProximityInventory. B42.21 single-player. Fixes competing tooltip coordinates and restores visible-row selections and the Shift anchor during Proximity Inventory refreshes, including expanded stacks, searches and Ctrl+A. Selection preservation accepts only reviewed CleanUI 2.10.3/2.10.4 and rejects unknown versions. Items, transfer rules and save structures remain unchanged.

No separate settings are needed. Keep upstream dependencies and relative order. Exit normally, disable and restart to remove it; no custom items require migration. Recorded actual-Lua controlled-object tests cover 30 cases/89 assertions and version acceptance/rejection. Imported-source reruns are recorded separately. Gameplay and FPS remain for user acceptance.

Acceptance: expand a stack of over 50 items, Shift-select, Ctrl+A, search/clear, refresh and transfer; check tooltips and save/reload. Bulk Inventory Refresh is a separate optional fix.

## B42.22.2 单人适配候选 / Single-player candidate

1.0.2 在 CleanUI 2.10.4 的 42.22 分支按真实绘制行恢复堆叠选中、可见子行与 Shift 锚点，旧分支沿用旧选择语义。新版原生对转移对象去重。

Version 1.0.2 restores selected stacks, visible children and Shift anchors from the rendered rows of CleanUI 2.10.4 for 42.22. Earlier branches retain their selection rules. CleanUI de-duplicates selected transfer items.

游戏内界面与鼠标操作待用户验收。

In-game UI and mouse input await user validation.

## 1.0.3 · CleanUI 2.10.5

在 42.19 和 42.22 分支恢复附近容器融合列表的选区和 Shift 起点。启用 Snake Utils 时保留 CleanUI 自己的渲染器。B42.21.0 和 B42.22.2 各通过 89 条离线断言，待游戏内验收。

Restores selection and Shift anchors in the Proximity Inventory list for CleanUI 2.10.5 branches 42.19 and 42.22. When Snake Utils is active, CleanUI retains control of its renderer. B42.21.0 and B42.22.2 each passed 89 offline assertions. In-game testing is pending.
