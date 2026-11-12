"""Offline Kahlua and Lua 5.1 checks with the installed MFS part-stat Lua."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "src/SuQingMFSFirearmUpgrade_4221/42"
TESTS = ROOT / "tests/mfs_firearm_upgrade"
GAME = Path(r"D:\steam\steamapps\common\ProjectZomboid")
JDK = Path(r"E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64\bin")
RUNNER = ROOT / "tests/cleanui/performance/KahluaValidation.java"
MFS_PART_STATS = Path("D:/steam/steamapps/workshop/content/108600/3633421539/mods/Escape from Kentucky4215/42/media/lua/shared/Gun_Vars/EFK_Part_Stat_Set.lua")


def literal(value):
    level = "="
    while "]" + level + "]" in value:
        level += "="
    return "[" + level + "[" + value + "]" + level + "]"


def unique_object(pairs):
    result = dict(pairs)
    if len(result) != len(pairs):
        raise ValueError("Duplicate JSON translation key")
    return result


def check_translations(sources):
    bundles = {}
    root = MOD / "media/lua/shared/Translate"
    for language in ("EN", "CN"):
        bundles[language] = {}
        paths = sorted((root / language).glob("*.json"))
        for path in paths:
            entries = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique_object)
            assert isinstance(entries, dict), path
            assert all(isinstance(value, str) and value.strip() for value in entries.values()), path
            assert bundles[language].keys().isdisjoint(entries), path
            bundles[language].update(entries)

    english, chinese = bundles["EN"], bundles["CN"]
    assert english and english.keys() == chinese.keys(), "CN and EN keys differ"
    placeholders = re.compile(r"%[1-9][0-9]*")
    for key, value in english.items():
        assert Counter(placeholders.findall(value)) == Counter(placeholders.findall(chinese[key])), key
    references = set(re.findall(r"\bUI_SuQingMFSFirearmUpgrade_[A-Za-z0-9_]+", "\n".join(sources)))
    references = {key for key in references if not key.endswith("_")}
    assert references <= english.keys(), f"Missing keys: {sorted(references - english.keys())}"
    return english


def build_bundle(mfs_part_stats):
    lua_root = MOD / "media/lua"
    runtime = {}
    for side in ("shared", "client"):
        for path in sorted((lua_root / side).rglob("*.lua")):
            name = path.relative_to(lua_root / side).with_suffix("").as_posix()
            assert name not in runtime, name
            runtime[name] = path.read_text(encoding="utf-8-sig")
    assert runtime, f"No Lua under {lua_root}"
    translations = check_translations(runtime.values())
    source_map = ["local sources = {}"]
    for name, source in runtime.items():
        source_map.append(f"sources[ {literal(name)} ] = {literal(source)}")
    source_map.append(f'sources["Gun_Vars/EFK_Part_Stat_Set"] = {literal(mfs_part_stats)}')
    source_map.append("MFSUpgradeTranslations = {}")
    for key, value in translations.items():
        source_map.append(f"MFSUpgradeTranslations[ {literal(key)} ] = {literal(value)}")
    source_map.append("""
local modules = {}
for name, source in pairs(sources) do assert(loadstring(source, name)) end
function require(name)
    if not sources[name] then return end
    if modules[name] == nil then
        modules[name] = assert(loadstring(sources[name], name))() or true
    end
    return modules[name]
end
""")
    cases = sorted(TESTS.glob("*.lua"))
    assert cases, f"No regression cases in {TESTS}"
    for path in cases:
        source = path.read_text(encoding="utf-8-sig")
        source_map.append(f"assert(loadstring({literal(source)}, {literal(path.name)}))()")
    source_map.append(f"return 'PASS: {len(runtime)} Lua files, {len(cases)} suites, {len(translations)} CN/EN keys'")
    return "\n".join(source_map)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path, default=GAME)
    parser.add_argument("--jdk-bin", type=Path, default=JDK)
    parser.add_argument("--mfs-part-stats", type=Path, default=MFS_PART_STATS)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    info = dict(line.split("=", 1) for line in (MOD / "mod.info").read_text(encoding="utf-8-sig").splitlines()
                if "=" in line and not line.lstrip().startswith("#"))
    assert info["id"] == "SuQingMFSFirearmUpgrade_4221"
    assert info["require"] == "ModernFirearmsSystem"
    assert info["name"] and info["namezh"] and info["modversion"]

    bundle = build_bundle(args.mfs_part_stats.read_text(encoding="utf-8-sig"))
    outcome = LuaRuntime(unpack_returned_tuples=True).execute(bundle)
    print(f"Lua 5.1: {outcome}")

    game = args.game_root.resolve()
    engines = {"game Kahlua": [game / "projectzomboid.jar"]}
    pzo = game / "pzopt/aot/pzopt.jar"
    if pzo.is_file():
        engines["PZO-first Kahlua"] = [pzo, *engines["game Kahlua"]]

    with tempfile.TemporaryDirectory(prefix="suqing-mfs-upgrade-") as temporary:
        work = Path(temporary)
        subprocess.run([str(args.jdk_bin / "javac.exe"), "--release", "17", "-d", str(work), str(RUNNER)],
                       cwd=work, check=True, timeout=60)
        for name in ("stdlib.lbc", "stdlib.lua"):
            shutil.copy2(game / name, work)
        suite = work / "suite.lua"
        suite.write_text(bundle, encoding="utf-8")
        for name, jars in engines.items():
            classpath = os.pathsep.join(str(path) for path in [*jars, work])
            result = subprocess.run(
                [str(game / "jre64/bin/java.exe"), f"-Duser.home={work}", "-cp", classpath,
                 "KahluaValidation", str(suite)], cwd=work, capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=60,
            )
            if result.returncode or f"[true, {outcome}]" not in result.stdout:
                raise RuntimeError(f"{name} failed\n{result.stdout}{result.stderr}")
            print(f"{name}: {outcome}")

    if args.report:
        report = {
            "result": "PASS",
            "summary": outcome,
            "engines": ["Lua 5.1", *engines],
            "coverage": "Simulated items and UI, installed MFS part-stat Lua, CN/EN translation checks",
            "upstream_part_stats_sha256": hashlib.sha256(args.mfs_part_stats.read_bytes()).hexdigest(),
            "candidate_sha256": {
                path.relative_to(MOD.parent).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in sorted(MOD.rglob("*")) if path.is_file()
            },
        }
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
