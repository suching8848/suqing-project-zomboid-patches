蘇清的船舱与房车房间兼容补丁
SuQing's Boat Cabin and RV Room Compatibility Patch
Version: 0.1.0-rc.2 | Mod ID: SuQingBoatRVRoomGuard_4221

中文
适用：Project Zomboid B42.21 单人，当前已核对的 PROJECTRVInterior42 3.0 与 FrotaBRRVAddon 1.6。
前置：Boat & Crab Fishing BR 的 BoteBR、FrotaBRRVAddon，以及 PROJECTRVInterior42。
顺序：保留其他模组原顺序，将 FrotaBRRVAddon 和本补丁依次放在其前置之后。本补丁在 FrotaBRRVAddon 后。
不要同时开启 ArcadiaRVAddon；本补丁不支持 Arcadia 或多人，也不是 Viewpoint 航行/画面修复。

船舱扩展复用 3x6caravan 的 38 间实际房间，但原作按类别分别记录占用，可能撞房。
补丁在原分配入口之前统一读取全部 AssignedRooms* 记录，为双方排除其他类别已占用的房间；保留自身已用项，维持原生菜单数量判断。
已有房间坐标、物品、车辆 ID、内饰记录均不迁移；不新建地图、不增加房间容量，也不维护第二份持久化占用数据库。
原有 38 间是共用总容量，不是房车和船各有独立的 38 间。用满后不能申请新内饰，已有内饰仍可正常申请进入。
传送前还有一次检查：若旧记录已发生撞房，阻止进入并提示，不擅自选择一份记录覆盖或搬家。
若核对的上游源码变化、读取失败或房间结构改变，暂停相关 3x6 房车和船舱入口并记日志；其他房车布局不由本补丁接管。

首次验收（由用户在游戏内执行）
1. 启动目标单人档，先检查原房车物品和进出、返回位置。
2. 制作/放置 Aberdeen 或钢制捕蟹船，停稳后用 V 菜单进入船舱；小划艇没有舱内扩展。
3. 在船舱放少量可辨认物品，返回并移动船，再确认原房车和船舱物品、返回位置彼此独立。
4. 分别正常保存、退出和重进，复查两个内饰。Viewpoint 普通/第三人称的显示和操作另行检查。
5. 若出现“占用冲突”或“兼容检查未通过”，停下记录提示和日志，不要反复删内饰数据或恢复旧档。

停用：先让人物回主地图，再停用船舱扩展与本补丁；保留世界数据。只关闭本补丁而继续使用船舱扩展会重新暴露撞房风险。
已有船舱物品在停用扩展后可能暂时无法访问，应先取出需要的物品。完整存档恢复会回退进度，不能直接覆盖后续游玩。
当前状态：开发与离线回归通过，已准备个人部署；实际游戏内、Viewpoint 与长期保存验收待用户完成。未提交 Git、推送或发布工坊。

English
Scope: Project Zomboid B42.21 single-player; reviewed PROJECTRVInterior42 3.0 and FrotaBRRVAddon 1.6 sources.
Requires BoteBR, FrotaBRRVAddon and PROJECTRVInterior42. Keep existing unrelated order; load this patch after FrotaBRRVAddon.
Do not combine with ArcadiaRVAddon. No multiplayer/Arcadia support or claim of Viewpoint navigation/rendering compatibility.

Boat cabins reuse the 38 physical 3x6caravan rooms, while upstream allocations are recorded separately by category.
The patch reads all AssignedRooms* maps before native selection, removes rooms occupied by OTHER groups from each candidate list, and retains OWN occupied rooms for the native menu's capacity calculation.
It does not move existing interiors/items, change vehicle IDs, create a new map, add capacity or introduce another persistent allocation database.
The 38 slots are a combined physical capacity. Full capacity blocks new interiors while retaining existing entry.
A pre-teleport hook rejects already-conflicting assignments without silently relocating either owner.
Reviewed-source or room-contract changes block affected boat/3x6 entry and log the reason. Other RV layouts are not taken over.

User acceptance: verify an existing RV first; use a stationary Aberdeen or steel crab boat for cabin entry; keep distinguishable items in each interior; move the boat and verify independent contents/return positions; save, quit and reload. The small rowboat has no cabin. Test Viewpoint views separately.
If a collision or compatibility warning appears, retain logs and stop instead of deleting interior records.
Before disabling, return to the main world and disable the cabin addon together with this patch. Remove needed belongings first; retained cabin data may be inaccessible until the addon is enabled again. A full-save restore rolls back progress.
Status: offline regression passed and personal rc.2 deployed. The user reported the cabin entrance working on2026-11-06; save/reload, Viewpoint and long-term acceptance remain unverified. No Git commit/push or Workshop publication.

Credits: PROJECT RV Interior by Mickey Knox; Boat & Crab Fishing BR / cabin addon by gadinho and credited contributors. This package contains original compatibility code and source fingerprints, not complete upstream scripts.

rc.2修复：直接读取Java字符码，避免不同Lua环境把原作Unicode注释误判成源码变化；stock和当前pzopt均通过350项断言与19组真实文件读取测试。冲突保护保留；用户已反馈入口正常，保存重进/Viewpoint及完整冲突组合仍待验。
rc.2: Java reader fingerprints prevent Unicode false drift warnings. 350 behavior assertions and 19 real-reader fixtures pass under stock/active pzopt. Collision gates remain; user entrance feedback is positive, while save/reload, Viewpoint and all conflict combinations remain unverified.
