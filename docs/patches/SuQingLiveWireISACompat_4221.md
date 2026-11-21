# 蘇清的 Live Wire × ISA 统一电网 / SuQing's Live Wire × ISA Unified Grid

## 0.1.3-rc.15

适配 LiveWire 2.2.0 与 ISA 1.2.16。统一电网沿用原生负载结算，保留电池直装和 Monitor，并校验长线 rc.8 和传送门 rc.14 的来源。

Supports LiveWire 2.2.0 with ISA 1.2.16. It keeps native load settlement, direct battery insertion and Monitor, and checks the sources of Long Cable rc.8 and Portals rc.14.

## 0.1.3-rc.14

适配 LiveWire 2.1.8 与 ISA 1.2.16。保留统一结算、ISA 电池直装和 Monitor，并核对长线 rc.7 和传送门 rc.13 的来源。

Supports LiveWire 2.1.8 with ISA 1.2.16, including shared settlement, direct ISA batteries, Monitor, and the reviewed Long Cable rc.7 and Portals rc.13.

### 0.1.3-rc.13

在 LiveWire 2.1.4–2.1.6 和已支持的 ISA 1.2.15–1.2.16 单人组合中，LiveWire 电池组可直接使用 ISA 200Ah、400Ah、有线汽车电池和 DIY 电池。把电池放入已接线的 LiveWire 电池组，在电池仓监视器或 LiveWire Monitor 的电池页查看。每仓计入前四块有效电池，允许混装。容量按各电池的实际 Ah、ISA 耐久公式和 12 V 折算。直接装仓的 ISA 电池与原 ISA 并网柜中的电池一样，沿用 ISA 容量规则，充放电时保留其耐久。该版本继续支持 ISA 柜整柜并网。

Direct storage is available with reviewed LiveWire 2.1.4–2.1.6 and ISA 1.2.15–1.2.16 in single-player. Place ISA 200 Ah, 400 Ah, wired car or DIY batteries into a wired LiveWire power bank. The bank display and the LiveWire Monitor Batteries tab report them. Each bank counts its first four valid batteries and supports mixed types. Each ISA battery keeps its per-item Ah and ISA capacity curve at 12 V. Cycling preserves its condition, as with the existing linked ISA cabinet. The cabinet can still be linked independently.


0.1.3-rc.12 支持已核对的 Live Wire 2.1.6 源文件，并兼容长距离接电 0.1.0-rc.6、传送门 0.1.6-rc.12。保留单人并网、Monitor、原有结算和版本回退。新版游戏内验收待完成。

0.1.3-rc.12 supports the reviewed Live Wire 2.1.6 sources, Long Cable 0.1.0-rc.6 and Portals 0.1.6-rc.12. It retains single-player grid and Monitor integration, settlement and fallback behavior. In-game acceptance is pending.

0.1.3-rc.11 适配已验证的 Live Wire 2.1.5 和 Immersive Solar Arrays 1.2.16，适用于已复核的 B42.21.0 和 B42.22.2 单人环境。两项前置后加载。若同时安装传送门，将补丁放在已核对的传送门版本后。

在 ISA 柜上选择要并网的设备，再在附近 Live Wire 主逆变器上接入。两类储能、负载、发电和备用机按混合电网结算。混合电网给传送门 0.1.6-rc.11 充电时，按电池实际充入量扣电。更换依赖前先退出并网。启动时仍校验实际脚本，陌生版本按原生逻辑运行。

148 项新组合断言分别通过 Lua 5.1 和原版 Kahlua。正式档已确认启动，实际并网、充放电和设备控制待玩法复测。

## English

0.1.3-rc.11 supports the reviewed Live Wire 2.1.5 and Immersive Solar Arrays 1.2.16 single-player combinations. Load after both dependencies and after the supported Portals release if it is enabled.

Select the cabinet using the ISA context menu, then connect it at the nearby Live Wire master inverter. The grid handles both storage pools, load, production and the backup generator. When charging Portals 0.1.6-rc.11 from the mixed grid, the bridge settles the amount actually stored. Disconnect the cabinet before changing dependencies. The original behavior remains available for unrecognized source revisions.

The new combination passed 148 assertions each in Lua 5.1 and native Kahlua. In-game initialization is verified. Grid operations still need gameplay verification.

## 先前版本记录 / Earlier release notes

## 中文

