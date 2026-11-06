# 蘇清的船舱与房车房间兼容补丁 / SuQing's Boat Cabin and RV Room Compatibility Patch

[总目录 / Index](../../README.md) · [English overview](../../README.en.md)

| 项目 / Field | 值 / Value |
| --- | --- |
| Mod ID / Folder | `SuQingBoatRVRoomGuard_4221` |
| Version | `0.1.0-rc.2` |
| Scope | B42.21 single-player / 仅单人 |
| Required mods | `PROJECTRVInterior42`, `BoteBR`, `FrotaBRRVAddon` |
| Load after | 上述前置；另保留 `RVViewpointPatch` 的已有顺序 / The prerequisites; retain the existing RVViewpointPatch order |
| Reviewed upstream | PROJECT RV Interior 3.0, FrotaBR RV Addon 1.6 |
| Source status | 2026-11-06 本地新增，未提交、推送或发布 / Local addition; not committed, pushed or published |
| Runtime source | `src/SuQingBoatRVRoomGuard_4221` |

## 中文

船舱注册器把 `frotabr_cabine.rooms` 指向原 `3x6caravan.rooms` 的 38 个物理房间。当前 RV 单人分配器却仅检查当前类别的 `AssignedRooms*`，因此船和房车可能获得同一坐标。

补丁在已有 `ISVehicleMenu.getVehicleToInteractWith` 包装链外增加占用检查，在原生分配器及菜单运行之前刷新两类候选列表。每一类只排除其他类别占用的位置，保留自身已用的房间；这同时维持原生 `roomsUsed < #rooms` 的菜单判断。房间总容量仍是共用的 38 间，不是双方各 38 间。

原生分配器继续创建、保存自己的分配记录，本补丁只读取已有 `AssignedRooms*`，不创建第二份持久化数据库。已有内饰坐标、物品、车辆 ID 与记录对象保留；不会把旧物品搬到“新房间”。满房时已有车辆仍可进入，新车辆不再申请房间。

通过 `RVHooks.preEnter` 在传送前复查当前车辆的实际记录和其他占用。旧记录已撞房、数据异常或检查失败时取消进入，不擅自迁移或删除任何一方。通知失败也不能被 RVHooks 的外层 `pcall` 转变为允许进入。

运行时读取已审查的六个上游文件，核对按 Java `BufferedReader.read()` 返回字符码计算的归一化指纹；精确原文件 SHA-256 保留在本轮审计中。上游变化、文件读取失败、房间定义被替换时暂停受影响入口。指纹用于防止无意的上游漂移，不是安全签名。当前实际游戏 `getModFileReader` 已离线反编译确认：先从所选版本目录读取，再回退 common；调用使用 `createIfNull=false`。

不支持多人或 Arcadia。未接管其他房车布局，不修改航速、燃油、发电、制作或 Viewpoint 画面；本补丁通过不等于这些上游功能全部兼容。

## English

The boat registry aliases its cabin pool to the same 38 physical rooms used by `3x6caravan`. The native single-player allocator only checks the requested category's assignment map, so separate categories can select the same coordinates.

This patch wraps the existing vehicle-lookup chain and filters each category's candidate rooms before native allocation/menu code runs. Rooms owned by OTHER assignment groups are removed; OWN allocated rooms stay in the list, preserving the native `roomsUsed < #rooms` menu rule. The combined physical capacity remains 38.

Native allocation and persistence are retained. Existing coordinates, item locations, vehicle IDs and assignment objects are not migrated; the patch adds no persistent reservation database. A pre-teleport RV hook rejects duplicate or invalid assignments. Source changes and room-contract replacement block affected entry. Notification failures also fail closed.

Six reviewed upstream files are checked with a Java-reader-normalized drift fingerprint; raw SHA-256 values are retained in the audit. The actual game's reader resolves the selected version directory before common, with file creation disabled. The fingerprint is a drift check, not a security signature.

