# 蘇清的僵尸毁灭工程补丁合集 / SuQing’s Project Zomboid Patch Collection

[中文](README.md) · [English](README.en.md)

面向 **Project Zomboid Build 42.21 单人环境**，收录蘇清维护的 **33 个独立 Mod ID**：兼容修复、汉化、菜单与性能优化、药物状态面板及其他小型扩展。每个补丁可单独选择，不是一个要求全部启用的合并模组。

[10 个源码仓库与 42 个 Mod ID](docs/project-index.md) · [2026-11-02 01:10 的单人档启用快照](docs/current-single-player-modlist.md) · [作者 Steam 合集](https://steamcommunity.com/sharedfiles/filedetails/?id=3823981387)

个人安装状态与后续安排见[源码范围与个人安装状态](docs/project-index.md)。2026-11-03用户已授权本轮统一Git与Steam更新；已正常实现所需效果的个人组合可保留原版本。音乐与饵托仍待游戏内验收；负重训练个人0.3.1反馈正常，源码0.3.2新美术待视觉验收。上传与源码同步不代替玩法验收。

## 主模组与补丁怎样搭配

**先选主模组，再按使用场景选补丁。** 下表中的“条件需要”只针对对应组合，不代表其他玩家也必须安装。`require` 是声明前置；`loadModAfter` 只是加载关系提示，不应把所有顺序提示都当作必装项。

| 主模组或使用场景 | 应选项目与关系 |
| --- | --- |
| [普通容器升级 1.0.1](https://github.com/suching8848/suqing-container-upgrade) | 基础功能不强制依赖合集。1.0.1 已内置针剂盒、Chemical 胸挂、HavenFall 前后腰包四项普通升级适配；个人 1.0.0 可由现有桥接提供这四项，不必仅因版本号而升级。旧普通注册器在 1.0.1 下跳过，同包 HavenFall EX 桥接仍独立工作，不能整包停用 |
| [EX 背包升级](https://github.com/suching8848/suqing-backpack-super-upgrade)＋猫又岭 | 容量包装链兼容用 `CodexNekomataEXCompat_4221`；要增加猫猫背包 EX 配方，还需 `CodexNekomataEXUpgrade_4221`。扩展明确依赖兼容层、猫又岭及 EX |
| EX＋HavenFall 大背包 | 条件需要 `Codex_SuQingWearableCompat_4221`。它声明依赖普通容器升级、EX 和 HavenFall，EX 桥接独立于旧普通注册适配器。不能因为想用桥接就忽略这些前置，或强行与自动容器实验版组合 |
| [自动容器实验版](https://github.com/suching8848/suqing-container-auto-upgrade) | 与普通容器版是替代关系，不能同时启用；当前正式档未启用该实验版 |
| MFS 与[减重挂件](https://github.com/suching8848/suqing-modern-firearms-weight-charms) | 挂件只强制 MFS。瞄具标签、弹药视觉、枪灯快捷键各补丁针对独立问题；[固定收购](https://github.com/suching8848/suqing-mfs-fixed-buyback)也是独立项目，均不应误当成挂件的通用前置 |
| N&C’s Narcotics | 汉化与状态面板均依赖 N&C 原作，按需选择；状态面板只读显示，不是药物本体 |
| XFACTION Dynamic Traits | 汉化、进度保护分别针对原作；人物菜单补丁另声明需要 XFACTION 汉化。不能只拷贝菜单补丁而遗漏它的前置 |
| [灌溉养护](https://github.com/suching8848/suqing-sprinkler-fertilizer)与 Batch Farming | 灌溉养护强制 Water Pipes；本合集的批量农耕菜单筛选只给 `vac_batch_farming` 用，不是灌溉养护的必装项 |
| [冷藏升级](https://github.com/suching8848/suqing-refrigeration-upgrade) | 没有强制的合集补丁；标准穿戴容器由原游戏或来源模组提供，特殊转换组合按该项目说明验证 |
| PZ Optimization 汉化 | 依赖匹配的外部引擎/UI 版本 154126d0；元数据没有 `require` 不代表无需安装引擎补丁。更新或移除引擎前先核对并停用此覆盖层 |
| Chemical 独立兼容构建 | 构建需要已安装的原始资源；独立版不把来源素材公开复制进 Git。游戏使用独立构建时，按子说明保持原 C.B.R.T. Chemical 关闭 |

每项子说明同时记录 Mod ID、原始 `require`、加载关系、实际功能和验证边界。保留你已有的相对顺序，仅按所选项目满足依赖；不要全选合集或自动重排整份名单。

## 获取可安装文件

仓库保存自制源码、必要的差异文件、原作来源与精确哈希。涉及上游完整车辆脚本、界面覆盖、模型/贴图、针剂回退参考文件的项目，通过本机已安装原作重建，不附带一份无来源说明的第三方整包。

需要 **Python 3.10+**。以下命令只读来源，在全新独立目录生成补丁；不会订阅、下载、部署到游戏或修改存档。

只生成一个不需要外部文件重建的小补丁：

```powershell
python tools/rebuild.py --mod-id Codex_MFSOpticsFix_4221 --output ../suqing-selected-patches
```

重建并校验全部 33 项。将示例 Steam 库路径换成自己的实际安装路径；输出目录必须尚不存在：

```powershell
python tools/rebuild.py --check --workshop-root "D:/SteamLibrary/steamapps/workshop/content/108600" --game-root "D:/SteamLibrary/steamapps/common/ProjectZomboid"
python tools/rebuild.py --output ../suqing-patches-built --workshop-root "D:/SteamLibrary/steamapps/workshop/content/108600" --game-root "D:/SteamLibrary/steamapps/common/ProjectZomboid"
```

`--mod-id` 可以重复指定，只构建选中的子项。重建器对来源与输出逐文件检查 SHA-256，来源版本不符会明确失败，不自动套用模糊差异；不要为绕过检查而关闭校验。

成功后，输出目录中的各个子文件夹才是可安装的独立模组。正常退出游戏，再将需要的完整子文件夹放入自己的 `Zomboid/mods`，保留版本与 `common` 目录，满足原作前置后按需启用。不要把整个仓库、`src` 或 `patches` 文件夹直接当作一个模组安装；不要保留同 Mod ID 的重复来源。

## 33 项补丁索引

| 中英名称 / Bilingual name | Mod ID | 声明前置 / Declared requirements |
| --- | --- | --- |
| [蘇清的洗衣皂中文文本修复补丁 / SuQing’s Washing Soap Chinese Text Fix Patch](docs/patches/Codex_AmmoBox_CN_TextFix_4221.md) | `Codex_AmmoBox_CN_TextFix_4221` | `B42ModTrans_CN` |
| [蘇清的挂点物品分组与穿戴菜单修复补丁 / SuQing’s Attached Item Grouping and Wear Menu Fix Patch](docs/patches/Codex_AttachedGrouping_4221.md) | `Codex_AttachedGrouping_4221` | `CleanUI` |
| [蘇清的房车手套箱容器兼容补丁 / SuQing’s Campers Glovebox Compatibility Patch](docs/patches/Codex_Campers_Glovebox_4221.md) | `Codex_Campers_Glovebox_4221` | `KI5campers` |
| [蘇清的中华菜与N&C种子提示兼容补丁 / SuQing’s Chinese Cuisine and N&C Seed Tooltips Patch](docs/patches/Codex_ChineseCrop_Tooltip_4221.md) | `Codex_ChineseCrop_Tooltip_4221` | `Chinesecuisine4213`, `MoreItemInformation` |
| [蘇清的Fashionoid储液提示兼容补丁 / SuQing’s Fashionoid Fluid Tooltip Compatibility Patch](docs/patches/Codex_FashionoidFluidTooltip_4221.md) | `Codex_FashionoidFluidTooltip_4221` | `Fashionoid42` |
| [蘇清的MFS瞄具标签修复补丁 / SuQing’s MFS Optics Tag Fix Patch](docs/patches/Codex_MFSOpticsFix_4221.md) | `Codex_MFSOpticsFix_4221` | `ModernFirearmsSystem` |
| [蘇清的Mustang引擎盖配方输入保护补丁 / SuQing’s Mustang Hood Recipe Guard Patch](docs/patches/Codex_MustangRecipeGuard_4221.md) | `Codex_MustangRecipeGuard_4221` | `ATA_Mustang` |
| [蘇清的N&C药物状态面板补丁 / SuQing’s N&C Drug Status Panel Patch](docs/patches/Codex_NarcoticsStatus_4221.md) | `Codex_NarcoticsStatus_4221` | `N&CsNarcotics` |
| [蘇清的针剂减重与肾上腺素笔兼容补丁 / SuQing’s Stim Weight and Adrenapen Compatibility Patch](docs/patches/Codex_StimCompatibility_4221.md) | `Codex_StimCompatibility_4221` | `TarkovCombatStims`, `AdrenalineShot` |
| [蘇清的旧普通容器桥接与HavenFall EX兼容补丁 / SuQing’s Legacy Container Bridge and HavenFall EX Compatibility Patch](docs/patches/Codex_SuQingWearableCompat_4221.md) | `Codex_SuQingWearableCompat_4221` | `SuQingContainerUpgrade_4221`, `ExSuQingBackpackSuperUpgrade_4221`, `HavenFall` |
| [蘇清的XFACTION进度记录保护补丁 / SuQing’s XFACTION Progress Record Guard Patch](docs/patches/Codex_XFDynamicRecordGuard_4221.md) | `Codex_XFDynamicRecordGuard_4221` | `XFACTION_DynamicTraits` |
| [蘇清的Chemical独立兼容构建补丁 / SuQing’s Chemical Independent Compatibility Build Patch](docs/patches/CodexCBRTIndependent_4221.md) | `CodexCBRTIndependent_4221` | 未声明 Mod ID；另看外部构建/引擎要求 / None declared; see external build/engine requirements |
| [蘇清的人物菜单调整补丁 / SuQing’s Character Menu Tweaks Patch](docs/patches/CodexCharacterMenuTweaks_4221.md) | `CodexCharacterMenuTweaks_4221` | `XFACTION_DynamicTraits`, `CodexXFACTION_CN_4221` |
| [蘇清的N&C中文补丁 / SuQing’s N&C Chinese Translation Patch](docs/patches/CodexNarcotics_CN_4221.md) | `CodexNarcotics_CN_4221` | `N&CsNarcotics` |
| [蘇清的猫又岭与EX兼容桥接补丁 / SuQing’s Nekomata Ridge and EX Compatibility Patch](docs/patches/CodexNekomataEXCompat_4221.md) | `CodexNekomataEXCompat_4221` | `Nekomata Ridge`, `ExSuQingBackpackSuperUpgrade_4221` |
| [蘇清的猫猫背包EX升级扩展补丁 / SuQing’s Nekomata Backpack EX Upgrade Extension Patch](docs/patches/CodexNekomataEXUpgrade_4221.md) | `CodexNekomataEXUpgrade_4221` | `CodexNekomataEXCompat_4221`, `Nekomata Ridge`, `ExSuQingBackpackSuperUpgrade_4221` |
| [蘇清的PZ Optimization设置汉化补丁 / SuQing’s PZ Optimization Chinese Settings Patch](docs/patches/CodexPZOptimization_CN_4221.md) | `CodexPZOptimization_CN_4221` | 未声明 Mod ID；另看外部构建/引擎要求 / None declared; see external build/engine requirements |
| [蘇清的True 3D Items百分号提示修复补丁 / SuQing’s True 3D Items Percent Tooltip Fix Patch](docs/patches/CodexTranslatorPercentFix_4221.md) | `CodexTranslatorPercentFix_4221` | `ProjectFullHD` |
| [蘇清的XFACTION动态特性汉化补丁 / SuQing’s XFACTION Dynamic Traits Chinese Translation Patch](docs/patches/CodexXFACTION_CN_4221.md) | `CodexXFACTION_CN_4221` | `XFACTION_DynamicTraits` |
| [蘇清的DAMN原版轮胎维修兼容补丁 / SuQing’s DAMN Vanilla Tire Repair Compatibility Patch](docs/patches/Codex_DAMN_VanillaTires_4221.md) | `Codex_DAMN_VanillaTires_4221` | `damnlib` |
| [蘇清的Erika家具与可选调试生成器修复补丁 / SuQing’s Erika Furniture and Optional Debug Generator Fix Patch](docs/patches/Codex_DebugMenu_Generator_4221.md) | `Codex_DebugMenu_Generator_4221` | 未声明 Mod ID；另看外部构建/引擎要求 / None declared; see external build/engine requirements |
| [蘇清的批量转移库存刷新优化补丁 / SuQing’s Bulk Transfer Inventory Refresh Optimization Patch](docs/patches/Codex_InventoryTransferPerformance_4221.md) | `Codex_InventoryTransferPerformance_4221` | `CleanUI` |
| [蘇清的MFS弹药盒与弹匣显示兼容补丁 / SuQing’s MFS Ammo Box and Magazine Visual Compatibility Patch](docs/patches/Codex_MFS_AmmoVisual_Compat_4221.md) | `Codex_MFS_AmmoVisual_Compat_4221` | `ModernFirearmsSystem` |
| [蘇清的MFS附加手电快捷键修复补丁 / SuQing’s MFS Attached Flashlight Hotkey Fix Patch](docs/patches/Codex_MFS_AttachedLight_Hotkey_4221.md) | `Codex_MFS_AttachedLight_Hotkey_4221` | `ModernFirearmsSystem` |
| [蘇清的Noir枪带单人兼容补丁 / SuQing’s Noir Sling Single-player Compatibility Patch](docs/patches/Codex_NoirSling_SP_Compat_4221.md) | `Codex_NoirSling_SP_Compat_4221` | `noirrsling4-42.13patch` |
| [蘇清的拼音搜索与界面兼容补丁 / SuQing’s Pinyin Search UI Compatibility Patch](docs/patches/PinyinSearch_SafeSources_4221_LocalFix.md) | `PinyinSearch_SafeSources_4221_LocalFix` | `yxjs_PinYinSearch` |
| [蘇清的原始装备储液提示修复补丁 / SuQing’s Primitive Equipment Fluid Tooltip Fix Patch](docs/patches/Codex_PrimitiveTooltip_4221.md) | `Codex_PrimitiveTooltip_4221` | `SuPrimitiveEquipment` |
| [蘇清的批量农耕菜单筛选补丁 / SuQing’s Batch Farming Menu Filter Patch](docs/patches/SuQingBatchFarmingMenu_4221.md) | `SuQingBatchFarmingMenu_4221` | `vac_batch_farming` |
| [蘇清的They Knew沙盒文本修复补丁 / SuQing’s They Knew Sandbox Text Fix Patch](docs/patches/Codex_TheyKnew_CN_TextFix_4221.md) | `Codex_TheyKnew_CN_TextFix_4221` | `TheyKnewContinued` |
| [蘇清的True Music耳机单人兼容补丁 / SuQing’s True Music Headphones Single-player Compatibility Patch](docs/patches/Codex_TrueMusic_Headphones_4221.md) | `Codex_TrueMusic_Headphones_4221` | `truemusic` |
| [蘇清的蛋白饮料训练强化 / Protein Shake Training Boost](docs/patches/SuQingProteinTrainingBoost.md) | `SuQingProteinTrainingBoost` | `VanillaFoodsExpanded` |
| [蘇清的配方材料输入修复 / Recipe Input Guard](docs/patches/SuQingRecipeInputGuard_4221.md) | `SuQingRecipeInputGuard_4221` | `SapphCooking_B42` |
| [蘇清的饵托量产补丁 / SuQing's Chum Mass Production Patch](docs/patches/SuQingChumMassProduction.md) | `SuQingChumMassProduction` | 无 / None |

## 验证与来源

内容重建检查保证与所记录的运行文件字节一致，不代表上游之后的版本、每个可选组合、多人或专用服务器已通过实际玩法测试。作者此前确认自己的完整 B42.21 单人配置游玩正常；2026-11-02 01:10 的 205 项历史清单记录当时启用状态，各项目的具体游戏内验证状态见子说明。容器自动实验版和 They Knew 文字补丁当前未在正式档启用；前者在独立仓库，后者仍保留于本合集。

本仓库不宣称所有上游代码或美术素材为蘇清原创，也不向第三方文件重新授予统一许可。保留原作归属、版本约束与来源说明。个人配置名单、旧回滚副本和无关 `.bak` 不属于可安装补丁；运行确需的针剂回退参考文件由重建器从匹配的已安装来源恢复。

2026-11-03 本地新增：[蘇清的蛋白饮料训练强化](docs/patches/SuQingProteinTrainingBoost.md)，Mod ID `SuQingProteinTrainingBoost`，依赖 `VanillaFoodsExpanded`。已离线验证，游戏内验收待完成；已纳入本轮统一源码与发布批次，实际提交结果以发布回执为准。

2026-11-03 本地新增：[配方材料输入修复](docs/patches/SuQingRecipeInputGuard_4221.md)，独立于未改动的野马保护补丁；需完全重启，游戏内制作验收待完成。


2026-11-03 发布材料新增：[蘇清的饵托量产补丁](docs/patches/SuQingChumMassProduction.md)。无额外前置；按用户最新说明仍待游戏内验收。与蛋白饮料训练强化、配方材料输入修复一起纳入本轮统一源码与工坊更新；实际提交结果以发布回执为准。
