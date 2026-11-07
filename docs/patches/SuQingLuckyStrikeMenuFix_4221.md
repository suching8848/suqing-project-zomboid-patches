# 蘇清的好彩香烟菜单修复 / SuQing's Lucky Strike Menu Fix

Mod ID `SuQingLuckyStrikeMenuFix_4221` · version `0.1.0` · Project Zomboid B42.21 single-player · CleanUI `2.10.4`.

## 中文

修复 MRE 的单根好彩香烟与盒装香烟因汉化同名而合组后，右键菜单调用食物接口失败的问题。`MR.lucky_strike` 是食物类，`MR.lucky_strike_Pack` 是可消耗品类；当前栀子汉化的适用分支把两者都译作“好彩香烟”，CleanUI 又按显示名称分组。原菜单仅检查组头的食物类别，再遍历全部成员，因此遇到盒装成员时可能缺少 `getHungChange()`。

本补丁包含两项集中修改：

- 中文分别显示“好彩香烟”和“好彩香烟（盒装）”；保留上游英文物品名称。
- Lua 保护仅接受已审查来源的 CleanUI 2.10.4 菜单。当好彩组头是食物类、实际成员中存在非食物类时，使用现有 `getActualItems` 将本次完整选择展平并去重，再调用原菜单一次。正常同质组和无关选择保留原参数引用，不改物品、配方、转移规则或存档结构。

来源门禁使用游戏的 `getFilenameOfClosure` 与 `getFirstLineOfClosure`。已审查的 CleanUI 42.19 分支中，菜单的定义行为326、API读回首条指令行为327；`getActualItems` 的定义行4013、API读回首条指令行4014。未知版本、来源或首条指令行跳过Lua保护并记录日志，中文名称修复仍可生效。

经本补丁归一化后仍混有两种类型的选择不提供统一的“吸烟”入口；分别选择单根或盒装后按原流程使用。盒装组首等未触发保护的路径保留原菜单行为。转移等通用菜单保留本次选择的全部实际物品，不会借保护逻辑丢弃盒装成员。

必需前置：`CleanUI`、`MREfood4213`。`GardeniaTranslate_CN`、`SuQingUIInteractionFixes` 和 `Codex_InventoryTransferPerformance_4221` 是兼容加载顺序提示，不是额外必需前置。保留其他模组的原相对顺序，按需在这些项目后启用。本补丁独立于现有转移刷新及融合选择修复，可分别停用。

停用：正常退出游戏，停用本补丁后重启。没有新增物品或迁移数据；中文名称与菜单恢复由上游提供。不要将停用补丁当成需要回滚整个存档的操作。

验证状态：实际游戏 Kahlua 离线回归 **22场景／239断言全部通过**，未修改的当前 CleanUI 完整 Lua 文件参与执行，Java物品、玩家、容器、UI及闭包元数据使用受控对象。覆盖修复前报错、修复后菜单、十根单根、盒装、混组及重复选中、原参数／返回值、下游错误保留、重复加载和版本／来源／行号／元数据拒绝。原生吸烟动作、真实UI、保存重进及FPS未实测；本项已部署并启用，待用户游戏内验收。离线工具：[run_tests.py](../../tests/lucky_strike_menu_fix/run_tests.py)。

用户验收：重启后确认单根与盒装名称分开；分别对十根单根、盒装右键并执行原吸烟操作；检查两者混选时右键不报错、通用转移包含全部所选物品；再检查普通食物及其他物品菜单，正常保存重进。

## English

Fixes an inventory context-menu error when MRE's loose Lucky Strike cigarettes and packs share the same Chinese display name and CleanUI groups them together. `MR.lucky_strike` is a Food item, while `MR.lucky_strike_Pack` is drainable. The applicable Gardenia Chinese translation names both identically. The upstream menu checks the group header before calling Food methods on every expanded member, so a pack can lack `getHungChange()`.

This patch makes two targeted changes:

