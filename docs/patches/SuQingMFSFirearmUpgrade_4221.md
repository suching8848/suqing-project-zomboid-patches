# 蘇清的现代枪械强化补丁 / SuQing's Modern Firearm Upgrades

| 项目 / Field | 值 / Value |
| --- | --- |
| Mod ID | SuQingMFSFirearmUpgrade_4221 |
| 版本 / Version | 0.12.1 |
| 游戏 / Game | Build 42.21–42.22 单人 / single-player. Tested offline on 42.22.2. |
| 依赖及顺序 / Dependency and load order | Load after ModernFirearmsSystem (Workshop 3633421539) and Nekomata Ridge (Workshop 3782173659) |

## 中文

在背包中单独右键一把普通实弹枪，选择「枪械强化」。菜单显示当前等级、伤害范围、最大射程、暴击率属性、暴击倍率、磨损概率、强化预览和材料需求。退下可拆弹匣，清空枪膛和弹仓，随身携带完好的螺丝刀和锤子。动作完成才结算材料，工具留用。拆解现代枪械可以获得所需零件。

| 等级 | 基础伤害和最大射程累计加成 | 基础暴击率加成 | 裸枪暴击倍率系数 | 金属零件 | 聚合物零件 |
| --- | ---: | ---: | ---: | ---: | ---: |
| +1 | +10% | +20 个百分点 | ×1.10 | 2 | 1 |
| +2 | +20% | +35 个百分点 | ×1.20 | 4 | 2 |
| +3 | +30% | +50 个百分点 | ×1.50 | 6 | 4 |
| +4 | +40% | +75 个百分点 | ×1.75 | 8 | 6 |
| +5 | +50% | +100 个百分点 | ×2.00 | 10 | 8 |

强化按单把枪存档，增加基础伤害上下限、最大射程和基础暴击率，并按对应系数提高裸枪的暴击倍率。配件加成单独计入。最大射程按裸枪基础射程计算，瞄具的有效瞄准区间由原版和配件决定。实战暴击率由原版结合瞄准技能、距离等因素计算并限幅。普通手枪、冲锋枪、步枪、霰弹枪和狙击枪共用一套规则。独立脚本处理的喷火、榴弹和爆炸附伤按各自规则结算。猫又岭的靛蓝逐罪使用专属能量子弹，支持五级强化。右键强化菜单显示当前数值及已获得的伤害加成。其他武器包按普通枪械接口识别，具体型号需实测。

可强化枪开火时，+0／+1／+2／+3／+4／+5 的招尸半径依次为同枪、同配件、未强化时的 100%／90%／80%／70%／60%／50%。强化菜单和现代枪械检视里的「噪音」读取同一有效半径。半径取整后由原版另算沙盒噪音倍率和室内衰减。现代枪械消音器继续提供自身的半径和声强修正，世界声强沿用原值。玩家听到的枪声增益每级降低 2 个百分点，+5 为未强化时的 90%。求生之路移植系列的 19 把枪和靛蓝逐罪使用同一降噪规则，原有强化存档直接读取等级。靛蓝逐罪的裸枪基准为 15 格，+5 取整为 8 格。额外的猫猫升级沿用 +5 的 50%，其他专属属性照常生效。

只有空枪的靛蓝逐罪达到 +5 后可执行「枪械强化 → 猫猫升级」。消耗 10 个枪械金属零件和 8 个枪械聚合物零件，需要螺丝刀和锤子。完成后射程属性为 0–800 格，裸枪伤害加成 +200%，暴击伤害倍率按原枪初始倍率 ×2 计算，现装靛蓝逐罪为 ×8。最大瞄准距离和手持时所选瞄具的距离按 800 格补齐。已完成猫猫升级的枪在装备后自动应用新数值，无需再次耗材。猫猫专属升级将裸枪基础命中率设为 90%，配件命中修正按原版叠加。已有专属升级装备时自动补齐命中率，清除强化恢复原有基础值。风罚按原版计算。

靛蓝逐罪在原版开火事件逐发播放对应原声，两种模式的声音片段增益均为 50%。普通射击沿用原版 M16 声音事件。超载使用已安装的猫又岭提供的原录音，保留原声开头的低音量段。

「清除强化」会撤回该枪的伤害、射程、暴击、耐用和招尸半径修正，已用材料视为工费。关闭补丁前先清除已强化枪的加成。锯短霰弹枪等会生成新物品的转换也需要先清除强化。同包全局伤害子模组 ModernFirearmsSystemDamageSandbox 会写入相同属性，属于互斥组合。

手动安装时，通过仓库重建工具生成补丁目录，再将其放入个人 Zomboid/mods。在目标单人档启用补丁，确保现代枪械系统和猫又岭先加载。

B42.22.2 离线回归覆盖五档属性和材料、0.2.0 强化枪的一次性射程补齐、同型号枪械隔离、现代枪械的实际配件重算脚本、模拟读档、结算回滚和双语菜单。游戏内可先用两把同型号枪测试单枪强化，再装拆配件、换弹匣、存档重进，最后用同弹种、近似距离和相同命中部位对比实弹伤害。用户已确认 0.2.0 功能正常。最大射程、耐用性和重进恢复待游戏内验收。


