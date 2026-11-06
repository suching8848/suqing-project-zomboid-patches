# SuQing’s Project Zomboid Patch Collection / 蘇清的僵尸毁灭工程补丁合集

## November 6 publication status

The source catalog has 40 entries: 32 optional collection submods were submitted and verified public, with 3 separate EX companions and 5 redistribution holds. The old 25-entry manifest is preserved in publishing/history; candidate-20261106.json remains pre-upload selection evidence, while publishing/workshop.json records the verified online item. Four new main mods are verified private uploaded candidates. Ordinary Containers 1.0.3 was uploaded to its existing item and verified public. See [publication status](publishing/release-status-20261106.json); source/upload status does not establish gameplay acceptance.

[中文](README.md) · [English](README.en.md)

The 2026-11-03 release snapshot contains **33 independent Mod IDs** maintained by SuQing for **Project Zomboid Build 42.21 single-player**: compatibility fixes, Chinese translations, menu and performance improvements, drug-status UI and small extensions. Select individual entries; this is not one combined mod that requires everything to be enabled.

[Fourteen source repositories and 53 Mod IDs](docs/project-index.md) · [Single-player enabled snapshot from 2026-11-02 01:10 UTC+08:00](docs/current-single-player-modlist.md) · [Author’s Steam collection](https://steamcommunity.com/sharedfiles/filedetails/?id=3823981387)

See [source scope and personal deployment](docs/project-index.md). The user authorized this unified Git/Steam update on 2026-11-03; working personal combinations may retain their existing versions. Music and Chum still await in-game acceptance. Personal Weight Training 0.3.1 was reported normal, while source 0.3.2 artwork awaits visual acceptance. Uploads and source synchronization do not establish gameplay acceptance.

## Source additions from 2026-11-04 now in the public 32-entry item

These entries are now registered in source/rebuild manifests and the public November 6 32-entry item. The 33-entry count and November 3 notes below remain historical snapshots. Consult the project index for all 53 current Mod IDs and separate online/personal states.

| Local addition | Mod ID | Validation boundary |
| --- | --- | --- |
| [Viewpoint Legacy Prompt Fix](docs/patches/Codex_ViewpointLegacyPromptFix_4221.md) | `Codex_ViewpointLegacyPromptFix_4221` | Requires `ProjectViewpointQOLLegacy0.1.6`; 19 original-game Kahlua offline behavior checks passed; in-game acceptance pending |
| [Brewing Skill Books 50x](docs/patches/Codex_ChinaBrewingBooks50_4221.md) | `Codex_ChinaBrewingBooks50_4221` | Requires `Chinesecuisine4213`; v0.1.1: 23 scenarios / 808 offline assertions passed; fixes the Script.Item exclusive-upper-bound check; restore original multipliers and save before disabling; in-game acceptance pending |

## Main mods and conditional patches

**Choose the main project first, then the patches needed for your scenario.** A conditional requirement applies to that combination only. Declared `require` entries are prerequisites; `loadModAfter` entries describe ordering and are not automatically mandatory dependencies.

| Main project or scenario | Relationship |
| --- | --- |
| [Ordinary Container Upgrades](https://github.com/suching8848/suqing-container-upgrade) | Basic operation does not require this collection. The live release is1.0.1; local source/personal1.0.3 is deployed and adds ordinary five-tier Freshness Lunchbox support. Four earlier ordinary IDs are integrated since1.0.1. The legacy ordinary registrar retains its version gate; the independent HavenFall EX bridge still applies, so do not disable the whole patch |
| [Backpack EX](https://github.com/suching8848/suqing-backpack-super-upgrade) with Nekomata Ridge | Use `CodexNekomataEXCompat_4221` for the audited capacity-wrapper bridge. Adding Nekomata EX recipes also requires `CodexNekomataEXUpgrade_4221`, which declares the bridge, Nekomata Ridge and EX as prerequisites |
| EX with HavenFall large backpacks | Requires `Codex_SuQingWearableCompat_4221` for this integration. It declares ordinary upgrades, EX and HavenFall. Its EX bridge is separate from the old ordinary-registration adapter; do not omit dependencies or force it into an automatic-container setup |
| [Automatic Container Upgrades — Experimental](https://github.com/suching8848/suqing-container-auto-upgrade) | An alternative to ordinary upgrades, not a companion to enable alongside them. Not enabled in the current main save |
| MFS and [Firearm Weight Charms](https://github.com/suching8848/suqing-modern-firearms-weight-charms) | Charms require MFS only. Optics, ammo visuals and flashlight-hotkey patches address separate issues. [Fixed Buyback](https://github.com/suching8848/suqing-mfs-fixed-buyback) is also independent; these are not universal charm requirements |
| N&C’s Narcotics | The translation and status panel require the original mod and are optional features. The read-only panel is not the drug system itself |
| XFACTION Dynamic Traits | Translation and record protection target the original. Character Menu Tweaks additionally declares the XFACTION translation as a requirement |
| [Irrigation Care](https://github.com/suching8848/suqing-sprinkler-fertilizer) and Batch Farming | Irrigation Care requires Water Pipes. The collection’s menu filter targets `vac_batch_farming` and is not required by Irrigation Care |
| [Refrigeration Upgrades](https://github.com/suching8848/suqing-refrigeration-upgrade) | No collection patch is mandatory. Original item providers supply the wearable containers; consult that project for special-conversion validation |
| PZ Optimization translation | Requires the matching external engine/UI revision 154126d0 despite having no declared Mod-ID prerequisite. Review and disable the overlay before replacing or removing the engine patch |
| Chemical independent compatibility build | Reconstruction needs the audited original resources. Those third-party assets are not redistributed in Git. Keep the original C.B.R.T. Chemical disabled when using the independent build, as its page explains |

Each entry documents its Mod ID, original `require`, load relationships, behavior and validation limits. Preserve unrelated existing order, satisfy the selected entries’ prerequisites and do not enable or reorder the collection wholesale.

## Build installable files

The repository stores custom source, necessary differences, attribution and exact hashes. Projects containing full upstream vehicle/UI overlays, artwork or stim fallback references are reconstructed from audited locally installed originals rather than bundling unexplained third-party packages.

Requires **Python 3.10+**. The tool reads sources and builds into a new isolated directory; it does not subscribe, download, deploy, launch the game or edit saves.

Build one entry that does not need external reconstruction sources:

```powershell
python tools/rebuild.py --mod-id Codex_MFSOpticsFix_4221 --output ../suqing-selected-patches
```

Check and build all registered entries (the 33-entry release snapshot plus the local additions above). Replace the example Steam-library paths with your own. The output directory must not already exist:

```powershell
python tools/rebuild.py --check --workshop-root "D:/SteamLibrary/steamapps/workshop/content/108600" --game-root "D:/SteamLibrary/steamapps/common/ProjectZomboid"
python tools/rebuild.py --output ../suqing-patches-built --workshop-root "D:/SteamLibrary/steamapps/workshop/content/108600" --game-root "D:/SteamLibrary/steamapps/common/ProjectZomboid"
```

Repeat `--mod-id` to select several entries. The tool pins every source and output by SHA-256. A different source version fails explicitly without fuzzy patching; do not bypass verification to force a build.

After success, each child folder in the output is an independent installable mod. Exit the game normally, copy only the required complete folders to your `Zomboid/mods`, retain version and `common` directories, install original prerequisites and enable selected IDs. Do not install the entire repository, `src` or `patches` as one mod, and do not keep duplicate sources for the same Mod ID.

## Index of 33 patches

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
| [Protein Shake Training Boost / 蘇清的蛋白饮料训练强化](docs/patches/SuQingProteinTrainingBoost.md) | `SuQingProteinTrainingBoost` | `VanillaFoodsExpanded` |
| [蘇清的配方材料输入修复 / Recipe Input Guard](docs/patches/SuQingRecipeInputGuard_4221.md) | `SuQingRecipeInputGuard_4221` | `SapphCooking_B42` |
| [蘇清的饵托量产补丁 / SuQing's Chum Mass Production Patch](docs/patches/SuQingChumMassProduction.md) | `SuQingChumMassProduction` | 无 / None |

## Validation and attribution

Exact reconstruction verifies the recorded runtime bytes. It does not establish gameplay acceptance of future upstream versions, every optional combination, multiplayer or dedicated servers. The author previously reported normal play with their full B42.21 single-player setup; the 205-ID enabled snapshot from 2026-11-02 01:10 UTC+08:00 records that earlier state. Consult individual pages for actual verification limits. The automatic-container experiment and They Knew text fix are not enabled in the current main save; the former has its own repository and the latter remains in this collection.

The repository does not claim upstream code/artwork as SuQing’s original work or relicense third-party files under one blanket license. Keep original attribution, source/version constraints and provenance. Personal enabled lists, rollback copies and unrelated `.bak` files are not installable content. Runtime-required stim fallback references are restored from matching installed originals by the builder.

2026-11-03 local addition: [Protein Shake Training Boost](docs/patches/SuQingProteinTrainingBoost.md), `SuQingProteinTrainingBoost`, requires `VanillaFoodsExpanded`. Offline validated; in-game acceptance pending. Included in the current unified source/publication batch; consult the publication receipts for actual submission results.

2026-11-03 local addition: [Recipe Input Guard](docs/patches/SuQingRecipeInputGuard_4221.md) is independent of the unchanged Mustang guard. Full restart required; in-game crafting acceptance pending.


2026-11-03 publishing preparation: [Chum Mass Production Patch](docs/patches/SuQingChumMassProduction.md), no external prerequisite. In-game acceptance remains pending under the latest instruction. Included with Protein Training Boost and Recipe Input Guard in this unified source/Workshop update; consult publication receipts for actual submission results.

2026-11-06 local addition: [Boat Cabin and RV Room Compatibility Patch](docs/patches/SuQingBoatRVRoomGuard_4221.md), Mod ID `SuQingBoatRVRoomGuard_4221`. Checks shared boat/3x6 RV occupancy while retaining existing interiors. 350 behavior assertions and19 real Reader fixtures pass under each stock/current PZO runtime. The user reported the entrance working; save/reload, Viewpoint and all conflict combinations remain unverified. Local source/personal candidate only; not part of the 2026-11-03 publication snapshot and not committed, pushed or published.

2026-11-06 local addition: [Boat Crafting Nearby Materials Patch](docs/patches/SuQingBoatCraftFromFloor_4221.md). Preserves three boat recipes and skips forced input pretransfer. 54 offline assertions passed; in-game pending; not committed or published.

2026-11-06 Boat/RV room guard rc.2 fixes cross-runtime Unicode false drift rejection. 350 assertions and 19 real-reader fixtures pass in stock and active pzopt; in-game pending, not committed or published.
