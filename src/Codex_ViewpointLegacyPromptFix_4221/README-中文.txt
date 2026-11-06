蘇清的Viewpoint旧版手柄提示修复补丁 / SuQing's Viewpoint Legacy Prompt Fix
Mod ID: Codex_ViewpointLegacyPromptFix_4221
Version:1.0.0
Requires: ProjectViewpointQOLLegacy0.1.6, with its own Viewpoint/ZombieBuddy prerequisites.

问题：上游Legacy在任何右键菜单打开时直接画A Select/B Close，跳过手柄总开关、提示开关和实际手柄活动检查。
本补丁仅包装公开的VPC_PromptHUD.renderPrompts方法；关闭手柄总开关/提示开关或设置尚未就绪时不绘制，纯鼠标菜单也不绘制手柄提示。保留真实活动手柄的菜单/HUD，以及上游键鼠脱离后切回手柄提示的精确条件。
不复制或修改工坊原文件，不更改QOL功能、快捷键、沙盒、经验或物品。没有Java文件，不增加新JAR审批。
重复安装不叠加包装；初始化时方法尚不可用则在游戏加载事件再尝试，契约缺失时保留上游行为并记录日志，不吞原方法的异常。

审计目标：Workshop3811256204 manifest44351957639799003，Legacy JAR6b52bf680538087b59ba85181c947bebdb8de0d65bf51959586f3390777e385e。
游戏内效果需正常启动后右键物品验收；离线回归与原游戏Lua编译结果另记在本轮任务证据目录。
