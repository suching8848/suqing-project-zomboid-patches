# 蘇清的Fashionoid储液提示兼容补丁 / SuQing’s Fashionoid Fluid Tooltip Compatibility Patch

[返回总目录 / Back to index](../../README.md) · [English overview](../../README.en.md)

| 项目 / Field | 当前值 / Current value |
| --- | --- |
| Mod ID | `Codex_FashionoidFluidTooltip_4221` |
| 文件夹 / Folder | `Codex_FashionoidFluidTooltip_4221` |
| 版本 / Version | `1.0.0` |
| 适用 / Target | Project Zomboid Build 42.21; single-player scope |
| 元数据硬依赖 / Declared prerequisites | `Fashionoid42` |
| 原样require / Literal require | `Fashionoid42` |
| 加载在其后 / Load after | `Fashionoid42` |

## 中文说明

让Fashionoid跳过缺少物品类型方法的非物品储液提示对象，其余判定仍交给Fashionoid。

只按需要安装本子补丁，不能把本仓库30项当作所有主模组的共同前置。`loadModAfter`是加载顺序声明，不等于要求安装列出的全部模组。`require`原字节保留，包括历史前缀语法；本仓库不擅自迁移Mod ID或改变依赖。

本补丁运行文件共2份。仓库直接收录2份自制桥接/翻译/元数据，另从本机上游原件复制重建0份、应用上下文差异重建0份。完整路径、输入与输出SHA-256见[重建清单](../../rebuild-manifest.json)。第三方完整美术、原始覆盖文件和针剂reference原件不直接入Git。

使用`tools/rebuild.py --mod-id "Codex_FashionoidFluidTooltip_4221" --check`配合所需来源根参数，先验证来源；再使用全新的隔离`--output`目录。缺失文件、上游更新或SHA不符会拒绝输出，不能靠重命名新版本绕过。工具不下载、不订阅、不部署、不编辑当前启用列表。原始个人README/backup/.bak不作为运行源码发布，内容已在本页重新整理。

## English notes

Lets Fashionoid skip non-item fluid tooltip objects without the item-type method. Normal eligibility is still delegated to Fashionoid.

Install this optional subpatch only for the relevant use case. All 30 are not a universal prerequisite. `loadModAfter` declares ordering, not a requirement to install every named mod. Literal `require` bytes, including historical prefix syntax, remain unchanged. No IDs or dependencies are migrated.

There are 2 runtime files: 2 tracked bridge/translation/metadata files, 0 local upstream copies and 0 context-diff reconstructions. The [manifest](../../rebuild-manifest.json) records every input/output SHA-256 and path. Full third-party artwork, overlay originals and stimulant reference originals are not stored in Git.

Run `tools/rebuild.py --mod-id "Codex_FashionoidFluidTooltip_4221" --check` with the required source-root arguments, then use a new isolated `--output` directory. Missing or updated sources fail their pinned hashes; do not substitute a renamed newer file. The tool performs no download, subscription, deployment or enabled-list edits. Old personal README/backup/.bak artifacts are not shipped as runtime source; current guidance is collected here.

## 验证边界 / Validation boundary

重建SHA一致仅证明还原了审计时的运行文件，不等于游戏内、所有组合、多人或存档持久化验收。原有调试、测试版或单人限制仍以该补丁为准。先在隔离单人档按本功能操作检查，勿把正式档当作自动测试环境。

Exact reconstruction proves byte identity to the audited local runtime files, not gameplay, all combinations, multiplayer or persistence. Existing test/single-player restrictions remain. Use an isolated single-player test save for acceptance; this repository never opens a personal save.

## 来源与权利 / Sources and rights

见[第三方来源说明](../THIRD_PARTY.md)。本仓库不对上游代码、模型、纹理或差异中的上游上下文另授MIT等许可。读取本机来源不等于获得再次分发原件的许可。

See [third-party notes](../THIRD_PARTY.md). No MIT or other blanket license is applied to upstream code, models, textures or upstream context in diffs. Access to a local source does not grant redistribution rights.
