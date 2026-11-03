# 蘇清的蛋白饮料训练强化 / SuQing's Protein Shake Training Boost

| 项目 / Field | 值 / Value |
| --- | --- |
| Mod ID / Folder | `SuQingProteinTrainingBoost` |
| Version | `1.0.0` |
| Target | Project Zomboid 42.21, single-player |
| Required mod | `VanillaFoodsExpanded` (Workshop `3577903007`) |
| Source | `src/SuQingProteinTrainingBoost` in this patch collection |
| Optional load-after | `SkillRecoveryJournal`, `CleanUI` |

饮用 Vanilla Foods Expanded 的四种口味蛋白饮料后，在正常结算的力量与体格经验上再乘10。水、牛奶、羊奶、豆奶底液均支持，共识别16种原有蛋白饮料流体。保留上游配方、营养、容器、消耗、物品ID和已有沙盒倍率；不复制或修改原作脚本。

## 行为 / Behaviour

- 500mL实际蛋白饮料提供180游戏分钟，250mL提供90分钟，125mL提供45分钟。按实际喝下体积计算；中断保留已摄入部分。
- 剂量增加剩余时间，上限3游戏小时。倍率固定×10，重复饮用不再叠成×100。兑水不会增加有效剂量，换瓶/混合口味照常识别；纯水、空摇摇杯、制作、倾倒、转移液体不触发。
- 从实际摄入开始计时，饮用过程经过的游戏时间也会扣除。睡觉及加速照常计时，退出游戏期间不流逝；按角色ModData保存到期世界时间。显示按剩余整分钟向上取整，不改变内部精度。
- 本来实际获得10点经验，增益期间合计获得100点。全局5倍叠加饮料相当于基础50倍，力量再有蛋白营养1.5倍时相当于基础75倍。其他技能、负向经验和原生十级上限保持原行为。
- 日记恢复及显式`addXpNoMultiplier`分配不作为新训练再放大。保留现有Skill Recovery Journal台账包装，不覆盖书本倍率槽，不修改沙盒。
- 屏幕上方显示可拖动的小型状态条：力量/体格经验×10和剩余游戏时间。到期自动隐藏并提示。只支持单人，联机不授予效果。
- 补发经验有重入保护，保留原版训练衰减计时器只执行一次的行为。若补发失败或增量不符，本会话停止该角色的额外奖励并提示检查日志，不自动重试或回滚已经入账的经验。

Drinking any of the sixteen upstream protein-shake fluids grants a timed final ×10 Strength/Fitness XP bonus. A 0.5 L dose contributes three game hours; partial consumption scales linearly and remaining duration is capped at three hours. Existing sandbox, nutrition, recipes and containers remain in place. Recovery/explicit flat grants are excluded; books' multiplier slots are not overwritten. This is a single-player bridge, not a multiplayer implementation.

## 重建与验证 / Build and verification

```powershell
python tools/rebuild.py --mod-id SuQingProteinTrainingBoost --check
python tools/rebuild.py --mod-id SuQingProteinTrainingBoost --output ../protein-training-built
```

输出目录须不存在。生成的`SuQingProteinTrainingBoost`目录包含`common`及`42`。不要求复制上游文件。依赖必须已经安装且启用；在上游后按需追加本补丁，保留其他模组相对顺序。停用本补丁即停止额外经验，已经获得的经验保留。

离线行为验证脚本：

```powershell
python tools/validate_protein_training_boost.py --game-root "D:/steam/steamapps/common/ProjectZomboid" --kahlua-runner-dir "D:/steam/steamapps/common/ProjectZomboid/CodexAssets/InventoryTransferAdapt_20261102_234116/tests" --report .validation/protein-training-boost.json
```

Python测试环境需要`lupa.lua51`。Kahlua参数使用本机既有`KahluaValidation.class`工具，并从游戏目录加载其标准库；工具只执行隔离fixtures，不启动游戏或读取玩家存档。`integration_tests.lua`接入本机原版`ISDrinkFluidAction:updateEat()`，验证消费、剂量与经验模块组合。

2026-11-03：Lua 5.1与游戏Kahlua的离线测试通过。它们证明当前源码和受控场景的行为，不代表已在游戏内读档、饮用、UI、保存重进或所有模组组合实测；首轮游戏验收仍待作者完成。当前上游审计分支为VFX `42.18`、版本`3.4.3`，实际游戏为42.21.0；分支名不等于游戏要求退回42.18。

## 游戏内验收 / In-game acceptance

1. 正常启动并确认本补丁已加载；使用隔离测试档，保留与目标档相同的全局5倍设置。
2. 以技能面板实际总经验增量验收；原版经验跳字先于额外奖励事件，可能只显示原始奖励部分。记录体格/力量当前经验、完成一次固定健身动作；喝250mL蛋白饮料，确认约90游戏分钟及×10状态，再比较相同行为的实际经验增量。
3. 检查500mL、125mL、中途取消、兑水、混口味、转普通瓶，验证仅实际蛋白饮料量计时；喝水及倾倒不触发。
4. 检查剩余时间上限、到期、睡觉/加速、保存退出再进入；到期后经验应恢复原速。
5. 蛋白营养正常/加成/不足分别比较；检查其他技能、满级、现有针剂、原版训练衰减计时以及恢复日志。日记返还不能被再次当成新训练奖励。

## 来源 / Attribution

Vanilla Foods Expanded supplies the original items, liquids and recipes. This repository contains only original bridge, UI, translation and metadata files. No upstream artwork or full third-party scripts are redistributed by this patch.
