# 蘇清的饵托量产补丁 / SuQing's Chum Mass Production Patch

| 项目 / Field | 值 / Value |
| --- | --- |
| Mod ID / Folder | `SuQingChumMassProduction` |
| Version | `1.0.0` |
| Target | Project Zomboid 42.21, single-player |
| Required mods | None; uses vanilla items/recipes |
| Source | `src/SuQingChumMassProduction` in this collection |

| 材料 / Material | 水 / Water | 产物 / Output |
| --- | --- | --- |
| 满沙袋 / Full sand bag | 0.1 L | 原版饵托×5，空袋×1 / 5 vanilla chum + empty bag |
| 满泥土袋 / Full dirt bag | 0.1 L | 原版饵托×5，空袋×1 / 5 vanilla chum + empty bag |
| 黏土×1 / Clay ×1 | 0.1 L | 原版饵托×5 / 5 vanilla chum |

在原版制作菜单选择相应饵托路线，可使用原版重复/批量制作。水来自任意原生 FluidContainer；支持净水、污水及两者混合，不接受混入其他液体。水容器保留，袋装材料必须为满袋，不拼合半袋。

沙袋路线保留 `Base.MakeChum` ID，泥土和黏土路线通过 `MetaRecipe=MakeChum` 继承原版配方知识，也保留钓鱼5级自动学会。成品为原版 `Base.Chum`，后续仍需正常添加鱼饵；空饵托不会凭空增加诱鱼效果。不改变鱼群、鱼饵、技能、地面沙地制作或袋装材料的其他配方。

The vanilla crafting menu gains full-sand/full-dirt/clay routes producing five original `Base.Chum` with 0.1 L water. Any native fluid container can supply clean water, tainted water or their mixture; other liquids are rejected. Water containers remain and consumed full bags leave empty bags. Vanilla recipe knowledge, Fishing 5 auto-learning and subsequent bait loading are retained. This does not rebalance fish populations, skills or unrelated recipes.

## 实现与边界 / Implementation and limits

B42同名配方会追加输入输出。自制小型Lua兼容层先核对当前原版配方签名，再只移除旧的一份沙和一个饵托条目。若原作结构变动且仍能完整识别本补丁新增项，则撤回本补丁新增项并警告；未知结构显式报错，须停用并复核。不打包游戏原作完整文件或第三方资源。

The original signature is checked before removing only the superseded sand/chum recipe IO lines. Known changed upstream structure causes owned additions to be withdrawn with a warning; unknown structure fails explicitly. Only original patch code, recipes, translations and metadata are redistributed.

## 重建 / Build

```powershell
python tools/rebuild.py --mod-id SuQingChumMassProduction --check
python tools/rebuild.py --mod-id SuQingChumMassProduction --output ../chum-patch-built
```

输出目录必须不存在，不需要外部模组原件。按需只启用本ID，不要全启用补丁合集。同ID只保留一个来源；退出游戏后换源或停用。已制作饵托、空袋都是原版物品，停用不删除这些成品，也不返还已消耗材料。

The output must not already exist. No external mod is required. Enable only the desired IDs and keep one installed source per ID. Exit normally before switching or removing sources. Existing chum and empty bags are vanilla items; removal does not refund consumed ingredients.

## 验证与来源 / Validation and provenance

2026-11-02原开发源码通过216项游戏原生离线检查，包括原生配方/计量/流体/知识与真实Kahlua兼容层；本次发布导入10文件与该测试源哈希逐项相同。用户随后明确反馈“饵托功能正常”。这项反馈不扩展为所有模组组合、多人或服务器验收。

The original 216 native offline checks passed. All ten imported files match that tested source byte for byte. The user subsequently reported that the chum feature works in game; this does not establish every combination, multiplayer or server support.

既有独立开发目录保留为 `D:/steam/steamapps/common/ProjectZomboid/CodexRepos/suqing-chum-mass-production`；本Git新增源码为明确的发布归档，不搬动或覆盖该开发目录、个人安装和存档。工坊待上传包以已公开22项为基础仅追加本补丁，独立于本仓库其他待提交内容。
