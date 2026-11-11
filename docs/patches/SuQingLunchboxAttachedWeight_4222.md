# 蘇清的返鲜餐盒外挂减重修复 / SuQing's Lunchbox Attached Weight Fix

`SuQingLunchboxAttachedWeight_4222` 0.1.0-rc.1，适用于 B42.22.2 单人。需要 `SuQingFreshnessLunchbox`、ZombieBuddy 2.3.4 和原生 Java 批准。

背包底部外挂会用热栏重量算法。原算法把餐盒和食品总重乘以 0.7，忽略容器的减重参数。补丁针对返鲜餐盒的普通、大型与 ALICE 底部挂点，把餐盒自重按原生外挂系数折算，内容物按当前容器减重计算。角色负重和原生提示共用该返回值。截图中的 14.7 总重、1.0 盒重及 99% 减重对应约 0.84。

将独立模组加入本地 mods，启用两项前置及配套补丁，批准 Java 模组并完整重启。停用并重启后恢复原生外挂计重。补丁无需迁移存档或升级记录。B42.22.2 原生负重和 ZombieBuddy 2.3.4 装载验证共 41 项断言通过，游戏内待验收。

`SuQingLunchboxAttachedWeight_4222` version 0.1.0-rc.1 supports B42.22.2 single-player. It requires `SuQingFreshnessLunchbox`, ZombieBuddy 2.3.4 and native Java approval.

The hotbar weight calculation multiplies the complete attached load by 0.7. For the ordinary, large and ALICE backpack-bottom Freshness Lunchbox slots, the fix applies the native attached multiplier to the box itself and the current container reduction to its contents. Carry weight and the native tooltip share this value. A total weight of 14.7 with a 1.0 box and 99 percent reduction contributes about 0.84.

Place the mod in local mods, enable both dependencies and the patch, approve the Java mod and fully restart. Disable the patch and restart to resume native attached weight. Existing items and upgrade records stay usable. Native weight and ZombieBuddy 2.3.4 loader validation passed 41 assertions. In-game testing is pending.

Build and validate with `tools/build_lunchbox_attached_weight.py`. The command takes the game directory, JDK 25 compiler and a fresh output directory. It produces the candidate ZIP and verification log.

随返鲜餐盒工坊条目分发，在模组列表中单独启用。 Distributed as an optional submod of the Freshness Lunchbox Workshop item. [Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3834693433)
