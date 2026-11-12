# 蘇清的酿酒技能书50倍补丁 / SuQing’s Brewing Skill Books 50x Patch

[返回总目录 / Back to index](../../README.md) · [English overview](../../README.en.md)

| 项目 / Field | 当前值 / Current value |
| --- | --- |
| Mod ID / Folder | `Codex_ChinaBrewingBooks50_4221` |
| 版本 / Version | `0.1.1` |
| 游戏 / Game | Project Zomboid 42.21.0 and 42.22.2 offline candidate; single-player only |
| 声明前置 / Declared prerequisite | `Chinesecuisine4213` |
| 加载在其后 / Load after | `Chinesecuisine4213` |
| 登记状态 / Registration | 2026-11-04 本地源码新增；尚未提交、推送或发布 / Local source addition; not committed, pushed or published |

## 中文说明

只将中国菜 `ChinaBrewing` 的五卷酿酒技能书满读书籍倍率设为 **50**，不是把原倍率再乘50，也不是保证所有来源的最终经验都是50倍。沙盒经验设置和人物原生系数继续生效，其他技能书不变。

部分阅读保留原版每10%进度一档：10%为5，50%为25，100%为50，不足10%不增加书倍率。载入时根据当前可训练卷和角色实际已读页数同步，因此已读完当前适用卷的角色不必重复阅读；未读卷、过期卷、书套装及单凭现有倍率都不会被当作读满。

补丁不直接奖励经验、不改技能等级、已读页数或沙盒，也不改工坊原件。它只调整酿酒书运行时定义及本角色的酿酒书籍倍率，并用独立 ModData 记录本补丁的来源。原作的技能、五卷元数据或原倍率不匹配时拒绝配置；无法识别的存档记录保留。高于原书上限且无法归属本补丁的外部倍率不会在载入同步时被强行覆盖。

## v0.1.1 修正 / Fix

v0.1.0 把 `Script.Item.getMaxLevelTrained()` 与物品实例 `Literature.getMaxLevelTrained()` 当成了同一契约。前者是排他上限 `low + count`，后者是包含上限 `low + count - 1`；因此正常的初级书会被旧校验拒绝，50倍未生效。v0.1.1 分别校验数量、排他上限及包含上限，保留所有元数据保护，并在失败时打印字段类型、期望值和实际值。没有放宽或关闭校验。

新回归由当前有效 `Script.Item` 与原游戏 `Literature` getter 字节码及原作五卷脚本生成契约输入；先用同一输入重现0.1.0失败，再验证0.1.1通过。原先19情景/770断言的结果使用了错误上限桩，不能作为旧版已生效的证据。读取倍率、恢复流程和其余行为未因此改变。

Version0.1.1 corrects the distinction between Script.Item’s exclusive upper bound and Literature’s inclusive upper bound. It retains strict metadata checks and adds typed actual/expected diagnostics. The corrected fixtures derive getter contracts from the current effective class bytecode and original book scripts, reproduce the0.1.0 rejection first, then pass with0.1.1. The old19-scenario/770-assertion result used the wrong upper-bound stub and did not establish that0.1.0 worked in-game.

## 停用与恢复

**倍率会保存进角色，直接删除或禁用补丁不会自动清理50。** 保持本补丁启用，在单人游戏的 Lua 上下文中调用：

```lua
CodexChinaBrewingBooks50.RestoreOriginal(getSpecificPlayer(0))
```

确认返回 `true`，再正常保存、退出并禁用。恢复按当前真实阅读进度和原版五档上限 `3/5/8/12/16` 计算，不回退已获得的经验和等级。检测到相关外部改动时返回 `false` 并保留外部值，应先核查；不要强行清除记录。恢复状态会记入 ModData，防止尚未禁用时重新升为50，也会修正已排队阅读动作的倍率。

以后重新使用可以在本补丁启用时调用 `CodexChinaBrewingBooks50.Enable(getSpecificPlayer(0))`。若已经直接禁用，先重新启用并按上述流程恢复；不要覆盖旧 `players.db` 来回退倍率和人物进度。

