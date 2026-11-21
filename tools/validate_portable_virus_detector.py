"""Verify the portable virus detector against the installed B42.22.2 files and package it."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
MOD_ID = "SuQingPortableVirusDetector_4222"
MOD = ROOT / "src" / MOD_ID
LUA = MOD / "42/media/lua"
TESTS = ROOT / "tests/portable_virus_detector"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def string_literal(text):
    marker = "="
    while f"]{marker}]" in text:
        marker += "="
    return f"[{marker}[{text}]{marker}]"


def inventory_function(path, clean_ui=False):
    text = path.read_text(encoding="utf-8-sig")
    selection = re.search(r"(?ms)^function ISInventoryPane\.getActualItems\(.*?^end\b", text)
    if clean_ui:
        helper = re.search(r"(?ms)^local function CleanUI_getStackActualStartIndex\(.*?^end\b", text)
        return helper[0] + "\n" + selection[0]
    return selection[0]


def suite(sources, translations):
    path = TESTS / "regression.lua"
    keys = "\n".join(f"[{json.dumps(key)}] = true," for key in sorted(translations))
    modules = "\n".join(
        f"[{json.dumps(key)}] = {string_literal(value)}," for key, value in sources.items()
    )
    return "TRANSLATIONS = {\n" + keys + "\n}\nSOURCES = {\n" + modules + "\n}\n" + path.read_text(encoding="utf-8")


def run(command, cwd, log):
    result = subprocess.run(list(map(str, command)), cwd=cwd, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, encoding="utf-8", errors="replace", timeout=75)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{log}:\n{result.stdout[-6500:]}")
    return result.stdout


def verify(game, workshop, javac, output):
    info = dict(line.split("=", 1) for line in (MOD / "42/mod.info").read_text(encoding="utf-8").splitlines())
    assert info["id"] == MOD_ID and info["require"] == "ModernFirearmsSystem"
    translations = [json.loads((LUA / f"shared/Translate/{language}/UI.json").read_bytes())
                    for language in ("CN", "EN")]
    assert translations[0].keys() == translations[1].keys()
    core_path = LUA / "shared/SuQingPortableVirusDetector/Core.lua"
    sources = {
        "SuQingPortableVirusDetector/Core": core_path.read_text(encoding="utf-8"),
        "SuQingPortableVirusDetector/Radar": (LUA / "client/SuQingPortableVirusDetector/Radar.lua").read_text(encoding="utf-8"),
        "Menu": (LUA / "client/SuQingPortableVirusDetectorMenu.lua").read_text(encoding="utf-8"),
    }
    inventory_path = Path("media/lua/client/ISUI/ISInventoryPane.lua")
    clean_ui = workshop / "3437629766/mods/CleanUI/42.22"
    mfs = workshop / "3633421539/mods/Escape from Kentucky4215/42"
    detector_script = mfs / "media/scripts/Part/L_Scope.txt"
    game_jar = game / "projectzomboid.jar"
    game_java = game / "jre64/bin/java.exe"
    for name in ("stdlib.lua", "stdlib.lbc"):
        shutil.copyfile(game / name, output / name)
    for directory in ("home", "temp"):
        (output / directory).mkdir()

    run([javac, "-encoding", "UTF-8", "--release", "25", "-cp", game_jar, "-d", output,
         ROOT / "tests/cleanui/performance/KahluaValidation.java", TESTS / "NativeInventoryAudit.java"],
        output, output / "compile.log")
    base_args = [game_java, "-XX:-UsePerfData", "-Dfile.encoding=UTF-8", "-Djava.awt.headless=true",
                 f"-Duser.home={output / 'home'}", f"-Djava.io.tmpdir={output / 'temp'}"]
    classpath = os.pathsep.join(map(str, (game_jar, output)))
    results = {}
    for name, source in (("vanilla", game / inventory_path), ("cleanui", clean_ui / inventory_path)):
        code = suite({**sources, "Selection": inventory_function(source, name == "cleanui")}, translations[0])
        script = output / f"{name}.lua"
        script.write_text(code, encoding="utf-8")
        result = LuaRuntime().execute(code)
        report = run([*base_args, "-cp", classpath, "KahluaValidation", script], output, output / f"{name}.log")
        assert result.startswith("PASS ") and f"[true, {result}]" in report
        results[name] = result
    report = run([*base_args, "-cp", classpath, "NativeInventoryAudit", game, detector_script, core_path],
                 output, output / "native-inventory.log")
    native = re.search(r"NATIVE_PORTABLE_VIRUS_DETECTOR PASS (\d+)", report)
    assert native, "Missing native inventory result"

    bundle = output / f"{MOD_ID}-{info['modversion']}.zip"
    runtime = {path.relative_to(MOD.parent).as_posix(): path
               for path in sorted(MOD.rglob("*")) if path.is_file()}
    with zipfile.ZipFile(bundle, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, path in runtime.items():
            archive.write(path, name)
    with zipfile.ZipFile(bundle) as archive:
        assert archive.testzip() is None and set(archive.namelist()) == runtime.keys()
        assert all(archive.read(name) == path.read_bytes() for name, path in runtime.items())

    receipt = {
        "result": "PASS",
        "version": info["modversion"],
        "menu_and_radar_lua_51_and_kahlua": results,
        "native_inventory_checks": int(native[1]),
        "translation_keys_per_language": len(translations[0]),
        "inputs_sha256": {str(path): digest(path) for path in
                          (game_jar, detector_script, game / inventory_path, clean_ui / inventory_path)},
        "runtime_sha256": {name: digest(path) for name, path in runtime.items()},
        "zip_sha256": digest(bundle),
        "gameplay_tested": False,
        "deployed": False,
    }
    (output / "verification.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"{bundle}\n{results}; native inventory: {native[1]} checks")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("game", "workshop", "javac", "output"):
        parser.add_argument(f"--{name}", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if any(output.is_relative_to(parent) for parent in (ROOT, args.game.resolve(), Path.home() / "Zomboid")):
        parser.error("Use a fresh verification folder outside game, save data and source")
    output.mkdir(parents=True, exist_ok=False)
    verify(args.game.resolve(), args.workshop.resolve(), args.javac.resolve(), output)


if __name__ == "__main__":
    main()
