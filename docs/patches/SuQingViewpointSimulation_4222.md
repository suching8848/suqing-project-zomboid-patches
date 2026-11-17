# 蘇清的 Viewpoint 模拟频率 / SuQing's Viewpoint Simulation Control

`SuQingViewpointSimulation_4222` 0.1.0 支持 B42.22.2 单人。需要 Viewpoint 0.1.7 工坊验签热修、ZombieBuddy 2.3.4 和本补丁的 Java 批准。由独立 Java 模组接入现装 Viewpoint 的固定模拟选项。

在原版游戏的 **选项 → 模组 → Viewpoint 模拟频率** 选择 **30 Hz**、**60 Hz** 或 **关闭**，点击 **应用**。默认 60 Hz，目标模拟间隔约 16.7 ms。更高频率会增加游戏线程负荷，实际帧率取决于场景和运行条件。关闭后按常规游戏循环和配置中的显示限帧运行。

启用后完整重启。先进入 3D 视角测试默认 60 Hz，再在同一位置和画质下切换 30 Hz 或关闭。可用控制台的 fixed tick 日志确认档位。若选项显示不可用，请核对前置版本和 Java 批准状态。停用补丁并完整重启后恢复 Viewpoint 原生 30 Hz 固定模拟。

2026-11-16 正式档实机日志确认 60 Hz、关闭及切回 60 Hz，退出后保留 60 Hz。用户反馈 60 Hz 合适。30 Hz 已通过离线验证，待游戏内复测。

本补丁的档位由原版模组选项保存在 `Lua/ModOptions.ini`。启用时读回已保存的档位。模组和选项 ID 分别为 `SuQingViewpointSimulation_4222` 和 `mode`，索引 `1`、`2`、`3` 分别对应 30 Hz、60 Hz 和关闭。

## English

`SuQingViewpointSimulation_4222` 0.1.0 supports B42.22.2 single-player. It requires the Viewpoint 0.1.7 Workshop signature hotfix, ZombieBuddy 2.3.4 and Java approval for the patch. A separate Java mod connects to the installed Viewpoint fixed simulation settings.

Open **Options → Mods → Viewpoint Simulation Rate** in the game's options, select **30 Hz**, **60 Hz** or **Off**, and select **Apply**. The default is 60 Hz, with a target update interval of about 16.7 ms. Higher rates add game-thread load, and actual frame rate depends on the scene and system. Off follows the regular game loop and the configured display framerate limit.

Enable the patch and fully restart. Try 60 Hz in a 3D view first, then compare 30 Hz or Off in the same scene and quality settings. The fixed tick console messages show the current rate. If the option is unavailable, check dependency versions and Java approval. Disable the patch and fully restart to restore Viewpoint's native 30 Hz rate.

The November 16, 2026 live session confirmed 60 Hz, Off, and the switch back to 60 Hz. The profile retained 60 Hz after exit. The user preferred the feel at 60 Hz. The 30 Hz mode passed offline verification.

Game Mod Options saves the selected mode in `Lua/ModOptions.ini` for the next launch. The mod ID is `SuQingViewpointSimulation_4222`, the option ID is `mode`, and indices `1`, `2`, and `3` select 30 Hz, 60 Hz and Off respectively.
