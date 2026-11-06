package suqingworldstateguard;

public final class Main {
    private Main() {}

    public static void main(String[] args) {
        System.out.println("[SuQingWorldStateGuard] 0.1.0 candidate: animalHole="
            + Compatibility.isAnimalSupported() + ", vehicleChunk=" + Compatibility.isVehicleSupported()
            + "; no save migration, database deletion, exception suppression, or world-copy bypass.");
    }
}
