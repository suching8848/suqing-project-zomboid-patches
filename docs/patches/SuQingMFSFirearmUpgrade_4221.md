# 蘇清的现代枪械强化补丁 / SuQing's Modern Firearm Upgrades

| 项目 / Field | 值 / Value |
| --- | --- |
| Mod ID | SuQingMFSFirearmUpgrade_4221 |
| 版本 / Version | 0.6.0 |
| 游戏 / Game | Build 42.21–42.22 单人 / single-player. Tested offline on 42.22.2. |
| 依赖及顺序 / Dependency and load order | Load after ModernFirearmsSystem (Workshop 3633421539) |

## 中文

在背包中单独右键一把普通实弹枪，选择「枪械强化」。菜单显示当前等级、伤害范围、最大射程、暴击率属性、暴击倍率、磨损概率、强化预览和材料需求。退下可拆弹匣，清空枪膛和弹仓，随身携带完好的螺丝刀和锤子。动作完成才结算材料，工具留用。拆解现代枪械可以获得所需零件。

| 等级 | 基础伤害和最大射程累计加成 | 基础暴击率加成 | 裸枪暴击倍率系数 | 金属零件 | 聚合物零件 |
| --- | ---: | ---: | ---: | ---: | ---: |
| +1 | +10% | +20 个百分点 | ×1.10 | 2 | 1 |
| +2 | +20% | +35 个百分点 | ×1.20 | 4 | 2 |
| +3 | +30% | +50 个百分点 | ×1.50 | 6 | 4 |
| +4 | +40% | +75 个百分点 | ×1.75 | 8 | 6 |
| +5 | +50% | +100 个百分点 | ×2.00 | 10 | 8 |

强化按单把枪存档，增加基础伤害上下限、最大射程和基础暴击率，并按对应系数提高裸枪的暴击倍率。配件加成单独计入。最大射程按裸枪基础射程计算，瞄具的有效瞄准区间由原版和配件决定。实战暴击率由原版结合瞄准技能、距离等因素计算并限幅。普通手枪、冲锋枪、步枪、霰弹枪和狙击枪共用一套规则。独立脚本处理的喷火、榴弹和爆炸附伤按各自规则结算。其他武器包按普通实弹枪接口识别，具体型号需实测。

「清除强化」会撤回该枪的伤害、射程、暴击和耐用加成，已用材料视为工费。关闭补丁前先清除已强化枪的加成。锯短霰弹枪等会生成新物品的转换也需要先清除强化。同包全局伤害子模组 ModernFirearmsSystemDamageSandbox 会写入相同属性，属于互斥组合。

手动安装时，通过仓库重建工具生成补丁目录，再将其放入个人 Zomboid/mods。在目标单人档启用补丁，确保现代枪械系统先加载。

B42.22.2 离线回归覆盖五档属性和材料、0.2.0 强化枪的一次性射程补齐、同型号枪械隔离、现代枪械的实际配件重算脚本、模拟读档、结算回滚和双语菜单。游戏内可先用两把同型号枪测试单枪强化，再装拆配件、换弹匣、存档重进，最后用同弹种、近似距离和相同命中部位对比实弹伤害。用户已确认 0.2.0 功能正常。最大射程、耐用性和重进恢复待游戏内验收。

### 擦拭维护

随身携带原版干毛巾，在背包里右键单独一把已卸弹且仍可用的受损枪械，选择「擦拭维护」。菜单预览当前和完成后的耐久、毛巾剩余次数。动作完成才消耗干毛巾一次使用次数并恢复 1 点耐久，上限为该枪原有的耐久上限。清洁完成后可继续逐次擦拭。满状态干毛巾有 10 次，最后一次沿用原版转换为湿毛巾。普通枪和强化枪都可擦拭，耐久归零的枪由现代枪械修理包修复。

离线回归已覆盖动作中断、持有状态变化、最后一次转换、结算失败回退和满耐久保护。进档后可用一把有磨损的枪验证耐久加 1、毛巾扣 1 次，再验证最后一次转换。

### 投掷物制作

打开制作界面的「现代枪械系统」分类。三条配方默认可用，每次产出一件。

| 配方 | 消耗 | 留用工具 |
| --- | --- | --- |
| 制作 MARK-III 进攻型手榴弹 | 枪械金属零件 ×1、火药 3 次用量 | 子弹复装套件 |
| 制作 MARK-II 防御型手榴弹 | 枪械金属零件 ×2、火药 5 次用量 | 子弹复装套件 |
| 改装无引燃气雾罐炸弹 | 原版气雾罐炸弹 ×1 | — |

B42.22.2 原生配方解析和简中／英文翻译读回通过。游戏内可各做一件，核对材料扣量和套件留用，再验证投掷与爆炸。

## English

