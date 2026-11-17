# 蘇清的现代枪械弹药重量补丁 / SuQing's MFS Ammunition Weight

SuQingMFSAmmoWeight_4222 · 1.0.0 · B42.22.2 单人 / single-player

## 中文

依赖 Modern Firearms System。把已核对的现实参考重量方案统一乘 0.5，覆盖正式档可用的 45 种弹匣、弹鼓和弹链盒、16 种散装弹药、28 种弹药包装。弹匣满装重量由游戏按空重加当前发数乘单发重计算。M240 盒的固定基重包含链节折算。兼容当前 TrueWeight，补丁在地图区域加载事件中应用指定物品的绝对重量。普通换匣和自动装弹 25 发继续使用原配置。TrueWeight 日志在补丁应用前生成，最终负重以进档后的库存提示为准。

- 独立模组中的武士之刃和阿尔伯特弹匣、SHG-M9 弹匣、手工连弩和猫猫能量弹在相应模组启用且物品存在时生效。SHG-M9 弹匣补齐了 B42.22.2 可读取的中英物品名称，避免显示为完整 ID 时引擎将重量记为 0。
- MFS 的 6.8mm 与原版短左轮共用 Base.Bullets38。MG42 弹鼓继续使用共用 .308 弹药。下挂发射器与榴弹匣共用 Base.GrenadeAmmo。
- 按实际拆包数量计算弹盒与整箱。半倍率包装皮重为普通盒 0.025、重型盒 0.04、普通箱 0.25、重型箱 0.40、连弩箭捆 0.005。现装 MFS 的 .44、.308 和 5.56 每盒 50 发，重量按该配方核算。动态 IO 储存箱和显式设置了自定义重量的库存实例沿用原存储规则。

将冻结包内的模组目录放入本地 mods，在目标单人档启用并重新读档。查看旧的 5.56 60 发鼓空重 0.29、满重 0.65，再查看 .50 BMG 20 发鼓空重 0.425、满重 1.575。装匣、开火一发、卸匣并读回弹数。检查 .50 BMG 整箱 14.68 可拆为 12 盒，14.5mm 整箱 19.80 可拆为 10 盒。停用后重新读档，恢复剩余模组计算的重量。

## English

Requires Modern Firearms System. This patch uses half of the proposed real-world reference weights for 45 magazines, drums and belt boxes, 16 loose ammunition types and 28 fixed packs. The game adds the empty magazine weight to the current round count times the weight per round. The fixed M240 belt-box weight includes an allowance for links. The map-zone load event applies the specified absolute weights after the current TrueWeight hook. Existing reload speeds and the 25-round auto-loading configuration remain in use. TrueWeight writes its log before the patch runs. Inspect the inventory after loading the save for the final values.

- Raccoon City, SHG-M9, the Primitive Equipment crossbow and Nekomata items are adjusted when their item definitions are present. English and Chinese names for the SHG-M9 magazine let B42.22.2 report the adjusted weight. The game reports zero weight when the displayed name equals the item ID.
- The MFS 6.8mm and the vanilla short revolver share Base.Bullets38. The MG42 drum continues to use the shared .308 ammunition. Underbarrel launchers and grenade magazines share Base.GrenadeAmmo.
- Box and carton weights include the ammunition and packaging. Half-scale tare is 0.025 for a standard box, 0.04 for a heavy box, 0.25 for a standard carton, 0.40 for a heavy carton and 0.005 for an arrow bundle. The installed MFS recipes pack 50 rounds per box for .44, .308 and 5.56. Dynamic IO containers and inventory items with an explicit stored custom weight follow their existing rules.

Copy the frozen mod folder to local mods, enable it for the intended single-player save and reload. Check an existing 60-round 5.56 drum at 0.29 empty and 0.65 full, and a 20-round .50 BMG drum at 0.425 empty and 1.575 full. Insert the magazine, fire one round, remove the magazine and check its remaining count. Check that the 14.68 .50 BMG carton splits into 12 boxes and the 19.80 14.5 mm carton splits into 10 boxes. Disabling the patch and reloading restores the weights supplied by the other enabled mods.

## 重建 / Rebuild

    python tools/rebuild.py --mod-id SuQingMFSAmmoWeight_4222 --check
    python tools/rebuild.py --mod-id SuQingMFSAmmoWeight_4222 --output ../mfs-ammo-weight-built

## 重量表 / Weight table

[运行时完整 ID 与重量 / Runtime item IDs and weights](../../src/SuQingMFSAmmoWeight_4222/42/media/lua/shared/SuQingMFSAmmoWeight/Weights.lua)
