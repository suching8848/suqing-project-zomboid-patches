# 蘇清的 Live Wire 长距离接电 / SuQing's Live Wire Long Cable

## 0.1.0-rc.8

适配 LiveWire 2.2.0 的接线与设备恢复。继续由原生事务扣线、返还旧线及同步设备，长线范围仍适用于原有 LiveWire 设备。

Supports LiveWire 2.2.0 wiring and recovery. The native transaction debits and returns wire and syncs devices. The existing range extension still applies to LiveWire equipment.

## 0.1.0-rc.7

适配 LiveWire 2.1.8 的设备来源校验，沿用原有距离、接线和设备恢复规则。

Recognizes the verified LiveWire 2.1.8 sources and retains existing range, wiring and recovery rules.

0.1.0-rc.6 支持已核对的 Live Wire 2.1.6。接线规则和设备恢复沿用现有实现。新版游戏内验收待完成。

0.1.0-rc.6 supports the reviewed Live Wire 2.1.6 sources. Wiring rules and device recovery follow the existing behavior. In-game acceptance is pending.

0.1.0-rc.5 适用于单人 B42.21.0 和 B42.22.2。需要已核对的 Live Wire，当前适配验证使用 2.1.5。沙盒选项「设备长距离接电上限」默认 40 格，最高 100 格。只用于 Live Wire 原生设备接主逆变器，沿用原模组的线材、技能、楼层和电网要求。

补丁在运行时从现装 Live Wire 读取受检脚本。未知版本继续使用原模组距离。离线 115 项断言分别通过 Lua 5.1 和两版原版 Kahlua。正式档已核对设备恢复入口，实际远端接线待复测。

## English

0.1.0-rc.5 is for single-player Build 42.21.0 and 42.22.2 with reviewed Live Wire files. The current compatibility check uses 2.1.5. The long cable sandbox limit defaults to 40 tiles and accepts up to 100 tiles. It applies to connections between original Live Wire equipment and a master inverter. Existing cable, skill, level and grid requirements still apply.

The patch reads reviewed scripts from the installed Live Wire mod at runtime. Unrecognized versions use the original distance. The update passed 115 assertions in Lua 5.1 and both stock Kahlua builds. In-game device recovery initialization is verified. Long-distance wiring still needs gameplay verification.
