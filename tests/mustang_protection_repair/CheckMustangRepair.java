import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaThread;

class CheckMustangRepair {
    public static void main(String[] args) throws Exception {
        var platform = new J2SEPlatform();
        var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        for (String arg : args) {
            try (Reader reader = Files.newBufferedReader(Path.of(arg), StandardCharsets.UTF_8)) {
                var closure = LuaCompiler.loadis(reader, arg, env);
                Object[] result = thread.pcall(closure, new Object[0]);
                if (!Boolean.TRUE.equals(result[0])) {
                    for (Object value : result) System.err.println(value);
                    throw new IllegalStateException(arg);
                }
                if (arg.endsWith("cases.lua")) {
                    if (result.length != 2 || !(result[1] instanceof Double count) || count != 9) {
                        throw new IllegalStateException("Expected nine completed checks");
                    }
                    System.out.println("PASS " + count.intValue() + " Kahlua cases (assertions executed)");
                }
            }
        }
    }
}