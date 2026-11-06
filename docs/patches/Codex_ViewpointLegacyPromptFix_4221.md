# 蘇清的 Viewpoint 旧版手柄提示修复补丁 / SuQing’s Viewpoint Legacy Prompt Fix Patch

[返回总目录 / Back to index](../../README.md) · [English overview](../../README.en.md)

| 项目 / Field | 当前值 / Current value |
| --- | --- |
| Mod ID / Folder | `Codex_ViewpointLegacyPromptFix_4221` |
| 版本 / Version | `1.0.0` |
| 游戏 / Game | Project Zomboid Build 42.21 |
| 声明前置 / Declared prerequisite | `ProjectViewpointQOLLegacy0.1.6` |
| 加载在其后 / Load after | `ProjectViewpointQOLLegacy0.1.6` |
| Viewpoint 目标 / Viewpoint target | Legacy 的 Viewpoint 0.1.6.1 组合；不是当前 0.1.7 QOL 的补丁 |
| 登记状态 / Registration | 2026-11-04 本地源码新增；尚未提交、推送或发布 / Local source addition; not committed, pushed or published |

## 中文说明

Legacy 的手柄提示在右键菜单分支直接生成 `A Select / B Close`，该分支先于原有 HUD 开关判断。因此，即使控制器总开关关闭，鼠标打开物品菜单时仍可能出现手柄文字。

本补丁在上游 `VPC_PromptHUD.renderPrompts` 外增加一个可重复安装的方法包装，不复制或覆盖上游整个脚本。控制器总开关未明确开启、提示关闭或选项尚未就绪时不绘制；只有实际手柄活跃，或满足上游原有的键鼠脱离后切回提示条件时，才继续调用原函数。启用时的手柄菜单、正常 HUD 和切回提示保留。重复加载或触发安装事件不会叠加包装；缺少目标方法时不修改其他对象。

补丁不写 `ctrl.*`、`qol.*`、ModOptions 或存档，不更换 Java 桥，也不改变物品菜单动作。当前 0.1.7 QOL、独立 Controller 子模组以及其他提示来源不在适配范围内。保留原有模组相对顺序，按需启用本补丁即可。

可重建包共 **5 个文件**：两份 `mod.info`、自制 Lua 包装器、中文说明和 `common/.keep`。清单中的文件均为 `own` 模式，原样保存到 [`src/Codex_ViewpointLegacyPromptFix_4221`](../../src/Codex_ViewpointLegacyPromptFix_4221)，不附带上游 `ViewpointController_Prompts.lua` 或 Java JAR。

```powershell
python tools/rebuild.py --mod-id Codex_ViewpointLegacyPromptFix_4221 --output ../viewpoint-legacy-prompt-fix-built
```

输出目录必须尚不存在。重建工具校验每个文件的 SHA-256，不下载、不部署，也不修改模组启用名单。

## English notes

The upstream Legacy context-menu branch creates `A Select / B Close` before checking the usual HUD gates. Mouse context menus can therefore display controller hints while controller support is disabled.

This patch wraps the original `VPC_PromptHUD.renderPrompts` method. It requires an explicitly enabled controller master, an enabled prompt HUD and initialized options. It forwards active-controller rendering and the upstream detached-controller resume-hint path, while suppressing mouse-only menu prompts. It retains the upstream renderer, avoids repeated wrapping and leaves missing targets alone.

It changes no persisted settings, item actions, Java bridge, save data or unrelated mod order. It targets the `ProjectViewpointQOLLegacy0.1.6` / Viewpoint 0.1.6.1 combination, not the current 0.1.7 QOL or standalone Controller submod. All five listed package files use `own` reconstruction; no upstream complete Lua file or JAR is bundled.

## 验证边界 / Validation boundary

2026-11-04 使用原游戏 Kahlua，在隔离的 UI、事件及外部上下文桩中加载真实上游提示脚本和本补丁，**19 项离线行为回归通过**。测试先复现原版总开关关闭仍绘制 A/B，再覆盖关闭、未就绪、纯鼠标、活跃手柄、正常 HUD、切回提示、动态开关、重复安装事件及 HUD 重建。上游实际绘制、条目构造和切回提示方法保留，只收集绘制输出；没有启动游戏或读写正式档。

原游戏编译和离线行为通过不代表游戏内 UI、全部控制器或其他组合已验收。首次游戏内检查：关闭手柄支持，用鼠标右键物品确认 A/B 消失；需要手柄时再检查正常提示和切回提示。当前游戏内验收待完成。

The 19 offline checks reproduce the upstream bug and exercise the wrapper with the original-game Kahlua interpreter and real upstream render methods. UI drawing, events and external context are stubbed. They do not constitute in-game acceptance or approval of every controller/mod combination. In-game mouse-menu and optional controller checks remain pending.

本地源码登记不等于 Git 提交、远端同步或创意工坊发布；2026-11-03 的 33 项发布快照保持独立记录。

Local registration is distinct from a Git commit, remote synchronization or Workshop publication. The previous 33-entry release snapshot remains separately recorded.
