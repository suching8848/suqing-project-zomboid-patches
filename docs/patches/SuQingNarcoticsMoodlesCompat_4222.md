# 蘇清的 N&C 状态图标兼容修复 / SuQing's N&C Moodles in Lua Fix

`SuQingNarcoticsMoodlesCompat_4222` · 1.0.0 · B42.22.2 单人 / single-player

## 中文

同时启用 `moodlesinlua` 与 `N&CsNarcotics` 时，Moodles in Lua 的设置刷新可能把 N&C 内置框架的 `updateTextures` 实例方法当作无参函数调用，导致 `NnC_MoodleFallback.lua:485` 报错。本补丁将设置刷新接到一个由 Moodles in Lua 自己注册的回调。N&C 与独立 Moodle Framework 的实例方法继续保留。

将补丁加载于这两个前置之后。重启并读取单人档，在 Mod Options 中应用一次 Moodles in Lua 的设置并检查状态图标。日志应出现 `Moodles in Lua texture refresh ready`，原调用栈应消失。停用本补丁并完全重启即可回退。

## English

When `moodlesinlua` and `N&CsNarcotics` are both enabled, the Moodles in Lua settings refresh can call the bundled N&C `updateTextures` instance method without a receiver. This causes the error at `NnC_MoodleFallback.lua:485`. The patch gives the settings refresh a private Moodles in Lua callback. The N&C and standalone Moodle Framework instance methods remain available for valid calls.

Load the patch after both dependencies. Restart, load the single-player save, and apply the Moodles in Lua settings once. Check that moodle icons remain visible. The log should report `Moodles in Lua texture refresh ready` and the original stack should disappear. Disable the patch and fully restart to roll back.

## 已核对的工坊文件 / Reviewed Workshop files

- Moodles in Lua v17, branch `42.20`, manifest `6471967619692061739`, SHA-256 of `MoodlesIn.lua` `42992ec814e3bba0f519882f13f3bfeba5c46f9803be1a4ceb13749ae6f1d62f`. [工坊 / Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3395171770)
- N&C's Narcotics, branch `42`, manifest `8243118625321731671`, SHA-256 of `NnC_MoodleFallback.lua` `a165dec9958e1ed6f3496b104e5f8591c8b4e6934f1e535abdc77febfcbb45e9`. [工坊 / Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3404956403)

上游更新后，复查刷新调用与实际运行方法的位置。 / Recheck the refresh call and the active method location after an upstream update.

## 本机重建 / Local build

```powershell
python tools/rebuild.py --mod-id SuQingNarcoticsMoodlesCompat_4222 --workshop-root "D:/steam/steamapps/workshop/content/108600" --output ../narcotics-moodles-built
```

同路径覆盖由锁定 SHA-256 的本机工坊脚本和差异文件生成。源码只存差异。 / The same-path override is rebuilt from the SHA-256-pinned local Workshop file and the diff. The repository stores the diff.
