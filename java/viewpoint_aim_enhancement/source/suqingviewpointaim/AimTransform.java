package suqingviewpointaim;

import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import net.bytebuddy.jar.asm.ClassReader;
import net.bytebuddy.jar.asm.ClassVisitor;
import net.bytebuddy.jar.asm.ClassWriter;
import net.bytebuddy.jar.asm.MethodVisitor;
import net.bytebuddy.jar.asm.Opcodes;

final class AimTransform implements ClassFileTransformer {
    static final String TARGET = "viewpoint/gunplay/Gunplay";
    private static final String FOCUS = "viewpoint/gunplay/Focus";
    private static final String SWAY = "viewpoint/gunplay/Sway";
    private static final String BRIDGE = "suqingviewpointaim/AimControl";
    private static final String CONTEXT = "Lzombie/characters/IsoGameCharacter;Lzombie/inventory/types/HandWeapon;";
    private static final String CONTEXT_METHOD = "(" + CONTEXT + ")V";
    private static final List<Site> SITES = List.of(
        new Site("update", FOCUS, "reset", "()V", "reset"),
        new Site("shotStarting", FOCUS, "reset", "()V", "reset"),
        new Site("update", FOCUS, "advance", "(DIZ)V", "advance"),
        new Site("update", FOCUS, "tighten", "(DD)D", "tighten"),
        new Site("update", SWAY, "advance", "(DDD)V", "sway")
    );
    private final Class<?> gunplay;
    private volatile boolean applied;

    private AimTransform(Class<?> gunplay) {
        this.gunplay = gunplay;
    }

    static AimTransform install(Instrumentation instrumentation, Class<?> gunplay) throws Exception {
        if (!instrumentation.isRetransformClassesSupported() || !instrumentation.isModifiableClass(gunplay)) {
            throw new IllegalStateException("Viewpoint Gunplay cannot be retransformed");
        }
        AimControl.bind(gunplay);
        var transformer = new AimTransform(gunplay);
        instrumentation.addTransformer(transformer, true);
        try {
            instrumentation.retransformClasses(gunplay);
            if (!transformer.applied) throw new IllegalStateException("Required aim call sites were not matched");
            return transformer;
        } catch (Exception | LinkageError failure) {
            instrumentation.removeTransformer(transformer);
            throw failure;
        }
    }

    boolean applied() {
        return applied;
    }

    @Override
    public byte[] transform(ClassLoader loader, String name, Class<?> redefined,
                            ProtectionDomain domain, byte[] original) {
        if (!TARGET.equals(name) || redefined != gunplay) return null;
        try {
            byte[] updated = rewrite(original);
            applied = true;
            return updated;
        } catch (RuntimeException | LinkageError failure) {
            applied = false;
            AimControl.setPlayer(null);
            System.err.println(Main.LOG + "Gunplay left at native behavior: " + failure);
            return null;
        }
    }

    static byte[] rewrite(byte[] original) {
        var reader = new ClassReader(original);
        if (!TARGET.equals(reader.getClassName())) throw new IllegalArgumentException("Unexpected class");
        var writer = new ClassWriter(reader, ClassWriter.COMPUTE_MAXS);
        Set<Site> found = new HashSet<>();
        boolean[] snapshot = {false};
        reader.accept(new ClassVisitor(Opcodes.ASM9, writer) {
            @Override
            public MethodVisitor visitMethod(int access, String methodName, String descriptor,
                                             String signature, String[] exceptions) {
                MethodVisitor target = super.visitMethod(access, methodName, descriptor, signature, exceptions);
                if ((access & Opcodes.ACC_STATIC) == 0) return target;
                if ("snapshot".equals(methodName) && "()V".equals(descriptor)) {
                    snapshot[0] = true;
                    return new MethodVisitor(Opcodes.ASM9, target) {
                        @Override
                        public void visitCode() {
                            super.visitCode();
                            super.visitFieldInsn(Opcodes.GETSTATIC, TARGET, "focus", "L" + FOCUS + ";");
                            super.visitMethodInsn(Opcodes.INVOKESTATIC, BRIDGE, "observeRelease", "(Ljava/lang/Object;)V", false);
                        }
                    };
                }
                if (!CONTEXT_METHOD.equals(descriptor)
                    || !("update".equals(methodName) || "shotStarting".equals(methodName))) return target;
                return new MethodVisitor(Opcodes.ASM9, target) {
                    @Override
                    public void visitMethodInsn(int opcode, String owner, String name, String desc, boolean itf) {
                        if (opcode == Opcodes.INVOKEVIRTUAL && !itf) {
                            for (Site site : SITES) {
                                if (!site.matches(methodName, owner, name, desc)) continue;
                                if (!found.add(site)) throw new IllegalStateException("Duplicate " + site);
                                super.visitVarInsn(Opcodes.ALOAD, 0);
                                super.visitVarInsn(Opcodes.ALOAD, 1);
                                super.visitMethodInsn(Opcodes.INVOKESTATIC, BRIDGE, site.bridge,
                                    "(Ljava/lang/Object;" + desc.substring(1).replace(")", CONTEXT + ")"), false);
                                return;
                            }
                        }
                        super.visitMethodInsn(opcode, owner, name, desc, itf);
                    }
                };
            }
        }, 0);
        if (!snapshot[0] || found.size() != SITES.size()) throw new IllegalStateException("Incomplete aim call sites");
        return writer.toByteArray();
    }

    private record Site(String method, String owner, String name, String descriptor, String bridge) {
        boolean matches(String enclosing, String type, String called, String signature) {
            return method.equals(enclosing) && owner.equals(type) && name.equals(called) && descriptor.equals(signature);
        }
    }
}