Single-player only, not Arcadia. Other RV layouts, boat movement/fuel/power/crafting and Viewpoint rendering are outside this patch's support claim.

## 离线验证 / Offline validation

使用当前游戏 Kahlua 和当前已安装原作的真实房间表、注册器、分配函数、菜单函数及 RVHooks，世界、玩家、车辆、事件和文件读取器使用桩。先复现未打补丁的撞房，再验证修复。当前 **350 项断言通过**，包括：

- RV/boat 双向分配；交替填满 38 间且无重复；原菜单不提前消失。
- 满房后的新申请拒绝与旧房重进；模拟保存重载保持既有分配。
- 已有撞房不迁移、不删除；外部类别占用也被避让。
- 源码变化/不可读、异常记录、运行时替换、检查与翻译通知异常均不放行。
- 重复安装和脚本重载不叠加包装；原有退出钩子保留；多人不被宣称支持。
- 三个补丁 Lua 编译通过；中英三个提示键及占位符一致。

The 350 assertions exercise the real installed allocator/menu/hooks in the original-game Kahlua runtime with mocked external context. They cover full capacity, existing interiors, reload simulation, legacy conflicts, foreign occupancy, drift/error guards and idempotence. All three patch Lua files compile; CN/EN message keys match. No game instance was started and no save data was written by these tests.

```powershell
python tests/run_boat_rv_room_guard.py --audit-dir .validation/boat-rv-room-guard
python tools/rebuild.py --mod-id SuQingBoatRVRoomGuard_4221 --output ../boat-rv-room-guard-built
```

重建输出目录必须不存在。脚本只生成离线测试/重建产物；不启动游戏、不部署、不改启用名单。The rebuild output must not exist; these commands do not launch the game, deploy or alter enabled lists.

## 用户验收及停用 / User acceptance and disabling

先检查原房车的物品和进出；再用停稳的 Aberdeen 或钢制捕蟹船进入船舱，小划艇无舱内。放少量可辨认物品，移船后核对两个内饰及返回位置，正常保存退出重进。Viewpoint 的实际显示与操作由用户另行验证。遇到冲突/上游变化提示时保留日志，不删除内饰记录。

Verify an existing RV first, then a stationary Aberdeen/steel crab boat cabin, independent belongings/return positions and save/reload. The small rowboat has no cabin. Viewpoint acceptance is separate. Keep logs and interior records if a warning appears.

停用前让人物回主地图，再同时停用船舱扩展和本补丁；需要的物品先取出。只关补丁继续开船舱会再次暴露撞房风险。保留存档；完整恢复会回退进度。Return to the main world and remove needed belongings before disabling the cabin addon together with this patch. Disabling only the patch exposes the original collision risk. Retain save data; full restores roll back progress.

原作归属：PROJECT RV Interior / Mickey Knox；Boat & Crab Fishing BR 及船舱扩展 / gadinho 与原作署名贡献者。本包仅含自制兼容逻辑与指纹，不重新分发原作完整代码。游戏内、Viewpoint 和长期游玩验收仍待完成。


2026-11-06 rc.2：修复运行时Unicode字符处理差异导致的源码误报。直接读取Java字符码，统一CR/LF/CRLF及末行，避开Lua byte/模式实现差异；6个上游原件SHA-256未变化。350项行为断言在stock及当前pzopt运行时分别通过，真实Java Reader的19组边界/原件测试亦在两环境通过。源码变化、缺文件、占用冲突仍拦截，不放宽保护，不改房间或物品。用户于2026-11-06反馈船舱入口正常；保存重进、Viewpoint及完整冲突组合仍待验。

rc.2 fixes the false source-change rejection across Unicode implementations. Java reader code units and normalized line endings avoid Lua byte/pattern differences. The same 350 behavior assertions and 19 real Java reader fixtures pass under stock and active pzopt classpaths. Reviewed upstream files are unchanged; drift/collision gates remain. The user reported the cabin entrance working on2026-11-06; save/reload, Viewpoint and all conflict combinations remain unverified.
