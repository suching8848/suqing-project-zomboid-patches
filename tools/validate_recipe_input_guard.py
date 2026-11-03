"""Offline checks for the standalone Sapph registry fix; no save/game launch."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/SuQingRecipeInputGuard_4221"


def literal(value):
    equals = "=="
    while "]" + equals + "]" in value:
        equals += "="
    return "[" + equals + "[" + value + "]" + equals + "]"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path)
    parser.add_argument("--kahlua-runner-dir", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    os.chdir(ROOT)
    from lupa.lua51 import LuaRuntime

    sources = {p.relative_to(ROOT).as_posix(): p.read_text(encoding="utf-8")
               for base in [SOURCE, ROOT / "tests/recipe_input_guard"]
               for p in base.rglob("*.lua")}
    results = []
    for suite in ["registration", "verification"]:
        lua = LuaRuntime(unpack_returned_tuples=True)
        for path, code in sources.items():
            lua.execute("local code, path = ...; assert(loadstring(code, path))", code, path)
        outcome = lua.execute(sources[f"tests/recipe_input_guard/{suite}_tests.lua"])["run"]()
        results.append({"engine": "Lua 5.1", "suite": suite, "checks": outcome, "result": "PASS"})

    if args.kahlua_runner_dir:
        if not args.game_root:
            parser.error("--kahlua-runner-dir requires --game-root")
        classpath = os.pathsep.join([str(args.kahlua_runner_dir), str(args.game_root / "projectzomboid.jar")])
        scratch = ROOT / ".validation"
        scratch.mkdir(exist_ok=True)
        for suite in ["registration", "verification"]:
            bundle = ["local sources = {}"]
            for path, code in sources.items():
                bundle.append(f"sources[ {literal(path)} ] = {literal(code)}")
            bundle.append("""
function dofile(path)
    return assert(loadstring(assert(sources[path], 'missing source: ' .. tostring(path)), path))()
end
for path, code in pairs(sources) do assert(loadstring(code, path)) end
""")
            bundle.append(f"dofile('tests/recipe_input_guard/{suite}_tests.lua').run()")
            with tempfile.TemporaryDirectory(prefix="recipe-guard-", dir=scratch) as temp:
                path = Path(temp) / "suite.lua"
                path.write_text("\n".join(bundle), encoding="utf-8")
                result = subprocess.run([str(args.game_root / "jre64/bin/java.exe"), "-cp", classpath,
                                         "KahluaValidation", str(path)], cwd=args.game_root,
                                        capture_output=True, text=True, encoding="utf-8", errors="replace")
                print(result.stdout.strip())
                if result.returncode:
                    raise RuntimeError(f"Kahlua {suite} failed:\n{result.stderr}")
            results.append({"engine": "game Kahlua", "suite": suite, "result": "PASS"})

    report = {"result": "PASS", "suites": results, "syntax_files": len(sources),
              "gameplay_validation": "not performed; cold-start registry fixtures and read-only input verification",
              "runtime_sha256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in SOURCE.rglob("*") if p.is_file()}}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"result": "PASS", "suites": len(results), "syntax_files": len(sources)}, indent=2))


if __name__ == "__main__":
    main()
