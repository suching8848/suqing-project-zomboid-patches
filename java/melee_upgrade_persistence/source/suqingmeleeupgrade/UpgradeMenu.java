package suqingmeleeupgrade;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.LuaClosure;
import zombie.Lua.LuaManager;
import zombie.characters.BodyDamage.Metabolics;
import zombie.characters.CharacterTimedActions.LuaTimedActionNew;
import zombie.characters.IsoPlayer;
import zombie.core.Translator;
import zombie.inventory.types.HandWeapon;
import zombie.network.GameClient;
import zombie.network.GameServer;

@Patch(className = "zombie.Lua.LuaManager$GlobalObject", methodName = "triggerEvent", strictMatch = true)
public final class UpgradeMenu {
    private static final String TEXT = "UI_SuQingMeleeUpgrade_";
    private static final String ACTION_TYPE = "ISSuQingMeleeUpgradeAction";
    private static boolean warned;

    private UpgradeMenu() {}

    // Positional parameters require this exact arity in ZombieBuddy's matcher.
    @Patch.OnExit
    public static void afterEvent(String event, Object playerNumber, Object context, Object items) {
        if ("OnFillInventoryObjectContextMenu".equals(event)) {
            UpgradeMenu.fill(playerNumber, context, items);
        }
    }

    public static void fill(Object playerNumber, Object context, Object items) {
        if (!inSinglePlayer() || !(playerNumber instanceof Number number)
                || !(context instanceof KahluaTable) || !(items instanceof KahluaTable)
                || LuaManager.env == null || LuaManager.thread == null || LuaManager.caller == null) {
            return;
        }

        try {
            IsoPlayer player = LuaManager.GlobalObject.getSpecificPlayer(number.intValue());
            if (player == null || !player.isLocalPlayer() || player.isDead()) return;
            Object pane = LuaManager.env.rawget("ISInventoryPane");
            Object actualItems = call(member(pane, "getActualItems"), items);
            if (!(actualItems instanceof KahluaTable selection) || selection.len() != 1
                    || !(selection.rawget(1) instanceof HandWeapon weapon) || !Upgrade.supports(weapon)
                    || !player.getInventory().contains(weapon, true)) {
                return;
            }

            Upgrade.Quote quote = Upgrade.preview(weapon);
            Upgrade.Supplies supplies = null;
            String reason = null;
            if (!Upgrade.isAvailable()) {
                reason = "Unavailable";
            } else if (quote == null) {
                reason = Upgrade.blocker(weapon);
            } else {
                supplies = Upgrade.supplies(player, weapon);
                if (supplies == null) reason = Upgrade.supplyBlocker(player, weapon);
            }
            if (reason == null && (quote == null || supplies == null)) reason = "Failed";

            String label = quote == null ? text("Menu") : text("Upgrade", Integer.toString(quote.level()));
            JavaFunction callback = null;
            if (reason == null) {
                TimedUpgrade action = new TimedUpgrade(player, weapon, quote, supplies);
                callback = (frame, count) -> {
                    action.queue();
                    return 0;
                };
            }
            KahluaTable tooltip = tooltip(quote, reason);
            KahluaTable option = (KahluaTable) call(member(context, "addOption"), context, label, weapon, callback);
            if (option == null) return;
            option.rawset("notAvailable", reason != null);
            option.rawset("toolTip", tooltip);
        } catch (RuntimeException | LinkageError failure) {
            warn(failure);
        }
    }

    private static KahluaTable tooltip(Upgrade.Quote quote, String reason) {
        StringBuilder description = new StringBuilder();
        if (quote != null) {
            append(description, text("ConditionMax", String.valueOf(quote.currentConditionMax()),
                    String.valueOf(quote.conditionMax())));
            int headMax = quote.headMax();
            if (headMax > 0) {
                append(description, text("HeadConditionMax", String.valueOf(quote.currentHeadMax()),
                        Integer.toString(headMax)));
            }
            append(description, text("DamageMultiplier", Math.round(quote.multiplier() * 100.0) + "%"));
            double wearPercent = 100.0 / quote.multiplier();
            String wear = wearPercent == (int) wearPercent
                ? Integer.toString((int) wearPercent) : Double.toString(wearPercent);
            append(description, text("WearRate", wear + "%"));
            if (quote.level() == Upgrade.MAX_LEVEL) {
                append(description, text("Weight", Float.toString(quote.currentWeight()), Float.toString(quote.weight())));
            }
        }
        append(description, text("Materials"));
        if (reason != null) append(description, "<RGB:1,0.45,0.45> " + error(reason));

        Object type = LuaManager.env.rawget("ISToolTip");
        KahluaTable tooltip = (KahluaTable) call(member(type, "new"), type);
        call(member(tooltip, "initialise"), tooltip);
        tooltip.rawset("description", description.toString());
        return tooltip;
    }

