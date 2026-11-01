# 第三方来源与重建 / Third-party sources and reconstruction

本仓库公开自制桥接、翻译、元数据和带上下文的修改差异，完整运行输出只在用户本机隔离构建。没有给第三方内容另加MIT许可证。未找到许可文件不等于原作者同意公开整包；这里不宣称已取得该授权。

This repository contains local bridges, translations, metadata and contextual changes. Complete runtime output is reconstructed only in a local isolated directory. It does not grant MIT or other new licenses over third-party content. An absent license file is not author permission to republish a complete mod; no such permission is claimed here.

| 来源 / Source | 处理 / Treatment |
| --- | --- |
| Workshop 3799632784, C.B.R.T. Chemical | 26 FBX/PNG files byte-match the installed original and are absent from Git. Source-clothing/item/registry overlays use copy/diff recipes. Renamed destinations are recorded in rebuild-manifest.json. Neither the local build nor audited upstream directory contained a LICENSE/COPYING/NOTICE file. |
| Workshop 3670064951, KI5campers 42.20 | Six complete vehicle definitions stay external; only six context diffs and source/output hashes are tracked. |
| Workshop 3619229745, SuPrimitiveEquipment | Full PE_Shield.lua stays external; an exact-source context diff reconstructs the fluid-tooltip overlay. |
| Game media/lua/client/pzopt/pzopt_mainscreen_menu.lua | External PZ Optimization d1bbdcf menu source is pinned by SHA. Only the translation/layout diff and own translation dictionary are tracked. Its upstream redistribution license has not been established by this task. |
| Workshop 3791221767, AdrenalineShot; 3815980431, TarkovCombatStims | Five runtime fallback/reference files are rebuilt from installed upstream sources; four are exact copies and one needs only byte-format restoration. No original reference payload is stored in Git. |

查看[精确输入路径与SHA](../upstream-sources.json)和[逐输出重建清单](../rebuild-manifest.json)。如果上游自动更新了这些字节，重建器拒绝输出；应重新审阅差异，不能用静默回退或关闭校验冒充兼容。

See [pinned input paths and hashes](../upstream-sources.json) and the [per-output manifest](../rebuild-manifest.json). Changed upstream bytes fail closed. Re-audit rather than bypassing hashes or silently claiming compatibility.

拼音补丁中的backup、旧mod.info、default.txt、current-save-mods.txt和.bak已排除。各模块原始个人README也未逐字复制，使用说明在docs/patches中重新整理。没有复制全局启用名单、存档、配置、订阅状态或Steam凭据。

Pinyin backups, old mod.info, default.txt, current-save-mods.txt and .bak files are excluded. Personal historical README files are replaced by the current per-patch documentation. Global enabled lists, saves, configuration, subscription state and Steam credentials are not copied.
