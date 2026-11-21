"""Exercise the final mod through the on-disk ZombieBuddy native loader in isolation."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]
MOD = "SuQingMeleeUpgrade_4222"
JAR = Path("42/media/java/client/SuQingMeleeUpgrade.jar")
TESTS = ROOT / "tests/melee_upgrade_persistence"


def sha256(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def write(path, content):
    path.write_text(content, encoding="utf-8", newline="\n")


def command(args, profile, log, env=None):
    result = subprocess.run(list(map(str, args)), cwd=profile, env=env,
                            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=85)
    report = result.stdout.decode("utf-8", errors="replace")
    write(log, report)
    if result.returncode:
        raise RuntimeError(f"{log}:\n{report[-8500:]}")
    return report


def validate(game, workshop, javac, output, with_pzo):
    candidate = output / "candidate" / MOD
    jar = candidate / JAR
    stock = game / "projectzomboid.jar"
    buddy = game / "ZombieBuddy.jar"
    agent = game / "zbNative.dll"
    installed_buddy_mod = workshop / "3619862853/mods/ZombieBuddy"
    runtime = output / "integration"
    attempt = 1
    while runtime.exists():
        attempt += 1
        runtime = output / f"integration-{attempt:02d}"
    test_classes = runtime / "classes"
    test_classes.mkdir(parents=True)
    classpath = lambda *files: os.pathsep.join(map(str, files))
    command([javac, "-encoding", "UTF-8", "--release", "25", "-cp", classpath(stock, buddy, jar),
             "-d", test_classes, TESTS / "NativeUpgradeAudit.java", TESTS / "NativeLoaderAudit.java"],
            runtime, runtime / "compile-test.log")

    runs = [("stock-exact", True, False), ("stock-denied", False, False)]
    if with_pzo:
        runs.append(("pzo-exact", True, True))
    receipt = {}
    for name, approved, pzo in runs:
        profile = runtime / name
        cwd = profile / "cwd"
        cache = profile / "cache"
        temp = profile / "tmp"
        home = profile / "home"
        config = profile / "zb"
        for directory in (cwd / "media", cache / "mods", temp, home, config):
            directory.mkdir(parents=True)
        shutil.copytree(candidate, cache / "mods" / MOD)
        shutil.copytree(installed_buddy_mod, cache / "mods/ZombieBuddy")
        shutil.copy2(buddy, cwd)
        shutil.copy2(game / "stdlib.lua", cwd)
        write(cache / "mods/default.txt", "VERSION = 1,\nmods\n{\n    mod = ZombieBuddy,\n    mod = " + MOD + ",\n}\n")
        write(cache / "mods/reset-mods-42_00.txt", "")
        write(config / "config.json", json.dumps({"trusted_authors": [], "preload_mods": {},
                                                  "auto_fix_mod_order": False, "fix_approval_dialog_cursor": False}))
        approvals = [{"id": MOD, "jar_hash": sha256(jar), "decision": True}] if approved else []
        write(config / "mod_approvals.json", json.dumps({"formatVersion": 1, "mods": approvals}))

        env = os.environ.copy()
        for key in ("JAVA_TOOL_OPTIONS", "_JAVA_OPTIONS", "JDK_JAVA_OPTIONS", "CLASSPATH", "ZB_VERBOSITY"):
            env.pop(key, None)
        env.update(HOME=str(home), USERPROFILE=str(home), APPDATA=str(home), LOCALAPPDATA=str(home),
                   TEMP=str(temp), TMP=str(temp))
        profile_args = []
        if pzo:
            shutil.copytree(game / "pzopt/overrides", cwd / "pzopt/overrides")
            profile_args.append(f"-javaagent:{game / 'pzopt/agent/pzopt-agent.jar'}")
        args = [game / "jre64/bin/java.exe", "-XX:-UsePerfData", "-Xverify:all",
                "--enable-native-access=ALL-UNNAMED", "-Djava.awt.headless=true", "-Dfile.encoding=UTF-8",
                f"-Duser.home={home}", f"-Djava.io.tmpdir={temp}",
                *profile_args, f"-agentpath:{agent}=config_dir={config},policy=deny-new,frontend=console,verbosity=1",
                "-cp", classpath(*((game,) if pzo else ()), stock, test_classes), "NativeLoaderAudit", game, profile, str(approved).lower()]
        report = command(args, cwd, profile / "native-loader.log", env)
        if f"NATIVE_MELEE_LOADER PASS approved={str(approved).lower()}" not in report:
            raise RuntimeError("Native loader result missing")
        if approved:
            for patch in ("HandWeapon.save", "HandWeapon.load", "HandWeapon.getActualWeight", "LuaManager$GlobalObject.triggerEvent",
                          "wear checks attached"):
                if patch not in report:
                    raise RuntimeError(f"Native output missing {patch}")
            match = re.search(r"NATIVE_MELEE_UPGRADE PASS assertions=(\d+)", report)
            if not match:
                raise RuntimeError("Native behavior result missing")
        receipt[name] = {"approved": approved, "pzo": pzo,
                         "behavior_assertions": int(match.group(1)) if approved else 0}

    write(runtime / "verification.json", json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", required=True, type=Path)
    parser.add_argument("--workshop", required=True, type=Path)
    parser.add_argument("--javac", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--with-pzo", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve(strict=True)
    if any(output.is_relative_to(path) for path in (args.game_root.resolve(), ROOT, Path.home() / "Zomboid")):
        parser.error("Use the isolated build output")
    validate(args.game_root.resolve(strict=True), args.workshop.resolve(strict=True),
             args.javac.resolve(strict=True), output, args.with_pzo)


if __name__ == "__main__":
    main()
