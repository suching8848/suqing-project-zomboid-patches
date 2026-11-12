# 蘇清的收藏配方材料标记修复 / SuQing's Favourite Recipe Materials Fix

## 中文

- **版本** 0.1.1-rc.1，Mod ID `SuQingFavouriteRecipeMaterials_4221`，适用于 B42.21.0 与 B42.22.2 单人游戏。原版与 CleanUI 2.10.4 详细列表共用修复入口，CleanUI 和 Neat Crafting 均为可选。
- **修复范围** 从已加载的制作和建造配方读取解析后的物品材料。补上自定义模块配方所需材料在列表中的原有绿勾，并在库存悬停提示末尾补上原有绿色提示。取消收藏后即时更新。补丁采用 Lua，沿用存档中的原有收藏键和物品标记优先级。
- **边界** 原生已识别的材料由原生显示。不同模块有相同配方短名时，原有收藏键无法区分，补丁跳过这种重名的额外识别。通配材料和纯流体输入沿用原生标记范围。适配已核对的详细列表和原版物品悬停提示。
- **验收** 进目标单人档，在背包或附近物品列表检查皮革条、碎布条和线。确认收藏的三个背包升级配方全部取消后，皮革条绿勾和绿色提示消失，重新收藏其中一个后恢复。用橡皮筋和窗帘布作对照。
- **停用** 退出游戏后在该档模组列表停用本项。收藏记录由原游戏继续管理。

## English

- **Version** 0.1.1-rc.1, Mod ID `SuQingFavouriteRecipeMaterials_4221`, for B42.21.0 and B42.22.2 single-player. Vanilla and CleanUI 2.10.4 detail lists use the same fix. CleanUI and Neat Crafting are optional.
- **Scope** Reads resolved item inputs from loaded crafting and building recipes. Restores the stock green badge and adds the stock green hint to the bottom of the inventory hover tooltip for materials of custom-module favourites. Toggling a favourite takes effect immediately. The Lua patch uses the original saved favourite keys and item badge precedence.
- **Limits** Native matches retain native rendering. If multiple modules define a recipe with the same short name, the stock favourite key is ambiguous and the fallback skips it. Wildcard and fluid-only inputs follow the native marking scope. Coverage is the reviewed detail lists and stock inventory hover tooltip.
- **Acceptance** Load the target single-player save and check Leather Strips, Ripped Sheets and Thread in the inventory or nearby loot list. Unstar all three matching backpack upgrades, verify the Leather Strips badge and hint clear, then star one again. Use Rubber Band and Sheet as controls.
- **Disable** Exit the game and disable this entry for the save. The game continues to manage its favourite records.

## 离线验证与部署 / Offline validation and deployment

在原版与当前 PZO Kahlua 中各执行 7 场景、46 断言，均通过。测试调用原版 `ISToolTipInv.lua` 的真实测量与绘制流程，Java 物品、配方与绘图接口使用受控替身。覆盖即时收藏切换、通配与短名冲突、建筑配方、原生提示去重和异常时清理渲染作用域。已部署至当前单人档，使用原生名单解析器确认 233 → 234 项。真实游戏界面待用户验收。

Both stock and current PZO Kahlua passed 7 scenarios and 46 assertions. The real stock tooltip Lua drives both measure and draw passes. Java items, recipe lists and drawing are fixtures. The existing native list reader confirmed 233 → 234 entries in the target single-player save. In-game UI acceptance is pending.

- [离线回归 / Offline fixture](../../tests/favourite_recipe_materials/regression.lua)

## 42.22.2 离线适配 / Offline compatibility

新版按完整构建号选择已核验的两版。原版收藏接口字节码对照一致，实际原版提示 Lua 在两版原版 Kahlua 上各通过 7 场景、48 断言。已拒绝未知 42.22 补丁号。游戏内详细列表和悬停仍待验收。

The candidate checks the full game build. Native favorite lookup matches across both builds. The real stock tooltip Lua passed seven scenarios and 48 assertions on each stock Kahlua. The unknown 42.22 patch build remains guarded. In-game list and hover rendering are pending.
