# 蘇清的 CleanUI 容器拖动排序修复 / SuQing's CleanUI Container Drag Fix

1.0.1 适用于 B42.22.2 单人和已审查的 CleanUI 2.10.7。修正容器侧栏滚动后的按钮拖放坐标，由 CleanUI 保存容器顺序。原版 Kahlua 通过 84 项断言，覆盖单列、双列、未滚动、滚动、越界和松手提交。进档后可滚动侧栏拖动容器图标，保存重进复核顺序。

1.0.1 supports single-player Build 42.22.2 with reviewed CleanUI 2.10.7. It fixes drag coordinates after scrolling the container sidebar and leaves order persistence to CleanUI. Native Kahlua passed 84 assertions covering one and two columns, scroll offsets and drag release. To check in game, scroll the sidebar and reorder containers, then reload the save.
