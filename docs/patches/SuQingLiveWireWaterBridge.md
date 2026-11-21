# 蘇清的 Live Wire × Waterpipes 水路桥接 / SuQing's Live Wire × Waterpipes Bridge

## 0.1.1-rc.13

适配 LiveWire 2.2.0 与现装 Waterpipes。水泵接入统一的逆变器分路供电判断。

Supports LiveWire 2.2.0 with the installed Waterpipes and uses the native inverter circuit check for pumps.

## 0.1.1-rc.12

适配 LiveWire 2.1.8 与当前 Waterpipes，沿用原有水循环、水箱和分路断电联动。

Supports LiveWire 2.1.8 with the current Waterpipes and retains the existing water cycle, tanks and circuit handling.

0.1.1-rc.11 支持已核对的 Live Wire 2.1.6 单人组合。保留水泵、四种原生水箱容量、集雨桶及分路断电联动。新版游戏内验收待完成。

0.1.1-rc.11 supports the reviewed Live Wire 2.1.6 single-player setup. Pump integration, the four native tank capacities, rain collectors and circuit control retain their existing behavior. In-game acceptance is pending.

0.1.1-rc.10 用于已审查的 Live Wire 2.1.5 和 Waterpipes 单人组合。兼容 Live Wire 的 25、80、150、300 升原生水箱以及四款 Useful Barrels 储水桶。按原模组接好电与水路，Waterpipes 继续处理用水需求。断电停止补水，恢复供电后重新按连通状态处理。

原版离线回归覆盖水箱容量、桶型、分路断电与恢复。正式档日志确认 Waterpipes 分钟事件已接入，具体水路操作待玩法复测。

## English

0.1.1-rc.10 supports the reviewed Live Wire 2.1.5 and Waterpipes single-player combination. It bridges the 25, 80, 150 and 300 L Live Wire tanks and four Useful Barrels tanks. Connect power and plumbing through the original mods. Loss of power pauses refilling, and a connected setup resumes as power returns.

Offline regression covers tank capacities, barrel types, circuit cut-off and recovery. In-game startup verified the Waterpipes minute integration. Plumbing operations still need gameplay verification.

## 先前版本记录 / Earlier release notes

`SuQingLiveWireWaterBridge` · `0.1.1-rc.6` · 单人离线候选，完整游戏版本限 42.21.0 或 42.22.2。前置为 LiveWire `batman_LiveWire` 1.7.2、2.0.0、2.0.1、2.0.2、2.0.3、2.1.0、2.1.1 或 2.1.2，以及 Waterpipes `Waterpipes` 42.20 分支。灌溉养护 `SuQingSprinklerFertilizer` 1.0.1-rc.2 可选。补丁排在两项必需前置之后。

## 首版功能

- **Waterpipes → 集雨桶 → Live Wire**。Waterpipes 直连新式原版集雨桶，并用 Live Wire 原菜单把同一桶接到水泵。已加载且身份匹配时，管网直接向实体桶补水，旧 Waterpipes 缓冲仅按实体桶实收量减少。实体桶容量、流体种类及原有 Live Wire 器具供水继续按各自规则执行。
- **集雨桶 → Live Wire → Waterpipes**。在一台专用 Live Wire 水泵旁接一段 Waterpipes 管道。右键水泵，在「Waterpipes 水路桥接」中选择对应方向。水泵沿用其原有集雨桶连线和供电。一轮共用 5 L／游戏分钟上限，按终端实收扣桶和计入 Live Wire 用电。关闭阀门、桶空或断开设备分路时，桥接停止出水。
- **Waterpipes 泵供电**。对 Live Wire 分路覆盖的已加载 Waterpipes 泵，设备或总断路器切断时保留泵开关选择，暂停出水和磨损，供电恢复后继续结算。归属按 Live Wire 面板规则判断，其他电源覆盖同一水泵时也遵循该面板的断路器设置。原生流体源按已加载泵重新识别。
- **LiveWire 2.0 的断路器**。桥接送水遵守 2.0 回路提供者对 LiveWire 泵的设备断电判断。Waterpipes 泵同时遵守格子范围内适用于该设备的断电判断。已绑定的 LiveWire 水泵继续使用原作的集雨桶连接校验。2.0.0 与 2.0.1 均报告运行版本 `2.0.0`。2.0.2 至 2.1.2 按已验证的核心源码签名及运行版本识别。2.1.0 至 2.1.2 的回路按器具类别判断断路，Waterpipes 水泵仍归设备分路。三版的水泵、回路及器具分类源码一致。
- **灌溉养护**。桥接先送水，再由 Waterpipes 执行原有喷水和代次更新。只用 Live Wire 供水的管线使用喷头自己的肥药库存。普通 Waterpipes 泵的已连库存仍由灌溉养护处理。

