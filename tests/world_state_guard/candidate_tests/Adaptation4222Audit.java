import java.io.*;
import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import java.util.jar.JarFile;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.description.method.MethodDescription;
import net.bytebuddy.dynamic.ClassFileLocator;
import net.bytebuddy.dynamic.loading.ByteArrayClassLoader;
import net.bytebuddy.jar.asm.*;
import net.bytebuddy.matcher.ElementMatcher;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.pool.TypePool;
import me.zed_0xff.zombie_buddy.Patch;

public final class Adaptation4222Audit {
    private static final String ANIMAL = "zombie.characters.IsoGameCharacter";
    private static final String VEHICLE = "zombie.vehicles.BaseVehicle";
    private static final String ANIMAL_PATCH = "suqingworldstateguard.PatchAnimalHole";
    private static final String VEHICLE_PATCH = "suqingworldstateguard.PatchVehicleChunk";
    private static final String COMPAT = "suqingworldstateguard.Compatibility";
    private static final String CORE = "zombie.core.Core";
    private static final String UNKNOWN = "unknown";
    private static final String MISSING = "missing";
    private static final String UNREADABLE = "unreadable";
    private static int checks;

    private static void check(boolean value, String message) {
        ++checks;
        if (!value) throw new AssertionError(message);
    }

    private record Resources(byte[] animal, byte[] vehicle) {}

    private static final byte[] READ_FAILURE = new byte[0];

    private static final class Loader extends ByteArrayClassLoader.ChildFirst {
        private final Resources resources;

        Loader(Map<String,byte[]> classes, Resources resources) throws ReflectiveOperationException {
            this(classes,resources,"42.22.2");
        }

        Loader(Map<String,byte[]> classes, Resources resources, String build) throws ReflectiveOperationException {
            super(Adaptation4222Audit.class.getClassLoader(),classes,PersistenceHandler.MANIFEST);
            this.resources = resources;
            loadClass(CORE).getField("fixtureBuild").set(null,build);
        }

        @Override public InputStream getResourceAsStream(String name) {
            byte[] bytes;
            if (name.equals(ANIMAL.replace('.','/')+".class")) bytes = resources.animal;
            else if (name.equals(VEHICLE.replace('.','/')+".class")) bytes = resources.vehicle;
            else return super.getResourceAsStream(name);
            if (bytes == READ_FAILURE) {
                return new InputStream() {
                    @Override public int read() throws IOException { throw new IOException("fixture unreadable"); }
                };
            }
            return bytes == null ? null : new ByteArrayInputStream(bytes);
        }
    }

    private static Map<String,byte[]> readPlugin(Path jarPath) throws IOException {
        try (var jar = new JarFile(jarPath.toFile())) {
            check("0.1.1-candidate".equals(jar.getManifest().getMainAttributes().getValue("Implementation-Version")),
                "packaged candidate version");
            var plugin = new HashMap<String,byte[]>();
            for (var item : jar.stream().filter(e->e.getName().endsWith(".class")).toList()) {
                var name = item.getName();
                check(name.startsWith("suqingworldstateguard/"), "candidate class namespace "+name);
                plugin.put(name.substring(0,name.length()-6).replace('/','.'),jar.getInputStream(item).readAllBytes());
            }
            check(plugin.size()==7,"exact plugin class count");
            return plugin;
        }
    }

    private static byte[] jarClass(Path jar,String name) throws IOException {
        return AdviceIntegrationAudit.jarBytes(jar,name.replace('.','/')+".class");
    }

    private static void assertProfile(Map<String,byte[]> plugin, String label, Resources resources, String build,
                                      boolean animalExpected, boolean vehicleExpected) throws Exception {
        Class<?> gate = new Loader(plugin,resources,build).loadClass(COMPAT);
        check(gate.getMethod("isAnimalSupported").invoke(null).equals(animalExpected),"animal gate "+label);
        check(gate.getMethod("isVehicleSupported").invoke(null).equals(vehicleExpected),"vehicle gate "+label);
        System.out.println("PROFILE "+label+" build="+build+" animal="+animalExpected+" vehicle="+vehicleExpected);
    }

    @SuppressWarnings("unchecked")
    private static ElementMatcher<MethodDescription> actualVehicleMatcher(Class<?> converted) throws Exception {
        var patch = converted.getAnnotation(Patch.class);
        check(patch.strictMatch() && patch.className().equals(VEHICLE) && patch.methodName().equals("update"),"vehicle target annotation");
        var enter = Arrays.stream(converted.getDeclaredMethods())
            .filter(m->m.isAnnotationPresent(Advice.OnMethodEnter.class)).findFirst().orElseThrow();
        check(enter.getReturnType()==void.class && enter.getAnnotation(Advice.OnMethodEnter.class).skipOn()==void.class,
            "vehicle advice always continues the original update");
        check(enter.getParameterCount()==1 && enter.getParameters()[0].isAnnotationPresent(Advice.This.class),
            "vehicle converter preserved receiver-only advice");
        var type = Class.forName("me.zed_0xff.zombie_buddy.PatchEngine$2");
        var constructor = type.getDeclaredConstructor(boolean.class,boolean.class,List.class,List.class,int.class);
        constructor.setAccessible(true);
        return (ElementMatcher<MethodDescription>)constructor.newInstance(true,true,List.of(),List.of(),0);
    }

