import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.expose.LuaJavaClassExposer;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.Lua.KahluaNumberConverter;

/** Actual Java BufferedReader -> Lua bridge; no game/world startup. */
public final class BoatRVReaderBridgeValidation {
    private static long[] reference(String text) throws Exception {
        long hash=0, count=0;
        try (BufferedReader r=new BufferedReader(new StringReader(text))) {
            String line;
            while ((line=r.readLine())!=null) {
                for (int i=0;i<line.length();i++) {
                    int c=line.charAt(i);
                    if (c>0 && c<128) { hash=(hash*131+c)%1000000007; count++; }
                }
                hash=(hash*131+10)%1000000007; count++;
            }
        }
        return new long[]{hash,count};
    }
    public static void main(String[] args) throws Exception {
        J2SEPlatform platform=new J2SEPlatform();
        KahluaTable env=platform.newEnvironment();
        KahluaConverterManager converters=new KahluaConverterManager();
        KahluaNumberConverter.install(converters);
        Set<Class<?>> exposed=Set.of(BufferedReader.class,Reader.class,Closeable.class,AutoCloseable.class,Object.class);
        LuaJavaClassExposer exposer=new LuaJavaClassExposer(converters,platform,env,env) {
            @Override public boolean shouldExpose(Class<?> c) { return exposed.contains(c); }
        };
        exposer.exposeLikeJava(BufferedReader.class);
        KahluaThread thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();
        String source=Files.readString(Path.of(args[0]),StandardCharsets.UTF_8);
        String helper=source.substring(source.indexOf("local function readFingerprint(pin)"),source.indexOf("function G.install()"));
        String code="function getModFileReader() return realReader end\n"
            +"string.byte=function() error('fingerprint must not use Lua byte semantics') end\n"
            +helper+"\nreturn readFingerprint({mod='fixture',path='fixture'})";
        Object closure=LuaCompiler.loadstring(code,"real-java-reader",env);
        List<String> fixtures=new ArrayList<>(List.of(
            "", "ABC", "ABC\n", "A\r\nB\rC\nD", "\0", "\u2014", "\u0100\u0141",
            "\u4e2d\u6587", new String(Character.toChars(0x10041)), "A\r\u2014\n",
            "\r\r\n", "\r\n\n", "\ufeffABC\r\n"));
        for (int i=1;i<args.length;i++) fixtures.add(Files.readString(Path.of(args[i]),StandardCharsets.UTF_8));
        int checked=0;
        for (String fixture:fixtures) {
            BufferedReader reader=new BufferedReader(new StringReader(fixture));
            env.rawset("realReader",reader);
            Object[] result=thread.pcall(closure,new Object[0]);
            if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(Arrays.toString(result));
            long[] expected=reference(fixture);
            if (((Number)result[1]).longValue()!=expected[0] || ((Number)result[2]).longValue()!=expected[1])
                throw new AssertionError("reader mismatch "+checked+" "+Arrays.toString(result)+" expected "+Arrays.toString(expected));
            try { reader.read(); throw new AssertionError("reader was not closed"); }
            catch (IOException correctlyClosed) { }
            checked++;
        }
        System.out.println("PASS real_java_reader_fixtures="+checked+"; raw UTF-16/CRLF/EOF; reader closed; string.byte disabled");
    }
}
