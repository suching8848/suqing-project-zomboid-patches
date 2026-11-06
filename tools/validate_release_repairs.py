"""Run imported offline suites in fresh ignored scratch; no game/UI/world startup."""
from pathlib import Path
from datetime import datetime
import argparse,json,shutil,subprocess,sys,zipfile,hashlib

REPO=Path(__file__).resolve().parents[1]
DEFAULT_GAME=Path(r'D:\steam\steamapps\common\ProjectZomboid')
DEFAULT_JDK=Path(r'E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64\bin')
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-root',type=Path,default=DEFAULT_GAME);p.add_argument('--jdk',type=Path,default=DEFAULT_JDK);p.add_argument('--only',choices=['cleanui','mustang','world']);args=p.parse_args()
    scratch=REPO/'.validation'/('release-repair-'+datetime.now().strftime('%Y%m%d_%H%M%S_%f'));scratch.mkdir(parents=True,exist_ok=False)
    game=args.game_root;jdk=args.jdk;records=[]
    def run(name,command,cwd):
        result=subprocess.run(list(map(str,command)),cwd=cwd,text=True,encoding='utf-8',errors='replace',capture_output=True,timeout=180)
        output=result.stdout+result.stderr;(scratch/(name+'.log')).write_text(output,encoding='utf-8')
        print(name,'PASS' if result.returncode==0 else 'FAIL',output[-1300:],flush=True)
        records.append({'name':name,'exit_code':result.returncode,'passed':result.returncode==0,'log':str(scratch/(name+'.log'))})
        if result.returncode:raise RuntimeError(name+' failed')
    if args.only in [None,'cleanui']:
        root=scratch/'cleanui';shutil.copytree(REPO/'tests/cleanui',root)
        for suite in ['performance','selection']:
            shutil.copy2(game/'stdlib.lua',root/suite/'stdlib.lua')
        for name in ['performance','selection']:
            script=root/name/'run_tests.py';s=script.read_text(encoding='utf-8-sig')
            s=s.replace("HERE.parent.parent / 'candidate/InventoryTransferPerformance_4221_Local/42/media/lua/client/Codex_InventoryTransferPerformance.lua'",repr(str(REPO/'src/InventoryTransferPerformance_4221_Local/42/media/lua/client/Codex_InventoryTransferPerformance.lua')))
            s=s.replace("HERE.parent.parent / 'candidate/SuQingUIInteractionFixes/42/media/lua/client/SuQing_ProximitySelectionFix.lua'",repr(str(REPO/'src/SuQingUIInteractionFixes/42/media/lua/client/SuQing_ProximitySelectionFix.lua')))
            # Replaced literals must remain Paths because suites hash and read them.
            s=s.replace("PERF = "+repr(str(REPO/'src/InventoryTransferPerformance_4221_Local/42/media/lua/client/Codex_InventoryTransferPerformance.lua')),"PERF = Path("+repr(str(REPO/'src/InventoryTransferPerformance_4221_Local/42/media/lua/client/Codex_InventoryTransferPerformance.lua'))+")")
            s=s.replace("CANDIDATE = "+repr(str(REPO/'src/SuQingUIInteractionFixes/42/media/lua/client/SuQing_ProximitySelectionFix.lua')),"CANDIDATE = Path("+repr(str(REPO/'src/SuQingUIInteractionFixes/42/media/lua/client/SuQing_ProximitySelectionFix.lua'))+")")
            script.write_text(s,encoding='utf-8')
        run('compile_kahlua',[jdk/'javac.exe','--release','17','-d',root/'performance',root/'performance/KahluaValidation.java'],root)
        run('inventory_refresh',[sys.executable,root/'performance/run_tests.py','--candidate',REPO/'src/InventoryTransferPerformance_4221_Local/42/media/lua/client/Codex_InventoryTransferPerformance.lua'],root)
        run('proximity_selection',[sys.executable,root/'selection/run_tests.py'],root)
        # Retain original version acceptance/rejection fixtures against imported source.
        for version in ['2_10_3','2_10_4','2_10_5']:
            files=[root/'selection/ui_prelude.lua',root/'selection/native_prepare.lua',root/'selection'/('version_'+version+'_setup.lua'),REPO/'src/SuQingUIInteractionFixes/42/media/lua/client/SuQing_ProximitySelectionFix.lua',root/'selection'/('version_'+version+'_assert.lua')]
            run('selection_'+version,[game/'jre64/bin/java.exe','-Duser.home='+str(scratch/'java-home'),'-cp',str(game/'projectzomboid.jar')+';'+str(root/'performance'),'KahluaValidation',*files],root/'selection')
    if args.only in [None,'mustang']:
        root=scratch/'mustang';shutil.copytree(REPO/'tests/mustang_protection_repair',root)
        shutil.copy2(game/'stdlib.lua',root/'stdlib.lua')
        run('compile_mustang',[jdk/'javac.exe','--release','17','-cp',game/'projectzomboid.jar','-d',root,root/'CheckMustangRepair.java'],root)
        patch=REPO/'src/SuQingMustangProtectionRepair/42/media/lua/client/SuQingMustangProtectionRepair.lua'
        workshop=game.parents[1]/'workshop/content/108600'
        definitions=[workshop/'3405178154/mods/ATA_Mustang/common/media/lua/shared/ATAMustang_Tuning2.lua',workshop/'3405239070/mods/AA2_Nikke_Mustang/42.14/media/lua/shared/AA2_ATAMustang_Tuning2.lua']
        base=[game/'jre64/bin/java.exe','-Duser.home='+str(scratch/'java-home'),'-cp',str(game/'projectzomboid.jar')+';'+str(root),'CheckMustangRepair']
        run('mustang_nine_cases',base+[root/'fixture.lua',*definitions,patch,root/'cases.lua'],root)
        run('mustang_native_timing',base+[root/'fixture.lua',root/'native_action_setup.lua',game/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',*definitions,patch,root/'native_action_regression.lua'],root)
        upstream=game.parents[1]/'workshop/content/108600/3402491515/mods/tsarslib/42.17/media/lua/client/Tuning2/ISVehicleTuning2.lua'
        run('mustang_actual_tuning',base+[root/'fixture.lua',*definitions,root/'tuning_setup.lua',upstream,root/'tuning_widgets.lua',patch,root/'tuning_regression.lua'],root)
    if args.only in [None,'world']:
        root=scratch/'world';root.mkdir()
        candidate=root/'candidate'
        run('world_reproducible_build',[sys.executable,REPO/'tools/build_world_state_guard.py','--game-root',game,'--jdk',jdk,'--output',candidate],root)
        shutil.copytree(REPO/'tests/world_state_guard/candidate_tests',candidate/'tests')
        animal=root/'animal_analysis';animal.mkdir();shutil.copy2(REPO/'tests/world_state_guard/build_hole_fixture.py',animal/'build_hole_fixture.py')
        # Read local jar methods only into ignored scratch, never commit full game classes.
        with zipfile.ZipFile(game/'projectzomboid.jar') as jar:
            for name in ['zombie/characters/IsoGameCharacter.class','zombie/characterTextures/BloodClothingType.class']:
                dest=animal/'vanilla-classes'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(jar.read(name))
        run('animal_actual_method_fixtures',[sys.executable,animal/'build_hole_fixture.py'],animal)
        run('world_advice_integration',[sys.executable,candidate/'tests/run_advice_audit.py'],candidate)
        vehicle=root/'vehicle';vehicle.mkdir();shutil.copy2(REPO/'tests/world_state_guard/build_vehicle_regression.py',vehicle/'build_regression.py');(vehicle/'tests').mkdir()
        for name in ['PatchVehicleChunk.java','VehicleChunkGuard.java']:
            target=vehicle/'source/suqingworldstateguard'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(REPO/'java/world_state_guard/source/suqingworldstateguard'/name,target)
        run('vehicle_107_assertions',[sys.executable,vehicle/'build_regression.py'],vehicle)
    report={'result':'PASS','suites':records,'scratch':str(scratch),'game_started':False,'deployment_performed':False,'acceptance':'Controlled fixtures only; gameplay/UI/FPS remain user acceptance'}
    (scratch/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
