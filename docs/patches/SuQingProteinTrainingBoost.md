# 蘇清的蛋白饮料训练强化 / SuQing's Protein Shake Training Boost

| 项目 / Field | 值 / Value |
| --- | --- |
| Mod ID / Folder | `SuQingProteinTrainingBoost` |
| Version | `1.1.0` |
| Target | Project Zomboid B42.21.0 单人 / single-player |
| Required mod | `VanillaFoodsExpanded` (Workshop `3577903007`) |
| Optional compatibility | Project Iron: One Last Rep `0.6.0` (`SweatWorkz`, Workshop `3830338118`) |
| Optional load-after | `SkillRecoveryJournal`, `CleanUI` |
| Source | `src/SuQingProteinTrainingBoost` in this patch collection |

饮用 Vanilla Foods Expanded 的蛋白饮料后，正常结算的力量与体格经验 ×10。支持四种口味和水、牛奶、羊奶、豆奶底液，共识别 16 种原有流体。Project Iron 可选适配集成在原 Mod ID 下。

Drinking a Vanilla Foods Expanded protein shake gives ×10 normally awarded Strength and Fitness XP. All 16 original fluids are supported across four flavors and four bases. Optional Project Iron compatibility is built into the existing mod.

## 饮用与计时 / Drinking and duration

- 500 mL 实际蛋白饮料提供 180 游戏分钟，250 mL 提供 90 分钟，125 mL 提供 45 分钟。中断饮用时按已摄入量计算。换瓶、兑水或混合口味仍按实际蛋白饮料量计时。
- 饮用增加剩余时间，上限 3 游戏小时。纯水、空杯、制作、倾倒和液体转移不触发强化。角色保存到期世界时间，睡觉和加速正常计时。
- Project Iron 的乳清饮料沿用锻炼后恢复机制。Project Iron 的训练前补剂使用自己的时长和沙盒倍率，继续处理体力、疲劳、结束后的反应及状态提示。蛋白增益使用独立的可拖动状态条，显示当前合计倍率。Project Iron 的提示继续显示其配置百分比。

A 500 mL dose contributes 180 game minutes, with 90 minutes for 250 mL and 45 minutes for 125 mL. The timer counts the protein shake actually consumed, including a partial drink or a mixed container, up to three game hours. Each character saves the world time at which the boost expires. Sleeping and time acceleration advance the timer. Project Iron whey retains its post-workout recovery effect. Its pre-workout keeps its own duration, sandbox XP setting, effects and status indicators. The protein boost uses its own draggable status bar to show the current total multiplier. The Project Iron indicator continues to show its configured bonus percentage.

## 经验结算 / XP calculation

倍率以原版已经结算的正向力量或体格经验为基准，已有沙盒、角色和营养规则先参与原生结算。Project Iron 训练前补剂按沙盒设置给出额外百分比，默认 +100%。

The multiplier starts from positive Strength or Fitness XP already awarded by the game, including native sandbox, character and nutrition rules. The Project Iron pre-workout uses its sandbox bonus percentage, which defaults to +100%.

| 当前生效的增益 / Active boost | 合计倍率 / Total multiplier | 原生 10 XP 示例 / Example with 10 native XP |
| --- | --- | --- |
| 无 / Neither | ×1 | 10 XP |
| 蘇清蛋白 / SuQing protein | ×10 | 100 XP |
| Project Iron 训练前补剂 / Project Iron pre-workout | ×(1 + 沙盒奖励比例 / sandbox bonus fraction) | 20 XP（+100%） |
| 两项同时生效 / Both | ×10 × (1 + 沙盒奖励比例 / sandbox bonus fraction) | 200 XP（+100%） |

适配把两项奖励合成一笔补差。经验遵守原生十级上限，显式 `addXpNoMultiplier` 发放和经该入口的技能恢复日记返还跳过两项强化。其他技能和负向经验照常结算。补发保留原版训练衰减计时，异常时保留已入账经验并停止本会话的强化补发。

The compatibility layer combines the two bonuses into one supplemental award. The native level-10 cap still applies. Explicit `addXpNoMultiplier` grants, including Skill Recovery Journal grants through that path, bypass both boosts. Other skills and negative XP follow their usual rules. The extra award preserves the native training decay timers. A failed award leaves any committed XP in place and stops supplemental XP for that character for the session.

## 重建与验证 / Build and verification

