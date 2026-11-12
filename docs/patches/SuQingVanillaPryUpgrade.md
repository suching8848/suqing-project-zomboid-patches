# 撬锁拓展补丁 / Crowbar Prying Expansion Patch

## 中文

0.1.3 是补丁合集的可选小补丁，适用于 Project Zomboid B42.22.2 单人模式，Mod ID 为 `SuQingVanillaPryUpgrade`。使用原版撬棍标签和游戏接口，独立运行，无前置模组。

- **加固门锁**。随身携带完好的撬棍，右键上锁的防盗门、牢门等原版禁撬门，选「撬开加固门锁」。原版木门、窗户、普通车库门和围栏门继续使用原有「撬开」动作。
- **路障**。门窗钉有木板、金属板或铁栅条时，先用原版操作拆除路障，再撬锁。门前有其他障碍物时，仍由游戏判断门能不能打开。
- **挂锁**。原版挂锁或密码挂锁保护的门、围栏门和储物容器可以右键「撬开挂锁」。成功会破坏挂锁，门会尝试打开，储物容器可搜刮。
- **车辆**。站在上锁的目标部件旁，按住 **V** 打开车辆轮盘，选择「撬车门锁」「撬后备箱锁」或「撬引擎盖锁」。成功只解锁所选部件，然后调用原版开门动作。锁仍可正常重新锁上，车辆警报按原版规则处理。模组车辆需要使用原版车门部件和交互区域。

新增动作每轮先沿用原版直接失败率，普通角色 10%，窃贼 5%。通过后再判定撬锁。成功判定取原版力量基础值加目标修正、力量等级和 1 三者的最大值。加固门与挂锁的修正为 −10 个百分点，车辆为 −5 个百分点，窃贼额外增加 20 个百分点并降低噪声。两个判定都未触发会继续尝试。撬锁会消耗体力，失败可能损耗撬棍，门的失败效果沿用原版门对象。

建议先在测试档实测。把压缩包中的 `SuQingVanillaPryUpgrade` 目录放入 `%UserProfile%\Zomboid\mods`，仅在测试档启用。携带撬棍测试一扇防盗门、一扇钉板的门和一辆上锁车辆，再保存重进核对锁状态。停用后新增菜单消失，已经改变的锁状态按普通世界状态保留。

源码位于 `src/SuQingVanillaPryUpgrade`。扩展原版右键填充事件和车辆轮盘的 `ISVehicleMenu.FillPartMenu`，沿用 `ISForceOpen` 的失败率、原生力量接口、`ISOpenVehicleDoor` 和世界门原生锁状态。0.1.1 更新补丁名称并登记合集重建清单。0.1.2 修正中英文轮盘、右键菜单及失败提示的翻译键。用户已实测车门撬锁可用，修正后的显示待复测。0.1.3 改用原版容器接口，修复右键返鲜冰箱等建造物件时的报错。已离线验证无锁冰箱、带钥匙挂锁与密码挂锁的箱柜，待游戏内复测。

## English

Version 0.1.3 is an optional patch in the collection and targets Project Zomboid B42.22.2 single-player. Mod ID is `SuQingVanillaPryUpgrade`. The patch uses the vanilla crowbar tag and game APIs and has no mod dependencies.

- **Reinforced locks.** Carry an intact crowbar and right-click a locked security or prison door. Choose “Pry Reinforced Door Lock.” Ordinary doors, windows, garage doors and fence gates keep their vanilla pry action.
- **Barricades.** Remove planks, metal sheets or bars through the vanilla actions before prying. The game still checks whether an obstruction prevents the door from opening.
- **Padlocks.** Right-click a vanilla door, gate or storage container secured by a regular or combination padlock. A successful pry breaks the padlock, attempts to open the door, or makes the container accessible.
- **Vehicles.** Stand beside a locked part and hold **V**. Select “Pry Vehicle Door Lock,” “Pry Trunk Lock” or “Pry Hood Lock.” Success unlocks only that part and queues the vanilla opening action. The lock can be used again and alarms retain their vanilla behavior. Modded vehicles need standard door parts and interaction areas.

Each cycle uses the vanilla 10% hard-failure chance, or 5% for a Burglar. The success roll then takes the maximum of 1, Strength level, or the vanilla Strength base plus the target modifier. Reinforced locks and padlocks apply −10 percentage points, vehicle locks apply −5, and Burglars gain 20 percentage points and make less noise. If neither outcome occurs, the character keeps trying. Prying costs endurance. Failure can wear the crowbar, and building doors use the native door failure effects.

For acceptance, extract the mod folder into `%UserProfile%\Zomboid\mods` and enable it in a test save. Try a reinforced door, a barricaded door and a locked vehicle, then save and reload to check lock states. Disabling the patch removes its actions. Locks already changed remain part of the world state.

The source is under `src/SuQingVanillaPryUpgrade`. It extends the vanilla world context event and `ISVehicleMenu.FillPartMenu`. It uses the `ISForceOpen` failure constants, native Strength API, `ISOpenVehicleDoor`, and native world lock state. Version 0.1.1 renames the patch and adds it to the collection build manifest. Version 0.1.2 fixes the Chinese and English keys for the radial menu, context menu, and feedback. Vehicle prying has been verified in game by the user. The corrected labels await retesting. Version 0.1.3 uses the vanilla container getter to fix an error when right-clicking the Freshness Fridge and similar objects. Offline checks cover an unlocked fridge, keyed padlocks, and combination padlocks. In-game retesting is pending.
