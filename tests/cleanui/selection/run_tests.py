"""Offline real-Kahlua / real-CleanUI source regressions; writes only here."""
from pathlib import Path
import subprocess, hashlib, json, re
from datetime import datetime, timezone, timedelta

HERE = Path(__file__).resolve().parent
GAME = Path(r'D:\steam\steamapps\common\ProjectZomboid')
OLD = HERE.parent / 'performance'
CLEAN = Path(r'D:\steam\steamapps\workshop\content\108600\3437629766\mods\CleanUI\42.19\media\lua\client\ISUI')
NEAT = Path(r'D:\steam\steamapps\workshop\content\108600\3790656296\mods\NeatUI_Equipment\42.20\media\lua\client\NeatEquipment')
PINYIN = Path(r'C:\Users\15792\Zomboid\mods\Pinyin_UI_4221_LocalCompat\42\media\lua\client\PinyinSafeCompat.lua')
PERF = HERE.parent.parent / 'candidate/InventoryTransferPerformance_4221_Local/42/media/lua/client/Codex_InventoryTransferPerformance.lua'
CANDIDATE = HERE.parent.parent / 'candidate/SuQingUIInteractionFixes/42/media/lua/client/SuQing_ProximitySelectionFix.lua'

for name in ['ui_prelude.lua', 'native_prepare.lua', 'native_fixtures.lua', 'stdlib.lua']:
    (HERE / name).write_bytes((OLD / name).read_bytes())
BASE = [HERE/'ui_prelude.lua', HERE/'native_prepare.lua', CLEAN/'ISInventoryPane.lua',
        NEAT/'NEQ_State.lua', NEAT/'ModCompatibility/NEQ_InventoryTetris.lua',
        HERE/'native_fixtures.lua', PINYIN, NEAT/'Patches/NEQ_HideEquipped.lua', HERE/'prepare.lua']

results = []
def run(name, case, fixed, expect_failure=False, performance=False):
    setup = HERE / (name + '_setup.lua')
    setup.write_text('SelectionFixed=' + ('true' if fixed else 'false') + '\n', encoding='utf-8')
    files = BASE + ([PERF] if performance else []) + [setup] + ([CANDIDATE] if fixed else []) + [HERE/case]
    home = HERE/'java-user-home'/name
    home.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run([str(GAME/'jre64/bin/java.exe'), '-Duser.home='+str(home), '-cp',
        str(GAME/'projectzomboid.jar')+';'+str(OLD), 'KahluaValidation', *map(str,files)],
        cwd=HERE, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=45)
    output = proc.stdout + proc.stderr
    log = HERE/(name+'_result.txt'); log.write_text(output, encoding='utf-8')
    expected_messages = {
        'dirty_anchor.lua': 'dirty rebuild must retain initial click',
        'stack_limit.lua': 'anchor row uses rendered rows',
        'repeat_refresh.lua': 'second refresh cannot capture a stale row index',
        'update_children.lua': 'virtual container must not prune valid physical selections',
        'draw_highlight.lua': 'one selected row is actually drawn',
    }
    passed = (proc.returncode != 0 and expected_messages[case] in output) if expect_failure else proc.returncode == 0
    counts = re.findall(r'cases=(\d+); assertions=(\d+)', output)
    record = dict(name=name, passed=passed, exitCode=proc.returncode, expectedFailure=expect_failure,
        cases=int(counts[-1][0]) if counts else 1, assertions=int(counts[-1][1]) if counts else 0,
        output=str(log), sourceHashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files})
    results.append(record)
    print(name, 'PASS' if passed else 'FAIL', flush=True)
    if not passed: print(output[-4500:], flush=True)

for case in ['dirty_anchor', 'stack_limit', 'repeat_refresh', 'update_children', 'draw_highlight']:
    run('baseline_'+case, case+'.lua', False, expect_failure=True)
    run('fixed_'+case, case+'.lua', True)
for case in ['clear_switch', 'ordinary', 'search_filter', 'refresh_move', 'guards']:
    run('fixed_'+case, case+'.lua', True)
run('baseline_ordinary', 'ordinary.lua', False)
run('fixed_input_flush', 'input_flush.lua', True, performance=True)
report = dict(checkedAt=datetime.now(timezone(timedelta(hours=8))).isoformat(),
    candidate=str(CANDIDATE), candidateSha256=hashlib.sha256(CANDIDATE.read_bytes()).hexdigest(),
    passed=all(r['passed'] for r in results), suites=results,
    cases=sum(r['cases'] for r in results), assertions=sum(r['assertions'] for r in results),
    runtimeHashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [GAME/'projectzomboid.jar', OLD/'KahluaValidation.class', HERE/'stdlib.lua']},
    offlineOnly=True, gameStarted=False,
    boundary='Actual CleanUI 2.10.4 Pane, Pinyin, Neat equipment and optional InventoryTransferPerformance 1.2.2 source execute in game Kahlua. Java items/containers/UI are controlled fixtures. Draw test calls the unmodified actual renderer and records its native selection drawRect. No in-game UI acceptance claim.')
(HERE/'test_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('TOTAL', report['passed'], report['cases'], report['assertions'], flush=True)
raise SystemExit(0 if report['passed'] else 1)