    private static byte[] weaveVehicle(Map<String,byte[]> classes, ElementMatcher<MethodDescription> signature,
                                       ClassFileLocator fallback) throws Exception {
        var locator = new ClassFileLocator.Compound(new ClassFileLocator.Simple(classes),fallback);
        var pool = TypePool.Default.of(locator);
        var vehicle = pool.describe(VEHICLE).resolve();
        var matcher = ElementMatchers.named("update").and(signature);
        var hits = vehicle.getDeclaredMethods().filter(matcher);
        check(hits.size()==1 && hits.getOnly().getDescriptor().equals("()V"),"actual ZB matcher selects only update()V");
        byte[] woven = new ByteBuddy().redefine(vehicle,locator)
            .visit(Advice.to(pool.describe(VEHICLE_PATCH).resolve(),locator).on(matcher)).make().getBytes();
        var sites = new ArrayList<String>();
        new ClassReader(woven).accept(new ClassVisitor(Opcodes.ASM9) {
            @Override public MethodVisitor visitMethod(int access,String name,String descriptor,String signature,String[] exceptions) {
                return new MethodVisitor(Opcodes.ASM9) {
                    @Override public void visitMethodInsn(int op,String owner,String method,String desc,boolean itf) {
                        if (owner.equals("suqingworldstateguard/VehicleChunkGuard") && method.equals("restoreIfProven"))
                            sites.add(name+descriptor);
                    }
                };
            }
        },ClassReader.SKIP_DEBUG|ClassReader.SKIP_FRAMES);
        check(sites.equals(List.of("update()V")), "exactly one vehicle advice call site");
        return woven;
    }

    private static void run(ClassLoader loader,String className,String... args) throws Throwable {
        try {loader.loadClass(className).getMethod("main",String[].class).invoke(null,(Object)args);}
        catch (InvocationTargetException ex) {throw ex.getCause();}
    }

