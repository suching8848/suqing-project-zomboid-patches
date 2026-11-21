package suqingmeleeupgrade;

import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import java.security.ProtectionDomain;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

import me.zed_0xff.zombie_buddy.Loader;
import net.bytebuddy.jar.asm.ClassReader;
import net.bytebuddy.jar.asm.ClassVisitor;
import net.bytebuddy.jar.asm.ClassWriter;
import net.bytebuddy.jar.asm.MethodVisitor;
import net.bytebuddy.jar.asm.Label;
import net.bytebuddy.jar.asm.Opcodes;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.HandWeapon;
import zombie.network.GameClient;
import zombie.network.GameServer;

public final class WearPatch {
    private static final String LOG = "[SuQingMeleeUpgrade] ";
    private static final String TARGET = "zombie/inventory/InventoryItem";
    private static final String RANDOM = "zombie/core/random/Rand";
    private static final String PATCH = "suqingmeleeupgrade/WearPatch";
    private static final String CHECK = "(IFZZLzombie/characters/IsoGameCharacter;)Z";
    private static final String GATE = "(ZLzombie/inventory/InventoryItem;)Z";

    private record Site(String wearEffect, String gate) {}

    private static final Map<String, Site> SITES = Map.of(
        "damageCheck", new Site("reduceCondition", "permitWear"),
        "headConditionCheck", new Site("reduceHeadCondition", "permitWear"),
        "sharpnessCheck", new Site("reduceSharpness", "permitSharpnessCheck")
    );

    private static volatile Transformer installed;

    private WearPatch() {}

    public static synchronized boolean install() {
        if (installed != null) return isActive();
        Instrumentation instrumentation = null;
        Transformer transformer = new Transformer();
        boolean registered = false;
        try {
            // ZombieBuddy owns this Instrumentation instance. Reuse it after the approved mod is loaded.
            Field field = Loader.class.getDeclaredField("g_instrumentation");
            if (!field.trySetAccessible()) throw new IllegalStateException("ZombieBuddy instrumentation is inaccessible");
            instrumentation = (Instrumentation) field.get(null);
            if (instrumentation == null || !instrumentation.isRetransformClassesSupported()
                || !instrumentation.isModifiableClass(InventoryItem.class)) {
                throw new IllegalStateException("ZombieBuddy cannot retransform InventoryItem");
            }
            instrumentation.addTransformer(transformer, true);
            registered = true;
            instrumentation.retransformClasses(InventoryItem.class);
            if (!transformer.applied) throw new IllegalStateException("three native wear checks were not matched");
            installed = transformer;
            System.out.println(LOG + "native body, head and dull-blade wear checks attached");
            return true;
        } catch (Exception | LinkageError failure) {
            if (registered) instrumentation.removeTransformer(transformer);
            System.err.println(LOG + "wear integration unavailable: " + failure);
            return false;
        }
    }

    public static boolean isActive() {
        Transformer transformer = installed;
        return transformer != null && transformer.applied;
    }

    public static boolean permitWear(boolean vanillaWear, InventoryItem item) {
        return vanillaWear && retainWear(level(item));
    }

    public static boolean permitSharpnessCheck(boolean vanillaWear, InventoryItem item) {
        if (!vanillaWear) return false;
        int level = level(item);
        // The same native check handles both positive sharpness loss and physical wear at zero.
        return level == 0 || !(item.getSharpness() <= 0.0f) || retainWear(level);
    }

    private static int level(InventoryItem item) {
        if (item instanceof HandWeapon weapon && !GameClient.client && !GameServer.server) {
            return WeaponPersistence.validLevel(weapon);
        }
        return 0;
    }

    private static boolean retainWear(int level) {
        // Keep the native roll and give upgraded weapons an independent chance to absorb successful wear.
        return level == 0 || ThreadLocalRandom.current().nextInt(Upgrade.multiplier(level)) == 0;
    }

    private static final class Transformer implements ClassFileTransformer {
        private volatile boolean applied;