`SuQingLiveWireISACompat_4221` · `0.1.3-rc.6` · 单人 Lua 离线候选。适用游戏构建为 42.21.0 或 42.22.2。需要 LiveWire 1.7.2、2.0.0–2.0.3 或 2.1.0–2.1.2（`batman_LiveWire`）和 Immersive Solar Arrays 1.2.15–1.2.16（`ISA`）。在两个前置及可选的蘇清传送门之后加载。传送门支持已校验的 0.1.4、0.1.5 和 0.1.6-rc.1 至 rc.6。LiveWire Extended 或 ISA-Fix 启用时，统一电网会停用并记录原因。启动时检查已安装版本、对应的 Lua 运行版本、关键源文件和相关函数来源。

- 每个 Live Wire 主逆变器可并入一台 ISA 电池柜。ISA 的电池仍放在柜中，太阳能板仍接在原柜上。并网后两边的发电与可用储能进入 Live Wire 的结算，由逆变器处理覆盖、分路、过载和家电负载。并网柜暂停 ISA 独立充放电与供电投影。
- ISA 电池按 12 V 等效换算。100 Ah 对应 1.2 kWh 额定容量，实际容量沿用 ISA 的耐久折算。首次并网保留现有电量比例和耐久。ISA 太阳能按原气候和沙盒倍率换算，效率设置为 40% 时单板基准为 498 W，实际发电还受昼夜、天气和温度影响。Live Wire 管理界面显示合计电量及实测发电，未来发电预测仍只估算 Live Wire 自己的电源。
- 参加过混合电网的汽车电池改接线或拆线时按 kWh 转移。电量超过新电池的有效容量时，只保留容量以内的部分。补丁启用期间，电池标记随转换保留。
- 两台设备都载入时，ISA 部分参与结算。柜子或逆变器离块后，重载时不补算缺失区间的 ISA 发电和耗电，避免拿当前库存或天气改写离块历史。原生 Live Wire 的离块规则继续适用于自己的设备。
- 备用发电机由 Live Wire 按混合电网的储能启停和计油。传送门在混合供电范围内从储能计费，每充入一块等效电池扣 `0.30 kWh ÷ 逆变效率`。仅扣实际充入量。市电保持优先。LiveWire 2.0 的市电充电由原仿真结算，符合条件的逆变器可给并网后的两类电池补电。

### 并网与退网

1. 在隔离单人档启用两个前置和补丁。需要测试传送门时再启用支持的传送门版本。
2. 在 ISA 柜旁右键选 **选择 ISA 电池柜并网**。走到 Live Wire 主逆变器旁，右键选 **将选中的 ISA 电池柜接入此逆变器**。两者需在 Live Wire 接线距离内、分属不同格子且已加载。柜与逆变器的并网标记无额外材料成本。连接太阳能板、Live Wire 储能、备用机仍按原模组操作。
3. 原 ISA 柜若有备用机，先关闭该机器。并网后通过 Live Wire 原有菜单把真实备用机接到逆变器。使用手动停机后，按 Live Wire 原有操作恢复自动模式。
4. 测试结束时，先在 Live Wire 解掉与原 ISA 柜共用的备用机，再在 ISA 柜旁选 **将 ISA 电池柜退出统一电网**。电池留在原容器内，退网后恢复 ISA 独立结算。移除补丁或更换上游版本前先完成退网。

### 游戏内验收

- 用 ISA 太阳能给 Live Wire 储能充电，再用 Live Wire 电源给 ISA 柜充电。关掉电源后观察家电用电从共用储能结算。拨分路和主开关，确认负载与电量变化。
- 让混合库存降到备用机启动阈值。确认只有一台机组运行，手动停机能保持。再测试缺油、恢复自动及充满后停机。
- 接传送门测试实际充电量、断电和分路。更换电池、退网重连、离开区块和保存重进后复核电量及设备关系。

### 离线验证

0.1.3-rc.6 适配 LiveWire 2.1.2 和传送门 0.1.6-rc.6，支持 ISA 1.2.15–1.2.16。B42.22.2 的 24 组组合均通过 Lua 5.1 和原版 Kahlua。最新组合在 B42.21.0 和 B42.22.2 的两个解释器各通过 143 条检查。2.1.2 管理面板在 Lua 5.1、原版 Kahlua 和作者版 PZO 独立 Kahlua 各通过 29 条。游戏内验收待完成。兼容矩阵 · 面板 PZO 结果

0.1.3-rc.5 适配 LiveWire 2.1.1、ISA 1.2.16 和传送门 0.1.6-rc.5。更新已核对版本及源码指纹，维持统一电网结算和存档。B42.22.2 的 18 组组合均通过 Lua 5.1 和原版 Kahlua，最新版组合在 B42.21.0 和 B42.22.2 均通过 143 条检查。2.1.1 管理面板在 Lua 5.1、原版 Kahlua 和作者版 PZO 独立 Kahlua 各通过 29 条。游戏内验收待完成。[兼容矩阵](<D:/GameBackups/ProjectZomboid/LiveWire211Offline_20261114/work/isa/validation/matrix.json>) · [面板 PZO 结果](<D:/GameBackups/ProjectZomboid/LiveWire211Offline_20261114/work/isa/monitor-ui/pzo-author/result.json>)

