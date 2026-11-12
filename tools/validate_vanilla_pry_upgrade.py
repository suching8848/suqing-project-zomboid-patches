"""Verify the crowbar patch with the current vanilla menu and action Lua."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from lupa.lua51 import LuaRuntime


REPO = Path(__file__).resolve().parents[1]
GAME = Path(r"D:\steam\steamapps\common\ProjectZomboid")
JDK = Path(r"E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64\bin")
MOD = REPO / "src/SuQingVanillaPryUpgrade/42"
RUNNER = REPO / "tests/cleanui/performance/KahluaValidation.java"
TEST = REPO / "tests/vanilla_pry_upgrade/regression.lua"

VANILLA = {
    "TimedActions/ISBaseTimedAction": "shared/TimedActions/ISBaseTimedAction.lua",
    "TimedActions/ISForceOpen": "shared/TimedActions/ISForceOpen.lua",
    "Vehicles/TimedActions/ISOpenVehicleDoor": "shared/Vehicles/TimedActions/ISOpenVehicleDoor.lua",
    "Vehicles/ISUI/ISVehicleMenu": "client/Vehicles/ISUI/ISVehicleMenu.lua",
}


def lua_string(text):
    delimiter = "="
    while "]" + delimiter + "]" in text:
        delimiter += "="
    return f"[{delimiter}[{text}]{delimiter}]"


def checked_translations(client_sources):
    bundles = {}
    for language in ("CN", "EN"):
        root = MOD / "media/lua/shared/Translate" / language
        bundles[language] = {}
        for filename, prefix in (("ContextMenu.json", "ContextMenu_"), ("IG_UI.json", "IGUI_")):
            for key, value in json.loads((root / filename).read_text(encoding="utf-8")).items():
                assert key.startswith(prefix) and value.strip()
                bundles[language][key] = value
    refs = set(re.findall(r'"((?:ContextMenu|IGUI)_SuQingPry_\w+)"', "\n".join(client_sources)))
    assert refs == bundles["EN"].keys() == bundles["CN"].keys()
    return bundles


def native_translations(scratch, translations):
    stock_path = Path("media/lua/shared/Translate")
    cache = scratch / "cache"
    shutil.copytree(MOD.parent, cache / "mods" / MOD.parent.name)
    rows = []
    for language, entries in translations.items():
        source = GAME / stock_path / language
        dest = scratch / stock_path / language
        dest.mkdir(parents=True)
        shutil.copy2(source / "language.json", dest / "language.json")
        for filename, control in (
            ("ContextMenu.json", "ContextMenu_Open_door"),
            ("IG_UI.json", "IGUI_invpanel_Type"),
        ):
            shutil.copy2(source / filename, dest / filename)
            stock = json.loads((source / filename).read_text(encoding="utf-8-sig"))
            rows.append(f"{language}\t{control}\t{stock[control]}")
        rows.extend(f"{language}\t{key}\t{value}" for key, value in entries.items())
    expected = scratch / "expected.tsv"
    expected.write_text("\n".join(rows), encoding="utf-8")

    jar = GAME / "projectzomboid.jar"
    probe = TEST.with_name("TranslationReadback.java")
    subprocess.run([
        str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", str(jar), "-d", str(scratch), str(probe)
    ], check=True)
    subprocess.run([
        str(GAME / "jre64/bin/java.exe"), "-Duser.home=" + str(scratch), "-Dfile.encoding=UTF-8",
        "-cp", os.pathsep.join((str(jar), str(scratch))), "TranslationReadback", str(cache), str(expected)
    ], cwd=scratch, check=True)


def main():
    client = MOD / "media/lua/client"
    sources = {
        file.relative_to(client).with_suffix("").as_posix(): file.read_text(encoding="utf-8")
        for file in sorted(client.rglob("*.lua"))
    }
    translations = checked_translations(sources.values())
    for name, file in VANILLA.items():
        sources[name] = (GAME / "media/lua" / file).read_text(encoding="utf-8-sig")

    bundle = ["local sources = {}", "local translations = {}"]
    for table, entries in (("sources", sources), ("translations", translations["EN"])):
        for key, value in entries.items():
            bundle.append(f"{table}[ {lua_string(key)} ] = {lua_string(value)}")
    bundle.append("""
local modules = {}
for name, source in pairs(sources) do assert(loadstring(source, name)) end
function require(name)
    if not sources[name] then return end
    if not modules[name] then
        modules[name] = assert(loadstring(sources[name], name))() or true
    end
    return modules[name]
end
""")
    bundle.append(TEST.read_text(encoding="utf-8"))
    source = "\n".join(bundle)
    print("Lua 5.1:", LuaRuntime().execute(source))
    with tempfile.TemporaryDirectory(prefix="sq-vanilla-pry-") as tmp:
        scratch = Path(tmp)
        script = scratch / "regression.lua"
        script.write_text(source, encoding="utf-8")
        subprocess.run([str(JDK / "javac.exe"), "--release", "17", "-d", tmp, str(RUNNER)], check=True)
        subprocess.run([
            str(GAME / "jre64/bin/java.exe"), "-Duser.home=" + tmp, "-cp",
            os.pathsep.join((str(GAME / "projectzomboid.jar"), tmp)),
            "KahluaValidation", str(script)
        ], cwd=GAME, check=True)
        native_translations(scratch, translations)
    print(f"CN/EN translation keys: {len(translations['EN'])}")


if __name__ == "__main__":
    main()
