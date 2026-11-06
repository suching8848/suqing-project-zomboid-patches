package suqingworldstateguard;
import me.zed_0xff.zombie_buddy.Patch;
import zombie.vehicles.BaseVehicle;

@Patch(className="zombie.vehicles.BaseVehicle", methodName="update", strictMatch=true)
public final class PatchVehicleChunk {
    @Patch.OnEnter
    public static void enter(@Patch.This BaseVehicle vehicle) {
        if (Compatibility.isVehicleSupported()) VehicleChunkGuard.restoreIfProven(vehicle);
    }
}
