# 蘇清的现代枪械弹药名称修复 / SuQing's MFS Chinese Ammo Names

SuQingMFSAmmo38NamesCN_4222 · 1.1.0 · B42.22.2 单人 / single-player

## 中文

依赖现代枪械系统。启用时加载于现代枪械、B42 基础汉化、B42 模组汉化和栀子汉化之后。1.1.0 沿用 1.0.0 的 Mod ID，将原先 6.8mm 三个名称的覆盖范围扩展到下表 36 条。从当前现代枪械工坊原包的简中物品表逐字取值。

| 弹药 | 散装 | 盒装 | 整箱 |
| --- | --- | --- | --- |
| 9mm | 9mm 弹药 | 9mm 盒装弹药 | 9mm 弹药整箱 |
| .44 | .44 马格南弹药 | .44 马格南盒装弹药 | .44 马格南弹药整箱 |
| .45 | .45 弹药 | .45 盒装弹药 | .45 弹药整箱 |
| .50 | .50 弹药 | .50 盒装弹药 | .50 弹药整箱 |
| 5.45 | 5.45 弹药 | 5.45 盒装弹药 | 5.45 弹药整箱 |
| 5.56 | 5.56 弹药 | 5.56 盒装弹药 | 5.56 弹药整箱 |
| 5.8mm | 5.8mm 弹药 | 5.8mm 盒装弹药 | 5.8mm 弹药整箱 |
| 6.8mm | 6.8mm 弹药 | 6.8mm 盒装弹药 | 6.8mm 弹药整箱 |
| 7.62 | 7.62 弹药 | 7.62 盒装弹药 | 7.62 弹药整箱 |
| 8.6mm | 8.6mm 弹药 | 8.6mm 盒装弹药 | 8.6mm 弹药整箱 |
| 14.5mm | 14.5mm 重型弹药 | 14.5mm 盒装弹药 | 14.5mm 弹药整箱 |
| 霰弹 / Shotgun shells | 霰弹 | 盒装霰弹 | 霰弹整箱 |

6.8mm 的原生物品 ID 是 `Base.Bullets38`，7.62 的原生物品 ID 是 `Base.308Bullets`。和它们共用 ID 的原版枪械也会看到相同名称。

将冻结包内的目录装入本地 mods 并在目标存档启用。从 1.0.0 升级后重新启动游戏，进档查看 .44、7.62 和 6.8mm 的物品名。停用补丁并重启后，由其他已启用模组提供名称。

## English

Requires Modern Firearms System. Load after MFS and the B42 base, B42 mod, and Gardenia Simplified Chinese translations when enabled. Version 1.1.0 retains the Mod ID from version 1.0.0 and restores the 36 author-supplied Simplified Chinese names above. It covers loose rounds, boxes and cartons of the 12 primary cartridge and shotgun-shell families. MFS 6.8mm and 7.62 retain the shared item IDs `Base.Bullets38` and `Base.308Bullets`, so vanilla weapons using those IDs show the same labels.

Install the packaged folder in the local mods directory and enable it for the intended single-player save. Restart after updating from 1.0.0 and inspect the .44, 7.62 and 6.8mm inventory names. Disabling the patch and restarting restores the names from the other enabled mods.

## 本机重建 / Local build

    python tools/rebuild.py --mod-id SuQingMFSAmmo38NamesCN_4222 --check
    python tools/rebuild.py --mod-id SuQingMFSAmmo38NamesCN_4222 --output ../mfs-ammo-names-built
