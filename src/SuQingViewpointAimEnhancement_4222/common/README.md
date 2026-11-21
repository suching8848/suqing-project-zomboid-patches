# 蘇清的瞄准增强补丁 / SuQing's Viewpoint Aim Enhancement

`SuQingViewpointAimEnhancement_4222` · 0.1.0 · Project Zomboid B42.22.2 单人 / single-player

## 中文

在 Viewpoint 的 3D 视角举枪瞄准时，收圈速度为原来的 **2 倍**。持续瞄准时可以边走边收圈。收满后，瞄准圈及准心的实际摆幅锁在本次举枪计算出的最小半径。移动、换目标和连续开火期间保持这个半径。松开瞄准或换枪时，下次举枪重新收圈。

最小半径使用 Viewpoint 按枪械、瞄具及瞄准等级计算的角度。改变镜头倍率时，同一角度在画面上对应的像素大小会变化。霰弹枪的外圈还包括枪械自身的弹丸散布。效果适用于游戏仍处于举枪瞄准状态的移动。

需要 Viewpoint 0.1.7 的工坊验签热修、ZombieBuddy 2.3.4 以及对此补丁 JAR 的精确批准。在单人档启用 Viewpoint 的 Gunplay Rework。STT、Viewpoint Arsenal 和旧第三人称瞄准修正属于互斥组合。B42.22.2 或依赖的加载来源不符合版本校验时，补丁会让出控制。

启用后完整重启。先用一把 MFS 枪边走边瞄，看看能否缩到小圈。保持举枪，切换两个远近不同的目标并连发，再松开瞄准重举，确认重新收圈。第一和第三人称各试一次。停用补丁并完整重启可恢复 Viewpoint 瞄准行为。

离线验证覆盖现装游戏的模组发现、Kahlua 编译、真实 Viewpoint 类重转换、收圈速度、最小圈、开枪、松开重瞄、换枪和兼容回退。游戏内操作待验收。

## English

Focus builds **twice as fast** when aiming a firearm in Viewpoint's 3D views. The ring can settle while walking. Once settled, the ring and actual crosshair sway hold the minimum radius calculated for that aim cycle through movement, target changes and consecutive shots. Releasing aim or switching weapons starts a fresh cycle on the next aim.

The minimum radius is a Viewpoint angle derived from the weapon, its sight and the Aiming level. Zoom changes how that angle maps to screen pixels. A shotgun's ring also includes its pellet spread. The effect applies as long as the character is still aiming.

Requires the Viewpoint 0.1.7 Workshop signature hotfix, ZombieBuddy 2.3.4 and exact Java approval for this patch. Enable Viewpoint's Gunplay Rework in single-player. Shoot to Thrill, Viewpoint Arsenal and the old third-person aim fix are mutually exclusive with this patch. An unsupported game build or dependency source causes the patch to yield control.

Fully restart after enabling the patch. With an MFS firearm, walk while aiming and check that the ring settles. Keep aiming, switch between targets at different distances and fire several shots, then release and aim again to check for a fresh settling cycle. Repeat in first and third person. Disable the patch and fully restart to restore Viewpoint's aiming behavior.

Offline verification covers game mod discovery, Kahlua compilation, real Viewpoint class retransformation, focus speed, locked radius, the shot entry, aim release, weapon switching and compatibility fallback. In-game acceptance is pending.

## 构建 / Build

Run `tools/build_viewpoint_aim_enhancement.py` with the installed game root, Workshop library, JDK 25 compiler and a fresh output directory. The script produces an audited candidate and a ZIP package.
