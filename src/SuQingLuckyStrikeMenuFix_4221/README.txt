蘇清的好彩香烟菜单修复 / SuQing's Lucky Strike Menu Fix
Mod ID: SuQingLuckyStrikeMenuFix_4221
Version: 0.1.1-rc.2

中文
适用：Project Zomboid B42.21.0 或 B42.22.2 单人，分别使用 CleanUI 2.10.4/2.10.5 的 42.19 或 42.22 分支。
必需：CleanUI、More MRE and World Cuisine（MREfood4213）。栀子汉化为可选来源，不强制安装。

修复：当前栀子汉化 42.0 分支将 MR.lucky_strike 和 MR.lucky_strike_Pack 都译为“好彩香烟”。
本补丁将盒装明确命名为“好彩香烟（盒装）”，单根仍为“好彩香烟”。英文物品名沿用上游。
单根是 Food，盒装是 DrainableComboItem。CleanUI 按名称合组，菜单只检查组首的食物类型，
随后访问全部成员的 getHungChange，混组可能在 ISInventoryPaneContextMenu.lua:763 报错。

局部保护：仅当含好彩物品的组首为 Food、实际成员含非 Food 时，使用 CleanUI 原有
getActualItems 将本次选择展开并去重，再调用一次原菜单。原列表、物品、存档不改写。
经本补丁归一化后仍混有两种类型的选择不提供统一吸烟入口；请分别选择单根或盒装。
通用转移仍保留全部真实成员。盒装组首等未触发保护的路径保留原菜单行为。
普通单根、盒装与无关物品沿用原路径；不吞掉下游错误，不替换吸烟效果、动作或配方。

安装：正常退出游戏，把整个目录放入 Zomboid/mods，满足前置后按需启用。
加载在 MRE、CleanUI、栀子汉化及已有 UI 补丁之后，保留其他模组的相对顺序。
Lua 保护仅接受审查过的版本、分支、原函数来源和起始行；未知组合跳过保护并写日志，
中文名称修复仍可生效。没有 Java 补丁，没有新增物品，无需迁移或转换旧物品。

验证：离线回归记录见源码仓库 tests/lucky_strike_menu_fix；游戏内操作、吸烟、保存重进待用户验收。
验收：确认盒装名称有“（盒装）”；选择十根单根右键；单独选择盒装右键；
展开堆叠多选及在附近物品栏重复操作，检查菜单、转移与吸烟，保存后重进再检查。
回退：正常退出、停用本补丁并重启。原物品和世界进度不回退；旧汉化同名问题可能恢复。
交付状态：已完成离线回归，游戏内操作待用户验收。

English
Target: Project Zomboid B42.21.0 or B42.22.2 single-player, with CleanUI 2.10.4/2.10.5 branches 42.19 or 42.22 respectively.
Requires CleanUI and More MRE and World Cuisine (MREfood4213).
GardeniaTranslate_CN is optional; it must precede this patch when present.

Separates the Chinese names of MR.lucky_strike (single) and MR.lucky_strike_Pack (pack).
English item names remain upstream. The single is Food; the pack is drainable.
CleanUI groups by display name and checks only the group header before calling Food methods
on every actual member, which can fail at getHungChange in a mixed stack.

Only a Lucky Strike stack with a Food header and non-Food actual members is normalized.
The existing CleanUI getActualItems helper flattens and deduplicates that menu's complete
selection before the original menu is called once. No original selection or item is mutated.
A normalized selection that still mixes both types has no shared smoking command;
select singles or packs separately. Pack-header groups keep their original menu behavior.
Common transfers retain all actual members. Ordinary selections keep their original path.
Smoking effects, actions, recipes and saves are unchanged; downstream errors remain visible.

Exit the game before installation. Enable after dependencies and existing UI patches while
preserving their relative order. The Lua guard accepts only the reviewed version, branch,
closure owners and first lines. Unknown combinations keep the CN name fix but skip the guard
with a log message. No Java component, new item or save migration is involved.

Offline tests are recorded in tests/lucky_strike_menu_fix. Gameplay acceptance is pending.
Check distinct pack names, right-click ten singles, right-click packs separately, expand and
multi-select stacks, test Proximity Inventory, smoking and transfers, then save and reload.
Disable after exiting normally and restart to revert; world progress and items are retained.
Offline regression passed. In-game acceptance is pending.
