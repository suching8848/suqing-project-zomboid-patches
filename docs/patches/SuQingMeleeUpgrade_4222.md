# 蘇清的近战强化 | SuQing’s Melee Upgrade

## 简体中文

B42.22.2（`3d39148846`）单人候选 0.2.0，Mod ID `SuQingMeleeUpgrade_4222`。前置为 ZombieBuddy 2.3.4，运行所用 JAR 需要精确批准。

在自己物品栏中右键单件可用的近战武器，选择强化。每次消耗 2 枚钉子、1 块小金属板、1 条碎布条。随身携带带原生 `base:hammer` 标签且可用的锤子，锤子作为保留工具。目标武器和锤子分开选择。动作完成前再次校验，取消时保留材料。

| 等级 | 主体与独立刀头上限 | 基础伤害 | 主体和刀头磨损触发率 | 武器重量 |
| --- | ---: | ---: | ---: | ---: |
| +1 | 2 倍 | 2 倍 | 原版的 1/2 | 100% |
| +2 | 4 倍 | 4 倍 | 原版的 1/4 | 100% |
| +3 | 8 倍 | 8 倍 | 原版的 1/8 | 50% |

三档伤害与耐久上限按未强化基值计算。主体耐久上限最多 127 点，独立刀头按属性上限截断并继承原有上限来源。升级时按当前耐久比例换算现值，整数换算兼顾现有锋利度。武器在原物品实例上升级。游戏按主体上限计算每次锋利度损失，正锋利度的原生触发率照常。零锋利度引起的实体耐久损失也应用本档磨损倍率。降损作用于原生磨损判定，其他模组直接修改耐久值的操作遵循各自规则。

已强化到 +1、+2 的武器可继续升级。+3 通过原生武器重量查询将实际重量减半，读档后按保存的等级生效。主体上限和剩余耐久由 Java 读写补丁恢复，独立刀头与伤害随原生物品数据保存。磨刀沿用当前主体或独立刀头的耐久比例，最高 100% 锋利度。擦拭和修理受当前耐久上限约束。回退到 0.1.0 时，使用强化到 +3 之前的存档和旧 JAR 一并恢复。

## English

Single-player candidate 0.2.0 for Build 42.22.2 (`3d39148846`), Mod ID `SuQingMeleeUpgrade_4222`. Requires ZombieBuddy 2.3.4 and approval of the specific JAR.

Right-click a single eligible melee weapon in your inventory. Each upgrade consumes 2 nails, 1 small metal sheet and 1 ripped sheet. Carry a working tool with the native `base:hammer` tag. The hammer is kept and must be a different item from the weapon being upgraded. The action checks the selected items again before committing. Canceling keeps the supplies.

| Level | Body and separate head condition caps | Base damage | Body and head wear chance | Weapon weight |
| --- | ---: | ---: | ---: | ---: |
| +1 | 2× | 2× | 1/2 of normal | 100% |
| +2 | 4× | 4× | 1/4 of normal | 100% |
| +3 | 8× | 8× | 1/8 of normal | 50% |

All three levels scale damage and condition caps from the unupgraded stats. Body condition caps at 127. Head condition follows its native attribute cap and fallback rules. Remaining condition scales with the cap, with rounding that preserves existing sharpness. The same weapon instance is retained. The game uses body condition capacity to calculate the amount of sharpness lost per successful roll. The zero-sharpness branch also receives the reduction when it causes physical wear. The probability change affects native wear checks. Direct edits by other mods follow their own rules.

Existing +1 and +2 weapons can be upgraded further. At +3, the native weapon weight query returns half the weight based on the saved level. Java hooks restore the body cap and remaining condition. Native weapon data stores damage and separate head condition. Sharpening follows the current body or head condition ratio with a 100% ceiling. Wiping and repairs respect the upgraded condition caps. To roll back to 0.1.0, use the previous JAR with a save made before upgrading a weapon to +3.
