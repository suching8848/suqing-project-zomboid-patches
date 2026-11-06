"""Offline native/Neat transfer-branch regression; does not launch the game."""
from pathlib import Path
import argparse,json,re,subprocess,hashlib
REPO=Path(__file__).resolve().parents[1]
GAME=Path(r'D:\steam\steamapps\common\ProjectZomboid')
SOURCE=REPO/'src/SuQingBoatCraftFromFloor_4221'
RECIPE=Path(r'D:\steam\steamapps\workshop\content\108600\3777121241\mods\BoteBR\42\media\scripts\botebr_recipes.txt')
NEAT=Path(r'D:\steam\steamapps\workshop\content\108600\3502080466\mods\Neat_Crafting\common\media\lua\client\Neat_Crafting\NC_VanillaInputTransfer.lua')
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--audit-dir',required=True,type=Path);args=ap.parse_args();args.audit_dir.mkdir(parents=True,exist_ok=True)
    native=GAME/'media/lua/client/Entity/ISUI/CraftRecipe/ISWidgetHandCraftControl.lua'
    t=native.read_text(encoding='utf-8-sig');van=t[t.index('function ISWidgetHandCraftControl:startHandcraft(force)'):t.index('function ISWidgetHandCraftControl:onHandcraftActionStart')]
    t=NEAT.read_text(encoding='utf-8-sig');nc=t[t.index('function NC_VanillaInputTransfer.queueCurrentInputsThenReady(panel)'):t.index('-- Convert the current automatic recipe allocation')]
    patch=SOURCE/'42/media/lua/shared/SQBoatCraftFromFloor.lua'
    prefix='SOURCE_LINES={'+','.join(json.dumps(l) for l in RECIPE.read_text(encoding='utf-8-sig').splitlines())+'}\nfunction LOAD_PATCH()\n'+patch.read_text(encoding='utf-8')+'\nend\nISWidgetHandCraftControl={}\n'+van+'\nlocal ncQueuePanelWait=function() return true end\nlocal ncContainsItem=function() return false end\nlocal ncRememberReturnEntry=function() end\nlocal ncQueueTrackedTransfer=function() transfers=transfers+1;return true end\nNC_VanillaInputTransfer={}\n'+nc+'\n'
    harness=args.audit_dir/'harness.lua';harness.write_text(prefix+(REPO/'tests/boat_craft_from_floor.lua').read_text(encoding='utf-8'),encoding='utf-8')
    cp=str(GAME/'CodexAssets/InventoryTransferAdapt_20261102_234116/tests')+';'+str(GAME/'projectzomboid.jar')+';'+str(GAME/'*')
    run=subprocess.run([str(GAME/'jre64/bin/java.exe'),'-cp',cp,'KahluaValidation',str(harness)],capture_output=True,text=True);log=run.stdout+run.stderr;(args.audit_dir/'regression.log').write_text(log,encoding='utf-8');print(log);assert run.returncode==0 and 'PASS assertions=' in log
    cp=str(GAME/'CodexRepos/suqing-freshness-fridge/tools')+';'+str(GAME/'projectzomboid.jar')+';'+str(GAME/'*')
    run=subprocess.run([str(GAME/'jre64/bin/java.exe'),'-cp',cp,'ReleaseLuaCompile',str(patch)],capture_output=True,text=True);(args.audit_dir/'compile.log').write_text(run.stdout+run.stderr,encoding='utf-8');assert run.returncode==0
    locales=[json.loads((SOURCE/('42/media/lua/shared/Translate/'+lang+'/IG_UI.json')).read_text(encoding='utf-8')) for lang in ['CN','EN']];assert set(locales[0])==set(locales[1])
    result={'status':'pass','assertions':int(re.search(r'PASS assertions=(\d+)',log).group(1)),'native_branch_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'neat_source_sha256':hashlib.sha256(NEAT.read_bytes()).hexdigest(),'recipe_source_sha256':hashlib.sha256(RECIPE.read_bytes()).hexdigest(),'scope':'Actual vanilla and installed Neat input-transfer branches; mocked recipe/containers/actions; native CraftRecipe backing-list API separately decompiled','game_started':False,'save_written':False}
    (args.audit_dir/'offline_validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(result))
if __name__=='__main__':main()
