# 增强消防斧耐久保险 / Trusty Fire Axe Condition Guard

## 简体中文

`SuQingTrustyAxeConditionGuard_4222` 0.1.0 适用 B42.22.2 单人模式，依赖 `TrustyFireAxeRedux`（工坊 3400045232）。

增强消防斧 `TrustyFireAxe.Trusty_Firefighter_Axe` 初始斧刃耐久为 32，未单独声明斧刃上限。原版回退到整斧上限 26，所以磨刀可能计算出 32 ÷ 26 ≈ 123% 的目标，实际锋利度最高可写入 100%。达到 100% 后，原版循环仍可能继续。

补丁将新斧的初始斧刃耐久压到已声明的上限。进档、装备、在物品栏右键选中或执行磨刀时，旧斧也会在超限时压回游戏计算出的上限。磨刀石、锉刀和砂轮都继续使用原版结算。26 是当前模组和游戏版本计算的结果，补丁读取实际数值。

启用后用出过问题的增强消防斧复测同一个磨刀入口。斧刃未满时确认动作开始、进度结束和磨后锋利度。已经磨满的斧头可能由原版隐藏磨刀选项。停用可撤销运行时保护，已保存的斧刃数值需通过同一时间点的备份恢复。两次挂起均未抓到磨刀线程栈，游戏内验收待完成。

## English

`SuQingTrustyAxeConditionGuard_4222` 0.1.0 targets Build 42.22.2 single-player and requires `TrustyFireAxeRedux` (Workshop 3400045232).

The assembled Trusty Firefighter Axe, `TrustyFireAxe.Trusty_Firefighter_Axe`, starts with 32 blade condition and declares no separate blade maximum. The game uses the weapon's general maximum of 26. Sharpening can therefore target about 123% while the native setter caps sharpness at 100%, which can leave the sharpening loop running.

The patch clamps the template and corrects over-limit axe instances when loading the player's inventory, equipping the axe, opening its inventory context menu, or sharpening it. The whetstone, file and grindstone keep their original sharpening logic. The cap is read from the game, which currently resolves it to 26.

After enabling the patch, retest the action that hung using the same axe. With a blade below full sharpness, check that the action starts, finishes and displays the resulting sharpness. The game may hide sharpening when the blade is already sharp. Disabling removes the runtime guard. Restoring earlier saved values requires a matching backup. The hang was observed without a sharpening stack trace, and in-game verification is pending.
