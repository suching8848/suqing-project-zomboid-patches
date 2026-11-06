# 蘇清的造船就地取材补丁 / SuQing's Boat Crafting Nearby Materials Patch

Mod ID `SuQingBoatCraftFromFloor_4221` · version `0.1.0` · B42.21 single-player · requires `BoteBR`.

当前三条船配方只有 `AnySurfaceCraft`。原版与当前 Neat Crafting 会识别附近材料，但开工前仍把它们全部转入人物主背包，可能因容量不足失败。

本补丁通过原生 `CraftRecipe.getModTags()` 给这三条配方追加 `CanBeDoneFromFloor`，保留 `AnySurfaceCraft`。不改材料、技能、工具、工作面、时间、船重量和其他配方。先检查原作文件指纹、有效对象来源与接口，再统一修改；失败时撤回本次追加。已存在的同标签不重复添加。

原生与 Neat 直接读取 `isCanBeDoneFromFloor()`，因此正常制作流程无需重建全局标签索引。没有调用会重注册所有配方并输出日志的 `CraftRecipeManager.Init()`；按新增 floor 标签查询的索引不会主动刷新。这不属于通用标签编辑器或新增检索功能。

The three upstream boat recipes recognize nearby ingredients but force all inputs into character inventory before crafting. This patch adds only the native `CanBeDoneFromFloor` flag through the mutable tag-list API and retains `AnySurfaceCraft`. Ingredients, skills, tools, surface, time and output weights stay unchanged. Source fingerprint, effective recipe owner and APIs are checked before modification; failed modifications are rolled back and existing flags are not duplicated.

Vanilla and the installed Neat transfer functions read the getter directly. No global tag-manager reset is performed; queries specifically indexed by the newly added tag are not rebuilt. This is a targeted crafting-flow fix, not a general tag editor.

使用 / Usage: 重启游戏，在工作面旁把材料放进拾取窗口可见的地面或可访问容器；照常点原配方制作。留出成品空间，原作船重10/16/20。Restart, place ingredients in visible accessible containers/floor beside a work surface, use the original recipes, and retain space for the output boat (upstream weights 10/16/20).

离线验证 / Offline validation: 当前游戏 Kahlua **54 项断言通过**，实际原版与已安装 Neat 输入转移函数参与测试，外部对象模拟；覆盖修改前强制转移、修改后跳过转移、工作面保留、重复事件、上游改变/缺失、配方缺失、其他来源覆盖、部分失败回滚和多人拒绝。Lua编译、中英提示键检查通过。Native/Neat transfer functions are real, recipes/containers/actions mocked. No game or save writes by tests; in-game crafting remains pending.

```powershell
python tests/run_boat_craft_from_floor.py --audit-dir .validation/boat-craft-from-floor
python tools/rebuild.py --mod-id SuQingBoatCraftFromFloor_4221 --output ../boat-craft-from-floor-built
```

停用后重启恢复原取材流程，保留已制作船只，无存档迁移。不支持多人；未提交Git、推送或发布。Disable and restart to restore upstream input handling without deleting boats. No multiplayer support, Git commit/push or Workshop publication.
