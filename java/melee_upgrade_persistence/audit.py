"""Build and verify the two persistence advices in an isolated offline JVM."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


HERE = Path(__file__).resolve().parent
BRIDGE_SOURCE = HERE / "source" / "suqingmeleeupgrade"
SOURCES = [BRIDGE_SOURCE / f"{name}.java" for name in (
    "WeaponPersistence", "PatchPersistenceSave", "PatchPersistenceLoad", "PatchWeight",
    "WearPatch", "Upgrade", "Main"
)]


def run(command, cwd, log, env=None):
    result = subprocess.run(list(map(str, command)), cwd=cwd, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
    output = result.stdout.decode("utf-8", errors="replace")
    log.write_text(output, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{log.name} failed ({result.returncode})\n{output[-6000:]}")
    return output


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path, required=True)
    parser.add_argument("--javac", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--lunchbox-jar", type=Path, help="Optional existing additional InventoryItem patch")
    args = parser.parse_args()
    game, output = args.game_root.resolve(), args.output.resolve()
    if any(output.is_relative_to(path) for path in (game, HERE.parent.parent / "src", Path.home() / "Zomboid")):
        parser.error("Use a fresh output directory outside installed and source mods")
    output.mkdir(parents=True, exist_ok=False)

    game_jar = game / "projectzomboid.jar"
    buddy = game / "ZombieBuddy.jar"
    agent = game / "zbNative.dll"
    classes = output / "classes"
    classes.mkdir()
    compile_options = [args.javac.resolve(), "-J-Dfile.encoding=UTF-8", "--release", "25", "-encoding", "UTF-8"]
    build_cp = os.pathsep.join(map(str, (game_jar, buddy)))
    run([*compile_options, "-cp", build_cp, "-d", classes, *SOURCES], output, output / "compile-bridge.log")

    jar = output / "persistence-audit-only.jar"
    with zipfile.ZipFile(jar, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for class_file in sorted(classes.rglob("*.class")):
            entry = zipfile.ZipInfo(class_file.relative_to(classes).as_posix(), (2026, 11, 18, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, class_file.read_bytes())

    test_classes = output / "testclasses"
    test_classes.mkdir()
    peer_jar = [args.lunchbox_jar.resolve(strict=True)] if args.lunchbox_jar else []
    test_cp = os.pathsep.join(map(str, (test_classes, jar, game_jar, buddy, *peer_jar)))
    run([*compile_options, "-cp", test_cp, "-d", test_classes, HERE / "tests/PersistenceAudit.java"],
        output, output / "compile-test.log")

    profile = output / "profile"
    temp = profile / "Temp"
    temp.mkdir(parents=True)
    shutil.copy2(buddy, profile)
    shutil.copy2(game / "stdlib.lua", profile)
    env = dict(os.environ, USERPROFILE=str(profile), APPDATA=str(profile / "AppData/Roaming"),
               LOCALAPPDATA=str(profile / "AppData/Local"), TEMP=str(temp), TMP=str(temp))
    output_log = run([game / "jre64/bin/java.exe", "-XX:-UsePerfData", "-Xverify:all",
                      "--enable-native-access=ALL-UNNAMED", f"-Duser.home={profile}",
                      f"-Djava.io.tmpdir={temp}", f"-agentpath:{agent}", "-cp", test_cp,
                      "PersistenceAudit", game, *peer_jar], profile, output / "native-persistence.log", env)
    match = re.search(r"NATIVE_MELEE_PERSISTENCE assertions=(\d+) PASS", output_log)
    if not match or not all(text in output_log for text in (
        "[ZB] Agent installed.", "zombie.inventory.types.HandWeapon.save", "zombie.inventory.types.HandWeapon.load"
    )):
        raise RuntimeError("Missing native readback or loader patch evidence")
    receipt = {
        "result": "PASS", "native_assertions": int(match.group(1)), "game_started": False,
        "game_files_modified": False, "audit_only_jar": str(jar), "audit_jar_sha256": sha256(jar),
        "inputs_sha256": {item.name: sha256(item) for item in (game_jar, buddy, agent, *peer_jar)},
    }
    (output / "verification.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(receipt))


if __name__ == "__main__":
    main()
