import java.nio.file.*;
import java.util.List;
import suqingworldstateguard.Compatibility;
import zombie.ZomboidFileSystem;
import zombie.core.Core;
import zombie.gameStates.ChooseGameInfo;

public final class NativeGuardDiscovery {
    private static int assertions;
    private static void check(boolean condition,String message) {
        ++assertions;
        if (!condition) throw new AssertionError(message);
    }

    public static void main(String[] args) throws Exception {
        var root = Path.of(args[0]);
        var fs = ZomboidFileSystem.instance;
        fs.setCacheDir(args[1]);
        fs.init();
        var core = Core.getInstance();
        String full = core.getGameAndBuildVersion();
        check(args[2].equals(full),"exact native build "+full);
        var info = ChooseGameInfo.readModInfo(root.toString());
        check(info!=null && info.isAvailableSelf(),"native eligibility");
        check("SuQingWorldStateGuard_4221".equals(info.getId()),"stable Mod ID");
        check("0.1.1-candidate".equals(info.getModVersion()),"candidate metadata version");
        check(Path.of(info.getVersionDir()).equals(root.resolve("42")),"native 42 branch");
        check(info.getRequire().equals(List.of("ZombieBuddy")),"native ZombieBuddy dependency "+info.getRequire());
        check(Compatibility.isAnimalSupported(),"native stock animal resource gate");
        check(Compatibility.isVehicleSupported(),"native stock vehicle resource gate");
        check(!Compatibility.isAllowedAnimalHash(null) && !Compatibility.isAllowedVehicleHash(null),"null digest rejection");
        System.out.println("PASS native "+full+" ("+core.getVersionNumber()+") assertions="+assertions);
    }
}
