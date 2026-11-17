# 蘇清的物品详情提示修复 / SuQing's More Item Information Tooltip Fix

SuQingMoreItemInfoText_4222 · 1.0.0 · Build 42.22.2 单人 / Single-player

## 中文

同时使用 More Item Information 和 XingHe 物品详情模组时，共用的物品详情数据可能包含数字。原 More Item Information 在测量和绘制提示文字时把数字传给 Java String 参数，触发 ItemInfo.lua:769 报错。补丁在 More Item Information 的提示绘制阶段将标签和值转换成文字，沿用原数据、提示布局和模组间调用链。

启用前置 MoreItemInformation，将补丁排在其后。重启读档后，将鼠标停在原来报错的物品上，检查提示详情是否正常显示，游戏日志是否停止出现对应错误。停用补丁并重启即可回退。

## English

More Item Information can receive numeric tooltip values through the shared item details table used by XingHe Item and Weapon Details. Its renderer passed them as Java String arguments, producing the error at ItemInfo.lua:769. The patch converts labels and values to text at the render boundary while preserving shared data, layout rules and the existing render chain.

Load the patch after MoreItemInformation. Restart and open the save, then hover the item that previously failed and check that its tooltip displays without the matching error. Disable the patch and restart to roll back.

## 上游与重建 / Upstream and rebuild

- [More Item Information](https://steamcommunity.com/sharedfiles/filedetails/?id=3494474677) 1.3.9, branch 42.13.0, Workshop manifest 4723111090488727039.
- media/lua/client/ItemInfo.lua SHA-256 4f23f4fbc23adcd6499343da937c74a5e2546b90010fa9e34847f89cdb425555.
- Rebuild the local override from the pinned original and patches/SuQingMoreItemInfoText_4222/42/media/lua/client/ItemInfo.lua.patch. Review the diff against the updated upstream file before enabling any rebuilt version.
