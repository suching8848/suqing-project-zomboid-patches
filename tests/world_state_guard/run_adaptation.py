"""Verify the packaged guard against exact stock builds in isolated JVMs."""
from pathlib import Path
import argparse
import ast
import hashlib
import json
import os
import shutil
import subprocess
import zipfile

from build_hole_fixture import SRC as ANIMAL_FIXTURE

TESTS = Path(__file__).resolve().parent
REPO = TESTS.parents[1]
MOD = "SuQingWorldStateGuard_4221"
GAME_JAR = "projectzomboid.jar"
ANIMAL_CLASS = "zombie/characters/IsoGameCharacter.class"
CLOTHING_CLASS = "zombie/characterTextures/BloodClothingType.class"
CORE_STUB = """package zombie.core;
public final class Core {
    public static String fixtureBuild;
    private static final Core INSTANCE = new Core();
    public static Core getInstance() { return INSTANCE; }
    public String getGameAndBuildVersion() { return fixtureBuild; }
}
"""
VEHICLE_GATE = """package suqingworldstateguard;
import zombie.iso.*;
import zombie.vehicles.BaseVehicle;

public final class VehicleGateRegression {
    public static void main(String[] args) {
        boolean supported = Boolean.parseBoolean(args[0]);
        IsoWorld.instance = new IsoWorld();
        var vehicle = new BaseVehicle();
        var owner = new IsoChunk();
        owner.refs.add(new Object());
        owner.vehicles.add(vehicle);
        vehicle.square = new IsoGridSquare();
        vehicle.square.chunk = owner;
        vehicle.current = vehicle.square;
        vehicle.cell = new IsoCell();
        vehicle.cell.vehicles.add(vehicle);
        IsoWorld.instance.currentCell = vehicle.cell;
        try {
            vehicle.update();
            if (!supported || vehicle.chunk != owner) throw new AssertionError("unexpected restoration");
        } catch (NullPointerException original) {
            if (supported || vehicle.chunk != null || !"original-null-chunk".equals(original.getMessage()))
                throw new AssertionError("unexpected failure",original);
        }
        if (vehicle.originalCalls != 1 || vehicle.cell.vehicles.size() != 1 || owner.vehicles.size() != 1)
            throw new AssertionError("original update or membership changed");
        System.out.println("PASS woven vehicle resource gate supported="+supported);
    }
}
"""
PROFILES = """
legacy-stock oldAnimal oldVehicle 42.21.0 true true
legacy-pzo pzoAnimal oldVehicle 42.21.0 true true
legacy-animal-only oldAnimal unknown 42.21.0 true false
legacy-pzo-only pzoAnimal missing 42.21.0 true false
legacy-vehicle-only unknown oldVehicle 42.21.0 false true
legacy-unreadable-animal unreadable oldVehicle 42.21.0 false true
stock-4222 newAnimal newVehicle 42.22.2 true true
stock-4222-wrong-build newAnimal newVehicle 42.22.3 false false
stock-4222-short-build newAnimal newVehicle 42.22 false false
stock-4222-missing-build newAnimal newVehicle - false false
new-classes-old-build newAnimal newVehicle 42.21.0 false false
current-mixed-pzo pzoAnimal newVehicle 42.22.2 false false
mixed-old-animal oldAnimal newVehicle 42.22.2 false false
mixed-old-vehicle newAnimal oldVehicle 42.22.2 false false
legacy-classes-new-build pzoAnimal oldVehicle 42.22.2 false false
unknown-animal unknown newVehicle 42.22.2 false false
unknown-vehicle newAnimal unknown 42.22.2 false false
missing-animal missing newVehicle 42.22.2 false false
missing-vehicle newAnimal missing 42.22.2 false false
unreadable-vehicle newAnimal unreadable 42.22.2 false false
both-unknown unknown unknown 42.22.2 false false
"""

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def put(root, relative, text):
    path = root / relative
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text,encoding="utf-8")
    return path

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ("game-root","old-game-root","jdk","asm","candidate","output"):
        parser.add_argument("--"+arg,type=Path,required=True)
    args = parser.parse_args()
    game, old = args.game_root.resolve(), args.old_game_root.resolve()
    candidate, out = args.candidate.resolve(), args.output.resolve()
    for forbidden in (game, old, REPO / "src", REPO / "tests", Path.home() / "Zomboid"):
        if out.is_relative_to(forbidden):
            raise ValueError("Choose an isolated output directory")
    out.mkdir(parents=True)
    home = out / "isolated-home"
    home.mkdir()
    buddy = game / "ZombieBuddy.jar"
    old_pzo = old / "pzopt/aot/pzopt.jar"
    javac = args.jdk.resolve() / "javac.exe"
    java = args.jdk.resolve() / "java.exe"
    jvm = [java,"-Duser.home="+str(home),"-Djava.io.tmpdir="+str(home),"-Dfile.encoding=UTF-8"]
    def run(label, command, cwd=out):
        result = subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=180)
        log = result.stdout + result.stderr
        (out/(label+".log")).write_bytes(log)
        if result.returncode:
            raise RuntimeError(label+"\n"+log.decode("utf-8",errors="replace"))
        for line in log.decode("utf-8",errors="replace").splitlines():
            if line.startswith(("PASS","WEAVE")):
                print(line,flush=True)

    source = out / "fixture-src"
    animal_base = out / "animal-base"
    animal_src = [put(source,name,text) for name,text in ANIMAL_FIXTURE.items()]
    animal_src += [put(source,"zombie/core/Core.java",CORE_STUB)]
    animal_src += [TESTS/"candidate_tests/WovenHoleRegression.java"]
    run("compile-animal",[javac,"--release","17","-encoding","UTF-8","-cp",args.asm.resolve(),"-d",animal_base,*animal_src])
    for label, character, common in (("old",old/GAME_JAR,old/GAME_JAR),("new",game/GAME_JAR,game/GAME_JAR),
                                      ("pzo",old_pzo,old/GAME_JAR)):
        dest = out / ("animal-"+label)
        shutil.copytree(animal_base,dest)
        inputs = out / ("animal-input-"+label)
        inputs.mkdir()
        for jarpath, entry in ((character,ANIMAL_CLASS),(common,CLOTHING_CLASS)):
            with zipfile.ZipFile(jarpath) as jar:
                (inputs/Path(entry).name).write_bytes(jar.read(entry))
        run("extract-animal-"+label,[*jvm,"-cp",os.pathsep.join(map(str,(animal_base,args.asm.resolve()))),
            "repro.ExtractMethods",inputs/Path(ANIMAL_CLASS).name,inputs/Path(CLOTHING_CLASS).name,dest])

    vehicle_ast = ast.parse((TESTS/"build_vehicle_regression.py").read_text(encoding="utf-8"))
    vehicle_source = ast.literal_eval(next(
        node.value for node in vehicle_ast.body if isinstance(node,ast.Assign)
        and any(isinstance(t,ast.Name) and t.id=="files" for t in node.targets)))
    # Compile against the actual packaged Java API and use only the original world stubs.
    del vehicle_source["me/zed_0xff/zombie_buddy/Patch.java"]
    # Match the runtime field and method descriptors. Allow duplicate identities
    # in the test Set so the defensive branch remains independently testable.
    vehicle_source["zombie/iso/IsoCell.java"] = """package zombie.iso;
import java.util.*;
import zombie.vehicles.BaseVehicle;
public class IsoCell {
    public final Set<BaseVehicle> vehicles = new AbstractSet<BaseVehicle>() {
        private final List<BaseVehicle> entries = new ArrayList<>();
        public Iterator<BaseVehicle> iterator() { return entries.iterator(); }
        public int size() { return entries.size(); }
        public boolean add(BaseVehicle vehicle) { return entries.add(vehicle); }
    };
}
"""
    chunk = "zombie/iso/IsoChunk.java"
    vehicle_source[chunk] = vehicle_source[chunk].replace("final List<","final ArrayList<")
    vehicle = "zombie/vehicles/BaseVehicle.java"
    vehicle_source[vehicle] = vehicle_source[vehicle].replace(
        "class BaseVehicle {","class BaseVehicle implements VehiclePartOwner, VehicleSoundOwner {")
    for package, owner, name in (("zombie.vehicles","VehiclePartOwner","VehicleParts"),
                                  ("zombie.vehicleSound","VehicleSoundOwner","VehicleSounds")):
        folder = package.replace(".","/")
        vehicle_source[f"{folder}/{owner}.java"] = f"package {package}; public interface {owner} {{}}"
        source_path = f"{folder}/{name}.java"
        vehicle_source[source_path] = vehicle_source[source_path].replace("Object",owner)
    regression = "suqingworldstateguard/VehicleGuardRegression.java"
    assert vehicle_source[regression].count("PatchVehicleChunk.enter(v);v.update();") == 1
    vehicle_source[regression] = vehicle_source[regression].replace(
        "PatchVehicleChunk.enter(v);v.update();","v.update();").replace("owner=new Object()","owner=new BaseVehicle()")
    vehicle_source["suqingworldstateguard/VehicleGateRegression.java"] = VEHICLE_GATE
    veh_paths = [put(out/"vehicle-src",name,text) for name,text in vehicle_source.items()]
    run("compile-vehicle",[javac,"--release","17","-encoding","UTF-8","-cp",candidate,"-d",out/"vehicle-fixture",*veh_paths])
    put(out,"gate-profiles.tsv","\n".join("\t".join(row.split()) for row in PROFILES.strip().splitlines())+"\n")
    integration_classes = out / "integration-classes"
    run("compile-advice",[javac,"--release","17","-encoding","UTF-8","-cp",buddy,"-d",integration_classes,
        TESTS/"candidate_tests/AdviceIntegrationAudit.java",TESTS/"candidate_tests/Adaptation4222Audit.java"])
    run("advice-integration",[*jvm,"-cp",os.pathsep.join(map(str,(integration_classes,buddy))),
        "Adaptation4222Audit",out,candidate,old/GAME_JAR,game/GAME_JAR,old_pzo])

    mod_root = out / MOD
    (mod_root/"42").mkdir(parents=True)
    shutil.copy2(REPO/"src"/MOD/"42/mod.info",mod_root/"42/mod.info")
    jar_dest = mod_root/"42/media/java/client/SuQingWorldStateGuard.jar"
    jar_dest.parent.mkdir(parents=True)
    shutil.copy2(candidate,jar_dest)
    native_classes = out / "native-classes"
    run("compile-native",[javac,"--release","17","-encoding","UTF-8","-cp",os.pathsep.join(map(str,(game/GAME_JAR,candidate))),
        "-d",native_classes,TESTS/"candidate_tests/NativeGuardDiscovery.java"])
    for label, root, version in (("4222",game,"42.22.2"),("4221",old,"42.21.0")):
        run("native-"+label,[*jvm,"-cp",os.pathsep.join(map(str,(root/GAME_JAR,candidate,native_classes))),
            "NativeGuardDiscovery",mod_root,home,version],cwd=home)
    receipt = {"candidate_jar":str(candidate),"sha256":digest(candidate),
        "input_sha256":{str(p):digest(p) for p in (game/GAME_JAR,old/GAME_JAR,old_pzo,buddy,args.asm.resolve())},
        "gated_profiles":len(PROFILES.strip().splitlines()),"native_builds":["42.21.0","42.22.2"],
        "real_zombiebuddy_transformer_and_matcher":True,"real_class_weaving":True,
        "in_game":False,"installation":False}
    put(out,"receipt.json",json.dumps(receipt,indent=2)+"\n")

if __name__ == "__main__":
    main()
