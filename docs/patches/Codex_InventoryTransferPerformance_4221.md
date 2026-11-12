# 蘇清的批量转移库存刷新优化补丁 / SuQing’s Bulk Transfer Inventory Refresh Optimization Patch

[返回总目录 / Back to index](../../README.md) · [English overview](../../README.en.md)

| 项目 / Field | 当前值 / Current value |
| --- | --- |
| Mod ID | `Codex_InventoryTransferPerformance_4221` |
| 文件夹 / Folder | `InventoryTransferPerformance_4221_Local` |
| 版本 / Version | `1.2.2` |
| 适用 / Target | Project Zomboid Build 42.21; single-player scope |
| 元数据硬依赖 / Declared prerequisites | `CleanUI` |
| 原样require / Literal require | `CleanUI` |
| 加载在其后 / Load after | `CleanUI`, `NeatUI_Equipment`, `Codex_AttachedGrouping_4221`, `PinyinSearch_SafeSources_4221_LocalFix`, `Codex_PetGunWeightKits_4221`, `ProximityInventory` |

## 中文说明

合并静止单人批量转移时的自动库存刷新，保留原生转移动作、交互、画面和提示；不能从离线重建推断FPS收益。

1.2.2适配已审阅的CleanUI 2.10.4，保留2.9.9、2.10.1、2.10.2、2.10.3支持与未知版本拒绝。2.10.4物品面板与2.10.3字节一致，搜索容器和优先屏障保护已用真实上游源码验证。当前离线回归通过153场景、854断言，覆盖新版底部标题栏折叠展开。游戏界面、实际批量转移及FPS待用户验收。

只按需要安装本子补丁，不能把本仓库的全部子项当作所有主模组的共同前置。`loadModAfter`是加载顺序声明，不等于要求安装列出的全部模组。`require`原字节保留，包括历史前缀语法；本仓库不擅自迁移Mod ID或改变依赖。

本补丁运行文件共2份。仓库直接收录2份自制桥接/翻译/元数据，另从本机上游原件复制重建0份、应用上下文差异重建0份。完整路径、输入与输出SHA-256见[重建清单](../../rebuild-manifest.json)。第三方完整美术、原始覆盖文件和针剂reference原件不直接入Git。

使用`tools/rebuild.py --mod-id "Codex_InventoryTransferPerformance_4221" --check`配合所需来源根参数，先验证来源；再使用全新的隔离`--output`目录。缺失文件、上游更新或SHA不符会拒绝输出，不能靠重命名新版本绕过。工具不下载、不订阅、不部署、不编辑当前启用列表。原始个人README/backup/.bak不作为运行源码发布，内容已在本页重新整理。

## English notes

Coalesces automatic inventory rebuilds during stationary single-player bulk transfers while retaining native transfers, interaction, rendering and tooltips. Reconstruction checks are not evidence of an FPS gain.

Version 1.2.2 supports reviewed CleanUI 2.10.4 while retaining 2.9.9/2.10.1/2.10.2/2.10.3 support and unknown-version rejection. The 2.10.4 inventory pane is byte-identical to 2.10.3. Actual-upstream-source regressions passed 153 cases and 854 assertions, including search-container reconciliation, priority barriers and Bottom collapse/expand geometry. In-game UI, real bulk transfers and measured FPS await user acceptance.

Install this optional subpatch only for the relevant use case. The whole collection is not a universal prerequisite. `loadModAfter` declares ordering, not a requirement to install every named mod. Literal `require` bytes, including historical prefix syntax, remain unchanged. No IDs or dependencies are migrated.

There are 2 runtime files: 2 tracked bridge/translation/metadata files, 0 local upstream copies and 0 context-diff reconstructions. The [manifest](../../rebuild-manifest.json) records every input/output SHA-256 and path. Full third-party artwork, overlay originals and stimulant reference originals are not stored in Git.

Run `tools/rebuild.py --mod-id "Codex_InventoryTransferPerformance_4221" --check` with the required source-root arguments, then use a new isolated `--output` directory. Missing or updated sources fail their pinned hashes; do not substitute a renamed newer file. The tool performs no download, subscription, deployment or enabled-list edits. Old personal README/backup/.bak artifacts are not shipped as runtime source; current guidance is collected here.

## 验证边界 / Validation boundary

重建SHA一致仅证明还原了审计时的运行文件，不等于游戏内、所有组合、多人或存档持久化验收。原有调试、测试版或单人限制仍以该补丁为准。先在隔离单人档按本功能操作检查，勿把正式档当作自动测试环境。

Exact reconstruction proves byte identity to the audited local runtime files, not gameplay, all combinations, multiplayer or persistence. Existing test/single-player restrictions remain. Use an isolated single-player test save for acceptance; this repository never opens a personal save.

## 来源与权利 / Sources and rights

见[第三方来源说明](../THIRD_PARTY.md)。本仓库不对上游代码、模型、纹理或差异中的上游上下文另授MIT等许可。读取本机来源不等于获得再次分发原件的许可。

See [third-party notes](../THIRD_PARTY.md). No MIT or other blanket license is applied to upstream code, models, textures or upstream context in diffs. Access to a local source does not grant redistribution rights.

## B42.22.2 单人适配候选 / Single-player candidate

1.2.3 在 CleanUI 2.10.4 的 42.22 分支恢复可见堆叠子行与明确选中的展示物品。旧分支沿用旧选择语义。补丁仅处理界面刷新，转移仍由原版处理，包含 42.22 的递归容器检查。

Version 1.2.3 restores visible selected stack children and explicitly selected display items in the CleanUI 2.10.4 branch for 42.22. Earlier branches retain their selection rules. The patch handles UI refreshes. Native transfers retain the 42.22 recursive-container check.

游戏内界面与鼠标操作待用户验收。

In-game UI and mouse input await user validation.

## 1.2.4 · CleanUI 2.10.5

在已审查的 42.19 和 42.22 分支恢复批量转移刷新合并与搜索优先级同步。42.22 同时保留展开堆叠的可见子行选区。启用 Snake Utils 时保留 CleanUI 自己的渲染器。B42.21.0 和 B42.22.2 各通过 180 场景、945 条离线断言，游戏内转移与帧率待验收。

Restores bulk-transfer refresh coalescing and search-priority synchronization for CleanUI 2.10.5 branches 42.19 and 42.22. The 42.22 branch also preserves visible child-row selection in expanded stacks. When Snake Utils is active, CleanUI retains control of its renderer. The B42.21.0 and B42.22.2 offline suites each passed 180 cases and 945 assertions. In-game transfers and frame rates await testing.
