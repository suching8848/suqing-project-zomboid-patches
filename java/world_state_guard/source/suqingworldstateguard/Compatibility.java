package suqingworldstateguard;

import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;
import zombie.core.Core;

/** Resource hashes describe original/PZO class bytes before runtime Java advice weaving. */
public final class Compatibility {
    public static final String ANIMAL_STOCK_SHA256 = "29040E19C3E420499F73BC0EA0D5B86D7F7D38655ACDC13D0107DF736EB54C0B";
    public static final String ANIMAL_PZO_SHA256 = "E4A9984940B144D976FF37331ED7DAD4B1DE7A017D34AD8BB47FF877F1EA3853";
    public static final String VEHICLE_STOCK_SHA256 = "E7ADE19E1E6F66450BEF2BD37E52B2AFCCC7377C4E4571D0FA39435ECDB55661";
    public static final String ANIMAL_STOCK_4222_SHA256 = "1CCABC492BA130F51486BF38A8400334545852253BBAC9C46FFF71242AB672F6";
    public static final String VEHICLE_STOCK_4222_SHA256 = "354B166DB919F8DE692A5327B7AFD01FEFDBFB8021F0C99E2B2B44A3FE606DE3";

    private static final String ANIMAL_RESOURCE = "zombie/characters/IsoGameCharacter.class";
    private static final String VEHICLE_RESOURCE = "zombie/vehicles/BaseVehicle.class";

    private Compatibility() {}

    private static final class Status {
        static final boolean ANIMAL;
        static final boolean VEHICLE;

        static {
            String animalHash = readHash(ANIMAL_RESOURCE);
            String vehicleHash = readHash(VEHICLE_RESOURCE);
            String build = readBuild();
            boolean newAnimal = ANIMAL_STOCK_4222_SHA256.equals(animalHash);
            boolean newVehicle = VEHICLE_STOCK_4222_SHA256.equals(vehicleHash);
            if ("42.22.2".equals(build) || newAnimal || newVehicle) {
                // The 42.22.2 stock pair is reviewed together. A 42.21 PZO
                // character class paired with a 42.22.2 vehicle class is unsupported.
                boolean supported = "42.22.2".equals(build) && newAnimal && newVehicle;
                if (supported) {
                    System.out.println("[SuQingWorldStateGuard] Verified 42.22.2 stock build and class pair.");
                } else {
                    System.err.println("[SuQingWorldStateGuard] Both guards inactive for build " + build
                        + " and this class pair. The reviewed profile requires the 42.22.2 stock build and both stock classes.");
                }
                ANIMAL = report(ANIMAL_RESOURCE, animalHash, supported);
                VEHICLE = report(VEHICLE_RESOURCE, vehicleHash, supported);
            } else {
                boolean legacyBuild = "42.21".equals(build) || build.startsWith("42.21.");
                ANIMAL = report(ANIMAL_RESOURCE, animalHash, legacyBuild && isAllowedAnimalHash(animalHash));
                VEHICLE = report(VEHICLE_RESOURCE, vehicleHash, legacyBuild && isAllowedVehicleHash(vehicleHash));
            }
        }
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
        return ANIMAL_STOCK_SHA256.equals(normalized) || ANIMAL_PZO_SHA256.equals(normalized)
            || ANIMAL_STOCK_4222_SHA256.equals(normalized);
    }

    public static boolean isAllowedVehicleHash(String hash) {
        if (hash == null) return false;
        String normalized = hash.toUpperCase(Locale.ROOT);
        return VEHICLE_STOCK_SHA256.equals(normalized) || VEHICLE_STOCK_4222_SHA256.equals(normalized);
    }

    private static String readBuild() {
        try {
            String build = Core.getInstance().getGameAndBuildVersion();
            return build == null ? "" : build;
        } catch (LinkageError | RuntimeException error) {
            System.err.println("[SuQingWorldStateGuard] Guards inactive: cannot read game build: " + error);
            return "";
        }
    }

    private static String readHash(String resource) {
        ClassLoader loader = Compatibility.class.getClassLoader();
        try (InputStream stream = loader.getResourceAsStream(resource)) {
            if (stream == null) {
                System.err.println("[SuQingWorldStateGuard] Guard inactive: class resource unavailable: " + resource);
                return null;
            }
            return sha256(stream.readAllBytes());
        } catch (IOException error) {
            System.err.println("[SuQingWorldStateGuard] Guard inactive: cannot read " + resource + ": " + error);
            return null;
        }
    }

    private static boolean report(String resource, String hash, boolean allowed) {
        if (hash == null) return false;
        if (allowed) {
            System.out.println("[SuQingWorldStateGuard] Verified class resource " + resource + " sha256=" + hash);
        } else {
            System.err.println("[SuQingWorldStateGuard] Guard inactive for unsupported class resource " + resource
                + " sha256=" + hash + "; original game behavior retained.");
        }
        return allowed;
    }

    public static String sha256(byte[] bytes) {
        try {
            return HexFormat.of().withUpperCase().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException impossible) {
            throw new AssertionError("Java runtime does not provide SHA-256", impossible);
        }
    }
}
