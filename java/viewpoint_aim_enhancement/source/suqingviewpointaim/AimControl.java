package suqingviewpointaim;

import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;

import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.inventory.types.HandWeapon;

/** Bridges the selected Gunplay call sites to the original Viewpoint objects. */
public final class AimControl {
    private static final double FOCUS_SPEED = 2.0;
    private static NativeMethods nativeMethods;
    private static volatile IsoPlayer player;
    // The update, shot and frame snapshot paths run on Viewpoint's game thread.
    private static AimCycle cycle;

    private AimControl() {}

    static void bind(Class<?> gunplay) throws ReflectiveOperationException {
        nativeMethods = NativeMethods.open(gunplay);
    }

    static void setPlayer(IsoPlayer selected) {
        cycle = null;
        player = selected;
    }

    private static boolean enhanced(IsoGameCharacter owner) {
        return owner != null && owner == player && Main.singlePlayer() && owner.isAiming();
    }

    private static boolean sameCycle(IsoGameCharacter owner, HandWeapon weapon) {
        return cycle != null && cycle.weapon == weapon && enhanced(owner);
    }

    public static void reset(Object focus, IsoGameCharacter owner, HandWeapon weapon) throws Throwable {
        if (!sameCycle(owner, weapon)) nativeMethods.reset.invokeExact(focus);
    }

    public static void observeRelease(Object focus) throws Throwable {
        IsoPlayer owner = player;
        if (cycle != null && (!enhanced(owner) || owner.getPrimaryHandItem() != cycle.weapon)) {
            cycle = null;
            nativeMethods.reset.invokeExact(focus);
        }
    }

    public static void advance(Object focus, double seconds, int skill, boolean settled,
                               IsoGameCharacter owner, HandWeapon weapon) throws Throwable {
        if (enhanced(owner)) {
            if (cycle == null || cycle.weapon != weapon) {
                cycle = new AimCycle(weapon);
                nativeMethods.reset.invokeExact(focus);
            }
            nativeMethods.advance.invokeExact(focus, seconds * FOCUS_SPEED, skill, true);
        } else {
            if (owner == player && cycle != null) {
                cycle = null;
                nativeMethods.reset.invokeExact(focus);
            }
            nativeMethods.advance.invokeExact(focus, seconds, skill, settled);
        }
    }

    public static double tighten(Object focus, double radius, double floor,
                                 IsoGameCharacter owner, HandWeapon weapon) throws Throwable {
        if (sameCycle(owner, weapon)) {
            cycle.capture(radius, floor);
            radius = cycle.startRadius;
            floor = cycle.minimumRadius;
        }
        return (double) nativeMethods.tighten.invokeExact(focus, radius, floor);
    }

    public static void sway(Object sway, double seconds, double radius, double focus,
                            IsoGameCharacter owner, HandWeapon weapon) throws Throwable {
        // Apply the timed focus curve directly. Keep the original sway phase on real elapsed time.
        if (sameCycle(owner, weapon)) nativeMethods.setRadius.invokeExact(sway, radius);
        nativeMethods.sway.invokeExact(sway, seconds, radius, focus);
    }

    private static final class AimCycle {
        final HandWeapon weapon;
        boolean measured;
        double startRadius;
        double minimumRadius;

        AimCycle(HandWeapon weapon) {
            this.weapon = weapon;
        }

        void capture(double radius, double floor) {
            if (measured) return;
            startRadius = Math.max(radius, floor);
            minimumRadius = floor;
            measured = true;
        }
    }

    private record NativeMethods(MethodHandle reset, MethodHandle advance, MethodHandle tighten,
                                 MethodHandle sway, MethodHandle setRadius) {
        static NativeMethods open(Class<?> gunplay) throws ReflectiveOperationException {
            ClassLoader loader = gunplay.getClassLoader();
            Class<?> focus = Class.forName("viewpoint.gunplay.Focus", false, loader);
            Class<?> sway = Class.forName("viewpoint.gunplay.Sway", false, loader);
            MethodHandles.Lookup lookup = MethodHandles.lookup();
            MethodHandles.Lookup f = MethodHandles.privateLookupIn(focus, lookup);
            MethodHandles.Lookup s = MethodHandles.privateLookupIn(sway, lookup);
            return new NativeMethods(
                virtual(f, focus, "reset", void.class),
                virtual(f, focus, "advance", void.class, double.class, int.class, boolean.class),
                virtual(f, focus, "tighten", double.class, double.class, double.class),
                virtual(s, sway, "advance", void.class, double.class, double.class, double.class),
                s.findSetter(sway, "radius", double.class).asType(MethodType.methodType(void.class, Object.class, double.class))
            );
        }

        private static MethodHandle virtual(MethodHandles.Lookup lookup, Class<?> owner, String name,
                                            Class<?> result, Class<?>... parameters) throws ReflectiveOperationException {
            var target = lookup.findVirtual(owner, name, MethodType.methodType(result, parameters));
            return target.asType(target.type().changeParameterType(0, Object.class));
        }
    }
}
