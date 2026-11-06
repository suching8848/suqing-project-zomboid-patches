# 蘇清的世界对象状态保护

SuQing's World Object State Guard 0.1.0-candidate

## 中文

需要 ZombieBuddy 至少2.3.4，适用已审查的42.21单人类资源。首次加载Java需通过ZombieBuddy原生批准，JAR变化可能需重新批准；不提供或自动设置allow-all，不改审批记录。

动物保护仅在动物缺少HumanVisual时跳过不适用的人类衣物破洞调用；人类、已有HumanVisual的动物、原伤害、部位及其他异常保持。车辆保护仅在当前cell与已加载chunk都按对象身份唯一含该车、其他全部状态成立时恢复丢失的chunk字段，继续原update。不创建区块，不增删集合，不删除车辆、动物、数据库或存档，不关闭原生异常复制，也不承诺修复所有车辆问题。

类资源按Compatibility.java中固定SHA256识别原版/PZO。未知、不可读资源保持原行为并明确告警；不放宽门禁。已有11月5用户首次进入原档、实际车辆保护触发及正常保存退出证据；再次读档、动物触发、Viewpoint、FPS及多人仍未全面验收，保留候选标签。正常退出、停用本ID并重启可撤销保护；不回滚世界进度或套用旧配置。

源码保存在java/world_state_guard/source，独立构建工具tools/build_world_state_guard.py；固定ZIP时间和JDK构建收据保留可重现性。离线测试包含真实方法抽取fixture、ZombieBuddy转换/签名及ByteBuddy编织、未知资源拒绝和107项车辆受控状态断言，不启动游戏。

## English

Requires ZombieBuddy 2.3.4 or newer and reviewed B42.21 single-player class resources. First Java loading requires ZombieBuddy's native approval; changed JAR bytes may require reapproval. No allow-all flag or approval-record changes are provided.

The animal guard only skips an inapplicable human clothing-hole call for animals lacking HumanVisual. Human behavior, visual-equipped animals, original damage/parts and other exceptions remain. The vehicle guard restores only a missing chunk field after unique identity membership in the current cell and a loaded chunk and every other condition pass, then continues the original update. It creates no chunks, changes no memberships and deletes no entities, databases or saves. Native crash copying remains. It is not a universal vehicle repair.

Compatibility.java pins reviewed stock/PZO resource SHA256 values. Unknown/unreadable resources retain native behavior and emit warnings. Keep the candidate label: initial save loading, an actual vehicle guard trigger and normal saving/exiting have limited November 5 evidence. Reloading, animals, Viewpoint, FPS and multiplayer are not comprehensively accepted. Exit normally, disable this ID and restart to remove its behavior without rolling back progress or settings.

Sources: java/world_state_guard/source. Isolated reproducible builder: tools/build_world_state_guard.py. Offline tests preserve actual-method fixtures, native ZombieBuddy conversion/signatures, ByteBuddy weaving, unknown-resource rejection and 107 vehicle-state assertions. They never start the game.
