# 蘇清的 KNOXWAVE 音量修复 / SuQing's KNOXWAVE Volume Fix

`SuQingKnoxwaveAudioFix_4222` 0.1.2 适用于 Project Zomboid B42.22.2 `3d39148846` 单人，依赖 KNOXWAVE 0.15.34（工坊 3827026518）与 ZombieBuddy 2.3.4。将 KNOXWAVE 放在本补丁前面，按实际 JAR 哈希批准两个模组，完整重启游戏。

KNOXWAVE 的文件音频处理会读取原版音量和音效名。这两个成员属于包内可见的类，原版 KNOXWAVE 的反射读取会失败。补丁在加载时为这两个反射缓存提供允许访问的原版成员，使音量计算继续从游戏提供的值开始，再应用 KNOXWAVE 原有的衰减。补丁未修改原作者 JAR 或游戏 JAR，也不提供上游文件。

0.1.1 处理仅在单人档启用 KNOXWAVE 时的 Lua 加载顺序。补丁将作者提供的两个设置函数绑定到当前 Lua 环境，供原设置页在 `OnGameBoot` 注册。后续 Lua 重建继续使用 ZombieBuddy 自带的导出流程。

0.1.2 修复打开选项页时两个滑块标题的格式化异常。语音回声强度和房间混响强度改用中英文翻译键，继续沿用原选项 ID、数值和应用回调。此版本沿用 0.1.1 的 Java 文件和精确批准。

进档后在「选项 → 模组 → Knoxwave」查看五个控件，调整并应用一个回声或混响选项。把摆放式 True Music 播放器或电视音量调低，再调高，确认播放响度随之变化。保持音量档位不变，开关附近的门窗或在同一房间与隔墙处对比。若出现异常，一并停用 `Knoxwave` 和 `SuQingKnoxwaveAudioFix_4222` 后完整重启。

2026-11-17 正式单人档 的 0.1.0 实机日志确认 Java 初始化和读档成功，随后发现 `knoxwaveGetOption` 在设置页注册时尚未导出。0.1.1 离线回归按正式档顺序先初始化 Lua，再加载模组。使用原版选项模块和作者的 Lua 文件验证五个控件及应用回调，原音量、静音和音效名读取回归通过。新版设置页待进档验收。

## English

`SuQingKnoxwaveAudioFix_4222` 0.1.2 targets Project Zomboid B42.22.2 `3d39148846` single-player with KNOXWAVE 0.15.34 (Workshop 3827026518) and ZombieBuddy 2.3.4. Load KNOXWAVE first, approve both JARs by their exact hashes, and restart the game.

KNOXWAVE's file audio path reads the game's gain and sound name from a package-private class. The lookup succeeds but access fails. This companion supplies the two accessible game members to KNOXWAVE's existing caches at startup. KNOXWAVE keeps its own attenuation, applied to the game's gain. The author and game JARs are left intact, and upstream files are not included.

Version 0.1.1 handles the Lua initialization order for save-only loads. It binds KNOXWAVE's two existing settings functions to the current environment before the original options panel registers on `OnGameBoot`. Subsequent Lua resets use ZombieBuddy's normal export path.

Version 0.1.2 repairs the formatting error when opening the options panel. The voice echo and room reverb sliders use localized labels with the same option IDs, values and Apply callbacks. This release uses the 0.1.1 Java file and its exact approval.

After loading the save, open **Options → Mods → Knoxwave**, confirm all five controls are visible, and apply a change to echo or reverb. Compare low and high volume on a placed True Music player or television. Keep the volume steady while opening and closing a door or window, or compare the same room and behind a wall. If playback misbehaves, disable `Knoxwave` and `SuQingKnoxwaveAudioFix_4222` together and restart.

The November 17, 2026 game log for the single-player save confirmed Java initialization with 0.1.0 and a successful save load. The options panel called `knoxwaveGetOption` before it was exposed. The isolated 0.1.1 test initialized Lua before loading the mods and verified all five controls and their Apply handlers with the vanilla options API and the original mod script. Volume, mute, and sound-name regression checks passed. Live verification of the updated options panel is pending.