```powershell
python tools/rebuild.py --mod-id SuQingProteinTrainingBoost --check
python tools/rebuild.py --mod-id SuQingProteinTrainingBoost --output ../protein-training-built
```

输出目录须不存在。生成的目录包含 `common` 及 `42`。启用 `VanillaFoodsExpanded` 后按需启用本补丁。搭配 Project Iron 时，继续使用同一 Mod ID。未启用 Project Iron 时，蛋白强化照常运行。若启用的 Project Iron 版本、接口或挂钩未通过校验，保留 Project Iron 原有结算，并暂停蘇清额外经验。游戏日志记录原因。停用本补丁会停用其蛋白强化与兼容逻辑，已获得的经验保留。

Use a new output directory. The generated mod contains `common` and `42`. Enable `VanillaFoodsExpanded` and this patch. The same Mod ID works with Project Iron. The protein boost runs independently when Project Iron is absent. If the enabled Project Iron version, interface or hook fails validation, Project Iron keeps its original XP handling and the protein XP boost pauses. The game log records the reason. Disabling the patch turns off its protein boost and compatibility logic. Earned XP remains on the character.

```powershell
python tools/validate_protein_training_boost.py --game-root "D:/steam/steamapps/common/ProjectZomboid" --kahlua-runner-dir "D:/steam/steamapps/common/ProjectZomboid/CodexAssets/InventoryTransferAdapt_20261102_234116/tests" --project-iron-dir "D:/steam/steamapps/workshop/content/108600/3830338118/mods/SweatWorkz/42" --report .validation/protein-training-boost.json
```

离线工具使用 `lupa.lua51` 和已有的 `KahluaValidation.class`。其饮用集成用例接入原版 `ISDrinkFluidAction:updateEat()`，在隔离环境运行。1.0.0 的离线验证记录为 2026-11-03。2026-11-08 的 1.1.0 在 Lua 5.1、原版 Kahlua 和当前 PZO Kahlua 各通过五套离线测试。Project Iron 专项载入实包的补剂和状态界面脚本，共 157 项检查。个人安装已逐文件校验，用户确认隔离单人测试可用。测试日志记录一次液体体积前后读数不一致，原有饮用保护跳过该次增益计时。

The offline runner uses `lupa.lua51` and the existing `KahluaValidation.class`. Its drinking integration fixture runs the vanilla `ISDrinkFluidAction:updateEat()` in isolation. The 1.0.0 offline validation was recorded on 2026-11-03. On November 8, 2026, version 1.1.0 passed five offline suites on Lua 5.1, stock Kahlua and the current PZO Kahlua runtime. The Project Iron suite loads the installed supplement and status scripts and runs 157 checks. The personal installation was verified file by file. The user accepted the isolated single-player setup. The existing drinking guard skipped one boost-timer update when the test log recorded inconsistent fluid volume measurements.

## 游戏内验收 / In-game acceptance

1. 在 B42.21.0 单人隔离档中用同一角色、同一动作比较四档增益。以技能面板的总经验增量为准，覆盖原版健身、Project Iron 器械及启用时的蘇清负重训练。核对蛋白状态条的合计倍率及 Project Iron 提示的配置百分比。
2. 饮用 250 mL VFE 蛋白饮料，核对约 90 游戏分钟。再测部分饮用、混合与兑水、上限、到期和保存重进。喝 Project Iron 乳清时核对原有的锻炼后恢复。
3. 核对原生营养倍率、满级、冲刺等其他技能、训练衰减和技能恢复日记。训练前补剂的恢复体力、疲劳变化、结束反应和提示按当前沙盒设置检查。

1. Compare all four boost states with the same character and exercise in an isolated B42.21.0 single-player save. Measure total XP in the skill panel. Cover vanilla exercise, Project Iron equipment and SuQing Weight Training when enabled. Check the total multiplier on the protein bar and the configured percentage in the Project Iron indicator.
2. Drink 250 mL of a VFE shake and verify roughly 90 game minutes. Check partial consumption, mixed and diluted drinks, the duration cap, expiry and save/reload. Verify Project Iron whey still gives its post-workout recovery.
3. Check native nutrition scaling, the level cap, other skills such as Sprinting, training decay and Skill Recovery Journal grants. Check pre-workout endurance, fatigue, crash and notifications against the active sandbox settings.

## 来源 / Attribution

Vanilla Foods Expanded provides the original protein shake items, fluids and recipes. Project Iron: One Last Rep provides its own gym equipment and supplements. This patch supplies the bridge, status bar, translations and metadata.
