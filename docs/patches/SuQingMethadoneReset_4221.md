# 蘇清的美沙酮增强 / SuQing's Methadone Reset

`SuQingMethadoneReset_4221` · `1.0.2` · Build 42.21–42.22 单人 / single-player

## 中文

依赖 N&C’s Narcotics（`N&CsNarcotics`）。在 N&C 及可选的蘇清中文补丁之后加载。药物状态面板可独立启用。

1.0.1 在美沙酮的简中说明追加「药物类别：美沙酮（阿片戒断用药）」。

正常服用一剂美沙酮后，清零六类 N&C 过量累计、七类成瘾累计及相应预警标记。成瘾累计与恢复进度共用计数器，补丁只清掉负值代表的成瘾累计，保留已有依赖特质和正值代表的戒除进度。其他药的持续药效照常运行。美沙酮仍按原规则压住阿片戒断，同时暂停阿片戒除进度。再次用药可以重新产生累计。

验收时先右键药物查看状态并记下累计值，再正常服用一剂美沙酮，检查对应值归零、美沙酮计时启动及现有依赖特质。取消服药不触发清零。停用此补丁后，后续剂量使用 N&C 原规则。已保存的清零结果属于存档进度，恢复需使用服药前存档。

## English

Requires N&C’s Narcotics (`N&CsNarcotics`). Load after N&C and the optional SuQing Chinese patch. The drug status panel can be enabled separately.

Version 1.0.1 adds the methadone category line to the Simplified Chinese description.

A completed methadone dose clears all six N&C overdose counters, all seven addiction buildups and their warning flags. Addiction buildup shares a counter with recovery. The patch clears the negative buildup and preserves existing dependence traits and positive recovery progress. Other drugs continue through their current effects. Methadone still suppresses opioid withdrawal and pauses opioid recovery while active. Subsequent use can build up risk again.

To verify, record existing buildup in the status panel and take one dose through the normal pill action. Check that the buildup clears, methadone is active and any existing traits remain. Cancelling the dose leaves buildup intact. Disabling the patch restores the upstream behavior for future doses. To undo a saved reset, use a save from before the dose.

## 42.22.2 离线核对 / Offline validation

用新版原版服药完成回调与当前 N&C 的美沙酮药效函数，核对实际服用后清除规则、未耗用时不清除，以及保留已有依赖和戒除进度。

Checked the current vanilla pill completion path with N&C's methadone effect callback, including successful doses, unused doses and preservation of existing dependence and recovery progress.