Right-click a single conventional firearm in your inventory and choose **Firearm Upgrades**. The menu shows its level, current and projected damage, maximum range, critical stats, wear probability, and required materials. Remove the detachable magazine and empty the chamber and internal magazine. Carry a working screwdriver and hammer. The action spends components on completion and keeps the tools. Salvaging Modern Firearms System guns supplies the components.

| Level | Cumulative base damage and max range bonus | Base crit chance bonus | Bare-gun crit multiplier factor | Metal components | Polymer components |
| --- | ---: | ---: | ---: | ---: | ---: |
| +1 | +10% | +20 percentage points | ×1.10 | 2 | 1 |
| +2 | +20% | +35 percentage points | ×1.20 | 4 | 2 |
| +3 | +30% | +50 percentage points | ×1.50 | 6 | 4 |
| +4 | +40% | +75 percentage points | ×1.75 | 8 | 6 |
| +5 | +50% | +100 percentage points | ×2.00 | 10 | 8 |

Each gun saves its own level. Upgrades increase its minimum and maximum base damage, maximum range, and base critical chance, and scale the bare gun's critical damage multiplier. Attachment bonuses apply separately. The range bonus uses the bare gun's maximum firing range. The game and its sights determine the effective aiming window. The game calculates and clamps the final critical chance after factoring in aiming skill, distance, and other modifiers. Pistols, SMGs, rifles, shotguns, and sniper rifles share the same flow. Scripted flamethrower, grenade and explosion effects use their own damage rules. Other weapon packs qualify through the standard firearm interface and need individual testing.

**Clear upgrade** removes the damage, range, critical stat, and durability bonuses from that gun. The components cover the original work. Clear upgrades before disabling the patch or converting a firearm into a new item, such as sawing off a shotgun. The bundled ModernFirearmsSystemDamageSandbox addon writes the same attributes and conflicts with this patch.

For manual installation, build the mod directory with the repository rebuild tool and place it in the personal Zomboid/mods directory. Enable it after Modern Firearms System in the selected single-player save.

B42.22.2 offline checks cover all levels and costs, the one-time range upgrade for 0.2.0 guns, per-item isolation, the installed Modern Firearms System part-stat recalculation, simulated reloads, rollback, and both languages. In game, upgrade one of two identical guns, install and remove a part, change magazines, save and reload, then compare live shots using the same ammo, similar range and the same hit location. The user accepted 0.2.0 in game. Live range, wear, and save reload tests are pending.

### Wipe firearm

Carry a dry bath towel and right-click one unloaded, damaged, working firearm in your inventory. The **Wipe firearm** option previews its condition and the towel's remaining uses. Each completed action uses one towel charge and restores one point, up to the firearm's existing condition limit. Select the action again for another wipe. A full bath towel holds ten uses and becomes a wet towel on depletion through the game's own item handling. Both regular and upgraded firearms qualify. The existing MFS repair kit covers broken firearms.

Offline tests cover interrupted actions, inventory changes, last-use replacement, rollback on failure, and full-condition checks. In game, verify one condition point and one towel use per wipe, then verify the final charge becomes a wet towel.

### Throwable crafting

Open the Modern Firearms System category in the crafting menu. All three recipes are available by default and make one item each.

| Recipe | Consumes | Reusable tool |
| --- | --- | --- |
| Make MARK-III Offensive Grenade | 1 firearm metal component and 3 uses of gunpowder | Ammunition Reloading Kit |
| Make MARK-II Defensive Fragmentation Grenade | 2 firearm metal components and 5 uses of gunpowder | Ammunition Reloading Kit |
| Modify Aerosol Bomb to Prevent Ignition | 1 vanilla aerosol bomb | — |

The B42.22.2 native recipe parser and both translations passed offline. In game, craft one of each, check material use and kit retention, then verify throwing and detonation.

0.2.0 使用新的单枪强化记录格式。此前仅加伤害的强化记录不迁移。

Version 0.2.0 uses a new per-gun upgrade record format. Legacy damage-only upgrade records are not migrated.

0.2.0 已强化的枪在首次装备时按原等级补齐最大射程，无需再花材料。

Guns upgraded in 0.2.0 receive the maximum-range bonus for their existing level when first equipped, at no additional material cost.

0.4.0 的五档磨损概率累计降低 10%、20%、30%、40%、50%。根据裸枪原始磨损判定的分母计算，结果取最接近的整数。例如满级 M110 从 1/118 降至 1/236。装备已有强化的枪时应用对应耐用加成。维护状态仍由原生当前耐久和耐久上限表示。

Version 0.4.0 reduces wear probability by 10%, 20%, 30%, 40%, and 50% across the five levels. The result is rounded to the nearest integer denominator using the bare gun's script value. A +5 M110 wears at 1/236 per check, down from 1/118. Previously upgraded guns gain the bonus when equipped. Current condition and maximum condition continue to use the game's normal values.
