package suqinglunchboxweight;

import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import zombie.core.Core;

public final class Compatibility {
    private Compatibility() {}

    private static final class Status {
        static final boolean SUPPORTED = verify();
    }

    public static boolean isSupported() {
        return Status.SUPPORTED;
    }

    private static boolean verify() {
        String version = Core.getInstance().getGameAndBuildVersion();
        boolean supported = "42.22.2".equals(version)
            && matches("zombie/inventory/InventoryItem.class",
                "b45d4438636509d992aaa7b7505ef8323cd898947efc27bf1f7e762951d6643d")
            && matches("zombie/inventory/types/InventoryContainer.class",
                "891cb2f37a7d13de869edf05909de493a55ef90aa8665368b36bff7fa6b2555e");
        System.out.println("[SuQingLunchboxWeight] build=" + version + " verified=" + supported);
        return supported;
    }

    private static boolean matches(String name, String expected) {
        try (InputStream input = Compatibility.class.getClassLoader().getResourceAsStream(name)) {
            if (input == null) return false;
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(input.readAllBytes());
            return expected.equals(HexFormat.of().formatHex(digest));
        } catch (IOException | NoSuchAlgorithmException error) {
            System.err.println("[SuQingLunchboxWeight] class verification failed " + name + " " + error);
            return false;
        }
    }
}