### +5 减重扩展

可选的蘇清的枪械升级扩展（仅本机试用）提供 +5 枪身和已装配件重量减半，适用于 B42.22.2 单人并需要 ZombieBuddy 2.3.4。启用主补丁后再启用扩展，并准许扩展的 JAR。已有 +5 直接读原等级。关闭扩展并重启后回到原重量，Lua 强化照常生效。扩展的进档验收待完成。

### 擦拭维护

同时启用蘇清的擦拭修复 1.0.0 时，枪械的「擦拭维护」由擦拭修复提供。单独启用本补丁，或与 0.2.0 的近战擦拭模组搭配时，本补丁提供枪械擦拭菜单。 [擦拭修复说明](SuQingMeleeWeaponWipe_4222.md)

随身携带擦拭材料，在背包里右键单独一把已卸弹且仍可用的受损枪械，选择「擦拭维护」。只有一种材料可用时可直接擦拭，有多种时从子菜单选择。提示会预览擦拭前后的耐久和所选材料的用量。

| 材料 | 每次擦拭的用量 |
| --- | --- |
| 干抹布、干毛巾 | 扣 1 次用量。满状态各有 10 次，最后一次沿用原版转换为对应的湿抹布或湿毛巾。 |
| 干净的碎布条、牛仔布条、普通绷带 | 用掉 1 条，按原版规则转成对应的脏布条或脏绷带。 |
| 粗麻布片、奶酪布 | 消耗 1 块。 |

动作完成后才结算用量并恢复 1 点耐久，上限为该枪原有的耐久上限。普通枪和强化枪都可擦拭，耐久归零的枪由现代枪械修理包修复。

进档后可同时携带干毛巾和碎布条，确认子菜单能选材料。用一把已卸弹的磨损枪验证耐久加 1、只扣选中的材料，再试毛巾末次变湿和碎布条变脏。

### 投掷物和能量弹匣制作

打开制作界面的「现代枪械系统」分类。四条配方默认可用，每次产出一件。

| 配方 | 消耗 | 留用工具 |
| --- | --- | --- |
| 制作 MARK-III 进攻型手榴弹 | 枪械金属零件 ×1、火药 3 次用量 | 子弹复装套件 |
| 制作 MARK-II 防御型手榴弹 | 枪械金属零件 ×2、火药 5 次用量 | 子弹复装套件 |
| 改装无引燃气雾罐炸弹 | 原版气雾罐炸弹 ×1 | — |
| 制作能量弹匣（100发） | 枪械弹匣零件 ×2 | — |

能量弹匣产物为猫又岭的空弹匣。制作后用能量子弹装填，再装入猫猫的靛蓝逐罪。在「弹药」分类搜索「制作散装能量子弹（100发）」，一节有电的普通电池直接产出 100 发散弹。该名称对应猫又岭现有散装配方，猫又岭的盒装配方也可以继续使用。

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

Each gun saves its own level. Upgrades increase its minimum and maximum base damage, maximum range, and base critical chance, and scale the bare gun's critical damage multiplier. Attachment bonuses apply separately. The range bonus uses the bare gun's maximum firing range. The game and its sights determine the effective aiming window. The game calculates and clamps the final critical chance after factoring in aiming skill, distance, and other modifiers. Pistols, SMGs, rifles, shotguns, and sniper rifles share the same flow. Scripted flamethrower, grenade and explosion effects use their own damage rules. Nekomata Ridge's DianLanZhuZui supports all five tiers with its dedicated energy bullets. The upgrade menu shows current damage and the applied upgrade bonus. Other weapon packs qualify through the standard firearm interface and need individual testing.

Gunshot attraction radius at +0 through +5 is 100%, 90%, 80%, 70%, 60%, and 50% of the same gun with the same attachments at +0. The upgrade menu and the Modern Firearms inspection panel's **Noise** value use the same effective radius. The game applies its sandbox and indoor modifiers after rounding. Modern Firearms suppressors keep their own radius and world sound strength effects. Audible gunshot gain decreases by 2 percentage points per level, reaching 90% at +5. DianLanZhuZui also qualifies, and existing upgrades use their saved level. DianLanZhuZui goes from 15 tiles at +0 to 8 after rounding at +5. Its special MaoMao upgrade keeps the +5 ratio of 50% and applies its other bonuses as usual.

Only the +5 DianLanZhuZui offers **Firearm Upgrades → MaoMao Upgrade**. Unload it and bring 10 firearm metal components, 8 firearm polymer components, a screwdriver and a hammer. The special upgrade sets the weapon range to 0–800 tiles, adds 200% of base damage, and sets the critical damage multiplier to twice the rifle's original base value (×8 for DianLanZhuZui). The rifle and its selected sight use an 800-tile base aiming distance while equipped. Previously upgraded rifles get the new values on equip at no additional cost. The special upgrade sets the bare rifle's base hit chance to 90%, with native attachment modifiers. Equipping an existing upgraded rifle applies the change automatically. Clearing the upgrade restores its original base hit chance. Native wind penalties apply.