    public static void main(String[] args) throws Throwable {
        var work = Path.of(args[0]);
        var candidate = Path.of(args[1]);
        var oldGame = Path.of(args[2]);
        var newGame = Path.of(args[3]);
        var oldPzo = Path.of(args[4]);
        var old = new Resources(jarClass(oldGame,ANIMAL),jarClass(oldGame,VEHICLE));
        var newer = new Resources(jarClass(newGame,ANIMAL),jarClass(newGame,VEHICLE));
        var pzo = new Resources(jarClass(oldPzo,ANIMAL),old.vehicle);
        var unknown = new byte[]{1,2,3};
        Map<String,byte[]> profiles = new HashMap<>();
        profiles.put("oldAnimal",old.animal); profiles.put("oldVehicle",old.vehicle);
        profiles.put("newAnimal",newer.animal); profiles.put("newVehicle",newer.vehicle);
        profiles.put("pzoAnimal",pzo.animal); profiles.put(UNKNOWN,unknown);
        profiles.put(MISSING,null); profiles.put(UNREADABLE,READ_FAILURE);

        var plugin = readPlugin(candidate);
        var coreStub = AdviceIntegrationAudit.readClasses(work.resolve("animal-new")).get(CORE);
        var gates = new HashMap<>(plugin);
        gates.put(CORE,coreStub);
        int profileCount=0;
        for (String row : Files.readAllLines(work.resolve("gate-profiles.tsv"))) {
            var cells=row.split("\t");
            assertProfile(gates,cells[0],new Resources(profiles.get(cells[1]),profiles.get(cells[2])),
                cells[3].equals("-") ? null : cells[3],Boolean.parseBoolean(cells[4]),Boolean.parseBoolean(cells[5]));
            ++profileCount;
        }

        var animalStubs = AdviceIntegrationAudit.readClasses(work.resolve("animal-new"));
        animalStubs.putAll(plugin);
        var mappedAnimal = AdviceIntegrationAudit.convertUsingActualZombieBuddy(new Loader(animalStubs,newer).loadClass(ANIMAL_PATCH));
        animalStubs.put(ANIMAL_PATCH,mappedAnimal);
        var animalMatcher = AdviceIntegrationAudit.actualSignatureMatcher(new Loader(animalStubs,newer).loadClass(ANIMAL_PATCH));

        var vehicleStubs = AdviceIntegrationAudit.readClasses(work.resolve("vehicle-fixture"));
        var vehicleConversion = new HashMap<>(vehicleStubs);
        vehicleConversion.putAll(plugin);
        vehicleConversion.put(CORE,coreStub);
        var mappedVehicle = AdviceIntegrationAudit.convertUsingActualZombieBuddy(new Loader(vehicleConversion,newer).loadClass(VEHICLE_PATCH));
        vehicleConversion.put(VEHICLE_PATCH,mappedVehicle);
        var vehicleMatcher = actualVehicleMatcher(new Loader(vehicleConversion,newer).loadClass(VEHICLE_PATCH));

        var system = ClassFileLocator.ForClassLoader.of(Adaptation4222Audit.class.getClassLoader());
        try (var oldLocator = ClassFileLocator.ForJarFile.of(oldGame.toFile());
             var newLocator = ClassFileLocator.ForJarFile.of(newGame.toFile());
             var pzoLocator = ClassFileLocator.ForJarFile.of(oldPzo.toFile())) {
            var allProfiles = Map.of("old",old,"new",newer,"pzo",pzo);
            for (var entry : allProfiles.entrySet()) {
                String label = entry.getKey();
                Resources bytes = entry.getValue();
                ClassFileLocator gameLocator = switch (label) {
                    case "new" -> newLocator;
                    case "pzo" -> new ClassFileLocator.Compound(pzoLocator,oldLocator);
                    default -> oldLocator;
                };
                var animalActual = new HashMap<>(plugin);
                animalActual.put(ANIMAL_PATCH,mappedAnimal);
                animalActual.put(ANIMAL,bytes.animal);
                var animalWoven = AdviceIntegrationAudit.weave(animalActual,animalMatcher,new ClassFileLocator.Compound(gameLocator,system));
                AdviceIntegrationAudit.verifyCallSites(animalWoven);
                check(AdviceIntegrationAudit.singleTrace(bytes.animal).equals(AdviceIntegrationAudit.singleTrace(animalWoven)),
                    "original single-argument overload untouched "+label);
                Files.write(work.resolve("IsoGameCharacter-"+label+"-woven.class"),animalWoven);
                var vehicleActual = new HashMap<>(plugin);
                vehicleActual.put(VEHICLE_PATCH,mappedVehicle);
                vehicleActual.put(VEHICLE,bytes.vehicle);
                var vehicleWoven = weaveVehicle(vehicleActual,vehicleMatcher,new ClassFileLocator.Compound(gameLocator,system));
                Files.write(work.resolve("BaseVehicle-"+label+"-woven.class"),vehicleWoven);
                System.out.println("WEAVE actual "+label+" addHole(bodyPart,boolean) and update()V");

                var fixture = AdviceIntegrationAudit.readClasses(work.resolve("animal-"+label));
                fixture.putAll(plugin);
                fixture.put(ANIMAL_PATCH,mappedAnimal);
                String build = label.equals("new") ? "42.22.2" : "42.21.0";
                run(new Loader(fixture,bytes,build),"repro.HoleRegression","suqingworldstateguard.AnimalHoleGuard","shouldSkip",label);
                fixture.put(ANIMAL,AdviceIntegrationAudit.weave(fixture,animalMatcher,system));
                AdviceIntegrationAudit.verifyCallSites(fixture.get(ANIMAL));
                run(new Loader(fixture,bytes,build),"repro.WovenHoleRegression","suqingworldstateguard.AnimalHoleGuard","shouldSkip",label);
            }
        }

        var mixed = new Resources(pzo.animal,newer.vehicle);
        var newerAnimal = new HashMap<>(animalStubs);
        newerAnimal.put(ANIMAL,AdviceIntegrationAudit.weave(newerAnimal,animalMatcher,system));
        run(new Loader(newerAnimal,mixed),"repro.GateReject","suqingworldstateguard.AnimalHoleGuard","shouldSkip","mixed");
        run(new Loader(newerAnimal,new Resources(unknown,newer.vehicle)),"repro.GateReject",
            "suqingworldstateguard.AnimalHoleGuard","shouldSkip","unknown");

        var vehicleWoven = new HashMap<>(vehicleConversion);
        vehicleWoven.put(VEHICLE,weaveVehicle(vehicleWoven,vehicleMatcher,system));
        run(new Loader(vehicleWoven,newer),"suqingworldstateguard.VehicleGateRegression","true");
        run(new Loader(vehicleWoven,mixed),"suqingworldstateguard.VehicleGateRegression","false");
        run(new Loader(vehicleWoven,new Resources(newer.animal,unknown)),"suqingworldstateguard.VehicleGateRegression","false");

        // Exercise every pre-existing vehicle assertion through the actual woven entry.
        vehicleWoven.put(COMPAT,vehicleStubs.get(COMPAT));
        run(new Loader(vehicleWoven,newer),"suqingworldstateguard.VehicleGuardRegression");

        System.out.println("PASS adaptation audit="+checks+" assertions, "+profileCount+" resource profiles; imported advice assertions="
            + AdviceIntegrationAudit.checks);
    }
}
