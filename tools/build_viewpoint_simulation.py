"""Build and verify the Viewpoint simulation-rate mod in an isolated output directory."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

REPO = Path(__file__).resolve().parents[1]
MOD_ID = "SuQingViewpointSimulation_4222"
JAR_REL = Path("42/media/java/client/SuQingViewpointSimulation.jar")
TEST = "suqingviewpointsimulation.NativeRateAudit"
SUCCESS = re.compile(r"NATIVE_VIEWPOINT_SIMULATION PASS assertions=(\d+)")


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def run(args, cwd, log, env=None):
    result = subprocess.run(list(map(str, args)), cwd=cwd, env=env, capture_output=True, timeout=60)
    transcript = (result.stdout + result.stderr).decode("utf-8", errors="replace")
    log.write_text(transcript, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{log}:\n{transcript[-4000:]}")
    return transcript


def zip_entry(archive, name, contents):
    info = zipfile.ZipInfo(name, (2026, 11, 16, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, contents)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", required=True, type=Path)
    parser.add_argument("--workshop", required=True, type=Path)
    parser.add_argument("--javac", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    game, workshop, output = (item.resolve(strict=True) for item in (args.game_root, args.workshop, args.output))
    if any(output.is_relative_to(root) for root in (game, workshop, REPO, Path.home() / "Zomboid")):
        parser.error("Use an isolated output directory")

    stock = game / "projectzomboid.jar"
    java = game / "jre64/bin/java.exe"
    mod_options = game / "media/lua/client/PZAPI/ModOptions.lua"
    buddy = workshop / "3619862853/mods/ZombieBuddy/libs/ZombieBuddy.jar"
    viewpoint = workshop / "3809306528/mods/Viewpoint/42/media/java/client/Viewpoint.jar"
    inputs = {str(file): digest(file) for file in (stock, mod_options, buddy, viewpoint)}
    candidate = output / "candidate" / MOD_ID
    source = REPO / "src" / MOD_ID
    shutil.copytree(source, candidate, ignore=shutil.ignore_patterns(JAR_REL.name))
    work = output / "build"
    classes = work / "classes"
    classes.mkdir(parents=True)
    java_files = sorted((REPO / "java/viewpoint_simulation/source").rglob("*.java"))
    cp = os.pathsep.join(map(str, (stock, buddy, viewpoint)))
    compiler = [args.javac.resolve(strict=True), "-encoding", "UTF-8", "--release", "25"]
    run([*compiler, "-cp", cp, "-d", classes, *java_files], work, work / "compile.log")

    jar = candidate / JAR_REL
    jar.parent.mkdir(parents=True)
    with zipfile.ZipFile(jar, "x") as archive:
        zip_entry(archive, "META-INF/MANIFEST.MF", b"Manifest-Version: 1.0\r\nImplementation-Version: 0.1.0\r\n\r\n")
        for path in sorted(classes.rglob("*.class")):
            zip_entry(archive, path.relative_to(classes).as_posix(), path.read_bytes())

    test = REPO / "tests/viewpoint_simulation/NativeRateAudit.java"
    test_classes = work / "testclasses"
    test_classes.mkdir()
    run([*compiler, "-cp", str(jar) + os.pathsep + cp, "-d", test_classes, test],
        work, work / "compile-test.log")
    counts = {}
    for name, option in (("native-default", None), ("saved-30", "1"), ("saved-off", "3"), ("guard", "reject")):
        profile = work / name
        profile.mkdir()
        env = dict(os.environ, USERPROFILE=str(profile), APPDATA=str(profile / "AppData/Roaming"),
                   LOCALAPPDATA=str(profile / "AppData/Local"), TEMP=str(profile), TMP=str(profile))
        view_input = viewpoint
        if option == "reject":
            view_input = profile / "different-Viewpoint.jar"
            shutil.copy2(viewpoint, view_input)
            with zipfile.ZipFile(view_input, "a") as archive:
                zip_entry(archive, "offline-test-marker.txt", b"Compatibility check fixture.\n")
        test_cp = os.pathsep.join(map(str, (test_classes, jar, stock, buddy, view_input)))
        argv = [java, "-XX:-UsePerfData", "--enable-native-access=ALL-UNNAMED",
                f"-Duser.home={profile}", f"-Djava.io.tmpdir={profile}", "-cp", test_cp,
                TEST, profile, stock, view_input]
        if option is not None:
            argv.append(option)
        report = run(argv, profile, work / (name + ".log"), env)
        match = SUCCESS.search(report)
        if not match:
            raise RuntimeError(f"Missing native validation evidence for {name}")
        counts[name] = int(match[1])
        if option == "reject":
            view_input.unlink()

    archive_file = output / f"{MOD_ID}-0.1.0.zip"
    files = sorted(path for path in candidate.rglob("*") if path.is_file())
    with zipfile.ZipFile(archive_file, "x") as archive:
        for path in files:
            zip_entry(archive, path.relative_to(candidate.parent).as_posix(), path.read_bytes())
    with zipfile.ZipFile(archive_file) as archive:
        assert archive.testzip() is None
        assert all(archive.read(path.relative_to(candidate.parent).as_posix()) == path.read_bytes()
                   for path in files)
    assert all(digest(Path(path)) == expected for path, expected in inputs.items()), "Upstream changed during verification"

    receipt = {
        "result": "PASS",
        "native_assertions": counts,
        "game_started": False,
        "world_loaded": False,
        "version": "0.1.0",
        "files": {path.relative_to(candidate).as_posix(): digest(path) for path in files},
        "jar_sha256": digest(jar),
        "artifact": str(archive_file),
        "artifact_sha256": digest(archive_file),
        "inputs": inputs,
    }
    (output / "verification.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {sum(counts.values())} native assertions, {len(files)} candidate files")
    print(receipt["jar_sha256"])


if __name__ == "__main__":
    main()
