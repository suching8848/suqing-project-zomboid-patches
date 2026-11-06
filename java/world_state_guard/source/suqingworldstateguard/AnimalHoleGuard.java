package suqingworldstateguard;

import java.util.concurrent.atomic.AtomicLong;
import zombie.characters.IsoGameCharacter;
import zombie.characters.animals.IsoAnimal;
import zombie.core.skinnedmodel.visual.IHumanVisual;

/** Protect only the human clothing-hole operation on an animal with no human visual. */
public final class AnimalHoleGuard {
    private static final AtomicLong SKIPPED = new AtomicLong();

    private AnimalHoleGuard() {}

    public static boolean applies(IsoGameCharacter character) {
        return character instanceof IsoAnimal
            && ((IHumanVisual) character).getHumanVisual() == null;
    }

    public static boolean shouldSkip(IsoGameCharacter character) {
        if (!Compatibility.isAnimalSupported() || !applies(character)) {
            return false;
        }
        if (SKIPPED.incrementAndGet() == 1) {
            System.out.println("[SuQingWorldStateGuard] Prevented animal human-clothing hole call; fall damage and landing logic remain active.");
        }
        return true;
    }
}
