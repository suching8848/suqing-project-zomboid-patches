package suqingworldstateguard;

import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;

/** Resource hashes describe original/PZO class bytes before runtime Java advice weaving. */
public final class Compatibility {
    public static final String ANIMAL_STOCK_SHA256 = "29040E19C3E420499F73BC0EA0D5B86D7F7D38655ACDC13D0107DF736EB54C0B";
    public static final String ANIMAL_PZO_SHA256 = "E4A9984940B144D976FF37331ED7DAD4B1DE7A017D34AD8BB47FF877F1EA3853";
    // Populated from the checked local projectzomboid.jar during candidate construction.
    public static final String VEHICLE_STOCK_SHA256 = "E7ADE19E1E6F66450BEF2BD37E52B2AFCCC7377C4E4571D0FA39435ECDB55661";

    private Compatibility() {}

    private static final class Status {
        static final boolean ANIMAL = verify("zombie/characters/IsoGameCharacter.class", true);
        static final boolean VEHICLE = verify("zombie/vehicles/BaseVehicle.class", false);
    }

    public static boolean isAnimalSupported() {
        return Status.ANIMAL;
    }

    public static boolean isVehicleSupported() {
        return Status.VEHICLE;
    }

    public static boolean isAllowedAnimalHash(String hash) {
        if (hash == null) return false;
        String normalized = hash.toUpperCase(Locale.ROOT);
        return ANIMAL_STOCK_SHA256.equals(normalized) || ANIMAL_PZO_SHA256.equals(normalized);
    }

    public static boolean isAllowedVehicleHash(String hash) {
        return hash != null && VEHICLE_STOCK_SHA256.equals(hash.toUpperCase(Locale.ROOT));
    }

    private static boolean verify(String resource, boolean animal) {
        ClassLoader loader = Compatibility.class.getClassLoader();
        try (InputStream stream = loader.getResourceAsStream(resource)) {
            if (stream == null) {
                System.err.println("[SuQingWorldStateGuard] Guard inactive: class resource unavailable: " + resource);
                return false;
            }
            String hash = sha256(stream.readAllBytes());
            boolean allowed = animal ? isAllowedAnimalHash(hash) : isAllowedVehicleHash(hash);
            if (allowed) {
                System.out.println("[SuQingWorldStateGuard] Verified class resource " + resource + " sha256=" + hash);
            } else {
                System.err.println("[SuQingWorldStateGuard] Guard inactive for unknown class resource " + resource
                    + " sha256=" + hash + "; original game behavior retained.");
            }
            return allowed;
        } catch (IOException error) {
            System.err.println("[SuQingWorldStateGuard] Guard inactive: cannot read " + resource + ": " + error);
            return false;
        }
    }

    public static String sha256(byte[] bytes) {
        try {
            return HexFormat.of().withUpperCase().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException impossible) {
            throw new AssertionError("Java runtime does not provide SHA-256", impossible);
        }
    }
}
