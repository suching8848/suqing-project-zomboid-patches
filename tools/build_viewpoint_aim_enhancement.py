"""Build and test the Viewpoint aim enhancement in a fresh private directory."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import zipfile

from build_viewpoint_simulation import digest, run, zip_entry

ROOT = Path(__file__).resolve().parents[1]
MOD = "SuQingViewpointAimEnhancement_4222"
VERSION = "0.1.0"
JAR = "SuQingViewpointAimEnhancement.jar"
AUDIT = "suqingviewpointaim.NativeAimAudit"
VIEWPOINT_HASH = "8d0d5a73227d3ba0724cab076f621435ebaed8ed2c73bfaf7d32a90b0a249e1f"
BUDDY_HASH = "eb79b9876332010733a8e0d7ce4fe0377846059a9e28859029e2a0fb449f6cf2"


def classpath(*entries):
    return os.pathsep.join(map(str, entries))


def build_jar(path, classes, manifest):
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "x") as jar:
        zip_entry(jar, "META-INF/MANIFEST.MF", manifest.encode("ascii"))
        for source in sorted(classes.rglob("*.class")):
            zip_entry(jar, source.relative_to(classes).as_posix(), source.read_bytes())
    with zipfile.ZipFile(path) as jar:
        if jar.testzip() is not None:
            raise ValueError(f"Invalid JAR {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path, required=True)
    parser.add_argument("--workshop", type=Path, required=True)
    parser.add_argument("--javac", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    game = args.game_root.resolve(strict=True)
    workshop = args.workshop.resolve(strict=True)
    javac = args.javac.resolve(strict=True)
    output = args.output.resolve()
    if output.exists() or any(output.is_relative_to(p) for p in (ROOT, game, workshop, Path.home() / "Zomboid")):
        parser.error("Use a fresh isolated output directory")

    stock = game / "projectzomboid.jar"
    vp_mod = workshop / "3809306528/mods/Viewpoint"
    zb_mod = workshop / "3619862853/mods/ZombieBuddy"
    viewpoint = vp_mod / "42/media/java/client/Viewpoint.jar"
    buddy = zb_mod / "libs/ZombieBuddy.jar"
    upstream = {path: digest(path) for path in (stock, viewpoint, buddy)}
    if upstream[viewpoint] != VIEWPOINT_HASH or upstream[buddy] != BUDDY_HASH:
        raise ValueError("The installed Viewpoint or ZombieBuddy does not match the verified version")

    work = output / "build"
    classes = work / "classes"
    testclasses = work / "testclasses"
    for root in (classes, testclasses):
        root.mkdir(parents=True)
    candidate = output / "candidate" / MOD
    shutil.copytree(ROOT / "src" / MOD, candidate)
    readme = candidate / "common/README.md"
    readme.parent.mkdir()
    shutil.copy2(ROOT / "docs/patches" / f"{MOD}.md", readme)
    jar = candidate / "42/media/java/client" / JAR
    sources = sorted((ROOT / "java/viewpoint_aim_enhancement/source").rglob("*.java"))
    compiler = [javac, "--release", "17", "-encoding", "UTF-8"]
    run([*compiler, "-cp", classpath(stock, buddy), "-d", classes, *sources], work, work / "compile.log")
    build_jar(jar, classes, f"Manifest-Version: 1.0\r\nImplementation-Version: {VERSION}\r\n\r\n")

    test = ROOT / "tests/viewpoint_aim_enhancement/NativeAimAudit.java"
    run([*compiler, "-cp", classpath(jar, stock, buddy), "-d", testclasses, test], work, work / "compile-test.log")
    agent = work / "audit-agent.jar"
    build_jar(agent, testclasses, f"Manifest-Version: 1.0\r\nPremain-Class: {AUDIT}\r\nCan-Retransform-Classes: true\r\n\r\n")

    wrong = work / "different-source/Viewpoint"
    shutil.copytree(vp_mod, wrong, ignore=shutil.ignore_patterns("media"))
    wrong_jar = wrong / viewpoint.relative_to(vp_mod)
    wrong_jar.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(viewpoint, wrong_jar)
    with zipfile.ZipFile(wrong_jar, "a") as archive:
        zip_entry(archive, "offline-audit-marker.txt", b"Incompatible JAR fixture.\n")

    results = {}
    for scenario, chosen in (("native", viewpoint), ("reject", wrong_jar)):
        profile = work / scenario
        profile.mkdir()
        env = dict(os.environ, USERPROFILE=str(profile), APPDATA=str(profile / "AppData/Roaming"),
                   LOCALAPPDATA=str(profile / "AppData/Local"), TEMP=str(profile), TMP=str(profile))
        command = [game / "jre64/bin/java.exe", "-XX:-UsePerfData", "--enable-native-access=ALL-UNNAMED",
                   f"-Duser.home={profile}", f"-Djava.io.tmpdir={profile}", f"-javaagent:{agent}",
                   "-cp", classpath(testclasses, jar, stock, buddy, chosen), AUDIT,
                   candidate, profile, chosen, zb_mod, scenario]
        log = run(command, profile, work / f"{scenario}.log", env)
        match = re.search(r"NATIVE_VIEWPOINT_AIM PASS assertions=(\d+)", log)
        if not match:
            raise ValueError(f"Missing native audit marker for {scenario}")
        results[scenario] = int(match[1])

    for lang in ("CN", "EN"):
        path = candidate / f"42/media/lua/shared/Translate/{lang}/Mod.json"
        if set(json.loads(path.read_text(encoding="utf-8"))) != {"name", "description"}:
            raise ValueError(f"Mod translations are incomplete for {lang}")

    archive = output / f"{MOD}-{VERSION}.zip"
    files = sorted(path for path in candidate.rglob("*") if path.is_file())
    with zipfile.ZipFile(archive, "x") as bundle:
        for path in files:
            zip_entry(bundle, path.relative_to(candidate.parent).as_posix(), path.read_bytes())
    with zipfile.ZipFile(archive) as bundle:
        if bundle.testzip() is not None or any(
                bundle.read(path.relative_to(candidate.parent).as_posix()) != path.read_bytes() for path in files):
            raise ValueError("Package readback failed")
    if any(digest(path) != expected for path, expected in upstream.items()):
        raise ValueError("An upstream input changed during the build")

    receipt = {
        "result": "PASS", "mod_id": MOD, "version": VERSION, "game_started": False,
        "world_loaded": False, "deployed": False, "native_assertions": results,
        "files": {path.relative_to(candidate).as_posix(): digest(path) for path in files},
        "sources": {path.relative_to(ROOT).as_posix(): digest(path) for path in sources},
        "jar_sha256": digest(jar), "archive": str(archive), "archive_sha256": digest(archive),
        "inputs": {str(path): expected for path, expected in upstream.items()},
    }
    (output / "verification.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {sum(results.values())} assertions, {len(files)} package files")
    print(archive)


if __name__ == "__main__":
    main()
