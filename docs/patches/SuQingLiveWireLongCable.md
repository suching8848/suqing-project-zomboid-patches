# 蘇清的 Live Wire 长距离接电 / SuQing's Live Wire Long Cable

0.1.0-rc.5 适用于单人 B42.21.0 和 B42.22.2。需要已核对的 Live Wire，当前适配验证使用 2.1.5。沙盒选项「设备长距离接电上限」默认 40 格，最高 100 格。只用于 Live Wire 原生设备接主逆变器，沿用原模组的线材、技能、楼层和电网要求。

补丁在运行时从现装 Live Wire 读取受检脚本。未知版本继续使用原模组距离。离线 115 项断言分别通过 Lua 5.1 和两版原版 Kahlua。正式档已核对设备恢复入口，实际远端接线待复测。

## English

0.1.0-rc.5 is for single-player Build 42.21.0 and 42.22.2 with reviewed Live Wire files. The current compatibility check uses 2.1.5. The long cable sandbox limit defaults to 40 tiles and accepts up to 100 tiles. It applies to connections between original Live Wire equipment and a master inverter. Existing cable, skill, level and grid requirements still apply.

The patch reads reviewed scripts from the installed Live Wire mod at runtime. Unrecognized versions use the original distance. The update passed 115 assertions in Lua 5.1 and both stock Kahlua builds. In-game device recovery initialization is verified. Long-distance wiring still needs gameplay verification.
