package suqingmeleeupgrade;

import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import zombie.ZomboidGlobals;
import zombie.Lua.LuaManager;
import zombie.core.random.RandLua;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoWorld;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ScriptModule;

public final class NativeUpgradeAudit {
    private static int assertions;
    private static int nextId = 100;

    private static void check(boolean condition, String label) {
        if (!condition) throw new AssertionError(label);
        assertions++;
        System.out.println("PASS " + label);
    }

    private static void near(float actual, float expected, String label) {
        check(Math.abs(actual - expected) < 0.00003f, label + ": " + actual);
    }

    private static Item template(Path file, String moduleName, String itemName) throws Exception {
        String scripts = Files.readString(file);
        var matcher = Pattern.compile("(?m)^\\h*item\\h+" + Pattern.quote(itemName) + "\\h*\\R").matcher(scripts);
        if (!matcher.find()) throw new IllegalArgumentException("Unknown fixture template " + itemName);
        int end = scripts.indexOf("\n    }", matcher.end());
        var module = new ScriptModule();
        module.name = moduleName;
        var item = new Item();
        item.setModule(module);
        item.Load(itemName, scripts.substring(matcher.start(), end + 6)
            .replaceAll("(?m)^\\s*Researchablerecipes\\s*=.*$", ""));
        item.setDisplayName(itemName);
        return item;
    }

    private static InventoryItem create(Item template) {
        InventoryItem item = template.InstanceItem(null);
        item.setID(nextId++);
        return item;
    }

    private static HandWeapon roundTrip(HandWeapon original) throws Exception {
        ByteBuffer payload = ByteBuffer.allocate(8192);
        original.save(payload, false);
        payload.flip();
        payload.position(3);
        HandWeapon restored = (HandWeapon) original.getScriptItem().InstanceItem(null);
        restored.load(payload, IsoWorld.WorldVersion);
        check(!payload.hasRemaining(), original.getFullType() + " consumes complete native payload");
        return restored;
    }

    private static void condition(HandWeapon item, int actual, int maximum) {
        check(item.getCondition() == actual && item.getConditionMax() == maximum,
            item.getFullType() + " expected " + actual + "/" + maximum
                + " saw " + item.getCondition() + "/" + item.getConditionMax());
    }

    private static List<InventoryItem> addSupplies(ItemContainer bag, Item nails, Item sheet, Item cloth) {
        List<InventoryItem> items = new ArrayList<>();
        for (Item template : List.of(nails, nails, sheet, cloth)) {
            items.add(bag.AddItem(create(template)));
        }
        return items;
    }

    private static void consumed(List<InventoryItem> items, ItemContainer inventory) {
        check(items.stream().noneMatch(item -> inventory.contains(item, true) || item.getContainer() != null),
            "exactly two nails, one small sheet and one ripped sheet were removed");
    }

