# 蘇清的擦拭修复 / SuQing's Wipe Repair

| 项目 / Field | 内容 / Details |
| --- | --- |
| Mod ID | SuQingMeleeWeaponWipe_4222 |
| 版本 / Version | 1.0.0 |
| 游戏 / Game | B42.22.2 单人模式 / single-player |
| 依赖 / Dependencies | 仅需原版游戏 / Base game only |

## 简体中文

随身携带干净的擦拭材料，在物品栏里右键一把可用的近战武器或已卸弹的可用枪械，选择「擦拭维护」。枪械需取下可拆弹匣，并清空枪膛和固定弹仓。只有一种材料可用时可直接擦拭，有多种时从子菜单选择。提示会预览耐久、适用的锋利度和材料用量。

| 材料 | 每次擦拭的用量 |
| --- | --- |
| 干抹布、干毛巾 | 扣 1 次用量。满状态有 10 次，最后一次用完后变湿。 |
| 干净的碎布条、牛仔布条、普通绷带 | 用掉 1 条，并转成对应的脏布条或脏绷带。 |
| 粗麻布片、奶酪布 | 消耗 1 块。 |

布条请先拆包，取出单条使用。干净的普通布条和绷带可用于擦拭，消毒用品可留作医疗用途。

每次完成动作使用所选材料一次。枪械恢复 1 点耐久，近战武器恢复 1 点主体耐久。有独立头部耐久的近战武器，头部也恢复 1 点。各项耐久以武器自身上限为准。有锋利度的近战武器再恢复最多 5 个百分点。游戏按恢复后的头部耐久限制锋利度，无独立头部时按主体耐久限制。比如猎刀可从耐久 6/10、锋利度 40% 擦到 7/10、45%。满耐久的钝刀仍可擦拭，也可以单独维护撬棍等钝器的耐久。

耐久和适用的锋利度都达到当前上限时，擦拭不可用。彻底损坏的武器沿用游戏中的修理途径。中途取消、武器或所选材料离开随身物品栏时，动作不会扣用量或恢复数值。

本版沿用 0.2.0 的 Mod ID。原版和符合枪械接口的现代枪械系统武器都可使用。与蘇清的现代枪械强化补丁 0.7.1 一起启用时，枪械擦拭菜单由本模组提供。 [枪械强化补丁说明](SuQingMFSFirearmUpgrade_4221.md)

### 游戏内验收

1. 同时带干毛巾、碎布条和奶酪布，右键磨损的武器，确认子菜单可选择材料。只带一种材料时检查能否直接擦拭。
2. 擦拭一把磨损的猎刀或斧头和一把磨损的已卸弹枪械，核对所选材料的用量和适用属性的恢复量。与枪械强化补丁 0.7.1 同用时，检查枪械菜单只出现一个擦拭选项。中途取消一次，核对用量和数值。
3. 用掉干毛巾的最后一次用量，确认背包得到湿毛巾。检查碎布条转成脏碎布条，奶酪布用一次消耗一块。保存重进后核对武器耐久与锋利度。

手动安装时，将模组目录放入个人 `Zomboid/mods`，在要使用的单人档启用。可通过同一模组名单停用补丁，擦拭后保存的武器属性由游戏继续读取。 [补丁源码](../../src/SuQingMeleeWeaponWipe_4222)

## English

Carry a clean wiping material, right-click one usable melee weapon or unloaded firearm in your inventory, and choose **Wipe weapon**. Remove any detachable magazine and empty the chamber and internal magazine. When only one material type is available, the action starts directly. If you have several, choose a material from the submenu. The tooltip previews condition, sharpness where applicable, and material use.

| Material | Cost per wipe |
| --- | --- |
| Dry dish towel, dry bath towel | One use. Each holds 10 uses when full and becomes wet after its last use. |
| Clean rag, denim strip, ordinary bandage | One piece, which becomes the corresponding dirty rag, strip, or bandage. |
| Burlap piece, cheesecloth | One piece. |

Unpack bundled rags or denim strips before using them. Use clean, ordinary rags or bandages and save sterilized supplies for first aid.

Each completed wipe uses the selected material once. Firearms regain one point of condition and melee weapons regain one point of general condition. Melee weapons with separate head condition also regain one point of head condition. Each value is capped at the weapon's own maximum. A melee weapon with sharpness also regains up to 5 percentage points. The game caps sharpness using the updated head condition, or general condition for weapons without a separate head. For example, a hunting knife can go from 6/10 condition and 40% sharpness to 7/10 and 45%. A dull knife at full condition can still be wiped, and blunt weapons such as crowbars regain condition.

The action is unavailable when every applicable stat is at its current limit. Use the game's repair options for broken weapons. Cancelling a wipe or moving the weapon or selected material out of carried inventory leaves the material uses and weapon stats as they were.

This release uses the same Mod ID as 0.2.0. It supports base-game firearms and compatible Modern Firearms System guns. When used with SuQing's Modern Firearm Upgrades 0.7.1, this mod provides the firearm wiping menu. [Firearm Upgrades guide](SuQingMFSFirearmUpgrade_4221.md)

### In-game checks

1. Carry a dry bath towel, a rag, and a cheesecloth. Right-click a worn weapon and check that the submenu lets you pick one. With just one material type available, check that wiping starts directly.
2. Wipe a worn hunting knife or axe and a worn, unloaded firearm. Confirm the material cost and the recovery of each applicable stat. With Modern Firearm Upgrades 0.7.1 active, check that guns have a single wipe option. Cancel a wipe midway and check the material and weapon stats.
3. Spend the bath towel's final use and confirm that a wet bath towel appears. Check that a clean rag becomes a dirty rag and that one cheesecloth is consumed per wipe. Save and reload to check the weapon's condition and sharpness.

For manual installation, place the mod directory in your personal `Zomboid/mods` folder and enable it for the intended single-player save. Disable it through the same list. The game still reads the weapon stats saved after wiping. [Patch source](../../src/SuQingMeleeWeaponWipe_4222)