首版接入一台专用 Live Wire 泵、一条独立且已加载的管线。支持阀门、分支、原有喷头和 Waterpipes 直接登记的有限容量器具。器具须有实体流体容器并关闭原版外接水源。已有原版器具供水的 Live Wire 泵优先保留原水路。共网双泵、回路、建筑整网接口、旧式雨桶、未加载区块和联机留待后续。

## 隔离档验收

用户此前在 B42.21.0 单人隔离档验收过 `0.1.0-rc.1`。保存数据记录 Live Wire 泵累计送水 8 L、Waterpipes 喷头收到水。`0.1.1-rc.6` 在 Lua 5.1 和上述两版原版 Kahlua 通过八版 LiveWire 的离线回归，覆盖 2.0 回路提供者接口和灌溉养护。Extended 的实际布线、喷水及保存重进待游戏内验收。

1. 用兼容的实体集雨桶做转接。先关 Live Wire 泵，观察 Waterpipes 将桶加到上限。再关 Waterpipes 泵，打开 Live Wire 的设备分路，观察原版外接器具取水及桶量变化。用有、无滤芯的 Waterpipes 水泵分别核对水质。
2. 另用一台 Live Wire 泵，将实体桶接到泵上，然后通过右键连接独立 Waterpipes 管线。将管线接到喷头和带实体流体容器的直连器具，分别检查出水、分支水量、关阀、满器具、空桶及关闭总闸／设备分路。单分钟实际总抽水应至多 5 L。
3. 在装有对应游戏版本的灌溉养护隔离档，给喷头装肥药。分别用原 Waterpipes 泵和桥接的 Live Wire 泵喷水，观察喷头与作物变化。关阀和断电时检查肥药余额，重复覆盖时检查同类养护去重。保存重进，再核对连接、水量和库存。
4. 停用前右键解除桥接并保存。桥接记录使用独立全局 ModData。已经进入实体桶和器具的水留在原容器中。卸载补丁后 Waterpipes 重新直接加载其原生周期。

## 实现和版本

补丁以原作的管道形状和 100 内部单位／L 为准。运行时直接读取所装 Waterpipes 脚本，仅对经过签名核对的版本插入桥接入口。游戏完整版本、适配接口或源码校验失败时加载所装 Waterpipes 的原回调。已用 42.21.0 和 42.22.2 原版 Kahlua、实际 Waterpipes 源码和灌溉养护候选回归。桥接连接仍用原 schema 1。安装包只含自制文件。

基线 SHA-256 如下。运行时签名采用原作读取路径的规范化换行及 ASCII 字节，另逐一检查注入点。

| 原作文件 | 审查时 SHA-256 |
| --- | --- |
| Waterpipes `WPServer.lua` | `ce98747d9ce4ab6592d063b78aede42c69af64f20722a0cfe420b4067699832c` |
| Waterpipes `WPIso.lua` | `e7463716852737bc6c08130c768161c29c1978e11ac23660fb90907fb6ad5106` |
| Waterpipes `WPVirtual.lua` | `15037ece0c1a9fe9e1d6443db930b16ae192ee911a0c98fae00ef9e5e7e47e47` |
| LiveWire 2.0.2 `LW_Core.lua` | `0e4466495d8bda5ca94730ca5b4028ad5910c55decdbf5ee63ca13b94944a9f1` |
| LiveWire 2.0.3 `LW_Core.lua` | `e71d1d4b2fad8e8e779122deb2fd32cbb80bcd6809053a67e9aff683f2feb778` |
| LiveWire 2.1.2 `LW_Core.lua` | `591114ae07370425e460165288ccfb0d6fa8f68f535de07ad12afe012c174c8a` |
| LiveWire 2.1.1 `LW_Core.lua` | `5e6165b13c7a874c0ca6699fd02dd1c59ac09d4c695fde6442cc8f9e4f8f84a9` |
| LiveWire 2.1.0 `LW_Core.lua` | `cf75328c06495dd35116b46d9a2627ee4f98cd64631b2bd7c8e6fdfeb6f57290` |
| LiveWire 2.1.0 `LW_Circuits.lua` | `99a01c057c09f0da95267fc0443f8f2c000f23ce2e156ed6c52f490182ad5fe5` |
| LiveWire 2.1.0 `LW_ApplianceFamilies.lua` | `f347f48dd503ce7fb59b6e471f29ea80b1f6a718d6fc85ee0d9d9a87408b192f` |
| LiveWire 2.1.0 `LW_Consumers.lua` | `60f477a77413bfec720ad3e8630dbd785b98cdf00ba38f8572e9d2da2c11cd82` |
| Live Wire `LW_Pump.lua` | `f3193a3b9c4d3f2e59453b941c490f34eea5ee26c18c8aa7c02b99ae31e1e0ac` |
| Live Wire `LW_Circuits.lua` | `90ff60066eab27058f5c770c0a5c1c56c6cba542f90baf36c4274632462ded06` |

