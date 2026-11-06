import java.io.*;
import java.lang.annotation.Annotation;
import java.lang.instrument.*;
import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import java.util.jar.*;
import net.bytebuddy.ByteBuddy;
import net.bytebuddy.asm.Advice;
import net.bytebuddy.description.method.MethodDescription;
import net.bytebuddy.description.type.TypeDescription;
import net.bytebuddy.dynamic.ClassFileLocator;
import net.bytebuddy.dynamic.loading.ByteArrayClassLoader;
import net.bytebuddy.jar.asm.*;
import net.bytebuddy.matcher.ElementMatcher;
import net.bytebuddy.matcher.ElementMatchers;
import net.bytebuddy.pool.TypePool;
import me.zed_0xff.zombie_buddy.Patch;

/** Isolated class-file weaving and stub-only execution. No game classes are initialized. */
public final class AdviceIntegrationAudit {
    static final String TARGET = "zombie.characters.IsoGameCharacter";
    static final String PATCH = "suqingworldstateguard.PatchAnimalHole";
    static final String DUAL = "(Lzombie/characterTextures/BloodBodyPartType;Z)Z";
    static final String SINGLE = "(Lzombie/characterTextures/BloodBodyPartType;)Z";
    static int checks;
    static void check(boolean result, String label) {
        ++checks;
        if (!result) throw new AssertionError(label);
    }
    static Map<String, byte[]> readClasses(Path folder) throws IOException {
        Map<String,byte[]> result = new HashMap<>();
        try (var walk = Files.walk(folder)) {
            for (Path path:walk.filter(p -> p.toString().endsWith(".class")).toList()) {
                String name = folder.relativize(path).toString().replace(File.separatorChar, '.');
                result.put(name.substring(0,name.length()-6),Files.readAllBytes(path));
            }
        }
        return result;
    }
    static byte[] jarBytes(Path jarPath,String name) throws IOException {
        try (JarFile jar = new JarFile(jarPath.toFile())) {
            return jar.getInputStream(jar.getJarEntry(name)).readAllBytes();
        }
    }
    static final class ResourceLoader extends ByteArrayClassLoader.ChildFirst {
        final byte[] animalResource;
        final byte[] vehicleResource;
        ResourceLoader(Map<String,byte[]> classes,byte[] animal,byte[] vehicle) {
            super(AdviceIntegrationAudit.class.getClassLoader(),classes,PersistenceHandler.MANIFEST);
            animalResource=animal;vehicleResource=vehicle;
        }
        @Override public InputStream getResourceAsStream(String name) {
            if(name.equals("zombie/characters/IsoGameCharacter.class"))return new ByteArrayInputStream(animalResource);
            if(name.equals("zombie/vehicles/BaseVehicle.class"))return new ByteArrayInputStream(vehicleResource);
            return super.getResourceAsStream(name);
        }
    }
    static byte[] convertUsingActualZombieBuddy(Class<?> raw) throws Exception {
        final byte[][] captured={null};
        Instrumentation recorder=(Instrumentation)Proxy.newProxyInstance(
            AdviceIntegrationAudit.class.getClassLoader(),new Class<?>[]{Instrumentation.class},
            (object,method,args)->{
                if(method.getName().equals("redefineClasses")) {
                    ClassDefinition[] definitions=(ClassDefinition[])args[0];
                    check(definitions.length==1,"one patch class converted");
                    captured[0]=definitions[0].getDefinitionClassFile();
                    return null;
                }
                throw new UnsupportedOperationException("Unexpected instrumentation action: "+method.getName());
            });
        Class<?> transformer=Class.forName("me.zed_0xff.zombie_buddy.PatchTransformer");
        Method convert=transformer.getDeclaredMethod("transformPatchClass",Class.class,Instrumentation.class,int.class,boolean.class);
        convert.setAccessible(true);
        convert.invoke(null,raw,recorder,0,false);
        check(captured[0]!=null,"real ZombieBuddy converter captured bytes without installing agent");
        return captured[0];
    }
    @SuppressWarnings("unchecked")
    static ElementMatcher<MethodDescription> actualSignatureMatcher(Class<?> converted) throws Exception {
        Method enter=Arrays.stream(converted.getDeclaredMethods())
            .filter(m->m.isAnnotationPresent(Advice.OnMethodEnter.class)).findFirst().orElseThrow();
        check(enter.getAnnotation(Advice.OnMethodEnter.class).skipOn()==Advice.OnNonDefaultValue.class,
            "real converter preserved boolean skipOn as OnNonDefaultValue");
        Map<Integer,Class<?>> arguments=new HashMap<>();
        Annotation[][] annotations=enter.getParameterAnnotations();
        for(int i=0;i<annotations.length;i++)for(Annotation annotation:annotations[i])
            if(annotation instanceof Advice.Argument argument)arguments.put(argument.value(),enter.getParameterTypes()[i]);
        check(arguments.size()==2 && arguments.containsKey(0) && arguments.containsKey(1),
            "complete explicit Argument(0)/Argument(1) signature");
        Patch patch=converted.getAnnotation(Patch.class);
        check(patch.strictMatch(),"strictMatch enabled");
        Class<?> matcherClass=Class.forName("me.zed_0xff.zombie_buddy.PatchEngine$2");
        Constructor<?> constructor=matcherClass.getDeclaredConstructor(boolean.class,boolean.class,List.class,List.class,int.class);
        constructor.setAccessible(true);
        return (ElementMatcher<MethodDescription>)constructor.newInstance(false,true,List.of(arguments),List.of(false),2);
    }
    static byte[] weave(Map<String,byte[]> classes,ElementMatcher<MethodDescription> signature,ClassFileLocator fallback) throws Exception {
        ClassFileLocator locator=new ClassFileLocator.Compound(new ClassFileLocator.Simple(classes),fallback);
        TypePool pool=TypePool.Default.of(locator);
        TypeDescription type=pool.describe(TARGET).resolve();
        var matcher=ElementMatchers.named("addHole").and(signature);
        var hits=type.getDeclaredMethods().filter(matcher);
        check(hits.size()==1 && hits.get(0).getDescriptor().equals(DUAL),"actual ZB matcher selects only addHole(bodyPart,boolean)");
        return new ByteBuddy().redefine(type,locator)
            .visit(Advice.to(pool.describe(PATCH).resolve(),locator).on(matcher)).make().getBytes();
    }
    static String singleTrace(byte[] bytes) {
        List<String> trace=new ArrayList<>();
        new ClassReader(bytes).accept(new ClassVisitor(Opcodes.ASM9) {
            @Override public MethodVisitor visitMethod(int access,String name,String descriptor,String signature,String[] exceptions) {
                if(!name.equals("addHole")||!descriptor.equals(SINGLE))return null;
                trace.add("method:"+access+":"+descriptor);
                return new MethodVisitor(Opcodes.ASM9) {
                    @Override public void visitInsn(int op){trace.add("i:"+op);}
                    @Override public void visitVarInsn(int op,int variable){trace.add("v:"+op+":"+variable);}
                    @Override public void visitMethodInsn(int op,String owner,String method,String desc,boolean itf){trace.add("m:"+op+":"+owner+":"+method+":"+desc+":"+itf);}
                };
            }
        },ClassReader.SKIP_DEBUG|ClassReader.SKIP_FRAMES);
        return trace.toString();
    }
    static void verifyCallSites(byte[] bytes) {
        Map<String,Integer> sites=new HashMap<>();
        new ClassReader(bytes).accept(new ClassVisitor(Opcodes.ASM9) {
            @Override public MethodVisitor visitMethod(int access,String name,String descriptor,String signature,String[] exceptions) {
                return new MethodVisitor(Opcodes.ASM9) {
                    @Override public void visitMethodInsn(int op,String owner,String method,String desc,boolean itf) {
                        if(owner.equals("suqingworldstateguard/AnimalHoleGuard")&&method.equals("shouldSkip"))
                            sites.merge(name+descriptor,1,Integer::sum);
                    }
                };
            }
        },ClassReader.SKIP_DEBUG|ClassReader.SKIP_FRAMES);
        check(sites.size()==1 && sites.getOrDefault("addHole"+DUAL,0)==1,"one advice call site, no other methods covered");
    }
    static void runMain(ClassLoader loader,String name,String label) throws Throwable {
        try {loader.loadClass(name).getMethod("main",String[].class).invoke(null,(Object)new String[]{"suqingworldstateguard.AnimalHoleGuard","shouldSkip",label});}
        catch(InvocationTargetException error){throw error.getCause();}
    }
    public static void main(String[] args) throws Throwable {
        Path candidate=Path.of(args[0]),animals=Path.of(args[1]),game=Path.of(args[2]);
        Path output=candidate.resolve("tests/output");Files.createDirectories(output);
        byte[] stock=jarBytes(game.resolve("projectzomboid.jar"),"zombie/characters/IsoGameCharacter.class");
        byte[] installed=Files.readAllBytes(game.resolve("zombie/characters/IsoGameCharacter.class"));
        byte[] vehicle=jarBytes(game.resolve("projectzomboid.jar"),"zombie/vehicles/BaseVehicle.class");
        Map<String,byte[]> plugin=readClasses(candidate.resolve("build/classes"));
        Map<String,byte[]> helper=readClasses(candidate.resolve("tests/classes"));
        Map<String,byte[]> base=new HashMap<>(readClasses(animals.resolve("fixture-installed")));
        base.putAll(plugin);base.putAll(helper);
        ResourceLoader rawLoader=new ResourceLoader(base,installed,vehicle);
        byte[] mapped=convertUsingActualZombieBuddy(rawLoader.loadClass(PATCH));
        base.put(PATCH,mapped);
        ResourceLoader mappedLoader=new ResourceLoader(base,installed,vehicle);
        ElementMatcher<MethodDescription> signature=actualSignatureMatcher(mappedLoader.loadClass(PATCH));
        ClassFileLocator system=ClassFileLocator.ForClassLoader.of(AdviceIntegrationAudit.class.getClassLoader());
        try(ClassFileLocator gameJar=ClassFileLocator.ForJarFile.of(game.resolve("projectzomboid.jar").toFile())) {
            for(var item:Map.of("stock",stock,"pzo",installed).entrySet()) {
                Map<String,byte[]> actual=new HashMap<>(plugin);actual.put(PATCH,mapped);actual.put(TARGET,item.getValue());
                byte[] result=weave(actual,signature,new ClassFileLocator.Compound(gameJar,new ClassFileLocator.ForFolder(game.toFile()),system));
                verifyCallSites(result);
                check(singleTrace(item.getValue()).equals(singleTrace(result)),"single-argument overload unchanged: "+item.getKey());
                Files.write(output.resolve("IsoGameCharacter-"+item.getKey()+"-woven.class"),result);
                System.out.println("PASS actual ZB conversion/matcher and actual "+item.getKey()+" class weave; dual-only, single overload unchanged");
            }
        }
        for(var item:Map.of("vanilla",stock,"installed",installed).entrySet()) {
            Map<String,byte[]> fixture=new HashMap<>(readClasses(animals.resolve("fixture-"+item.getKey())));
            fixture.putAll(plugin);fixture.putAll(helper);fixture.put(PATCH,mapped);
            fixture.put(TARGET,weave(fixture,signature,system));
            verifyCallSites(fixture.get(TARGET));
            runMain(new ResourceLoader(fixture,item.getValue(),vehicle),"repro.WovenHoleRegression",item.getKey());
            runMain(new ResourceLoader(fixture,new byte[]{1,2,3},vehicle),"repro.GateReject","unknown-woven");
        }
        System.out.println("PASS Advice integration assertions="+checks+"; no game startup, scenes, attach, or world operations");
    }
}
