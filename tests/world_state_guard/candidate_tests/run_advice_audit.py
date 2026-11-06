from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(r"D:\steam\steamapps\common\ProjectZomboid")
ANIMALS = ROOT.parent / "animal_analysis"
JDK = Path(r"E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64\bin")
TESTS = ROOT / "tests"
CLASSES = TESTS / "classes"
CLASSES.mkdir(exist_ok=True)
original = (ANIMALS / "fixture-src/repro/HoleRegression.java").read_text(encoding="utf-8")
woven = original.replace("class HoleRegression", "class WovenHoleRegression")
woven = woven.replace(
    'boolean skip;try{skip=(boolean)guard.invoke(null,c);}catch(InvocationTargetException e){throw e.getCause();}\n  return skip?false:c.addHole(p,all);',
    'return c.addHole(p,all);'
)
woven = woven.replace('guard=Class.forName(a[0]).getDeclaredMethod(a[1],IsoGameCharacter.class);guard.setAccessible(true);', '')
woven = woven.replace(
    'IsoAnimal raw=new IsoAnimal();try{raw.addHole(BloodBodyPartType.Head,false);throw new AssertionError("expected animal null NPE");}catch(NullPointerException expected){yes(expected.getStackTrace()[0].getClassName().equals("zombie.characterTextures.BloodClothingType"),"actual target NPE site");}',
    'IsoAnimal raw=new IsoAnimal();yes(!raw.addHole(BloodBodyPartType.Head,false),"woven skip returns original boolean default false");'
)
assert "return skip?" not in woven and "expected animal null NPE" not in woven
helper = TESTS / "WovenHoleRegression.java"
helper.write_text(woven, encoding="utf-8")
compile_command = [
    str(JDK / "javac.exe"), "--release", "17", "-encoding", "UTF-8",
    "-classpath", str(GAME / "ZombieBuddy.jar") + ";" + str(ANIMALS / "fixture-installed"),
    "-d", str(CLASSES), str(TESTS / "AdviceIntegrationAudit.java"), str(helper),
]
subprocess.run(compile_command, check=True)
command = [
    str(JDK / "java.exe"), "-classpath", str(CLASSES) + ";" + str(GAME / "ZombieBuddy.jar"),
    "AdviceIntegrationAudit", str(ROOT), str(ANIMALS), str(GAME)
]
result = subprocess.run(command, text=True, encoding="utf-8", capture_output=True)
(TESTS / "advice-integration-output.txt").write_text(result.stdout + result.stderr, encoding="utf-8")
print(result.stdout + result.stderr)
if result.returncode:
    raise SystemExit(result.returncode)
(TESTS / "advice-integration-result.json").write_text(json.dumps({
    "passed": True, "real_zombie_buddy_transformer": True,
    "real_zombie_buddy_signature_matcher": True,
    "real_stock_and_pzo_class_weaving": True,
    "woven_actual_method_fixtures": ["vanilla", "installed"],
    "unknown_resource_gate": True, "game_started": False,
    "game_objects_instantiated": False, "stub_objects_only": True
}, indent=2), encoding="utf-8")
