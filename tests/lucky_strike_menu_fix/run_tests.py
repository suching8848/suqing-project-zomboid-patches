"""Stock Kahlua and complete CleanUI Lua, with controlled Java/UI boundaries.

No game, world, UI or save is initialized. Existing compiled Kahlua runner only.
"""
from pathlib import Path
from datetime import datetime,timezone,timedelta
import argparse,subprocess,hashlib,json,re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
GAME=Path(r'D:\steam\steamapps\common\ProjectZomboid')
CLEAN_ROOT=Path(r'D:\steam\steamapps\workshop\content\108600\3437629766\mods\CleanUI')
RUNNER=GAME/'CodexAssets/CleanUICompat_20261105_232936/tests/performance'
parser=argparse.ArgumentParser()
parser.add_argument('--candidate',type=Path,default=ROOT/'src/SuQingLuckyStrikeMenuFix_4221/42/media/lua/client/SuQing_LuckyStrikeMenuFix.lua')
parser.add_argument('--probe',action='store_true')
parser.add_argument('--game-version',choices=('42.21.0','42.22.2'),default='42.21.0')
parser.add_argument('--game-jar',type=Path,default=GAME/'projectzomboid.jar')
parser.add_argument('--output',type=Path,default=HERE/'results')
args=parser.parse_args()
CLEAN=CLEAN_ROOT/({'42.21.0':'42.19','42.22.2':'42.22'}[args.game_version])
OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
assert (RUNNER/'KahluaValidation.class').is_file()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def setup(name,text):
 p=OUT/(name+'.lua');p.write_text(text+'\n',encoding='utf-8');return p
clean_version=re.search(r'^modversion=(.+)$',(CLEAN/'mod.info').read_text('utf-8-sig'),re.M).group(1).strip()
config=setup('config','LuckyTest.modVersion='+json.dumps(clean_version)+'\n'+'LuckyTest.cleanDir='+json.dumps(CLEAN.as_posix())+'\nLuckyTest.gameVersion='+json.dumps(args.game_version))
base=[HERE/'prelude.lua',config,CLEAN/'media/lua/client/ISUI/ISInventoryPane.lua',CLEAN/'media/lua/client/ISUI/ISInventoryPaneContextMenu.lua',HERE/'boundaries.lua']
def run(name,files):
 home=OUT/'java-user-home'/name;home.mkdir(parents=True,exist_ok=True)
 cmd=[str(GAME/'jre64/bin/java.exe'),'-Dfile.encoding=UTF-8','-Dstdout.encoding=UTF-8','-Dstderr.encoding=UTF-8','-Duser.home='+str(home),'-cp',str(args.game_jar)+';'+str(RUNNER),'KahluaValidation',*map(str,files)]
 # Kahlua's unchanged runner resolves its stdlib.lua from cwd. Read the
 # already-existing historical harness; all new output remains under OUT.
 p=subprocess.run(cmd,cwd=RUNNER,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=45)
 out=p.stdout+p.stderr;(OUT/(name+'.txt')).write_text(out,encoding='utf-8')
 matches=re.findall(r'cases=(\d+); assertions=(\d+)',out)
 print(name,'PASS' if p.returncode==0 else 'FAIL',flush=True)
 if p.returncode:print(out[-6500:],flush=True)
 return {'name':name,'passed':p.returncode==0,'cases':int(matches[-1][0]) if matches else 0,'assertions':int(matches[-1][1]) if matches else 0,'output':str(OUT/(name+'.txt')),'sourceHashes':{str(x):sha(x) for x in files}}
if args.probe:
 probe=setup('probe','local T=LuckyTest; local a=T.item("Food"); T.call({T.group({a})}); print("probe complete")')
 result=run('probe',base+[probe]);raise SystemExit(0 if result['passed'] else 1)
assert args.candidate.is_file(),args.candidate
suites=[]
suites.append(run('regression',base+[HERE/'before_patch.lua',args.candidate,args.candidate,HERE/'after_patch.lua']))
suites.append(run('wrapper_contract',base+[HERE/'contract_prepare.lua',args.candidate,HERE/'contract_assertions.lua']))
for flag in ['future_version','game_mismatch','source_mismatch','line_mismatch','branch_mismatch','metadata_missing']:
 mutation={'future_version':'LuckyTest.modVersion="2.10.6"','game_mismatch':'LuckyTest.gameVersion="42.22.0"','source_mismatch':'LuckyTest.sourceMismatch=true','line_mismatch':'LuckyTest.lineMismatch=true','branch_mismatch':'LuckyTest.cleanDir="fixture/CleanUI/42.20"','metadata_missing':'LuckyTest.missingMetadata=true'}[flag]
 path=setup(flag,mutation)
 suites.append(run(flag,base+[path,args.candidate,HERE/'guard_assertions.lua']))
modroot=args.candidate.parents[4]
resource_assertions=0
def resource_check(ok,message):
 global resource_assertions
 resource_assertions+=1
 assert ok,message
resource_check((modroot/'mod.info').read_bytes()==(modroot/'42/mod.info').read_bytes(),'root and 42 mod.info differ')
info=(modroot/'42/mod.info').read_text('utf-8')
resource_check('require=CleanUI,MREfood4213' in info,'required mods changed')
resource_check('GardeniaTranslate_CN' in info,'translation load relation missing')
def unique_pairs(pairs):
 d={}
 for key,value in pairs:
  assert key not in d,'duplicate translation key '+key
  d[key]=value
 return d
cn_path=modroot/'42/media/lua/shared/Translate/CN/ItemName.json'
cn=json.loads(cn_path.read_text('utf-8'),object_pairs_hook=unique_pairs)
resource_check(set(cn)=={'MR.lucky_strike','MR.lucky_strike_Pack'},'CN scope is not exactly two Lucky Strike keys')
resource_check(cn['MR.lucky_strike']=='好彩香烟','single-cigarette name changed')
resource_check(cn['MR.lucky_strike_Pack']!='好彩香烟' and '盒装' in cn['MR.lucky_strike_Pack'],'pack remains indistinguishable')
resource_check(not(modroot/'42/media/lua/shared/Translate/EN/ItemName.json').exists(),'upstream English item names must be left untouched')
suites.append({'name':'resource_contract','passed':True,'cases':1,'assertions':resource_assertions,'sourceHashes':{str(p):sha(p) for p in [modroot/'mod.info',modroot/'42/mod.info',cn_path]}})
report={'game_build':args.game_version,'cleanui_branch':CLEAN.name,'game_jar_sha256':sha(args.game_jar),'checked_at_bjt':datetime.now(timezone(timedelta(hours=8))).isoformat(),'passed':all(x['passed'] for x in suites),'cases':sum(x['cases'] for x in suites),'assertions':sum(x['assertions'] for x in suites),'candidate':str(args.candidate),'candidate_sha256':sha(args.candidate),'suites':suites,'offline_only':True,'game_started':False,'boundary':'Complete current CleanUI ISInventoryPane.lua and ISInventoryPaneContextMenu.lua execute unmodified in existing standalone actual-game Kahlua. Java InventoryItem/Food/Drainable, player/container objects, UI builders and closure metadata globals are controlled fixtures. Tests execute actual createMenu classification/Food branch/getActualItems; unrelated menu helpers are bounded. No gameplay, actual Java item creation, native UI, save reload or FPS acceptance is claimed.'}
(OUT/'test_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('TOTAL',report['passed'],report['cases'],report['assertions'],flush=True)
raise SystemExit(0 if report['passed'] else 1)
