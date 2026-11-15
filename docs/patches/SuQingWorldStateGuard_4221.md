# 蘇清的世界对象状态保护 / SuQing's World Object State Guard

版本 / Version  `0.1.1-candidate`

## 中文

适用于已审查的 42.21 原版和 PZO 类资源，以及 42.22.2 原版单人环境。需要 ZombieBuddy 2.3.4 或更新版本。新 JAR 首次加载需要通过 ZombieBuddy 的原生审批。

动物保护仅在动物缺少 HumanVisual 时跳过不适用的人类衣物破洞操作，保留原落地伤害和其余处理。车辆保护仅在同一辆车已按对象身份唯一登记于当前 cell 和已加载 chunk，且其余状态校验通过时，恢复丢失的区块引用并继续原版车辆更新。车辆更新失败时仍由原版处理。

42.22.2 要求完整构建号和两个目标类的原版 SHA-256 同时匹配。混合或缺失资源会保留原行为并在日志告警。42.21 仍按已审查哈希分别判断两项保护。42.22.2 的 PZO 组合仍待独立验证。

42.22.2 已完成原版类离线比对、实际 ZombieBuddy/ByteBuddy 编织和受控回归，游戏内验收待完成。42.21 曾有用户首次读档、车辆保护触发和正常保存退出的记录。独立验收可在配套的 42.22.2 环境读档，检查日志的构建号及两项门禁，然后正常保存退出并重进。退出后可停用该 Mod ID。

源码位于 `java/world_state_guard/source`。用 `tools/build_world_state_guard.py` 在独立目录复现候选 JAR，用 `tests/world_state_guard/run_adaptation.py` 对两版原版类、旧版 PZO 动物类和未知资源运行离线检查。

## English

Supports reviewed 42.21 stock and PZO class resources and stock 42.22.2 single player. It requires ZombieBuddy 2.3.4 or newer. A new JAR requires ZombieBuddy's native approval on first load.

The animal guard skips the human clothing-hole operation only for animals lacking HumanVisual and preserves the rest of landing damage handling. The vehicle guard restores a missing chunk reference only after unique identity membership in the current cell and a loaded chunk and the remaining state checks pass. It then continues the original vehicle update. The engine still handles vehicle update failures.

The 42.22.2 gate requires the full build number and matching SHA-256 digests for both stock target classes. Mixed or missing resources preserve engine behavior and emit a warning. The reviewed 42.21 hashes retain separate eligibility for the two guards. A 42.22.2 PZO configuration awaits separate validation.

Offline checks for 42.22.2 cover the stock classes, actual ZombieBuddy and ByteBuddy weaving, and controlled regressions. In-game acceptance remains pending. The 42.21 release had limited user evidence of loading a save, a vehicle guard trigger, and normal saving and exiting. For acceptance in a matching 42.22.2 test environment, load a save, check the reported build and both gates in the log, save, exit normally, and reload. The Mod ID can be disabled after exiting.

Sources are in `java/world_state_guard/source`. Reproduce the candidate JAR in a fresh directory with `tools/build_world_state_guard.py`. Run `tests/world_state_guard/run_adaptation.py` to verify both stock builds, the old PZO animal class, and unknown resources offline.
