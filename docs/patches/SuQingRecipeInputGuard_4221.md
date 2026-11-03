# 蘇清的配方材料输入修复 / SuQing's Recipe Input Guard

| Field | Value |
| --- | --- |
| Mod ID / folder | `SuQingRecipeInputGuard_4221` |
| Version | `1.0.0` |
| Target | Project Zomboid 42.21, single-player validation scope |
| Dependency | `SapphCooking_B42`, Workshop `3409143790` |
| Source | `src/SuQingRecipeInputGuard_4221` |

修复当前Sapph草莓芝士蛋糕把衣服等无关物品列为草莓材料的问题。本补丁独立于`Codex_MustangRecipeGuard_4221`，不改旧野马补丁，也不依赖野马模组。

## 原因与处理

当前Sapph的`Base.SapphCooking PrepareStrawberryCheesecake`使用`sapphcooking:strawberry`，但其`media/registries.lua`缺少该标签。当前原生脚本解析会保存缺失标签的null引用，物品标签索引又允许null作为键，因而不同未注册标签的物品可能进入同一候选池。Neat Crafting按原生候选列表显示材料，不能只靠改显示名称修复。

本补丁在版本分支的`media/registries.lua`中先查询标签，不存在时才注册。该阶段早于物品和配方脚本解析；合法草莓物品与配方会引用同一个有效标签，并由原生系统正常建立候选。

- 保留原材料数量、消耗模式、技能、时间、产物及牛奶流体过滤。
- 当前确认的草莓来源为`Base.Strewberrie`及`SapphCooking.Syrup_Strawberry`。启动验证要求它们存在，同时保留其他真正带有效草莓标签的合法来源，不把候选硬编码锁死为两件。
- 不改衣服/弹壳等原物品标签，不清理全局null标签池，不覆盖原作文件，不重写UI，不改其它配方。
- 上游以后补注册时复用现有标签。必须先get再决定register；原生重复注册可能先修改映射再抛错，不能靠捕获重复错误来规避。
- 进入游戏后只读核验目标原输入行、有效标签、候选归属和`canUseItem`的正反结果；异常记录ERROR，不对未知新版本做强制重建。

**必须完全重启游戏。**在已解析脚本的当前进程中晚注册，不会自动替换旧null引用；仅回到主菜单或在控制台运行注册语句不能作为可靠更新方式。

## 安装与停用

启用原Sapph模组后，按需追加本补丁，保留其它Mod ID相对顺序。普通的Mustang修复可继续独立使用。B42安装目录必须包含`common`和`42`。

```powershell
python tools/rebuild.py --mod-id SuQingRecipeInputGuard_4221 --check
python tools/rebuild.py --mod-id SuQingRecipeInputGuard_4221 --output ../recipe-input-guard-built
```

停用本补丁并完全重启会恢复上游本身的注册状态；不自动更改已经制作的物品或返还以前误消耗的材料。没有物品或存档数据迁移。

## 验证与边界

```powershell
python tools/validate_recipe_input_guard.py --game-root "D:/steam/steamapps/common/ProjectZomboid" --kahlua-runner-dir "D:/steam/steamapps/common/ProjectZomboid/CodexAssets/InventoryTransferAdapt_20261102_234116/tests" --report .validation/recipe-input-guard.json
```

测试环境需要Python与`lupa.lua51`；Kahlua工具使用本机既有`KahluaValidation.class`和游戏标准库。离线fixture覆盖缺失/已有标签、原生null桶污染的负控与注册后隔离、只读输入核验、合法扩展来源保留、无关材料拒绝和上游结构变化。它们不等于真实游戏制作、所有组合或联机验收。

2026-11-03审计：Sapph当前适用分支42.20.0，元数据modversion0.1。首轮游戏验收待完成：完全重启后搜索草莓芝士蛋糕，确认草莓输入不再出现JK上衣、弹壳等，检查牛奶/鸡蛋/糖/酸奶油/烤盘仍正确；先在隔离单人档用合法食材检查实际制作与消耗。日志应有`[SuQingRecipeInputGuard] registered`或`existing`以及`verified strawberry input`，不应有本补丁ERROR。

## English notes

Standalone early-registry fix for Sapph's missing `sapphcooking:strawberry` tag. The missing tag can put unrelated items with other unresolved tags into the same native null-tag bucket. Registration happens before item and recipe parsing; a read-only startup verifier checks the resolved ingredient candidates. Existing upstream tags are reused, legitimate tagged additions remain allowed, and recipe quantities, outputs and fluid inputs are retained. A full game restart is required. The Mustang guard is neither modified nor required. Single-player offline checks do not establish gameplay or multiplayer acceptance.
