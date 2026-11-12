# 蘇清的猫又岭与EX兼容桥接补丁 / SuQing’s Nekomata Ridge and EX Compatibility Patch

[返回总目录 / Back to index](../../README.md) · [English overview](../../README.en.md)

| 项目 / Field | 当前值 / Current value |
| --- | --- |
| Mod ID | `CodexNekomataEXCompat_4221` |
| 文件夹 / Folder | `CodexNekomataEXCompat_4221` |
| 版本 / Version | `1.0.1` |
| 适用 / Target | Build 42.21–42.22 单人 / single-player. Tested offline on 42.22.2. |
| 元数据硬依赖 / Declared prerequisites | `Nekomata Ridge`, `ExSuQingBackpackSuperUpgrade_4221` |
| 原样require / Literal require | `\Nekomata Ridge,ExSuQingBackpackSuperUpgrade_4221` |
| 加载在其后 / Load after | `Nekomata Ridge`, `ExSuQingBackpackSuperUpgrade_4221` |

## 中文说明

保留猫又背包逻辑，为其他容器透传hasRoomFor参数，并仅对已知MaoMao包装链恢复EX就绪判定；未知包装仍拒绝。

只按需要安装本子补丁，不能把本仓库30项当作所有主模组的共同前置。`loadModAfter`是加载顺序声明，不等于要求安装列出的全部模组。`require`原字节保留，包括历史前缀语法；本仓库不擅自迁移Mod ID或改变依赖。

本补丁运行文件共2份。仓库直接收录2份自制桥接/翻译/元数据，另从本机上游原件复制重建0份、应用上下文差异重建0份。完整路径、输入与输出SHA-256见[重建清单](../../rebuild-manifest.json)。第三方完整美术、原始覆盖文件和针剂reference原件不直接入Git。

使用`tools/rebuild.py --mod-id "CodexNekomataEXCompat_4221" --check`配合所需来源根参数，先验证来源；再使用全新的隔离`--output`目录。缺失文件、上游更新或SHA不符会拒绝输出，不能靠重命名新版本绕过。工具不下载、不订阅、不部署、不编辑当前启用列表。原始个人README/backup/.bak不作为运行源码发布，内容已在本页重新整理。

## English notes

Preserves Nekomata backpack logic, passes hasRoomFor arguments for other containers and restores EX readiness only for the audited MaoMao wrapper chain; unknown wrappers remain rejected.

Install this optional subpatch only for the relevant use case. All 30 are not a universal prerequisite. `loadModAfter` declares ordering, not a requirement to install every named mod. Literal `require` bytes, including historical prefix syntax, remain unchanged. No IDs or dependencies are migrated.

There are 2 runtime files: 2 tracked bridge/translation/metadata files, 0 local upstream copies and 0 context-diff reconstructions. The [manifest](../../rebuild-manifest.json) records every input/output SHA-256 and path. Full third-party artwork, overlay originals and stimulant reference originals are not stored in Git.

Run `tools/rebuild.py --mod-id "CodexNekomataEXCompat_4221" --check` with the required source-root arguments, then use a new isolated `--output` directory. Missing or updated sources fail their pinned hashes; do not substitute a renamed newer file. The tool performs no download, subscription, deployment or enabled-list edits. Old personal README/backup/.bak artifacts are not shipped as runtime source; current guidance is collected here.

## 验证边界 / Validation boundary

1.0.1 已在 42.22.2 原厂 Kahlua 核对猫又岭与 EX 1.0.0-rc.2 的调用链。新版桥接仅在已识别的作者包装上读取实际容量，供猫猫背包扩展取得 120 基线。未知包装仍拒绝。请与猫猫背包扩展 1.0.1 一起使用。

Version 1.0.1 checks the Nekomata Ridge and EX 1.0.0-rc.2 call chain on stock 42.22.2 Kahlua. It reads the authored base capacity for the backpack extension only through the recognized wrapper. Unknown wrappers remain blocked. Pair this bridge with backpack extension 1.0.1.

重建SHA一致仅证明还原了审计时的运行文件，不等于游戏内、所有组合、多人或存档持久化验收。原有调试、测试版或单人限制仍以该补丁为准。先在隔离单人档按本功能操作检查，勿把正式档当作自动测试环境。

Exact reconstruction proves byte identity to the audited local runtime files, not gameplay, all combinations, multiplayer or persistence. Existing test/single-player restrictions remain. Use an isolated single-player test save for acceptance; this repository never opens a personal save.

## 来源与权利 / Sources and rights

见[第三方来源说明](../THIRD_PARTY.md)。本仓库不对上游代码、模型、纹理或差异中的上游上下文另授MIT等许可。读取本机来源不等于获得再次分发原件的许可。

See [third-party notes](../THIRD_PARTY.md). No MIT or other blanket license is applied to upstream code, models, textures or upstream context in diffs. Access to a local source does not grant redistribution rights.

## EX依赖关系 / EX dependency relationship

基础背包EX本身不要求猫又岭。只有猫又场景才选兼容桥接；猫猫升级扩展还要求兼容桥接、猫又岭和基础EX。它们保留独立Mod ID，不合并成强制前置。
The base EX mod does not require Nekomata Ridge. Select the bridge only for that scenario. The Nekomata upgrade extension additionally needs the bridge, Nekomata Ridge and base EX. IDs stay separate and are not made universal dependencies.