Each shot uses its corresponding original sound on the native firing event, with both sound clips set to 50% gain. Normal shots use the vanilla M16 event. Overload shots use the original recording supplied by the installed copy of Nekomata Ridge, including its quiet lead-in.

**Clear upgrade** removes the damage, range, critical stat, durability, and attraction radius modifiers from that gun. The components cover the original work. Clear upgrades before disabling the patch or converting a firearm into a new item, such as sawing off a shotgun. The bundled ModernFirearmsSystemDamageSandbox addon writes the same attributes and conflicts with this patch.

For manual installation, build the mod directory with the repository rebuild tool and place it in the personal Zomboid/mods directory. Enable it after Modern Firearms System and Nekomata Ridge in the selected single-player save.

B42.22.2 offline checks cover all levels and costs, the one-time range upgrade for 0.2.0 guns, per-item isolation, the installed Modern Firearms System part-stat recalculation, simulated reloads, rollback, and both languages. In game, upgrade one of two identical guns, install and remove a part, change magazines, save and reload, then compare live shots using the same ammo, similar range and the same hit location. The user accepted 0.2.0 in game. Live range, wear, and save reload tests are pending.

### Optional level +5 weight extension

The Firearm Upgrade Extension (local-only) halves firearm and attached-part weight at level +5. It supports B42.22.2 single-player and requires ZombieBuddy 2.3.4. Enable the extension after this patch and approve the extension JAR. It reads existing level +5 records. Disabling the extension and restarting restores normal weight while the Lua upgrade continues to work. In-game acceptance is pending.

### Wipe firearm

When SuQing's Wipe Repair 1.0.0 is enabled, it provides the firearm wiping menu. This patch provides the firearm wiping menu when used alone or with the earlier 0.2.0 melee wipe mod. [Wipe Repair guide](SuQingMeleeWeaponWipe_4222.md)

Carry a wiping material and right-click one unloaded, damaged, working firearm in your inventory. Choose **Wipe firearm** to use the only available material type directly, or choose a material from the submenu if several types are available. The tooltip previews condition before and after wiping and how much material the action will use.

| Material | Cost per wipe |
| --- | --- |
| Dry dish towel, dry bath towel | One use. Each holds 10 uses when full and becomes the corresponding wet item after its last use. |
| Clean rag, denim strip, ordinary bandage | One piece, which becomes the corresponding dirty item through the game's own item handling. |
| Burlap piece, cheesecloth | One piece. |

Each completed wipe uses the selected material and restores one point, up to the firearm's existing condition limit. Both regular and upgraded firearms qualify. The existing MFS repair kit covers broken firearms.

In game, carry a dry bath towel and a clean rag to check material selection. Wipe a worn, unloaded gun to verify one condition point and the selected material cost. Confirm that the last towel use produces a wet towel and that the rag becomes dirty.

### Throwable and energy magazine crafting

Open the Modern Firearms System category in the crafting menu. All four recipes are available by default and make one item each.

| Recipe | Consumes | Reusable tool |
| --- | --- | --- |
| Make MARK-III Offensive Grenade | 1 firearm metal component and 3 uses of gunpowder | Ammunition Reloading Kit |
| Make MARK-II Defensive Fragmentation Grenade | 2 firearm metal components and 5 uses of gunpowder | Ammunition Reloading Kit |
| Modify Aerosol Bomb to Prevent Ignition | 1 vanilla aerosol bomb | — |
| Make Energy Magazine (100 Rounds) | 2 firearm magazine components | — |

The recipe produces Nekomata Ridge's empty magazine. Load it with energy bullets before inserting it into DianLanZhuZui. Under Ammunition, choose **Convert Battery to Loose Energy Rounds (100)** to turn one battery with remaining charge into 100 loose rounds. This label uses Nekomata Ridge's existing loose-round recipe. The boxed recipe is also available.

The B42.22.2 native recipe parser and both translations passed offline. In game, craft one of each, check material use and kit retention, then verify throwing and detonation.

0.2.0 使用新的单枪强化记录格式。此前仅加伤害的强化记录不迁移。

Version 0.2.0 uses a new per-gun upgrade record format. Legacy damage-only upgrade records are not migrated.

0.2.0 已强化的枪在首次装备时按原等级补齐最大射程，无需再花材料。

Guns upgraded in 0.2.0 receive the maximum-range bonus for their existing level when first equipped, at no additional material cost.

0.4.0 的五档磨损概率累计降低 10%、20%、30%、40%、50%。根据裸枪原始磨损判定的分母计算，结果取最接近的整数。例如满级 M110 从 1/118 降至 1/236。装备已有强化的枪时应用对应耐用加成。维护状态仍由原生当前耐久和耐久上限表示。

Version 0.4.0 reduces wear probability by 10%, 20%, 30%, 40%, and 50% across the five levels. The result is rounded to the nearest integer denominator using the bare gun's script value. A +5 M110 wears at 1/236 per check, down from 1/118. Previously upgraded guns gain the bonus when equipped. Current condition and maximum condition continue to use the game's normal values.
