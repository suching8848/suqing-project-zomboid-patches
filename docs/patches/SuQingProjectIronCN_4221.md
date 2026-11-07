# 蘇清的 Project Iron 简体中文补丁 / SuQing's Project Iron Chinese Patch

[返回总目录 / Back to index](../../README.md) · [English overview](../../README.en.md)

| 项目 / Field | 当前值 / Current value |
| --- | --- |
| Mod ID | `SuQingProjectIronCN_4221` |
| 补丁版本 / Patch version | `1.0.0` |
| 适用 / Target | Project Zomboid Build 42.21 |
| 必需前置 / Required mod | Project Iron: One Last Rep 0.6.0, `SweatWorkz` |
| 加载在其后 / Load after | `SweatWorkz`, `B42ModTrans_CN`, `GardeniaTranslate_CN` |

## 中文说明

为 Project Iron 0.6.0 提供简体中文资源，覆盖 24 个沙盒选项、右键菜单、器械与训练动作、家具状态、补剂和流体、提示、状态图标及音效选项。补丁通过原生语言资源加载，游戏选择简体中文后使用。两项通用汉化只有在已启用时才参与加载排序。

所有 177 个上游英语资源键都有对应译文，另补齐上游 Lua 实际查询的 11 个右键菜单及提示键、4 个可移动家具状态名称和 16 个音效名称。补丁名和描述通过 `Translate/CN/Mod.json` 本地化。数据资源沿用原来的物品、家具和音效 ID，训练、经验、补剂计时和存档数据由 Project Iron 处理。

调试或管理员领取器械菜单的个别名称使用了通用文本查询，器械生成失败的角色发言由上游 Lua 写死，这些分支可能保留英文。离线检查覆盖 UTF-8、JSON、全部上游键和占位符，并将补齐的键与安装包中的实际调用对照。建议在简体中文的 B42.21 单人环境重启后，检查沙盒页、器械右键、补剂提示和状态图标的显示。

## English notes

This patch supplies Simplified Chinese resources for Project Iron 0.6.0. It covers the 24 sandbox settings, context menus, equipment and exercises, moveable states, supplements and fluids, tooltips, status icons, and sound options. Select Simplified Chinese in the game. The two general translation packs affect load order when enabled.

The patch translates all 177 upstream English resource keys and fills in 11 menu and tooltip keys called from upstream Lua, four moveable states, and 16 sound names. The native `Translate/CN/Mod.json` file localizes the patch name and description. Project Iron continues to own exercise mechanics, XP, supplement durations, and saved data.

Some equipment labels in the debug and admin grant menu use generic lookup, and the failure speech there is written directly in upstream Lua. Those branches can retain English. Offline checks cover UTF-8, JSON, all upstream keys and placeholders, and the upstream references for the added keys. In-game acceptance is pending. After restarting a B42.21 Simplified Chinese single-player session, check the sandbox page, equipment menus, supplement tooltips, and status icons.

## 来源 / Source

译文按本机 Project Iron 0.6.0 的资源与实际调用独立编写。 / The translations were authored against the installed Project Iron 0.6.0 resources and their call sites.

[Project Iron: One Last Rep · Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3830338118)
