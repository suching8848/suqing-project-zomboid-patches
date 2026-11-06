package suqingworldstateguard;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.characterTextures.BloodBodyPartType;
import zombie.characters.IsoGameCharacter;

@Patch(className = "zombie.characters.IsoGameCharacter", methodName = "addHole", strictMatch = true)
public final class PatchAnimalHole {
    private PatchAnimalHole() {}

    @Patch.OnEnter(skipOn = true)
    public static boolean enter(
        @Patch.This IsoGameCharacter character,
        @Patch.Argument(0) BloodBodyPartType bodyPart,
        @Patch.Argument(1) boolean alsoSkin
    ) {
        // ByteBuddy returns the original boolean method's default false only when this is true.
        return AnimalHoleGuard.shouldSkip(character);
    }
}