    public static void run(Path game) throws Exception {
        RandLua.INSTANCE.init();
        LuaManager.init();
        ZomboidGlobals.equippedOrWornEncumbranceMultiplier = 0.3; // media/lua/shared/defines.lua
        check(Upgrade.isAvailable(), "real loader installed wear filter and both persistence paths");
        var definitions = game.resolve("media/scripts/generated/items");
        var normal = definitions.resolve("normal.txt");
        var weapon = definitions.resolve("weapon.txt");
        Item nails = template(normal, "Base", "Nails");
        Item sheet = template(normal, "Base", "SmallSheetMetal");
        Item cloth = template(normal, "Base", "RippedSheets");
        Item hammerTemplate = template(weapon, "Base", "BallPeenHammer");
        Item knifeTemplate = template(weapon, "Base", "HuntingKnife");
        Item axeTemplate = template(weapon, "Base", "Axe");
        Item crowbarTemplate = template(weapon, "Base", "Crowbar");
        var playerInventory = new ItemContainer();
        var bag = (InventoryContainer) create(template(definitions.resolve("container.txt"), "Base", "Bag_Schoolbag"));
        playerInventory.AddItem(bag);
        ItemContainer supplies = bag.getInventory();
        var knife = (HandWeapon) playerInventory.AddItem(create(knifeTemplate));
        var plain = (HandWeapon) create(knifeTemplate);
        InventoryItem hammer = playerInventory.AddItem(create(hammerTemplate));
        int hammerCondition = hammer.getCondition();
        knife.setConditionWhileLoading(6);
        knife.setSharpness(0.4f);
        float sharpness = knife.getSharpness();
        float oldMin = knife.getMinDamage();
        float oldMax = knife.getMaxDamage();
        float originalWeight = knife.getActualWeight();
        float equippedWeight = knife.getEquippedWeight();
        check(originalWeight > 0 && equippedWeight > 0, "test knife has native inventory and equipped weight");

        check(Upgrade.supports(knife) && Upgrade.supports((HandWeapon) crowbarTemplate.InstanceItem(null)), "sharp and blunt melee items supported");
        check(!Upgrade.supports(nails.InstanceItem(null)), "crafting materials cannot be upgraded");
        check(Upgrade.supplies(playerInventory, knife) == null && Upgrade.supplies(playerInventory, (HandWeapon) hammer) == null,
            "missing supplies and using the only hammer as its own tool are rejected");
        var items = addSupplies(supplies, nails, sheet, cloth);
        var quote = Upgrade.preview(knife);
        check(quote.level() == 1 && quote.multiplier() == 2 && quote.conditionMax() == 20, "level 1 projects double base");
        var pack = Upgrade.supplies(playerInventory, knife);
        check(pack != null && pack.hammer() == hammer, "native hammer tag and nested inventory recognized");
        InventoryItem firstNail = items.getFirst();
        supplies.Remove(firstNail);
        check("InvalidMaterials".equals(Upgrade.commit(playerInventory, knife, quote, pack)), "missing selected material aborts without a debit");
        check(supplies.contains(items.getLast()) && knife.getConditionMax() == 10, "failure preserves weapon and remaining material");
        supplies.AddItem(firstNail);
        check(Upgrade.commit(playerInventory, knife, quote, pack) == null, "first transaction succeeds");
        condition(knife, 12, 20);
        near(knife.getMinDamage(), 2 * oldMin, "minimum damage x2");
        near(knife.getMaxDamage(), 2 * oldMax, "effective maximum damage x2 with same sharpness");
        near(knife.getSharpness(), sharpness, "upgrade retains sharpness");
        near(knife.getSharpnessIncrement(), 0.05f, "first-level sharpness decrement governed by increased cap");
        near(knife.getActualWeight(), originalWeight, "first level keeps original weight");
        consumed(items, playerInventory);
        check(playerInventory.contains(hammer) && hammer.getCondition() == hammerCondition, "hammer retained without wear");
        check(playerInventory.contains(knife) && "Base.HuntingKnife".equals(knife.getFullType()), "original weapon instance and full type retained");
        check("Changed".equals(Upgrade.commit(playerInventory, knife, quote, pack)), "replayed quote cannot charge or upgrade again");

        items = addSupplies(supplies, nails, sheet, cloth);
        quote = Upgrade.preview(knife);
        check(quote.level() == 2 && quote.multiplier() == 4 && quote.conditionMax() == 40, "level 2 projects quadruple original");
        check(Upgrade.commit(playerInventory, knife, quote, Upgrade.supplies(playerInventory, knife)) == null, "second transaction succeeds");
        condition(knife, 24, 40);
        near(knife.getMinDamage(), 4 * oldMin, "minimum damage x4");
        near(knife.getMaxDamage(), 4 * oldMax, "effective maximum damage x4 with same sharpness");
        near(knife.getSharpnessIncrement(), 0.025f, "second-level sharpness decrement governed by 4x cap");
        consumed(items, playerInventory);
        var restored = roundTrip(knife);
        condition(restored, 24, 40);
        near(restored.getActualWeight(), originalWeight, "second level keeps original weight");
        near(restored.getMaxDamage(), knife.getMaxDamage(), "upgraded damage survives save and load without reapplying bonuses");
        playerInventory.Remove(knife);
        knife = (HandWeapon) playerInventory.AddItem(restored);
        items = addSupplies(supplies, nails, sheet, cloth);
        quote = Upgrade.preview(knife);
        check(quote.level() == 3 && quote.multiplier() == 8 && quote.conditionMax() == 80, "saved level 2 offers level 3");
        near(quote.weight(), originalWeight * 0.5f, "preview projects half the original weight");
        check(Upgrade.commit(playerInventory, knife, quote, Upgrade.supplies(playerInventory, knife)) == null,
            "third transaction succeeds with the same material costs");
        consumed(items, playerInventory);
        condition(knife, 48, 80);
        near(knife.getMinDamage(), 8 * oldMin, "minimum damage x8");
        near(knife.getMaxDamage(), 8 * oldMax, "effective maximum damage x8 with same sharpness");
        near(knife.getSharpness(), sharpness, "third level retains sharpness");
        near(knife.getActualWeight(), originalWeight * 0.5f, "third level halves actual weight");
        near(knife.getWeight(), originalWeight * 0.5f, "third level halves item weight");
        near(knife.getUnequippedWeight(), originalWeight * 0.5f, "third level halves backpack weight");
        near(knife.getEquippedWeight(), equippedWeight * 0.5f, "third level halves equipped weight");
        check("MaxLevel".equals(Upgrade.blocker(knife)) && Upgrade.preview(knife) == null, "level 4 unavailable");
        restored = roundTrip(roundTrip(knife));
        condition(restored, 48, 80);
        near(restored.getActualWeight(), originalWeight * 0.5f, "native weight survives repeated load without stacking");
        near(restored.getWeight(), originalWeight * 0.5f, "native item weight is restored");
        near(restored.getMaxDamage(), knife.getMaxDamage(), "third-level damage survives save and load");
        check(WeaponPersistence.validLevel(restored) == 3, "maximum level restored");
        condition(plain, 10, 10);
        near(plain.getActualWeight(), originalWeight, "same unmarked weapon template weight never modified");
        check(WeaponPersistence.validLevel(plain) == 0, "same unmarked weapon template never modified");

        var axe = (HandWeapon) playerInventory.AddItem(create(axeTemplate));
        int originalBody = axe.getConditionMax();
        int originalHead = axe.getHeadConditionMax();
        check(axe.hasHeadCondition(), "native axe tests independent head");
        axe.setConditionWhileLoading(originalBody - 2);
        axe.setHeadCondition(originalHead - 3);
        addSupplies(supplies, nails, sheet, cloth);
        check(Upgrade.commit(playerInventory, axe, Upgrade.preview(axe), Upgrade.supplies(playerInventory, axe)) == null,
            "axe with worn body and head upgrades");
        condition(axe, 2 * (originalBody - 2), 2 * originalBody);
        check(axe.getHeadConditionMax() == 2 * originalHead && axe.getHeadCondition() == 2 * (originalHead - 3),
            "independent head preserves its own wear ratio");

        axeTemplate.setConditionMax(70);
        var highAxe = (HandWeapon) playerInventory.AddItem(create(axeTemplate));
        highAxe.setConditionWhileLoading(68);
        for (int level = 1; level <= 3; level++) {
            addSupplies(supplies, nails, sheet, cloth);
            check(Upgrade.commit(playerInventory, highAxe, Upgrade.preview(highAxe),
                Upgrade.supplies(playerInventory, highAxe)) == null, "high-cap axe upgrades to " + level);
        }
        condition(highAxe, 123, 127);
        restored = roundTrip(highAxe);
        condition(restored, 123, 127);
        check(restored.getHeadConditionMax() == highAxe.getHeadConditionMax()
            && restored.getHeadCondition() == highAxe.getHeadCondition(), "native head stats survive with high body cap");
        restored.setCondition(Integer.MAX_VALUE, false);
        condition(restored, 127, 127);
        var repairedFull = roundTrip(restored);
        condition(repairedFull, 127, 127);

        // RecipeCodeOnCreate's whetstone, file and grindstone share the native setSharpness call.
        knife.setSharpness(knife.getSharpness() + 10.0f);
        near(knife.getSharpness(), 48f / 80, "sharpening cannot exceed worn body condition ratio");
        knife.setCondition(Integer.MAX_VALUE, false);
        knife.setSharpness(1.1f);
        near(knife.getSharpness(), 1.0f, "fully repaired weapon cannot sharpen above 100%");

        int limitHead = axe.getHeadConditionMax();
        axe.setSharpness(1.1f);
        near(axe.getSharpness(), (float) axe.getHeadCondition() / limitHead,
            "sharpening uses the worn independent head cap");
        axe.setHeadCondition(Integer.MAX_VALUE);
        check(axe.getHeadCondition() == limitHead, "head repair cannot exceed its upgraded limit");
        axe.setSharpness(1.1f);
        near(axe.getSharpness(), 1.0f, "fully repaired head cannot sharpen above 100%");

        System.out.println("NATIVE_MELEE_UPGRADE PASS assertions=" + assertions);
    }
}