    private static void append(StringBuilder description, String line) {
        if (!description.isEmpty()) description.append(" <LINE> ");
        description.append(line);
    }

    private static Object member(Object table, String key) {
        if (!(table instanceof KahluaTable)) throw new IllegalStateException("Missing vanilla table for " + key);
        return LuaManager.thread.tableget(table, key);
    }

    private static Object call(Object callable, Object... arguments) {
        if (!(callable instanceof JavaFunction) && !(callable instanceof LuaClosure)) {
            throw new IllegalStateException("Missing vanilla Lua function");
        }
        Object[] result = LuaManager.caller.pcall(LuaManager.thread, callable, arguments);
        if (result.length == 0 || !Boolean.TRUE.equals(result[0])) {
            throw new IllegalStateException("Vanilla Lua call failed: " + (result.length > 1 ? result[1] : callable));
        }
        return result.length > 1 ? result[1] : null;
    }

    private static boolean inSinglePlayer() {
        return !GameClient.client && !GameServer.server
                && LuaManager.thread != null && Thread.currentThread() == LuaManager.thread.debugOwnerThread;
    }

    private static String text(String key, Object... arguments) {
        return Translator.getText(TEXT + key, arguments);
    }

    private static String error(String reason) {
        return text("Error_" + (reason == null ? "Failed" : reason));
    }

    private static void warn(Throwable failure) {
        if (!warned) {
            warned = true;
            System.err.println("[SuQingMeleeUpgrade] inventory action unavailable: " + failure);
        }
    }

    private static final class TimedUpgrade {
        private final IsoPlayer player;
        private final HandWeapon weapon;
        private final Upgrade.Quote quote;
        private final Upgrade.Supplies supplies;
        private String invalidReason;

        private TimedUpgrade(IsoPlayer player, HandWeapon weapon, Upgrade.Quote quote, Upgrade.Supplies supplies) {
            this.player = player;
            this.weapon = weapon;
            this.quote = quote;
            this.supplies = supplies;
        }

        private String validate() {
            if (!inSinglePlayer() || !Upgrade.isAvailable()) return "Unavailable";
            if (player.isDead() || !player.isLocalPlayer()) return "Ineligible";
            return Upgrade.check(player, weapon, quote, supplies);
        }

        private void queue() {
            try {
                String blocker = validate();
                if (blocker != null) {
                    player.Say(error(blocker));
                    return;
                }
                Object base = LuaManager.env.rawget("ISBaseTimedAction");
                KahluaTable action = (KahluaTable) call(member(base, "new"), base, player);
                action.rawset("Type", ACTION_TYPE);
                action.rawset("maxTime", player.isTimedActionInstant() ? 1.0 : 90.0);
                action.rawset("isValid", (JavaFunction) (frame, count) -> {
                    invalidReason = validate();
                    return frame.push(invalidReason == null);
                });
                action.rawset("start", (JavaFunction) (frame, count) -> {
                    nativeAction(action).setActionAnim("Craft");
                    weapon.setJobType(text("Working"));
                    weapon.setJobDelta(0.0f);
                    return 0;
                });
                action.rawset("update", (JavaFunction) (frame, count) -> {
                    weapon.setJobDelta(nativeAction(action).getJobDelta());
                    player.setMetabolicTarget(Metabolics.UsingTools);
                    return 0;
                });
                action.rawset("stop", (JavaFunction) (frame, count) -> {
                    weapon.setJobDelta(0.0f);
                    if (invalidReason != null) player.Say(error(invalidReason));
                    call(member(base, "stop"), action);
                    return 0;
                });
                action.rawset("perform", (JavaFunction) (frame, count) -> {
                    weapon.setJobDelta(0.0f);
                    call(member(base, "perform"), action);
                    return 0;
                });
                action.rawset("complete", (JavaFunction) (frame, count) -> frame.push(complete()));
                call(member(LuaManager.env.rawget("ISTimedActionQueue"), "add"), action);
            } catch (RuntimeException | LinkageError failure) {
                warn(failure);
                player.Say(error("Failed"));
            }
        }

        private boolean complete() {
            String reason = validate();
            if (reason == null) reason = Upgrade.commit(player, weapon, quote, supplies);
            if (reason != null) {
                player.Say(error(reason));
                return false;
            }

            var container = weapon.getContainer();
            if (container != null) container.setDrawDirty(true);
            player.Say(text("Upgraded", Integer.toString(quote.level())));
            return true;
        }

        private static LuaTimedActionNew nativeAction(KahluaTable action) {
            return (LuaTimedActionNew) action.rawget("action");
        }
    }
}