## English notes

Only the five Chinese Cuisine `ChinaBrewing` books have a fully-read book maximum of **50**. This is not another multiplication by50, nor a promise that final XP from every source is50x. Native 10-percent reading steps, sandbox modifiers and character factors remain; unrelated skills and books are unchanged.

The currently trainable volume is synchronized from actual saved read pages. The patch does not award XP, change levels, mark books read, edit sandbox settings or modify Workshop originals. It validates the expected original book metadata and caps, and records ownership in a separate ModData key. It fails closed on unexpected definitions or saved schemas and preserves unrelated high custom multipliers during load synchronization.

Before disabling, call `RestoreOriginal` while the patch is enabled, confirm `true`, save and quit. It restores the original `3/5/8/12/16` caps at the character’s actual reading progress without undoing earned XP or levels. A detected external change is preserved and reports failure. Removing the mod cannot execute cleanup of a saved multiplier; re-enable it to perform recovery. Do not restore an old player database over newer progress.

## B42.22.2 离线适配 / Offline compatibility

2026-11-09 在两版原版 Kahlua 中分别使用各自的阅读动作及本机中国菜技能定义，22 情景、955 条断言各通过。两版另各通过 46 条原生断言，由实际五卷脚本和原版 Item、Literature 核对排他上限及包含上限。保留 0.1.1 运行版本和原有存档 schema，仅扩展适用分支，游戏内待验。

Each stock runtime passed 22 scenarios and 955 assertions using its native reading action and the locally installed Chinese Cuisine skill definition. Each native parser and item implementation passed 46 additional assertions on the five actual book scripts, including the exclusive script and inclusive inventory bounds. The 0.1.1 runtime and save schema are retained. In-game acceptance remains pending.

## 源码与重建 / Source and rebuild

可重建包共 **4 个自制文件**：`42/mod.info`、客户端入口、共用核心及 `README.txt`，全部采用 `own` 模式，位于 [`src/Codex_ChinaBrewingBooks50_4221`](../../src/Codex_ChinaBrewingBooks50_4221)。不包含中国菜的原始书籍脚本或完整原版阅读动作文件。

```powershell
python tools/rebuild.py --mod-id Codex_ChinaBrewingBooks50_4221 --output ../brewing-books-50-built
```

输出目录必须尚不存在；工具只在隔离目录重建并逐文件校验SHA-256，不下载、订阅、部署或编辑启用名单。

All four listed files are owned source and rebuild byte-for-byte from the manifest. No upstream full book script or `ISReadABook.lua` is distributed. The isolated rebuild does not install or activate the mod.

## 验证边界 / Validation boundary

2026-11-04 在原游戏 Kahlua 中加载真实 `ISReadABook.lua` 与本补丁核心、入口，**23 情景 / 808 断言通过**。覆盖全部阅读进度阶梯、五卷满读和半读、实际260/260页角色输入、重复载入不追加经验、原生阅读及完成动作、无关技能、等级转换、来源记录、外部倍率、恢复和排队完成回退、存档恢复标记、单人门禁及重复安装。

原生接口为隔离桩，实际构造、阅读进度、倍率检查和完成的 Lua 路径执行；没有启动游戏、打开正式档或修改实际人物数据库。首次实际载入后仍应检查酿酒书倍率、实际酿造经验，并保存重进确认。离线通过不等于游戏内验收。

The real native Lua read-action code and staged patch passed23 scenarios and808 assertions with isolated native-boundary stubs. This is behavioral offline verification, not in-game XP or persistence acceptance. Check the displayed book multiplier, actual brewing XP and a save/reload after normal deployment.

本地源码登记不等于 Git 提交、远端同步或创意工坊发布；原有33项发布快照未因此改为35项已发布。

Local registration is distinct from commit, remote synchronization or Workshop publication. The previous33-entry release snapshot is not relabeled as35 published entries.
