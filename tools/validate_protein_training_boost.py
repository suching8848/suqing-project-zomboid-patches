"""Offline Lua 5.1/Kahlua checks. Does not launch the game or open a save."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "src/SuQingProteinTrainingBoost/42/media/lua"
TESTS = ROOT / "tests/protein_training_boost"


def long_string(value):
    level = "=="
    while "]" + level + "]" in value:
        level += "="
    return "[" + level + "[" + value + "]" + level + "]"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path)
    parser.add_argument("--kahlua-runner-dir", type=Path)
    parser.add_argument("--project-iron-dir", type=Path, help="Path to the installed SweatWorkz 0.6.0 42 branch")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    os.chdir(ROOT)
    from lupa.lua51 import LuaRuntime

    source_map = {}
    module_map = {}
    for kind in ("shared", "client"):
        for path in (MOD / kind).rglob("*.lua"):
            relative = path.relative_to(ROOT).as_posix()
            source_map[relative] = path.read_text(encoding="utf-8")
            module_map[path.relative_to(MOD / kind).with_suffix("").as_posix()] = relative
    for path in TESTS.glob("*.lua"):
        source_map[path.relative_to(ROOT).as_posix()] = path.read_text(encoding="utf-8")
    game_drink = None
    if args.game_root:
        game_drink = (args.game_root / "media/lua/shared/TimedActions/ISDrinkFluidAction.lua").resolve()
        source_map[game_drink.as_posix()] = game_drink.read_text(encoding="utf-8-sig")

    iron_sources = {}
    if args.project_iron_dir:
        for name, relative in {
            "IRON_SUPPLEMENTS_SOURCE_PATH": "media/lua/shared/SweatWorkz_Supplements.lua",
            "IRON_UI_SOURCE_PATH": "media/lua/client/SweatWorkz_BoostUI.lua",
        }.items():
            path = (args.project_iron_dir / relative).resolve()
            iron_sources[name] = path.as_posix()
            source_map[path.as_posix()] = path.read_text(encoding="utf-8-sig")

    suites = ["core", "xp", "drinking"] + (["integration"] if game_drink else [])
    if iron_sources:
        suites.append("iron")
    results = []
    for suite in suites:
        lua = LuaRuntime(unpack_returned_tuples=True)
        paths = ";".join((MOD / kind / "?.lua").as_posix() for kind in ("shared", "client"))
        lua.execute("local paths = ...; package.path = paths .. ';' .. package.path", paths)
        if game_drink:
            lua.globals().GAME_DRINK_SOURCE_PATH = game_drink.as_posix()
        for name, path in iron_sources.items():
            lua.globals()[name] = path
        for path, source in source_map.items():
            lua.execute("local source, path = ...; assert(loadstring(source, path))", source, path)
        outcome = lua.execute(source_map[f"tests/protein_training_boost/{suite}_tests.lua"])
        if suite == "drinking":
            outcome = outcome["run"]()
        results.append({"engine": "Lua 5.1", "suite": suite, "result": "PASS"})

    if args.kahlua_runner_dir:
        if not args.game_root:
            parser.error("--kahlua-runner-dir also needs --game-root")
        java = args.game_root / "jre64/bin/java.exe"
        classpath = os.pathsep.join((str(args.kahlua_runner_dir), str(args.game_root / "projectzomboid.jar")))
        scratch = ROOT / ".validation"
        scratch.mkdir(exist_ok=True)
        for suite in suites:
            prelude = ["package = { loaded = {} }", "local sources = {}", "local modules = {}"]
            for path, source in source_map.items():
                prelude.append(f"sources[ {long_string(path)} ] = {long_string(source)}")
            for name, path in module_map.items():
                prelude.append(f"modules[ {long_string(name)} ] = {long_string(path)}")
            prelude.append("""
function dofile(path)
    local source = assert(sources[path], 'missing test source: ' .. tostring(path))
    return assert(loadstring(source, path))()
end
function require(name)
    if package.loaded[name] then return package.loaded[name] end
    local result = dofile(assert(modules[name], 'unknown module: ' .. tostring(name)))
    package.loaded[name] = result or true
    return package.loaded[name]
end
for path, source in pairs(sources) do assert(loadstring(source, path)) end
""")
            if game_drink:
                prelude.append(f"GAME_DRINK_SOURCE_PATH = {long_string(game_drink.as_posix())}")
            for name, path in iron_sources.items():
                prelude.append(f"{name} = {long_string(path)}")
            prelude.append(f"local outcome = dofile('tests/protein_training_boost/{suite}_tests.lua')")
            if suite == "drinking":
                prelude.append("outcome.run()")
            prelude.append(f"print('KAHLUA PASS: {suite}')")
            with tempfile.TemporaryDirectory(prefix="protein-", dir=scratch) as temporary:
                bundle = Path(temporary) / "suite.lua"
                bundle.write_text("\n".join(prelude), encoding="utf-8")
                completed = subprocess.run([str(java), "-cp", classpath, "KahluaValidation", str(bundle)],
                                           cwd=args.game_root, capture_output=True, text=True,
                                           encoding="utf-8", errors="replace")
                print(completed.stdout.strip())
                if completed.returncode:
                    raise RuntimeError(f"Kahlua {suite} failed:\n{completed.stderr}")
            results.append({"engine": "game Kahlua", "suite": suite, "result": "PASS"})

    report = {"result": "PASS", "suites": results, "syntax_files": len(source_map),
              "gameplay_validation": "not performed; isolated offline fixtures",
              "project_iron_sources": {path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
                                       for path in iron_sources.values()},
              "runtime_sha256": {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                                 for path in (ROOT / "src/SuQingProteinTrainingBoost").rglob("*") if path.is_file()}}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"result": report["result"], "suites": len(results), "syntax_files": len(source_map)}, indent=2))


if __name__ == "__main__":
    main()
