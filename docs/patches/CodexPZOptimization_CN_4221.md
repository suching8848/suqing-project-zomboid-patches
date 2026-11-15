# 蘇清的 PZ Optimization 设置汉化 / SuQing’s PZ Optimization Chinese Settings

| 项目 / Field | 当前值 / Value |
| --- | --- |
| Mod ID | `CodexPZOptimization_CN_4221` |
| 版本 / Version | `1.3.0` |
| 游戏 / Game | B42.22.2，单人 / single-player |
| 外部前置 / External prerequisite | PZ Optimization `fad57862` / `f0bca707` |

## 中文

沿用 577 项设置标签、选项说明、菜单导航、中文搜索和 7 项预设翻译。简体中文且检测到指定 PZO 时才挂接译文。其他语言、缺少 PZO 或版本不符时使用作者原有界面。作者的入口动作、事件和设置键保留。1.3.0 加入 fad57862 以及该版本新增的 Windows 卸载提醒。

使用 `tools/rebuild.py --game-root <游戏目录> --mod-id CodexPZOptimization_CN_4221 --check` 校验来源，再使用新的 `--output` 目录构建。菜单差异以作者原件的 SHA-256 固定输入。游戏内验收时打开 PZ Optimization 的性能、画质、预设和兼容性页面，检查中文查询、换行及返回。1.1.0 对应 B42.21 与 PZO 154126d0。

## English

The optional Simplified Chinese localization retains 577 setting labels, selected descriptions, menu navigation, Chinese search and seven presets. It activates for the Simplified Chinese game language with PZ Optimization fad57862 or f0bca707. The author's interface stays active for other languages or when the engine is missing or mismatched. Original menu actions, events and settings keys are preserved. Version 1.3.0 includes the Windows uninstall warning added in fad57862.

Check the pinned local source with `tools/rebuild.py --game-root <game directory> --mod-id CodexPZOptimization_CN_4221 --check`, then build to a fresh `--output` directory. To validate in game, open the optimization, enhancement, preset and compatibility pages and check text layout, Chinese search and back navigation. Version 1.1.0 targeted B42.21 and PZO 154126d0.

The translated menu methods are reconstructed from the pinned author menu with a context diff. See [third-party sources](../THIRD_PARTY.md) and the [rebuild manifest](../../rebuild-manifest.json). Public distribution remains on hold.