0.1.3-rc.4 适配 LiveWire 2.1.0，保持并网记录和结算规则。统一管理面板显示 ISA 和 LiveWire 的发电、储能和状态，并保留原生设备页。最新组合离线验证第三方登记电器经统一电网计费一次，遵循设备分路。38 组组合分别通过 Lua 5.1 与原版 Kahlua。游戏内验收待完成。[详细回执](<D:/GameBackups/ProjectZomboid/LiveWire210Offline_20261114_122943/离线验证.md>)

0.1.3-rc.1 保留 schema 1 并网记录。LiveWire 2.0.0 和 2.0.1 使用相同的上游 Lua，2.0.1 的安装版本对应 2.0.0 Lua 运行版本。B42.22.2 下以实际发布源码运行 Lua 5.1 与游戏目录 Kahlua，覆盖储能、备用机、传送门扣费及回滚、离块重进、配方能量继承和市电充电。三版 LiveWire 和传送门 0.1.5、0.1.6-rc.1 的离线回归分别检查。游戏内验收待完成。

`0.1.2-rc.1` 使用原版 Core 实读的完整构建号，保留版本、源码指纹与闭包来源三项校验和 schema 1 并网数据。以本机 Live Wire、ISA 和首批冻结传送门 0.1.5 在 Lua 5.1、两版原版 Kahlua 分别回归，覆盖拒绝未知构建、并网储能和回退。42.22.2 游戏内验收待完成。

0.1.1 修复客户端菜单先加载时捕获空桥接对象的问题。右键菜单在桥接就绪后读取当前状态。

现装传送门 0.1.4 与冻结传送门 0.1.5 各通过 79 项检查，分别运行于 Lua 5.1、B42.21.0 原版 Kahlua 和本机 PZO Kahlua。验证使用实装上游 Lua 和模拟世界对象，覆盖启动、右键并网、重复初始化、双向储能、同机备用、配方电量守恒和传送门扣电回滚。用户在 B42.21.0 隔离档验收通过，保存数据中记录两组并网关联。该版本曾装入正式单人档。0.1.4 的面板用现有「区域供电」文案显示桥接电源。

## English

`SuQingLiveWireISACompat_4221` · `0.1.3-rc.6` · single-player Lua offline candidate. Supports the exact Project Zomboid builds 42.21.0 and 42.22.2. Requires LiveWire 1.7.2, 2.0.0–2.0.3 or 2.1.0–2.1.2 (`batman_LiveWire`), and Immersive Solar Arrays 1.2.15–1.2.16 (`ISA`). Load it after both dependencies and after SuQing's Portals when installed. The optional portal bridge supports pinned Portals 0.1.4, 0.1.5 and 0.1.6-rc.1 through rc.6. If LiveWire Extended or ISA-Fix is enabled, the unified grid stays inactive and logs the reason. Startup checks installed versions, Lua runtime versions, upstream sources and hook ownership.

- Link one ISA cabinet to each Live Wire master inverter. ISA batteries and existing solar panel connections stay with their cabinet. Both systems supply the same Live Wire settlement, coverage, breakers and appliance loads. A linked cabinet suspends its ISA charge loop and local power projection.
- ISA energy uses a 12 V equivalent. A 100 Ah battery has 1.2 kWh of rated capacity with ISA's original condition adjustment. Joining preserves battery charge percentages and condition. The existing ISA climate and sandbox multipliers determine output. At the 40% efficiency setting, the reference output is 498 W per panel before actual light, weather and temperature. Live Wire telemetry includes measured ISA production. Its generation forecast covers its own sources.
- Wiring or unwiring a car battery that has participated in the mixed grid preserves its kWh up to the new item's effective capacity. A smaller battery sheds energy above that capacity. The marker follows the item across conversions while the patch is active.
- ISA contributes while both devices are loaded. Missing ISA intervals do not accrue retrospective generation or consumption. Native Live Wire equipment follows its existing unloaded simulation rules.
- Live Wire controls backup operation and fuel use from the mixed stock. Portals in a mixed power area draw `0.30 kWh / inverter efficiency` per full-battery equivalent actually charged. Utility power retains priority. The native LiveWire 2.0 simulation settles utility charging and can charge both battery types through an eligible inverter.

### Connection and removal