- Distinguishes loose cigarettes and packs in Chinese. Upstream English item names are retained.
- Installs the Lua guard only for the reviewed CleanUI 2.10.4 menu source. If a Lucky Strike group has a Food header but includes non-Food members, the existing `getActualItems` function flattens and deduplicates the entire selection before the original menu is called once. Homogeneous groups and unrelated selections keep their original argument reference. Item definitions, recipes, transfer rules and save structures are preserved.

The source gate uses the game APIs `getFilenameOfClosure` and `getFirstLineOfClosure`. In the reviewed CleanUI 42.19 branch, the menu definition is at line 326 and the API reports its first instruction at 327; `getActualItems` is defined at 4013 with its first instruction reported at 4014. Unknown versions, sources or first-instruction lines skip the Lua guard with a log message; the Chinese name fix can still apply.

A normalized selection that still mixes both types has no combined Smoke action. Select loose cigarettes or packs separately to use their original action. Pack-header groups and other paths that do not trigger the guard retain their original menu behavior. Generic actions such as transfer retain every selected actual item; the guard does not discard packs.

Requires `CleanUI` and `MREfood4213`. `GardeniaTranslate_CN`, `SuQingUIInteractionFixes` and `Codex_InventoryTransferPerformance_4221` are optional ordering hints rather than additional prerequisites. Keep other mods in their existing relative order. This independent patch does not replace the bulk-transfer or proximity-selection patches.

Removal: exit normally, disable this patch and restart. No custom items or data migration are introduced; upstream names and menu behavior return. No complete-save rollback is required to remove this patch.

Validation: **22 offline scenarios / 239 assertions passed** in the actual-game standalone Kahlua runtime with complete, unmodified installed CleanUI Lua files. Java items, players, containers, UI builders and closure metadata are controlled fixtures. Coverage includes the original failure, guarded menus, ten loose cigarettes, packs, mixed groups and duplicate selections, argument/return preservation, visible downstream errors, duplicate loading and version/source/line/metadata rejection. Native smoking actions, real UI, save/reload and FPS remain untested. Personal deployment and enablement are complete; user gameplay acceptance is pending. Offline runner: [run_tests.py](../../tests/lucky_strike_menu_fix/run_tests.py).

User acceptance: restart and check distinct loose/pack names; right-click ten loose cigarettes and packs separately and use the original Smoke actions; check mixed-selection menus and complete-item transfer; check ordinary food and unrelated item menus, then save and reload normally.

## 上游来源核验 / Audited upstream sources

2026-11-07本地Steam Workshop文件的SHA-256核验快照如下；路径相对于Workshop `content/108600`。这些指纹用于复核本轮审查来源，运行时版本与闭包来源门禁见上文。The following SHA-256 values identify the locally audited Workshop files on November 7. Paths are relative to Workshop `content/108600`; the runtime version/closure checks are described above.

| 来源 / Source | 相对路径 / Relative path | SHA-256 |
| --- | --- | --- |
| CleanUI 菜单 / menu | `3437629766/mods/CleanUI/42.19/media/lua/client/ISUI/ISInventoryPaneContextMenu.lua` | `1c04a2804b428a587d8c27614e7616b751e4b80cad2780b5ff5b34c85dc68143` |
| CleanUI 物品栏 / inventory pane | `3437629766/mods/CleanUI/42.19/media/lua/client/ISUI/ISInventoryPane.lua` | `b0de68c2766c29ef26d001a20ba42e8fe17176b77eeaed1c73035b0e8e7ac06e` |
| 栀子汉化 / Gardenia Chinese names | `3488835702/mods/Gardenia's translation _CN/42.0/media/lua/shared/Translate/CN/ItemName.json` | `ed67285d353a096a69be01fc2fc15bac030a6dcbdf676984b9cb775b3eb68126` |
| MoreMRE 物品脚本 / item definitions | `3488617262/mods/MoreMRE/42/media/scripts/items/items_shiwu.txt` | `90713a439da2c9c455793284a03cc194d607c4da8eb7cf938e6b8f801bc3e35d` |
