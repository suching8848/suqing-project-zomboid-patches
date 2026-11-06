"""Offline regression using installed upstream declarations/entry/menu functions.

No game startup, Steam mutations, world access or save writes. The only output
is a harness and logs in the requested audit directory.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

REPO = Path(__file__).resolve().parents[1]
GAME = Path(r'D:\steam\steamapps\common\ProjectZomboid')
SOURCE = REPO / 'src/SuQingBoatRVRoomGuard_4221'
RV = Path(r'D:\steam\steamapps\workshop\content\108600\3543229299\mods\modPROJECTRVInterior\42')
BOAT = Path(r'D:\steam\steamapps\workshop\content\108600\3777121241\mods\FrotaBRRVAddon\42')

def text(path):
    return path.read_text(encoding='utf-8-sig')

def block(source, start, end):
    return source[source.index(start):source.index(end, source.index(start))]

def function(name, source):
    return 'function ' + name + '()\n' + source + '\nend\n'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--audit-dir', required=True, type=Path)
    args = parser.parse_args()
    args.audit_dir.mkdir(parents=True, exist_ok=True)
    sp = text(RV / 'media/lua/client/RVClientSP.lua')
    vt = text(RV / 'media/lua/shared/RVVehicleTypes.lua')
    reg = text(BOAT / 'media/lua/shared/FrotaBRRV_Registro.lua')
    hooks = text(RV / 'media/lua/shared/RVHooks.lua')
    helper1 = block(sp, 'local function tableContains', 'local function isTrunkAccessibleForPart')
    helper2 = block(sp, 'local function isTrunkAccessibleForPart', '------ Fallback')
    entry = block(sp, 'local function GetInToRV(player)', 'function ISVehicleMenu.showRadialMenu')
    menu = block(sp, 'function ISVehicleMenu.showRadialMenu', 'check = false')
    actual = ('function BUILD_NATIVE_FUNCTIONS(teleportPlayerToRoom)\n'
              'local VehicleTypes, RVHooks = VehicleTypes, RVHooks\n'
              'local RV_showRadialMenu = function() end\n' + helper1 + helper2 + entry + menu +
              '\nreturn GetInToRV, ISVehicleMenu.showRadialMenu\nend\n')
    pin_specs = [('PROJECTRVInterior42', RV, p) for p in [
        'media/lua/client/RVClientSP.lua', 'media/lua/shared/RVVehicleTypes.lua', 'media/lua/shared/RVHooks.lua']]
    pin_specs += [('FrotaBRRVAddon', BOAT, p) for p in [
        'media/lua/shared/FrotaBRRV_Registro.lua', 'media/lua/client/FrotaBRRV_Fantasma.lua', 'media/lua/client/FrotaBRRV_Energia.lua']]
    unicode_points = {}
    for _, base, rel in pin_specs:
        for char in text(base / rel):
            if ord(char) >= 128:
                unicode_points[char] = ord(char)
    lines = 'NON_ASCII_CODEPOINTS = {' + ''.join('[' + json.dumps(char, ensure_ascii=False) + ']=' + str(value) + ',' for char, value in unicode_points.items()) + '}\n'
    lines += 'BOM_CHARACTER = ' + json.dumps('\ufeff', ensure_ascii=False) + '\nPIN_LINES = {}\nPIN_CHARS = {}\n'
    evidence = []
    for mod, base, rel in pin_specs:
        p = base / rel
        rows = text(p).splitlines()
        lines += 'PIN_LINES[' + json.dumps(mod + '|' + rel) + '] = {\n'
        lines += ''.join(json.dumps(row, ensure_ascii=False) + ',\n' for row in rows) + '}\n'
        utf16 = p.read_bytes().decode('utf-8-sig').encode('utf-16-le')
        units = [int.from_bytes(utf16[i:i+2], 'little') for i in range(0, len(utf16), 2)]
        lines += 'PIN_CHARS[' + json.dumps(mod + '|' + rel) + '] = function() return {' + ','.join(map(str, units)) + '} end\n'
        evidence.append({'mod': mod, 'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()})
    harness = (lines + function('LOAD_NATIVE_TYPES', vt) + function('LOAD_ADDON_REGISTRATION', reg) +
               function('LOAD_NATIVE_HOOKS', hooks) +
               function('LOAD_PATCH_CORE', text(SOURCE / '42/media/lua/shared/SQBoatRVRoomGuard/Core.lua')) +
               function('LOAD_PATCH_PINS', text(SOURCE / '42/media/lua/shared/SQBoatRVRoomGuard/SourcePins.lua')) +
               function('LOAD_PATCH_CLIENT', text(SOURCE / '42/media/lua/client/zz_SQBoatRVRoomGuard.lua')) +
               actual + text(REPO / 'tests/boat_rv_room_guard_scenarios.lua'))
    harness_path = args.audit_dir / 'boat_rv_room_guard_harness.lua'
    harness_path.write_text(harness, encoding='utf-8')
    checker = GAME / 'CodexAssets/InventoryTransferAdapt_20261102_234116/tests'
    classpath = str(checker) + ';' + str(GAME / 'projectzomboid.jar') + ';' + str(GAME / '*')
    command = [str(GAME / 'jre64/bin/java.exe'), '-cp', classpath, 'KahluaValidation', str(harness_path)]
    result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
    log = result.stdout + result.stderr
    (args.audit_dir / 'boat_rv_room_guard_regression.log').write_text(log, encoding='utf-8')
    print(log)
    if result.returncode or 'PASS assertions=' not in log:
        raise SystemExit('Offline behavior regression failed')
    compiler = GAME / 'CodexRepos/suqing-freshness-fridge/tools'
    lua = sorted(SOURCE.rglob('*.lua'))
    compile_command = [str(GAME / 'jre64/bin/java.exe'), '-cp', str(compiler) + ';' + str(GAME / 'projectzomboid.jar') + ';' + str(GAME / '*'), 'ReleaseLuaCompile', *map(str, lua)]
    result = subprocess.run(compile_command, capture_output=True, text=True)
    (args.audit_dir / 'patch_compile.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    if result.returncode:
        raise SystemExit(result.stdout + result.stderr)
    cn = json.loads(text(SOURCE / '42/media/lua/shared/Translate/CN/IG_UI.json'))
    en = json.loads(text(SOURCE / '42/media/lua/shared/Translate/EN/IG_UI.json'))
    assert set(cn) == set(en)
    for key in en:
        assert sorted(re.findall(r'%[1-9sdif]', en[key])) == sorted(re.findall(r'%[1-9sdif]', cn[key]))
    outcome = {'status': 'pass', 'assertions': int(re.search(r'PASS assertions=(\d+)', log).group(1)),
               'upstream': evidence, 'lua_files_compiled': len(lua), 'cn_en_keys': len(en),
               'game_started': False, 'save_written': False,
               'scope': 'Real installed native allocator, menu, type declarations and hooks; mocked player, vehicle, world, events and file readers'}
    (args.audit_dir / 'offline_validation.json').write_text(json.dumps(outcome, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(outcome, ensure_ascii=False))

if __name__ == '__main__':
    main()
