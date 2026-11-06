"""Freeze the explicitly selected local patch candidate in a new directory.

Reads byte-pinned local inputs only; no Steam calls, deployment or Git writes.
"""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess,sys

REPO=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--workshop-root',type=Path,required=True);p.add_argument('--game-root',type=Path,required=True);args=p.parse_args()
    root=args.output.resolve()
    if root.exists():raise ValueError('Candidate output already exists; use a new directory')
    forbidden=[REPO/'src',REPO/'publishing',args.game_root.resolve(),args.workshop_root.resolve(),Path.home()/'Zomboid']
    if any(root==f or root.is_relative_to(f) for f in forbidden):raise ValueError('Source/installed output rejected')
    candidate=json.loads((REPO/'publishing/candidate-20261106.json').read_text(encoding='utf-8'))
    catalog=json.loads((REPO/'catalog.json').read_text(encoding='utf-8'))
    items={m['id']:m for m in catalog['mods']};ids=candidate['mod_ids'];assert len(ids)==32 and len(set(ids))==32
    description=(REPO/'publishing/description.bbcode.txt').read_text(encoding='utf-8-sig').replace('\r\n','\n').strip()
    title=(REPO/'publishing/title.txt').read_text(encoding='utf-8-sig').strip()
    assert len(description.encode())<8000 and len(title.encode())<128
    preview=REPO/'publishing/preview.png';assert preview.stat().st_size<1000000
    root.mkdir(parents=True);(root/'Contents').mkdir()
    command=[sys.executable,str(REPO/'tools/rebuild.py'),'--output',str(root/'Contents/mods'),'--workshop-root',str(args.workshop_root),'--game-root',str(args.game_root)]
    for mid in ids:command+=['--mod-id',mid]
    proc=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',check=True)
    reconstruction=json.loads(proc.stdout)
    for mid in ids:
        m=items[mid];dest=root/'Contents/mods'/m['folder'];source=REPO/'src'/m['folder']
        # Ship the source-authored removal instructions, including book restoration.
        readme=source/'README.txt'
        if readme.exists():shutil.copy2(readme,dest/'README.txt')
        doc=REPO/m['doc'];body=doc.read_text(encoding='utf-8-sig')
        def url(match):
            label,path=match.groups()
            if '://' in path or path.startswith('#'):return match[0]
            rel=(doc.parent/path).resolve()
            if rel.is_relative_to(REPO):return f'[{label}](https://github.com/suching8848/suqing-project-zomboid-patches/blob/main/{rel.relative_to(REPO).as_posix()})'
            return label
        body=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',url,body)
        (dest/'README.md').write_text(body,encoding='utf-8')
    shutil.copy2(preview,root/'preview.png')
    for name in ['description.bbcode.txt','description.CN.bbcode.txt','description.EN.bbcode.txt','title.txt','changenote.txt','candidate-20261106.json']:shutil.copy2(REPO/'publishing'/name,root/name)
    fields=['version=1','id='+str(candidate['publishedfileid']),'title='+title]
    fields+=['description='+line for line in description.splitlines()]
    fields+=['tags=Build 42;Interface;QoL;Balance;Translation','visibility=public']
    (root/'workshop.txt').write_text('\n'.join(fields)+'\n',encoding='utf-8')
    manifest={f.relative_to(root).as_posix():{'bytes':f.stat().st_size,'sha256':sha(f)} for f in sorted(root.rglob('*')) if f.is_file()}
    # Read back every frozen byte and bind the explicit candidate selection.
    for rel,rec in manifest.items():assert sha(root/rel)==rec['sha256']
    actual=[]
    for modinfo in (root/'Contents/mods').glob('*/42/mod.info'):
        raw=modinfo.read_text(encoding='utf-8-sig');actual.append(re.search(r'^id=(.*)$',raw,re.M)[1].strip())
    assert set(actual)==set(ids) and len(actual)==32
    report={**candidate,'root':str(root),'native_workshop_file':str(root/'workshop.txt'),'contents':str(root/'Contents'),'frozen_files':len(manifest),'description_lf_field_utf8_bytes':len(description.encode()),'preview_bytes':(root/'preview.png').stat().st_size,'native_mod_ids_verified':True,'reconstruction':reconstruction,'publication_performed':False,'personal_environment_changed':False}
    (root/'content-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (root/'release.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
