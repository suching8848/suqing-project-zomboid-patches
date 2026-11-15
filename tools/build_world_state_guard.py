"""Compile the candidate Java sources in a fresh isolated directory.

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
    p.add_argument('--zombiebuddy-jar',type=Path,help='Local ZombieBuddy API JAR, defaults to the game root')
    p.add_argument('--stage',action='store_true',help='Stage a new candidate before recording its JAR in source')
    args=p.parse_args();out=args.output.resolve();game=args.game_root.resolve()
    if out.exists():raise ValueError('Output exists; choose a new isolated directory')
    forbidden=[game,REPO/'src',Path.home()/'Zomboid']
    if any(out==x or out.is_relative_to(x) for x in forbidden):raise ValueError('Installed/source output rejected')
    classes=out/'build/classes';classes.mkdir(parents=True)
    sources=sorted((REPO/'java/world_state_guard/source').rglob('*.java'))
    buddy=(args.zombiebuddy_jar or game/'ZombieBuddy.jar').resolve()
    game_jar=game/'projectzomboid.jar'
    javac=args.jdk/'javac.exe'
    subprocess.run([str(javac),'--release','17','-encoding','UTF-8','-classpath',str(buddy)+';'+str(game_jar),'-d',str(classes),*map(str,sources)],check=True)
    source_mod=REPO/'src/SuQingWorldStateGuard_4221/42'
    mod_info=source_mod/'mod.info'
    version=next(line.split('=',1)[1] for line in mod_info.read_text(encoding='utf-8').splitlines() if line.startswith('modversion='))
    jarpath=out/'mod/SuQingWorldStateGuard_4221/42/media/java/client/SuQingWorldStateGuard.jar';jarpath.parent.mkdir(parents=True)
    with zipfile.ZipFile(jarpath,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as jar:
        def entry(name,data):
            item=zipfile.ZipInfo(name,(2026,11,5,0,0,0));item.compress_type=zipfile.ZIP_DEFLATED;jar.writestr(item,data)
        entry('META-INF/MANIFEST.MF',f'Manifest-Version: 1.0\nImplementation-Version: {version}\n\n')
        for f in sorted((classes/'suqingworldstateguard').rglob('*.class')):entry(f.relative_to(classes).as_posix(),f.read_bytes())
    digest=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
    recorded=source_mod/'media/java/client/SuQingWorldStateGuard.jar'
    same=digest(jarpath)==digest(recorded)
    result={
        'result':'PASS' if same else 'STAGED' if args.stage else 'FAIL',
        'modversion':version,'jar':str(jarpath),'jar_sha256':digest(jarpath),
        'same_as_imported_runtime':same,'java_release':17,
        'javac_version':subprocess.check_output([str(javac),'-version'],text=True).strip(),
        'inputs':{str(f):digest(f) for f in (game_jar,buddy,mod_info)},
        'sources':{f.relative_to(REPO).as_posix():digest(f) for f in sources},
        'game_started':False,'deployment_performed':False,
    }
    (out/'build-manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    if result['result']=='FAIL':raise ValueError('Build differs from the recorded candidate; no source JAR was overwritten')
if __name__=='__main__':main()
