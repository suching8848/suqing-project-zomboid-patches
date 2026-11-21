"""Build a reproducible pure-Java melee-upgrade candidate in a fresh offline directory."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[1]
MOD = "SuQingMeleeUpgrade_4222"
JAR_PATH = Path("42/media/java/client/SuQingMeleeUpgrade.jar")
SOURCES = ROOT / "java/melee_upgrade_persistence/source"
STAMP = (2026, 11, 18, 0, 0, 0)


def sha256(file):
    with file.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def archive_file(archive, name, contents):
    member = zipfile.ZipInfo(name, STAMP)
    member.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(member, contents)


def run(command, cwd, log):
    result = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True, timeout=90)
    transcript = (result.stdout + result.stderr).decode("utf-8", errors="replace")
    log.write_text(transcript, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{log}:\n{transcript[-6000:]}")


def build(game, javac, output, freeze):
    source = ROOT / "src" / MOD
    metadata = (source / "42/mod.info").read_text(encoding="utf-8")
    version = next(line.removeprefix("modversion=") for line in metadata.splitlines()
                   if line.startswith("modversion="))
    stock = game / "projectzomboid.jar"
    buddy = game / "ZombieBuddy.jar"
    hashes = {item: sha256(item) for item in (stock, buddy)}
    work = output / "build"
    classes = work / "classes"
    classes.mkdir(parents=True)
    sources = sorted(SOURCES.rglob("*.java"))
    if not sources:
        raise RuntimeError("No Java mod sources")
    run([javac, "-encoding", "UTF-8", "--release", "25", "-cp", os.pathsep.join(map(str, (stock, buddy))),
         "-d", classes, *sources], output, work / "compile.log")

    candidate = output / "candidate" / MOD
    shutil.copytree(source, candidate, ignore=shutil.ignore_patterns("*.jar"))
    if list(candidate.rglob("*.lua")):
        raise RuntimeError("Unexpected Lua executable source in pure-Java candidate")
    languages = []
    for code in ("EN", "CN"):
        translation = candidate / "42/media/lua/shared/Translate" / code / "UI.json"
        languages.append(json.loads(translation.read_bytes()))
    if languages[0].keys() != languages[1].keys():
        raise RuntimeError("EN and CN translation keys differ")

    jar = candidate / JAR_PATH
    jar.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(jar, "x") as archive:
        manifest = f"Manifest-Version: 1.0\r\nImplementation-Version: {version}\r\n\r\n"
        archive_file(archive, "META-INF/MANIFEST.MF", manifest.encode("utf-8"))
        for file in sorted(classes.rglob("*.class")):
            archive_file(archive, file.relative_to(classes).as_posix(), file.read_bytes())

    files = sorted(path for path in candidate.rglob("*") if path.is_file())
    bundle = output / f"{MOD}-{version}.zip"
    if freeze:
        with zipfile.ZipFile(bundle, "x") as archive:
            for file in files:
                archive_file(archive, file.relative_to(candidate.parent).as_posix(), file.read_bytes())
        with zipfile.ZipFile(bundle) as archive:
            if archive.testzip() or any(archive.read(file.relative_to(candidate.parent).as_posix())
                                        != file.read_bytes() for file in files):
                raise RuntimeError("Frozen archive failed readback")
    if any(sha256(item) != expected for item, expected in hashes.items()):
        raise RuntimeError("Installed game or loader changed during build")

    receipt = {
        "version": version, "game_started": False, "deployed": False,
        "source_sha256": {file.relative_to(SOURCES).as_posix(): sha256(file) for file in sources},
        "runtime_sha256": {file.relative_to(candidate).as_posix(): sha256(file) for file in files},
        "inputs_sha256": {item.name: digest for item, digest in hashes.items()},
        "jar_sha256": sha256(jar),
        "artifact_sha256": sha256(bundle) if freeze else None,
    }
    (output / "build.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"Candidate: {candidate}, {len(files)} files, JAR SHA-256 {receipt['jar_sha256']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path, required=True)
    parser.add_argument("--javac", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--freeze", action="store_true")
    args = parser.parse_args()
    game, output = args.game_root.resolve(strict=True), args.output.resolve()
    if any(output.is_relative_to(path) for path in (game, ROOT, Path.home() / "Zomboid")):
        parser.error("Use a fresh directory outside the game, user data and source repository")
    output.mkdir(parents=True, exist_ok=False)
    build(game, args.javac.resolve(strict=True), output, args.freeze)


if __name__ == "__main__":
    main()
