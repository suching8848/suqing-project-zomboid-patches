package suqingmeleeupgrade;

public final class Main {
    private static final String LOG = "[SuQingMeleeUpgrade] ";
    private static volatile boolean wearInstalled;

    private Main() {}

    public static synchronized void main(String[] args) {
        if (!WeaponPersistence.isSupported()) {
            System.err.println(LOG + "inactive: requires single-player Build 42.22.2 (3d39148846)");
            return;
        }
        wearInstalled = WearPatch.install();
    }

    static boolean ready() {
        // ZombieBuddy applies the annotation patches after the package entry point.
        return wearInstalled && WearPatch.isActive() && WeaponPersistence.verifyInstalledBridge();
    }
}
