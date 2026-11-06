"""Isolated Kahlua regressions. Writes only beside this file, never game/user data."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import argparse, subprocess, re, json, hashlib

HERE = Path(__file__).resolve().parent
GAME = Path(r'D:\steam\steamapps\common\ProjectZomboid')
CLEAN = Path(r'D:\steam\steamapps\workshop\content\108600\3437629766\mods\CleanUI\42.19\media\lua\client\ISUI')
NEAT = Path(r'D:\steam\steamapps\workshop\content\108600\3790656296\mods\NeatUI_Equipment\42.20\media\lua\client\NeatEquipment')
PINYIN = Path(r'C:\Users\15792\Zomboid\mods\Pinyin_UI_4221_LocalCompat\42\media\lua\client\PinyinSafeCompat.lua')
parser = argparse.ArgumentParser()
parser.add_argument('--candidate',type=Path,required=True)
parser.add_argument('--old-candidate',type=Path)
parser.add_argument('--only',help='Rerun one suite; merge unchanged-candidate prior evidence for the others')
args=parser.parse_args()
results=[]

def setup(name,text):
    path=HERE/(name+'_setup.lua')
    path.write_text(text+'\n',encoding='utf-8')
    return path

def run(name,files):
    if args.only and name!=args.only:
        return True
    home=HERE/'java-user-home'/name
    home.mkdir(parents=True,exist_ok=True)
    command=[str(GAME/'jre64/bin/java.exe'),'-Duser.home='+str(home),'-cp',str(GAME/'projectzomboid.jar')+';'+str(HERE),'KahluaValidation']+list(map(str,files))
    proc=subprocess.run(command,cwd=HERE,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=45)
    output=proc.stdout+proc.stderr
    (HERE/(name+'_result.txt')).write_text(output,encoding='utf-8')
    matches=re.findall(r'cases=(\d+); assertions=(\d+)',output)
    count=re.findall(r'assertions=(\d+)',output)
    record={'name':name,'passed':proc.returncode==0,'cases':int(matches[-1][0]) if matches else 1,'assertions':int(matches[-1][1]) if matches else int(count[-1]) if count else 0,'output':str(HERE/(name+'_result.txt')),'sourceHashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
    results.append(record)
    print(name, 'PASS' if record['passed'] else 'FAIL', 'cases',record['cases'],'assertions',record['assertions'],flush=True)
    if proc.returncode: print(output[-7000:],flush=True)
    return record['passed']

base=[HERE/'ui_prelude.lua']
adapter=base+[HERE/'adapter_fixture.lua']
native=base+[HERE/'native_prepare.lua',CLEAN/'ISInventoryPane.lua',NEAT/'NEQ_State.lua',NEAT/'ModCompatibility/NEQ_InventoryTetris.lua',HERE/'native_fixtures.lua',PINYIN,NEAT/'Patches/NEQ_HideEquipped.lua']
if args.old_candidate:
    guard=setup('old_2103_repro','PerfTest.guardExpected=false; PerfTest.beforeRefresh=ISInventoryPane.refreshContainer; PerfTest.beforeRender=ISInventoryPane.renderdetails; PerfTest.beforePageRefresh=ISInventoryPage.refreshBackpacks')
    run('old_2103_repro',native+[guard,args.old_candidate,HERE/'old_native_rejection_assertions.lua'])
if not run('native_2104',native+[args.candidate,HERE/'native_assertions.lua']):
    # Keep running independent suites to expose separate contract problems.
    pass
run('legacy_299',base+[args.candidate,HERE/'ui_assertions.lua'])
run('modeled_lifecycle',base+[HERE/'ui_chain_prelude.lua',args.candidate,HERE/'ui_chain_assertions.lua'])
for version in ['2.10.1','2.10.2','2.10.3','2.10.4']:
    config=setup('adapter_'+version.replace('.','_'),'PerfTest.modVersions.CleanUI='+json.dumps(version))
    run('adapter_'+version.replace('.','_'),adapter+[config,args.candidate,HERE/'ui_assertions.lua',HERE/'adapter_assertions.lua'])
for flag in ['barrierError','skipBarrierRefresh','doubleBarrierRefresh']:
    config=setup('failure_'+flag,'PerfTest.failureFlag='+json.dumps(flag))
    run('failure_'+flag,adapter+[config,args.candidate,HERE/'adapter_failure_assertions.lua'])
guards={
 'known_2103':(True,'PerfTest.modVersions.CleanUI="2.10.3"'),
 'known_2104':(True,'PerfTest.modVersions.CleanUI="2.10.4"'),
 'future_2105':(False,'PerfTest.modVersions.CleanUI="2.10.5"'),
 'future_300':(False,'PerfTest.modVersions.CleanUI="3.0.0"'),
 'unreviewed_2100':(False,'PerfTest.modVersions.CleanUI="2.10.0"'),
 'future_neat':(False,'PerfTest.activeMods={"NeatUI_Equipment"}; PerfTest.modVersions.NeatUI_Equipment="1.0.3"'),
 'known_neat':(True,'PerfTest.activeMods={"NeatUI_Equipment"}; PerfTest.modVersions.NeatUI_Equipment="1.0.2"'),
 'missing_metadata':(False,'PerfTest.missingMetadata=true'),
 'missing_search':(False,'ISInventoryPane.searchContainer=nil'),
 'missing_refresh':(False,'ISInventoryPane.refreshContainer=nil'),
 'private_equipment':(False,'PerfTest.activeMods={"EQUIPMENT_UI"}'),
}
for name,(expected,mutation) in guards.items():
    config=setup('guard_'+name,mutation+'\nPerfTest.guardExpected='+str(expected).lower()+'\nPerfTest.beforeRefresh=ISInventoryPane.refreshContainer; PerfTest.beforeRender=ISInventoryPane.renderdetails')
    files=adapter+[config,args.candidate,HERE/'ui_guard_assertions.lua']
    if name in ('known_2103','known_2104'):files.append(HERE/'priority_assertion.lua')
    run('guard_'+name,files)
page_config=setup('page_2104','PerfTest.modVersions.CleanUI="2.10.4"')
run('page_baseline_notification_control',base+[HERE/'native_prepare.lua',HERE/'page_prepare.lua',CLEAN/'ISInventoryPage.lua',HERE/'page_boundaries.lua',HERE/'adapter_fixture.lua',page_config,HERE/'page_baseline_assertions.lua'])
run('page_bottom_2104',base+[HERE/'native_prepare.lua',HERE/'page_prepare.lua',CLEAN/'ISInventoryPage.lua',HERE/'page_boundaries.lua',HERE/'adapter_fixture.lua',page_config,args.candidate,HERE/'page_bottom_assertions.lua'])
candidate_hash=hashlib.sha256(args.candidate.read_bytes()).hexdigest()
if args.only and (HERE/'test_report.json').exists():
    previous=json.loads((HERE/'test_report.json').read_text('utf-8'))
    assert previous['candidateSha256']==candidate_hash, 'Cannot reuse prior suites after candidate changes'
    replaced={r['name'] for r in results}
    results=[r for r in previous['suites'] if r['name'] not in replaced]+results
report={'checkedAt':datetime.now(timezone(timedelta(hours=8))).isoformat(),'candidate':str(args.candidate),'candidateSha256':candidate_hash,'passed':all(r['passed'] for r in results),'cases':sum(r['cases'] for r in results),'assertions':sum(r['assertions'] for r in results),'suites':results,'offlineOnly':True,'gameStarted':False,'javaUserHomeRoot':str(HERE/'java-user-home'),'boundary':'Actual CleanUI Pane, Pinyin and Neat State/Tetris/HideEquipped Lua sources execute in isolated actual game Kahlua. Native Java UI drawing, containers, item objects, page refresh, scrollbar/highlight and input dispatch are controlled fixtures. Page suite loads the complete actual CleanUI Page source; calls unmodified Bottom capture/collapse/restore/content visibility geometry, while page refresh and prerender outer UI boundaries are controlled. No measured gameplay FPS or actual mouse/UI acceptance.'}
(HERE/'test_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('TOTAL',report['passed'],report['cases'],report['assertions'],flush=True)
raise SystemExit(0 if report['passed'] else 1)
