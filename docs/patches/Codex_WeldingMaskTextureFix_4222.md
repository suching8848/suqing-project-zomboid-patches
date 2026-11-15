# 蘇清的焊工面罩贴图修复 / SuQing's Welding Mask Texture Fix

| 项目 / Field | 值 / Value |
| --- | --- |
| Mod ID | `Codex_WeldingMaskTextureFix_4222` |
| 版本 / Version | 1.0.0 |
| 验证目标 / Tested build | B42.22.2 单人 / Single-player |
| 前置及加载顺序 / Dependency and order | 启用 FantasyWorkshop 4.0 后加载 / Load after `FantasyWorkshopVS42_4.0` |
| 创意工坊来源 / Workshop source | [3717576490](https://steamcommunity.com/sharedfiles/filedetails/?id=3717576490), manifest `6949822386245763083` |

## 中文

FantasyWorkshop 4.0 把原版焊工面罩 `Base.WeldingMask` 的贴图值改成了 `weldermask`。游戏在纹理根目录找不到该贴图，面罩会显示红白格纹。本补丁把 `textureChoices` 恢复为 `clothes\hat\weldermask`，继续使用原版贴图和当前面罩配置中的网格与 GUID。落地朝向由游戏的佩戴模型变换和摆放角度决定。

从当前 Steam 安装重建独立补丁，在使用 FantasyWorkshop 4.0 的存档中启用。要回退，在存档模组列表停用本补丁并完整重启。进档后检查原有地面面罩、重新放下的面罩和佩戴时的贴图。实际游戏显示待验收。

## English

FantasyWorkshop 4.0 overrides the vanilla welder mask (`Base.WeldingMask`) texture with the unqualified name `weldermask`. The resulting lookup fails and the mask displays a red-and-white checkerboard. This patch restores `textureChoices` to `clothes\hat\weldermask`, retaining the configured meshes and GUID. Ground orientation follows the game's clothing transform and the item's placement angles.

Rebuild from your installed Workshop files and enable the patch in a save that uses FantasyWorkshop 4.0. To revert, disable the patch for that save and restart the game. Check an existing ground mask, a newly dropped mask, and the equipped mask after loading the save. In-game visuals are pending acceptance.

## 本机重建 / Local rebuild

```powershell
python tools/rebuild.py --mod-id Codex_WeldingMaskTextureFix_4222 --workshop-root "D:/steam/steamapps/workshop/content/108600" --output ../welding-mask-texture-fix-built
```

清单校验上游 XML 的 SHA-256 `b2ddab03ea08aa2681ec7104bd5b39fcc02833b63f7f0a44700e886dce9ae215`，并从一行差异重建。Git 收录重建配方和差异。完整运行 XML 保留为本机重建输出。 / The manifest pins the upstream XML SHA-256 and reconstructs it from a one-line diff. Git carries only the reconstruction recipe and diff.
