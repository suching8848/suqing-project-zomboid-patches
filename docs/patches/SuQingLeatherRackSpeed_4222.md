# 蘇清的皮革晾晒加速 / SuQing's Faster Leather Drying

适用于 Project Zomboid B42.22.2 单人游戏。版本为 1.0.0，Mod ID 为 `SuQingLeatherRackSpeed_4222`。

小、中、大皮革晾晒架每次获得的干燥进度乘 2。环境速率 1.1× 时，补丁后的实际速率约为 2.2×。原版温度、湿度、雨雪暂停、材料和产物规则继续生效。原版显示的 7 天工作量和环境速率仍有原来的含义，悬停提示另列加速后的速率。

已在架上的批次从原有进度接着干燥。读取存档或区块回载后的第一个原生计算周期用来建立比较基线。退出游戏后停用该 Mod ID 即可恢复原版速率，已经完成的干燥进度随原生存档保留。

进档后悬停晾晒架的进行中皮革，查看新增的加速速率与进度变化。取出产物前确认该批完成，并可在重进后继续观察进行中批次。

For Project Zomboid B42.22.2 single-player. Version 1.0.0, Mod ID `SuQingLeatherRackSpeed_4222`.

Doubles each positive drying progress increment on all three vanilla leather racks. An environmental rate of 1.1x becomes approximately 2.2x. Stock temperature, moisture, precipitation pauses, ingredients, and outputs still apply. The seven-day workload and stock environmental rate retain their meaning. The hover tooltip adds the boosted rate separately.

Batches already on a rack continue from their existing progress. The first native update after loading establishes the new baseline for that batch. To revert, exit the game and disable this mod for the save. The stock save format retains progress already earned.

Load the save, hover the in-progress leather, and verify the boosted rate and progression. Check the output when the batch completes and confirm that an in-progress batch resumes after reloading.

## 个人安装 / Local deployment

2026-11-17 已备份并部署至单人档。原版 Kahlua、原生干燥组件和进度读回离线验证通过。游戏内验收待用户完成。

Installed in a single-player save on November 17, 2026, after verifying the backup. Offline tests covered stock Kahlua, native drying ticks, and recipe progress readback. In-game acceptance remains pending.
