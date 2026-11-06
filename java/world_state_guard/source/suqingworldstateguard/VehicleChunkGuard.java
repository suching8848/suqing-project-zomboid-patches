package suqingworldstateguard;

import java.util.Collection;
import java.util.WeakHashMap;
import zombie.iso.IsoCell;
import zombie.iso.IsoChunk;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoWorld;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.vehicleSound.VehicleSounds;
import zombie.vehicles.BaseVehicle;
import zombie.vehicles.VehicleParts;

/** Restores only a lost reference whose ownership is already proven by world registries. */
public final class VehicleChunkGuard {
    private static final WeakHashMap<BaseVehicle, Integer> diagnostics = new WeakHashMap<>();
    private static int diagnosticCount;
    private static final int MAX_DIAGNOSTICS = 128;
    private VehicleChunkGuard() {}

    /** Called only after Compatibility's exact BaseVehicle class-source SHA-256 gate passes. */
    public static boolean restoreIfProven(BaseVehicle vehicle) {
        if (vehicle == null || vehicle.chunk != null) return false;
        String rejected = null;
        IsoChunk owner = null;
        if (GameClient.client || GameServer.server) rejected = "multiplayer-unsupported";
        else if (!vehicle.addedToWorld || vehicle.isRemovedFromWorld()) rejected = "not-active-in-world";
        else if (!Float.isFinite(vehicle.getX()) || !Float.isFinite(vehicle.getY()) || !Float.isFinite(vehicle.getZ())) rejected = "non-finite-position";
        else {
            IsoCell cell = vehicle.getCell();
            IsoWorld world = IsoWorld.instance;
            if (world == null || cell == null || world.currentCell != cell) rejected = "not-current-cell";
            else if (identityCount(cell.vehicles, vehicle) != 1) rejected = "cell-membership-not-unique";
            else {
                IsoGridSquare square = vehicle.getSquare();
                if (square == null || vehicle.getCurrentSquare() != square) rejected = "current-square-unproven";
                else {
                    owner = square.chunk;
                    if (owner == null || !owner.loaded || owner.refs.isEmpty()) rejected = "chunk-not-loaded-and-referenced";
                    else if (identityCount(owner.vehicles, vehicle) != 1) rejected = "chunk-membership-not-unique";
                    else {
                        VehicleParts parts = vehicle.getParts();
                        VehicleSounds sounds = vehicle.getVehicleSounds();
                        if (parts == null || parts.getOwner() != vehicle) rejected = "parts-owner-not-vehicle";
                        else if (sounds != null && sounds.getOwner() != vehicle) rejected = "sounds-owner-not-vehicle";
                    }
                }
            }
        }
        if (rejected != null) {
            diagnostic(vehicle, 1, "not-restored", rejected);
            return false;
        }
        // Do not add/remove memberships, create chunks, restore virtual vehicles, or skip update.
        // This exact field is the sole write in the guard. The complete original method follows.
        vehicle.chunk = owner;
        diagnostic(vehicle, 2, "restored", "existing-unique-loaded-chunk=" + owner.wx + "," + owner.wy);
        return true;
    }

    private static int identityCount(Collection<?> list, Object object) {
        int count = 0;
        for (Object value : list.toArray()) if (value == object) ++count;
        return count;
    }

    private static synchronized void diagnostic(BaseVehicle vehicle, int bit, String action, String reason) {
        int flags = diagnostics.getOrDefault(vehicle, 0);
        if ((flags & bit) != 0 || diagnosticCount >= MAX_DIAGNOSTICS) return;
        diagnostics.put(vehicle, flags | bit);
        ++diagnosticCount;
        System.out.println("[SuQingWorldStateGuard] vehicle-chunk " + action
                + " sqlId=" + vehicle.getSqlId()
                + " position=" + vehicle.getX() + "," + vehicle.getY() + "," + vehicle.getZ()
                + " script=" + vehicle.getScriptName() + " reason=" + reason);
    }
}
