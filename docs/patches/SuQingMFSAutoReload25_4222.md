# 蘇清的现代枪械自动装弹 25 发补丁 / SuQing's MFS Auto-Reload 25 Rounds

SuQingMFSAutoReload25_4222 · 1.0.0 · B42.22.2 单人 / single-player

## 中文

在使用 [现代枪械系统](https://steamcommunity.com/sharedfiles/filedetails/?id=3633421539) 的存档中启用本补丁，并加载于 `ModernFirearmsSystem` 之后。佩戴自动装弹机构或把它放在角色主物品栏时，每轮最多装 25 发，实际数量取决于弹匣空位和散弹数量。每发照常扣除一发散弹，装填经验沿用原来的每轮判定。

验收时带上装置和至少 30 发散弹，为一个空的 30 发弹匣装弹。第一轮应装 25 发，第二轮补 5 发。停用本补丁并完整重启即可恢复原模组的 5 发上限。

## English

Enable the patch for a save that uses [Modern Firearms System](https://steamcommunity.com/sharedfiles/filedetails/?id=3633421539) and load it after `ModernFirearmsSystem`. Wearing the device or carrying it in the main inventory allows up to 25 rounds per cycle. Magazine space and available cartridges limit the actual count. Each round consumes one cartridge and the experience roll still runs once per cycle.

To test, carry the device and at least 30 loose rounds and load an empty 30-round magazine. The first cycle should load 25 rounds and the second should load the remaining five. Disable the patch and restart the game to restore the original five-round limit.

## 本机重建 / Local build

```powershell
python tools/rebuild.py --mod-id SuQingMFSAutoReload25_4222 --workshop-root "D:/steam/steamapps/workshop/content/108600" --output ../mfs-autoreload25-built
```

- 上游 / Upstream manifest `6406515251394288770`
- 上游 Lua SHA-256 / Upstream Lua SHA-256 `ef0df7fb6d21f49ea12e5e3fb4d5299c59022561676ae3660d7818348bff117d`
本机运行文件由一行差异重建。上游更新后应重新核对差异。 / The local runtime file is rebuilt from a one-line diff. Re-audit the diff after an upstream update.