        @Override
        public byte[] transform(ClassLoader loader, String name, Class<?> redefined,
                                ProtectionDomain domain, byte[] original) {
            if (!TARGET.equals(name) || redefined != InventoryItem.class) return null;
            try {
                byte[] rewritten = rewrite(original);
                applied = true;
                return rewritten;
            } catch (RuntimeException | LinkageError failure) {
                applied = false;
                System.err.println(LOG + "wear checks left at native behavior: " + failure);
                return null;
            }
        }
    }

    static byte[] rewrite(byte[] original) {
        ClassReader reader = new ClassReader(original);
        if (!TARGET.equals(reader.getClassName())) throw new IllegalArgumentException("unexpected wear target class");
        ClassWriter writer = new ClassWriter(reader, ClassWriter.COMPUTE_MAXS);
        int[] matched = {0};
        reader.accept(new ClassVisitor(Opcodes.ASM9, writer) {
            @Override
            public MethodVisitor visitMethod(int access, String name, String descriptor,
                                             String signature, String[] exceptions) {
                MethodVisitor method = super.visitMethod(access, name, descriptor, signature, exceptions);
                Site site = SITES.get(name);
                if (!CHECK.equals(descriptor) || site == null) return method;
                if ((access & Opcodes.ACC_STATIC) != 0) throw new IllegalStateException("wear check became static");
                return new RollSite(method, site) {
                    @Override public void visitEnd() {
                        super.visitEnd();
                        matched[0]++;
                    }
                };
            }
        }, 0);
        if (matched[0] != SITES.size()) throw new IllegalStateException("incomplete wear check set");
        return writer.toByteArray();
    }

    private static class RollSite extends MethodVisitor {
        // Native shape: Rand.NextBool -> IFEQ -> ALOAD 0 -> reduceCondition/reduceHeadCondition/reduceSharpness.
        private static final int SEEK_ROLL = 0;
        private static final int EXPECT_BRANCH = 1;
        private static final int EXPECT_RECEIVER = 2;
        private static final int EXPECT_EFFECT = 3;
        private static final int MATCHED = 4;

        private final Site site;
        private int position = SEEK_ROLL;

        RollSite(MethodVisitor method, Site site) {
            super(Opcodes.ASM9, method);
            this.site = site;
        }

        private void require(boolean matches) {
            if (!matches) throw new IllegalStateException("unexpected native wear path for " + site.wearEffect());
        }

        private void outsideSite() {
            require(position == SEEK_ROLL || position == MATCHED);
        }

        @Override
        public void visitMethodInsn(int opcode, String owner, String name, String descriptor, boolean isInterface) {
            if (opcode == Opcodes.INVOKESTATIC && RANDOM.equals(owner) && "NextBool".equals(name) && "(I)Z".equals(descriptor)) {
                require(position == SEEK_ROLL && !isInterface);
                super.visitMethodInsn(opcode, owner, name, descriptor, false);
                super.visitVarInsn(Opcodes.ALOAD, 0);
                super.visitMethodInsn(Opcodes.INVOKESTATIC, PATCH, site.gate(), GATE, false);
                position = EXPECT_BRANCH;
                return;
            }
            if (position == EXPECT_EFFECT) {
                require(opcode == Opcodes.INVOKEVIRTUAL && TARGET.equals(owner) && site.wearEffect().equals(name)
                    && "()V".equals(descriptor) && !isInterface);
                position = MATCHED;
            } else {
                outsideSite();
            }
            super.visitMethodInsn(opcode, owner, name, descriptor, isInterface);
        }

        @Override
        public void visitJumpInsn(int opcode, Label label) {
            if (position == EXPECT_BRANCH) {
                require(opcode == Opcodes.IFEQ);
                position = EXPECT_RECEIVER;
            } else {
                outsideSite();
            }
            super.visitJumpInsn(opcode, label);
        }

        @Override
        public void visitVarInsn(int opcode, int var) {
            if (position == EXPECT_RECEIVER) {
                require(opcode == Opcodes.ALOAD && var == 0);
                position = EXPECT_EFFECT;
            } else {
                outsideSite();
            }
            super.visitVarInsn(opcode, var);
        }

        @Override
        public void visitInsn(int opcode) {
            outsideSite();
            super.visitInsn(opcode);
        }

        @Override
        public void visitEnd() {
            require(position == MATCHED);
            super.visitEnd();
        }
    }
}
