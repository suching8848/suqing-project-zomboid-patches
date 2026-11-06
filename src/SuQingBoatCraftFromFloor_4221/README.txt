蘇清的造船就地取材补丁 / SuQing's Boat Crafting Nearby Materials Patch
Mod ID: SuQingBoatCraftFromFloor_4221 | Version: 0.1.0

中文
适用当前B42.21单人、BoteBR；配方来源必须仍为BoteBR，已核对的原作配方文件必须匹配。
仅给“制作划艇、制作渔船、制作钢制捕蟹船”增加原生 CanBeDoneFromFloor 标记。
这会让原版制作和当前Neat Crafting不再把全部输入提前搬进人物主背包，而直接使用已识别的附近材料。
材料数量、工具、技能、制作时间、工作面、产物和重量均不修改。不新增材料获取范围、不读取锁定容器、不忽略缺料。

使用
重启游戏并读档。站在可用工作面旁，把木板、金属板等放在附近地面或可访问容器，确保拾取面板能看到、制作界面能识别。
工具可留在身上。仍需给成品腾出空间：划艇重量10、阿伯丁号16、钢制捕蟹船20（原作值；其他减重模组可能另行影响）。
选择原来的船配方进行制作，缺料或不靠近工作面仍不能制作。建议在水边附近的工作面制作，完成后携船到水边放置。

验证与限制
54项当前游戏Kahlua离线断言通过，使用原生及当前Neat输入转移函数，配方/容器/动作对象模拟；不等于游戏内完整制作已验收。
原生CraftRecipe的可修改标签列表和getter已离线反编译核对。只追加一个标签，不调用影响全部配方的CraftRecipeManager.Init()。
新增标签不会主动重建按“CanBeDoneFromFloor”查询的全局索引；普通配方枚举和直接getter的制作行为不依赖这一新增索引。
不支持多人。上游文件或有效配方来源变化时停止应用并提示；原作文件不被覆盖。
停用后重启即可回到原配方取材流程；已制作船只和物品保留，无存档迁移。未提交Git或发布工坊。

English
B42.21 single-player only. Requires BoteBR; the effective recipes must remain owned by BoteBR and the reviewed upstream recipe file must match.
Adds only the native CanBeDoneFromFloor flag to the three boat recipes. Vanilla and the installed Neat Crafting skip the forced input pretransfer into the character inventory.
Ingredient quantities, tools, skills, crafting time, work-surface requirements, outputs and weights remain unchanged. Container access/range and missing-material checks are retained.
Restart, stand by a usable work surface, place materials in visible nearby floor/accesssible containers, and use the original recipes. Keep room for the output: upstream boat weights are 10 / 16 / 20.
54 offline assertions cover the actual native/Neat transfer functions with mocked external objects; in-game crafting acceptance is pending.
The native mutable tag-list API was decompiled and reviewed. No global CraftRecipeManager.Init() is called. Queries specifically using the newly added floor tag keep their original index; ordinary recipe listing and the direct crafting getter still work.
Disabling and restarting restores upstream input handling without migrating or deleting boats. No Git commit or Workshop publication. Original boat content belongs to gadinho and the credited upstream contributors.