## SuQing’s Live Wire and Waterpipes Bridge

`SuQingLiveWireWaterBridge` · `0.1.1-rc.6` · single-player offline candidate for exact game builds 42.21.0 and 42.22.2. Requires LiveWire `batman_LiveWire` 1.7.2, 2.0.0, 2.0.1, 2.0.2, 2.0.3, 2.1.0, 2.1.1 or 2.1.2, and the Waterpipes `Waterpipes` 42.20 branch. Irrigation Care `SuQingSprinklerFertilizer` 1.0.1-rc.2 is optional. Load this patch after both required mods.

- **Waterpipes → collector → Live Wire.** Connect both systems to the same supported, loaded vanilla fluid-container rain collector. Waterpipes adds water directly to the collector. Any existing Waterpipes buffer drains by the physical amount accepted.
- **Collector → Live Wire → Waterpipes.** Connect a dedicated Live Wire pump to a neighboring Waterpipes pipe with its new context menu. The whole line shares up to 5 L per game minute. The pump debits its existing linked collectors and records energy use by actual delivery. Closing a valve, emptying the collector or cutting equipment power stops bridge delivery.
- **Power and irrigation.** Cutting the Live Wire main or equipment circuit stops loaded Waterpipes pumps assigned to that panel without clearing their switch choice. The panel still governs the pump in areas with overlapping power sources. Waterpipes runs native sprinkler watering. Irrigation Care uses local supplies on a line fed only by Live Wire.
- **LiveWire 2.0 breakers.** Bridge delivery follows the circuit provider's cut for its LiveWire pump. A Waterpipes pump also follows applicable circuit provider cuts at its grid square. A bridged LiveWire pump retains the native barrel-link check. The 2.0.0 and 2.0.1 packages report runtime version `2.0.0`. The patch identifies reviewed builds from 2.0.2 through 2.1.2 by their core signatures and corresponding runtime versions. The circuit code in 2.1.0 through 2.1.2 routes appliances by family. The Waterpipes pump is still on the equipment circuit. The pump, circuit, and appliance-classification sources are identical across these three releases.

This candidate supports one connected pump and one loaded, dedicated line with valves, branches, native sprinklers and directly registered finite fixtures with a real fluid container and external plumbing off. A pump that supplies vanilla-plumbed fixtures keeps that service. Shared feeds, loops, building-wide inlets, legacy rain barrels, unloaded networks and multiplayer are outside the candidate scope.

The user previously accepted `0.1.0-rc.1` on B42.21.0 single-player. The saved data records 8 L pumped by Live Wire and water at the Waterpipes sprinkler. `0.1.1-rc.6` passed offline regression for all eight LiveWire packages in Lua 5.1 and both stock Kahlua builds, including the 2.0 circuit provider API and Irrigation Care. Extended wiring, sprinkler operation, and save reload remain pending in-game acceptance.

To repeat the test, build both layouts in an isolated save. Check collector capacity and water quality, the shared limit, valve and breaker cutoffs, empty and full endpoints, and persistence after save and reload. Check Irrigation Care stock and overlap behavior with each water source, then close the valve and cut power. Disconnect the bridge in the context menu before disabling the patch. Water already stored stays in the original containers.

The patch uses Waterpipes pipe geometry and its scale of 100 units per litre. It reads the installed Waterpipes callback and adds hooks only on the reviewed sources. An unsupported game build, source or adapter version runs the installed Waterpipes callback. Regression uses both stock Kahlua builds, the installed Waterpipes sources and the Irrigation Care candidate. Stored connections retain schema 1. The candidate package contains only original patch files.