1. In an isolated single-player save, enable the dependencies and the patch. Enable a supported version of Portals to test charging.
2. Near the ISA cabinet, choose **Select ISA cabinet for the unified grid**. Near the master inverter, choose **Connect selected ISA cabinet to this inverter**. Both devices must be loaded on separate squares within the Live Wire wiring distance. The bridge association costs no additional materials. The upstream actions still apply to panels, storage and generators.
3. If the cabinet already has an ISA backup, switch it off before connecting. Use the original Live Wire action to wire the real generator to the inverter. After a manual stop, use Live Wire's existing action to restore automatic mode.
4. Before detaching, unlink the shared generator in Live Wire. Near the cabinet, choose **Disconnect ISA cabinet from the unified grid**. Its inventory stays in place and its independent ISA settlement resumes. Detach before removing the patch or changing upstream versions.

### In-game checks

- Charge Live Wire storage from ISA panels and ISA storage from a Live Wire source. Turn the sources off and verify appliance loads, branch switches and the main switch against the shared stock.
- Run through low stock, a manual stop, no fuel, return to automatic mode and recovery. Confirm one backup runs and stops at the configured threshold.
- Verify actual portal charging and branch cut-off. Check battery replacement, detach and reconnect, chunk reload, and save and reload.

### Offline verification

0.1.3-rc.6 supports LiveWire 2.1.2 and Portals 0.1.6-rc.6 with ISA 1.2.15–1.2.16. All 24 B42.22.2 combinations passed Lua 5.1 and stock Kahlua. The latest combination passed 143 checks in each interpreter on both B42.21.0 and B42.22.2. The 2.1.2 management interface passed 29 standalone checks in each of Lua 5.1, stock Kahlua and the PZO author Kahlua fixture. In-game acceptance is pending. Compatibility matrix · PZO interface results

0.1.3-rc.5 supports LiveWire 2.1.1, ISA 1.2.16 and Portals 0.1.6-rc.5. Reviewed versions and source fingerprints were updated. Unified grid settlement and saved links stay compatible. All 18 B42.22.2 combinations passed Lua 5.1 and stock Kahlua. The latest combination passed 143 checks on both B42.21.0 and B42.22.2. The 2.1.1 management interface passed 29 standalone checks in each of Lua 5.1, stock Kahlua and the PZO author Kahlua fixture. In-game acceptance is pending. [Compatibility matrix](<D:/GameBackups/ProjectZomboid/LiveWire211Offline_20261114/work/isa/validation/matrix.json>) · [PZO interface results](<D:/GameBackups/ProjectZomboid/LiveWire211Offline_20261114/work/isa/monitor-ui/pzo-author/result.json>)

0.1.3-rc.4 supports LiveWire 2.1.0 and retains the saved grid links and billing rules. The management interface shows LiveWire and ISA generation, storage and status alongside the upstream equipment views. In the latest offline combination, a registered third-party consumer is billed once and follows the equipment circuit. All 38 combinations passed in Lua 5.1 and stock Kahlua. In-game acceptance is pending. [Detailed record](<D:/GameBackups/ProjectZomboid/LiveWire210Offline_20261114_122943/离线验证.md>)

0.1.3-rc.1 retains schema 1 links. LiveWire 2.0.0 and 2.0.1 ship the same upstream Lua, so the 2.0.1 package still reports 2.0.0 at runtime. The B42.22.2 suite uses the release sources on Lua 5.1 and the game directory's Kahlua. It covers mixed storage, backup operation, portal payment and rollback, returning from an unloaded chunk, battery conversion and utility charging. Offline regressions cover the three LiveWire releases and Portals 0.1.5 and 0.1.6-rc.1. In-game acceptance is pending.

`0.1.2-rc.1` checks the full build string read from stock Core, retains source fingerprints and closure ownership checks, and keeps schema 1 for stored links. The installed Live Wire and ISA sources and frozen Portals 0.1.5 were exercised on Lua 5.1 and the two stock Kahlua builds, including unknown-build refusal, shared storage and rollback. In-game acceptance on 42.22.2 is pending.

0.1.1 fixes an early client-menu load that captured an empty bridge reference. The menu reads the current bridge once it is ready.

The installed Portals 0.1.4 and frozen Portals 0.1.5 each passed 79 checks on Lua 5.1, B42.21.0 stock Kahlua, and the local PZO Kahlua. The suite runs the installed upstream Lua with simulated world objects and covers startup, the context menu, repeated initialization, shared storage, backup control, battery conversions and portal payment rollback. The user accepted the B42.21.0 single-player test. The saved data records two linked grids. This version was installed in the personal single-player save. Portals 0.1.4 displays the bridged source using its existing area-power label.
