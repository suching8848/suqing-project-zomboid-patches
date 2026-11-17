"""Run the ammunition-weight regression with Lua 5.1 and the game JAR's Kahlua."""

from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile

from lupa.lua51 import LuaRuntime


TEST_ROOT = Path(__file__).resolve().parent
REPOSITORY = TEST_ROOT.parents[1]
DEFAULT_MOD = REPOSITORY / "src/SuQingMFSAmmoWeight_4222"


def lua_literal(value):
    delimiter = "="
    while "]" + delimiter + "]" in value:
        delimiter += "="
    return f"[{delimiter}[{value}]{delimiter}]"


def make_suite(mod_root, true_weight_script):
    lua_root = mod_root / "42/media/lua/shared"
    modules = {
        path.relative_to(lua_root).with_suffix("").as_posix(): path
        for path in sorted(lua_root.rglob("*.lua"))
    }
    modules["true-weight-source"] = true_weight_script
    sources = ["local modules = {}"]
    for name, path in modules.items():
        source = lua_literal(path.read_text(encoding="utf-8-sig"))
        sources.append(f"modules[ {lua_literal(name)} ] = assert(loadstring({source}, {lua_literal(name)}))")
    sources.append(
        """
local loaded = {}
local results = {}
function require(name)
    local module = assert(modules[name], "Module not found: " .. name)
    if not loaded[name] then
        results[name] = module()
        loaded[name] = true
    end
    return results[name]
end
"""
    )
    sources.append((TEST_ROOT / "regression.lua").read_text(encoding="utf-8"))
    return "\n".join(sources)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mod-root", type=Path, default=DEFAULT_MOD)
    parser.add_argument("--game-root", type=Path, required=True)
    parser.add_argument("--jdk-bin", type=Path, required=True)
    parser.add_argument("--true-weight-script", type=Path, required=True)
    args = parser.parse_args()

    suite = make_suite(args.mod_root, args.true_weight_script)
    expected = LuaRuntime().execute(suite)
    print(f"Lua 5.1: {expected}")
    runner = REPOSITORY / "tests/cleanui/performance/KahluaValidation.java"

    with tempfile.TemporaryDirectory(prefix="suqing-mfs-ammo-weight-") as temporary:
        work = Path(temporary)
        subprocess.run(
            [str(args.jdk_bin / "javac.exe"), "--release", "17", "-d", str(work), str(runner)],
            cwd=work,
            check=True,
            timeout=60,
        )
        for name in ("stdlib.lbc", "stdlib.lua"):
            shutil.copy2(args.game_root / name, work)
        suite_file = work / "suite.lua"
        suite_file.write_text(suite, encoding="utf-8")
        result = subprocess.run(
            [
                str(args.game_root / "jre64/bin/java.exe"),
                f"-Duser.home={work}",
                "-cp",
                os.pathsep.join([str(args.game_root / "projectzomboid.jar"), str(work)]),
                "KahluaValidation",
                str(suite_file),
            ],
            cwd=work,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
        )
        if result.returncode or f"[true, {expected}]" not in result.stdout:
            raise RuntimeError(result.stdout + result.stderr)
        print(f"Game Kahlua: {expected}")


if __name__ == "__main__":
    main()
