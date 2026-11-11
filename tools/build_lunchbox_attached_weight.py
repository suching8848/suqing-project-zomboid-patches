"""Build and test the attached-weight mod in an isolated directory."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


REPO = Path(__file__).resolve().parents[1]
MOD_ID = "SuQingLunchboxAttachedWeight_4222"
JAR_PATH = Path("media/java/client/SuQingLunchboxAttachedWeight.jar")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args, cwd, log, env=None):
    result = subprocess.run(list(map(str, args)), cwd=cwd, env=env, check=False,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
    output = result.stdout.decode("utf-8", errors="replace")
    log.write_text(output, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{log.name} failed ({result.returncode})\n{output[-4000:]}")
    return output


def write_entry(archive, name, data):
    entry = zipfile.ZipInfo(name, (2026, 11, 11, 0, 0, 0))
    entry.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(entry, data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", required=True, type=Path)
    parser.add_argument("--javac", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    game, output = args.game_root.resolve(), args.output.resolve()
    protected = (game, REPO / "src", Path.home() / "Zomboid")
    if any(output.is_relative_to(root) for root in protected):
        parser.error("Choose an output outside installed and source mod directories")
    output.mkdir(parents=True)
    source = REPO / "src" / MOD_ID / "42"
    package = output / "candidate" / MOD_ID
    branch = package / "42"
    branch.mkdir(parents=True)
    metadata = source / "mod.info"
    version = next(line.split("=", 1)[1] for line in metadata.read_text(encoding="utf-8").splitlines()
                   if line.startswith("modversion="))
    shutil.copy2(metadata, branch)
    shutil.copy2(source / "README.txt", branch)

    game_jar, buddy, agent = (game / name for name in ("projectzomboid.jar", "ZombieBuddy.jar", "zbNative.dll"))
    classes = output / "classes"
    classes.mkdir()
    sources = sorted((REPO / "java/lunchbox_attached_weight/source").rglob("*.java"))
    compile_args = [args.javac.resolve(), "-J-Dfile.encoding=UTF-8", "--release", "25", "-encoding", "UTF-8"]
    run([*compile_args, "-cp", os.pathsep.join(map(str, (game_jar, buddy))), "-d", classes, *sources],
        output, output / "compile.log")
    candidate_jar = branch / JAR_PATH
    candidate_jar.parent.mkdir(parents=True)
    with zipfile.ZipFile(candidate_jar, "w") as archive:
        manifest = f"Manifest-Version: 1.0\r\nImplementation-Version: {version}\r\n\r\n"
        write_entry(archive, "META-INF/MANIFEST.MF", manifest.encode())
        for path in sorted(classes.rglob("*.class")):
            write_entry(archive, path.relative_to(classes).as_posix(), path.read_bytes())

    test = REPO / "tests/lunchbox_attached_weight/NativeWeightAudit.java"
    test_classes = output / "testclasses"
    test_classes.mkdir()
    classpath = os.pathsep.join(map(str, (test_classes, candidate_jar, game_jar, buddy)))
    run([*compile_args, "-cp", classpath, "-d", test_classes, test], output, output / "compile-test.log")
    profile = output / "testprofile"
    temp = profile / "Temp"
    temp.mkdir(parents=True)
    shutil.copy2(buddy, profile)
    shutil.copy2(game / "stdlib.lua", profile)
    env = dict(os.environ, USERPROFILE=str(profile), APPDATA=str(profile / "AppData/Roaming"),
               LOCALAPPDATA=str(profile / "AppData/Local"), TEMP=str(temp), TMP=str(temp))
    log = run([game / "jre64/bin/java.exe", "-XX:-UsePerfData", "-XX:ActiveProcessorCount=2", "-Xverify:all",
               "--enable-native-access=ALL-UNNAMED", f"-Duser.home={profile}", f"-Djava.io.tmpdir={temp}",
               f"-agentpath:{agent}", "-cp", classpath, "NativeWeightAudit", package],
              profile, output / "native-weight.log", env)
    match = re.search(r"NATIVE_LUNCHBOX_WEIGHT assertions=(\d+) PASS", log)
    if not match or "[ZB] Agent installed." not in log or "InventoryItem.getHotbarEquippedWeight" not in log:
        raise RuntimeError("Missing verified native or ZombieBuddy runtime evidence")

    artifact = output / f"{MOD_ID}-{version}.zip"
    files = sorted(package.rglob("*.*"))
    with zipfile.ZipFile(artifact, "w") as archive:
        for path in files:
            write_entry(archive, path.relative_to(package.parent).as_posix(), path.read_bytes())
    with zipfile.ZipFile(artifact) as archive:
        for path in files:
            if archive.read(path.relative_to(package.parent).as_posix()) != path.read_bytes():
                raise RuntimeError(f"Package readback differs for {path.name}")
    receipt = {
        "result": "PASS", "native_assertions": int(match[1]), "game_started": False, "world_loaded": False,
        "installed": False, "mod_id": MOD_ID, "version": version, "artifact": str(artifact),
        "artifact_sha256": digest(artifact), "jar_sha256": digest(candidate_jar),
        "inputs": {path.name: digest(path) for path in (game_jar, buddy, agent)},
        "sources": {path.relative_to(REPO).as_posix(): digest(path) for path in (*sources, test, metadata)},
    }
    (output / "verification.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(receipt, ensure_ascii=False))


if __name__ == "__main__":
    main()
