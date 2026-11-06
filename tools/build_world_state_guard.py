"""Compile the unchanged candidate Java sources in a fresh isolated directory.

Requires local game/ZombieBuddy APIs and JDK 17+. Never deploys or launches game.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,zipfile

REPO=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game-root',type=Path,required=True)
    p.add_argument('--jdk',type=Path,required=True,help='JDK bin directory')
    p.add_argument('--output',type=Path,required=True,help='New .validation or external output')
    args=p.parse_args();out=args.output.resolve();game=args.game_root.resolve()
    if out.exists():raise ValueError('Output exists; choose a new isolated directory')
    forbidden=[game,REPO/'src',Path.home()/'Zomboid']
    if any(out==x or out.is_relative_to(x) for x in forbidden):raise ValueError('Installed/source output rejected')
    classes=out/'build/classes';classes.mkdir(parents=True)
    sources=sorted((REPO/'java/world_state_guard/source').rglob('*.java'))
    subprocess.run([str(args.jdk/'javac.exe'),'--release','17','-encoding','UTF-8','-classpath',str(game/'ZombieBuddy.jar')+';'+str(game/'projectzomboid.jar'),'-d',str(classes),*map(str,sources)],check=True)
    jarpath=out/'mod/SuQingWorldStateGuard_4221/42/media/java/client/SuQingWorldStateGuard.jar';jarpath.parent.mkdir(parents=True)
    with zipfile.ZipFile(jarpath,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as jar:
        def entry(name,data):
            item=zipfile.ZipInfo(name,(2026,11,5,0,0,0));item.compress_type=zipfile.ZIP_DEFLATED;jar.writestr(item,data)
        entry('META-INF/MANIFEST.MF','Manifest-Version: 1.0\nImplementation-Version: 0.1.0-candidate\n\n')
        for f in sorted((classes/'suqingworldstateguard').rglob('*.class')):entry(f.relative_to(classes).as_posix(),f.read_bytes())
    digest=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
    recorded=REPO/'src/SuQingWorldStateGuard_4221/42/media/java/client/SuQingWorldStateGuard.jar'
    result={'result':'PASS' if digest(jarpath)==digest(recorded) else 'FAIL','jar':str(jarpath),'jar_sha256':digest(jarpath),'same_as_imported_runtime':digest(jarpath)==digest(recorded),'java_release':17,'sources':{f.relative_to(REPO).as_posix():digest(f) for f in sources},'game_started':False,'deployment_performed':False}
    (out/'build-manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    if result['result']!='PASS':raise ValueError('Build differs from imported candidate; no source JAR was overwritten')
if __name__=='__main__':main()
