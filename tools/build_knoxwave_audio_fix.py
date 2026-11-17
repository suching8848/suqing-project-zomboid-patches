"""Build the standalone KNOXWAVE companion into an isolated output directory."""

import argparse
from pathlib import Path
import shutil
import subprocess
import zipfile

REPO = Path(__file__).resolve().parents[1]
MOD_ID = "SuQingKnoxwaveAudioFix_4222"
JAVA_VERSION = "0.1.1"
JAVA_SOURCE = REPO / "java/knoxwave_audio_fix/source/suqingknoxwaveaudiofix/Main.java"
JAR_PATH = Path("42/media/java/client/SuQingKnoxwaveAudioFix.jar")


def put(archive, name, data):
    entry = zipfile.ZipInfo(name, (2026, 11, 17, 0, 0, 0))
    entry.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(entry, data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--javac", type=Path, required=True)
    parser.add_argument("--game-jar", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    game_jar = args.game_jar.resolve(strict=True)
    if any(output.is_relative_to(root) for root in (REPO, game_jar.parent, Path.home() / "Zomboid")):
        parser.error("output must be outside the repository and live game directories")
    classes = output / "classes"
    classes.mkdir(parents=True)
    subprocess.run([str(args.javac.resolve(strict=True)), "--release", "25", "-encoding", "UTF-8",
                    "-cp", str(game_jar), "-d", str(classes), str(JAVA_SOURCE)], check=True)

    candidate = output / "candidate" / MOD_ID
    shutil.copytree(REPO / "src" / MOD_ID, candidate, ignore=shutil.ignore_patterns(JAR_PATH.name))
    jar = candidate / JAR_PATH
    jar.parent.mkdir(parents=True)
    with zipfile.ZipFile(jar, "x") as archive:
        put(archive, "META-INF/MANIFEST.MF", f"Manifest-Version: 1.0\r\nImplementation-Version: {JAVA_VERSION}\r\n\r\n".encode("ascii"))
        for path in sorted(classes.rglob("*.class")):
            put(archive, path.relative_to(classes).as_posix(), path.read_bytes())
    print(jar)


if __name__ == "__main__":
    main()
