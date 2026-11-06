"""Read local mod metadata and an explicit Steam snapshot; write only the two public indexes.

Supply a machine-local route map and a preserved historical index. This tool does
not initialize repositories, change mods, contact Steam, or publish anything.
Absolute machine paths stay in the input route map, outside the public indexes.
"""
from pathlib import Path
from datetime import datetime, timezone, timedelta
from collections import Counter
import argparse
import hashlib
import json
import re
import subprocess
from urllib.parse import urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = (ROOT/'docs/project-index.json', ROOT/'docs/project-index.md')

def need(condition, message):
    if not condition:
        raise ValueError(message)

def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def info(path):
    return dict(line.split('=',1) for line in path.read_text(encoding='utf-8-sig').splitlines() if '=' in line)

def effective_info(root, mod_id, preferred=None):
    root=Path(root).resolve()
    paths=[root/preferred] if preferred else [root/'42.21/mod.info', root/'42/mod.info', root/'mod.info']
    for path in paths:
        if path.is_file():
            fields=info(path)
            if fields.get('id')==mod_id:
                return path, fields
    raise ValueError('No applicable metadata entry for '+mod_id+' in '+str(root))

def tokens(raw):
    return [x.strip().lstrip('\\') for x in raw.split(',') if x.strip().lstrip('\\')]

def git_value(repo, args):
    # Read-only commands, with no credential helper, fetch, stage, commit or push.
    proc=subprocess.run(['git','-C',str(repo),*args],capture_output=True,text=True,encoding='utf-8',errors='replace')
    return proc.stdout.strip() if proc.returncode==0 else None

def remote_url(repo):
    value=git_value(repo,['remote','get-url','origin'])
    if not value:
        return None
    if value.startswith('git@github.com:'):
        value='https://github.com/'+value.split(':',1)[1]
    if value.startswith(('http://','https://')):
        parsed=urlsplit(value)
        value=urlunsplit((parsed.scheme,parsed.hostname or '',parsed.path,'',''))
    return value[:-4] if value.endswith('.git') else value

def repository(repo, title_zh, title_en, mod_count):
    repo=Path(repo).resolve()
    need(repo.is_dir(), 'Missing source repository '+str(repo))
    remote=remote_url(repo)
    slug=remote.rstrip('/').rsplit('/',1)[-1] if remote else repo.name
    head=git_value(repo,['rev-parse','--verify','HEAD']) if (repo/'.git').exists() else None
    return {'slug':slug,'local_directory_name':repo.name,'repository':remote,
            'title_zh':title_zh,'title_en':title_en,'mod_count':mod_count,
            'git_initialized':(repo/'.git').exists(),'git_head':head if repo!=ROOT else None,
            'git_head_policy':'Observed at generation time; owner-index commit is recorded in external publication receipts to avoid self-reference' if repo==ROOT else 'Observed at generation time',
            'git_state':'has_commit' if head else 'initialized_without_commit' if (repo/'.git').exists() else 'not_initialized',
            'remote_state':'configured' if remote else 'local_only_remote_not_created'}

def personal_entry(personal_root, mod_id, preferred_folder=None):
    candidates=[]
    # Scan every personal folder, including when the expected folder exists, so
    # a duplicate same-ID installation cannot be hidden by the routing hint.
    for folder in sorted(personal_root.iterdir()):
        if folder.is_dir():
            try:candidates.append(effective_info(folder,mod_id))
            except ValueError:pass
    need(len(candidates)<=1, 'Multiple personal sources for '+mod_id)
    if not candidates:
        return {'version':None,'mod_info':None,'installed':False}
    path, fields=candidates[0]
    return {'version':fields.get('modversion'),'mod_info':path.relative_to(personal_root).as_posix(),
            'installed':True,'mod_info_sha256':digest(path)}

def common(mod_id, title_zh, title_en, repo, source_info, fields, personal):
    need(fields.get('id')==mod_id,'Source identity mismatch '+mod_id)
    need(fields.get('modversion'), 'No source modversion for '+mod_id)
    return {'mod_id':mod_id,'title_zh':title_zh,'title_en':title_en,
            'repository':repo['repository'],'repository_slug':repo['slug'],
            'source_version':fields['modversion'],'source_mod_name':fields.get('name'),
            'personal_runtime_version':personal['version'],'personal_installed':personal['installed'],
            'personal_mod_info_relative_to_mods':personal['mod_info'],
            'mod_info':source_info,'source_mod_info_sha256':None,
            'require_raw':fields.get('require',''),'required_mods':tokens(fields.get('require','')),
            'load_after_raw':fields.get('loadModAfter',''),'load_after_mods':tokens(fields.get('loadModAfter','')),
            'gameplay_validation':'Metadata/source/publication indexing only. See project documentation for limited user acceptance and remaining gameplay tests.'}

OWNER='76561198881912882'
APP=108600
COLLECTION_IDS={'3823981387'}

def snapshot_items(snapshot):
    need(snapshot.get('enumeration_stable') is True and not snapshot.get('errors'), 'Steam snapshot is incomplete or unstable')
    need(snapshot.get('mutations_allowed') is False, 'Snapshot must explicitly be read-only')
    for field in ['items','owned','owned_at_end']:
        values=snapshot.get(field)
        need(isinstance(values,list) and values, 'Missing complete '+field+' enumeration')
        ids=[str(x['id']) for x in values]
        need(len(ids)==len(set(ids)), 'Duplicate Workshop ID in '+field)
    items={str(x['id']):x for x in snapshot['items']}
    owned={str(x['id']) for x in snapshot['owned']}
    ended={str(x['id']) for x in snapshot['owned_at_end']}
    need(owned==ended==set(items), 'Start/end/detail owner enumerations differ')
    for item in items.values():
        need(str(item.get('owner'))==OWNER and item.get('consumer_app')==APP, 'Workshop owner/app mismatch')
        need(not item.get('cached'), 'Cached Workshop detail cannot establish final state')
        need(type(item.get('visibility')) is int and item['visibility'] in (0,1,2,3), 'Unknown Workshop visibility')
    return items

def metadata(item):
    if not item or not item.get('metadata'):
        return {}
    value=json.loads(item['metadata'])
    need(isinstance(value,dict), 'Invalid native Workshop metadata')
    return value

def native_evidence(directory, items):
    records=[]
    if directory:
        need(directory.is_dir(), 'Native receipt directory is missing')
        for path in sorted(directory.rglob('*.json')):
            need(not path.is_symlink(), 'Linked native receipt rejected')
            value=read_json(path)
            # A dedicated receipt directory contains only actual publisher stages.
            need(value.get('stage') in ['read','preflight','create','upload','dependencies','verify'], 'Unknown receipt stage')
            need(str(value.get('owner'))==OWNER and value.get('app')==APP, 'Native receipt owner/app mismatch')
            records.append((path,value))
    records.sort(key=lambda pair:pair[1].get('finished_at',pair[1].get('started_at','')))
    evidence={}
    for item_id,item in items.items():
        relevant=[(p,r) for p,r in records if str(r.get('item'))==item_id]
        uploads=[(p,r) for p,r in relevant if r.get('stage')=='upload']
        latest=uploads[-1][1] if uploads else {}
        row={'verified':False,'upload_succeeded':False,'latest_upload_status':latest.get('status'),
             'latest_callback_result':latest.get('callback',{}).get('result'),'mod_versions':{},'receipts':[]}
        for path,record in uploads:
            if record.get('status')=='uploaded' and record.get('callback',{}).get('result')==1:
                if metadata(item)==json.loads(record.get('inputs',{}).get('metadata','{}')):
                    row['upload_succeeded']=True
                    row['mod_versions']=record['inputs'].get('mod_versions',{})
                    row['receipt_version']=metadata(item).get('version')
        for path,record in relevant:
            if record.get('stage')!='verify' or record.get('status') not in ['verified_public','verified_preserved_visibility']:
                continue
            checks=record.get('checks',{})
            need(checks and all(value is True for value in checks.values()), 'Native verification lacks all passing checks')
            matching=[(p,r) for p,r in uploads if r.get('status')=='uploaded' and r.get('callback',{}).get('result')==1 and r.get('inputs')==record.get('inputs')]
            need(matching, 'Verify receipt has no successful matching native submit')
            inputs=record['inputs'];observed=record.get('remote_before',{})
            need(str(observed.get('id'))==item_id and str(observed.get('owner'))==OWNER and observed.get('consumer_app')==APP, 'Verify target mismatch')
            need(observed.get('visibility')==item['visibility'], 'Final visibility differs from verification')
            need((record['status']=='verified_public')==(item['visibility']==0), 'Private receipt must never be labelled public')
            need(metadata(item)==json.loads(inputs['metadata'])==metadata(observed), 'Final metadata differs from verified frozen inputs')
            need(metadata(item).get('content_tree_sha256')==inputs.get('content_tree_sha256'), 'Verified tree identity mismatch')
            need(record.get('item')==matching[-1][1].get('item') and matching[-1][1].get('submitted_visibility')==item['visibility'], 'Submit/verify visibility mismatch')
            row.update(verified=True,upload_succeeded=True,mod_versions=inputs.get('mod_versions',{}),receipt_version=metadata(item).get('version'),
                       content_tree_sha256=inputs.get('content_tree_sha256'),visibility=item['visibility'],
                       verification_boundary=record.get('verification_boundary','Native verification, not remote per-file download or gameplay acceptance'))
            row['receipts']=[{'stage':'upload','filename':matching[-1][0].name,'sha256':digest(matching[-1][0])},
                             {'stage':'verify','filename':path.name,'sha256':digest(path)}]
        evidence[item_id]=row
    return records,evidence

def item_identity(mod_id, original, records):
    options={str(original)} if original else set()
    for _,record in records:
        if mod_id in record.get('inputs',{}).get('mod_versions',{}) and record.get('item'):
            options.add(str(record['item']))
    need(len(options)<=1, 'Conflicting Workshop IDs for '+mod_id)
    return next(iter(options)) if options else None

def current_state(row, item, evidence, version, version_basis):
    visibility=item.get('visibility') if item else None
    public=bool(item and visibility==0 and version)
    private_uploaded=bool(item and visibility!=0 and version)
    row.update(workshop_visibility=visibility,workshop_visibility_name={0:'public',1:'friends_only',2:'private',3:'unlisted'}.get(visibility),
               workshop_version=version,published_version=version if public else None,
               uploaded_private_version=version if private_uploaded else None,
               currently_published=public,private_uploaded=private_uploaded,
               native_verified=bool(evidence.get('verified')),native_upload_status=evidence.get('latest_upload_status'),
               publication_evidence=evidence.get('receipts',[]),published_version_basis=version_basis if version else None)
    if public:
        if version!=row['source_version']:
            status='published_update_failed' if evidence.get('latest_upload_status')=='mutation_failed' else 'published_update_pending'
        else:
            status='verified_public_current' if evidence.get('verified') else 'published_source_version_matches'
    elif private_uploaded:
        status='verified_private_candidate' if evidence.get('verified') else 'private_uploaded_pending_verification'
    elif item:
        status='created_private_pending_upload' if visibility!=0 else 'created_pending_upload'
    else:
        status='unpublished_new_main_mod' if row['publication_group']=='independent_main_mod' else 'unpublished_new_patch'
    row['publication_status']=status

def build(args, generated_at):
    need(ROOT.name=='suqing-project-zomboid-patches' and (ROOT/'catalog.json').is_file(),'Unexpected index owner directory')
    need((ROOT/'docs').is_dir() and (ROOT/'docs').resolve().is_relative_to(ROOT),'Index output must stay in its repository')
    need(all(not path.is_symlink() for path in OUTPUTS),'Linked index output rejected')
    routes=read_json(args.local_map);need(Path(routes['patch_repo']).resolve()==ROOT,'Wrong route-map repository')
    personal_root=Path(routes['personal_mods']).resolve();need(personal_root.is_dir(),'Personal mod directory missing')
    titles={x['mod_id']:x for x in read_json(args.main_audit)['mods']}
    catalog=read_json(ROOT/'catalog.json');history=read_json(args.history_index)
    historical={x['mod_id']:x for x in history['mods']}
    candidate=read_json(ROOT/'publishing/candidate-20261106.json')
    snapshot=read_json(args.workshop_snapshot);items=snapshot_items(snapshot)
    records,evidence=native_evidence(getattr(args,'native_receipts',None),items)
    selected_ids=set(candidate['mod_ids']);need(len(selected_ids)==len(candidate['mod_ids']),'Duplicate candidate Mod IDs')
    held={mid for mid,x in historical.items() if x.get('publication_group')=='held_upstream_payload'}
    ex={mid for mid,x in historical.items() if x.get('publication_group')=='optional_companion_in_EX_package'}
    baseline_ids={mid for mid,x in historical.items() if x.get('publication_group')=='optional_in_patch_collection'}
    need(len(held)==5 and len(ex)==3,'Held/EX audit history incomplete')
    need(not (selected_ids&(held|ex)) and not held&ex,'Candidate includes held or separate EX patches')
    patch_ids={x['id'] for x in catalog['mods']}
    need(patch_ids==selected_ids|held|ex,'Source/catalog publication groups differ')
    need(len(routes['main_mods'])==13 and len(catalog['mods'])==40,'Expected current 13 main/40 patch inventory')
    need(len({x['mod_id'] for x in routes['main_mods']})==13 and len(patch_ids)==40,'Duplicate source Mod ID')
    baseline_collection_version=history.get('workshop_patch_distribution',{}).get('published_collection_version','2026.11.03-25')
    group_id=str(candidate['publishedfileid']);need(group_id in items,'Patch Workshop item missing from owner snapshot')
    group_item=items[group_id];group_evidence=evidence.get(group_id,{})
    group_version=metadata(group_item).get('version')
    if group_evidence.get('verified'):
        group_versions=group_evidence['mod_versions']
        need(set(group_versions)<=selected_ids,'Verified parent item unexpectedly includes held/EX/unselected IDs')
        group_basis='Matching native upload/verify plus final owner metadata; no remote per-file download'
    elif group_version==baseline_collection_version:
        group_versions={mid:historical[mid]['source_version'] for mid in baseline_ids}
        group_basis='Preserved prior per-mod payload manifest plus unchanged parent-item version in final snapshot'
    else:
        # A changed 32-entry parent must have exact native verification before
        # its new per-mod versions or availability can be asserted.
        raise ValueError('Changed patch parent requires a matching native verify receipt')
    repos=[];mods=[]
    for route in routes['main_mods']:
        mid=route['mod_id'];data=titles[mid];source_repo=Path(route['source_repo']).resolve();source_root=Path(route['source_mod_root']).resolve()
        need(source_root.is_relative_to(source_repo),'Source root escapes repository')
        source_path,fields=effective_info(source_root,mid)
        repo=repository(source_repo,data['title_zh'],data['title_en'],1);repos.append(repo)
        personal=personal_entry(personal_root,mid)
        row=common(mid,data['title_zh'],data['title_en'],repo,source_path.relative_to(source_repo).as_posix(),fields,personal)
        row.update(source_form='complete_mod_package',source_mod_info_sha256=digest(source_path),publication_group='independent_main_mod')
        item_id=item_identity(mid,data.get('workshop_id'),records);item=items.get(item_id)
        need(not item_id or item is not None,'Known/recovered Workshop ID is absent from complete owner snapshot')
        ev=evidence.get(item_id,{})
        version=metadata(item).get('version') if item else None
        if ev.get('verified'):
            need(ev.get('mod_versions')=={mid:version},'Native main-mod identity/version map differs')
        row['workshop_item_id']=item_id
        current_state(row,item,ev,version,'Native version metadata, cross-checked with matching native receipts when present')
        retry_path=getattr(args,'pending_retry',None)
        if retry_path:
            retry=read_json(retry_path)
            if str(retry.get('item'))==item_id:
                need(retry.get('status')=='waiting_for_user_node_switch' and retry.get('online_version')==version
                     and retry.get('target_version')==fields['modversion'] and row['publication_status']=='published_update_failed',
                     'Pending retry record does not match an explicit failed update and actual versions')
                row['publication_status']='update_failed_pending_node_switch'
                row['retry_status']='waiting_for_user_node_switch'
                row['retry_record_sha256']=digest(retry_path)
        row['candidate']={'selected':not row['currently_published'] or version!=fields['modversion'],
                          'version':fields['modversion'],'status':'private_uploaded_candidate' if row['private_uploaded'] else 'source_version_matches_public' if row['currently_published'] and version==fields['modversion'] else 'local_source_update_pending',
                          'package_verification':'Consult native verification evidence and frozen release receipt; no gameplay acceptance is inferred.'}
        mods.append(row)
    patch_repo=repository(ROOT,'蘇清的僵尸毁灭工程补丁合集','SuQing’s Project Zomboid Patch Collection',40);repos.append(patch_repo)
    ex_id='3832223700';need(ex_id in items,'EX parent item missing')
    ex_item=items[ex_id];ex_ev=evidence.get(ex_id,{})
    ex_parent_version=historical['ExSuQingBackpackSuperUpgrade_4221']['source_version']
    need(ex_ev.get('verified') or metadata(ex_item).get('version')==ex_parent_version,'Changed EX parent requires native per-mod verification')
    for data in catalog['mods']:
        mid=data['id'];old=historical.get(mid,{})
        source_path,fields=effective_info(ROOT/'src'/data['folder'],mid,data['source_runtime_info'])
        need(source_path.resolve().is_relative_to((ROOT/'src').resolve()),'Source metadata escapes src')
        need((ROOT/data['doc']).is_file() and (ROOT/data['doc']).resolve().is_relative_to(ROOT),'Patch guide missing/escaping')
        row=common(mid,old.get('title_zh',data['title_zh']),old.get('title_en',data['title_en']),patch_repo,source_path.relative_to(ROOT).as_posix(),fields,personal_entry(personal_root,mid))
        row.update(source_form='custom_source_and_pinned_upstream_reconstruction',documentation=data['doc'],source_mod_info_sha256=digest(source_path))
        if mid in held:
            row.update(publication_group='held_upstream_payload',workshop_item_id=None,workshop_visibility=None,workshop_version=None,
                       published_version=None,uploaded_private_version=None,currently_published=False,private_uploaded=False,native_verified=False,
                       publication_status='held_pending_upstream_redistribution_review',publication_evidence=[],published_version_basis=None)
        else:
            group='optional_companion_in_EX_package' if mid in ex else 'optional_in_patch_collection'
            parent=ex_item if mid in ex else group_item;ev=ex_ev if mid in ex else group_evidence
            versions=ev.get('mod_versions',{}) if mid in ex and ev.get('verified') else {mid:old.get('source_version')} if mid in ex else group_versions
            version=versions.get(mid);row.update(publication_group=group,workshop_item_id=ex_id if mid in ex else group_id)
            current_state(row,parent if version else None,ev,version,'Preserved EX payload with unchanged parent version' if mid in ex and not ev.get('verified') else group_basis)
            if mid in ex and row['currently_published']:row['publication_status']='published_in_EX_package'
        row['candidate']={'selected':mid in selected_ids,'version':fields['modversion'] if mid in selected_ids else None,
                          'collection_version':candidate['version'] if mid in selected_ids else None,
                          'status':'matches_verified_public_payload' if row['currently_published'] and row['published_version']==fields['modversion'] else 'private_uploaded_candidate' if row['private_uploaded'] else 'selected_local_update_pending' if mid in selected_ids else 'held_or_separate_EX_distribution',
                          'package_verification':'Native proof and exact frozen manifest are separate from gameplay acceptance.'}
        mods.append(row)
    need(len(mods)==53 and len({x['mod_id'] for x in mods})==53,'Index count/IDs differ')
    need(len(repos)==14 and len({x['slug'] for x in repos})==14 and all(x['git_initialized'] for x in repos),'Repository count/state differs')
    counts=Counter(x['publication_status'] for x in mods)
    public_patch=sum(x['mod_id'] in selected_ids and x['currently_published'] for x in mods)
    private_patch=sum(x['mod_id'] in selected_ids and x['private_uploaded'] for x in mods)
    known_collection_ids=COLLECTION_IDS&set(items)
    publication_counts={'published_mod_ids':sum(x['currently_published'] for x in mods),
                        'private_uploaded_mod_ids':sum(x['private_uploaded'] for x in mods),
                        'verified_private_mod_ids':sum(x['private_uploaded'] and x['native_verified'] for x in mods),
                        'created_without_verified_payload_mod_ids':sum(x['publication_status'].startswith('created_') for x in mods),
                        'unpublished_new_main_mods':counts['unpublished_new_main_mod'],'unpublished_new_patches':counts['unpublished_new_patch'],
                        'published_projects_with_pending_updates':counts['published_update_pending']+counts['published_update_failed']+counts['update_failed_pending_node_switch'],
                        'failed_existing_updates':counts['published_update_failed']+counts['update_failed_pending_node_switch'],'held_patches':len(held),
                        'git_repositories_with_remote':sum(bool(x['repository']) for x in repos),'git_repositories_without_remote':sum(not x['repository'] for x in repos)}
    return {'schema':3,'generated_at_bjt':generated_at,'game_target':catalog['target_game']+' single-player',
            'repository_count':len(repos),'independent_mod_repositories':len(routes['main_mods']),'patch_collection_mod_count':len(catalog['mods']),'mod_count':len(mods),
            'path_policy':'Only repository-relative source paths and personal paths relative to mods; absolute locations remain in the local input map.',
            'source_and_publication_boundary':'Public, private uploaded, failed update, local source and personal installation are distinct. No game acceptance or remote per-file download is inferred.',
            'workshop_snapshot':{'started_at_bjt':snapshot['started_at'],'finished_at_bjt':snapshot['finished_at'],'enumeration_stable':True,
                                 'expected_owner':OWNER,'consumer_app':APP,'owned_entry_count':len(items),'owned_item_count':len(items)-len(known_collection_ids),
                                 'owned_collection_count':len(known_collection_ids),'public_owned_entry_count':sum(x['visibility']==0 for x in items.values()),
                                 'nonpublic_owned_entry_count':sum(x['visibility']!=0 for x in items.values()),'snapshot_sha256':digest(args.workshop_snapshot),'remote_file_download':False},
            'workshop_patch_distribution':{'published_collection_mod_count':public_patch,'private_uploaded_collection_mod_count':private_patch,
                                           'candidate_collection_mod_count':len(selected_ids),'EX_package_companion_mod_count':len(ex),
                                           'held_for_upstream_payload_review_count':len(held),'new_unpublished_patch_count':counts['unpublished_new_patch'],
                                           'existing_patch_update_count':sum(x['publication_group']=='optional_in_patch_collection' and x['publication_status'] in ['published_update_pending','published_update_failed'] for x in mods),
                                           'published_collection_version':group_version if group_item['visibility']==0 else None,
                                           'workshop_collection_version':group_version,'collection_visibility':group_item['visibility'],
                                           'local_candidate_version':candidate['version'],'held_ids':sorted(held),'EX_companion_ids':sorted(ex)},
            'publication_counts':publication_counts,'publication_status_counts':dict(counts),
            'historical_index':{'snapshot_generated_at_bjt':history['generated_at_bjt'],'preserved_json_sha256':digest(args.history_index),
                                'retention':'Original November 3 index and November 6 prepublication index preserved verbatim in local release-repair history.'},
            'repositories':repos,'mods':mods}

def md_escape(value):
    return str(value if value is not None else '—').replace('|','\\|').replace('\n',' ')

def markdown(index):
    snap=index['workshop_snapshot'];pub=index['publication_counts'];dist=index['workshop_patch_distribution']
    lines=['# 蘇清的模组与补丁项目索引 | SuQing’s Mod and Patch Index','',
           '生成时间 / Generated at: '+index['generated_at_bjt'],'',
           f"**{index['mod_count']}个Mod ID：{index['independent_mod_repositories']}个主模组、{index['patch_collection_mod_count']}个补丁，共{index['repository_count']}个本地Git仓库；{pub['git_repositories_with_remote']}个已配置远端。**",
           f"**{index['mod_count']} Mod IDs: {index['independent_mod_repositories']} main mods and {index['patch_collection_mod_count']} patches in {index['repository_count']} local Git repositories; {pub['git_repositories_with_remote']} have configured remotes.**",'',
           f"线上依据{snap['finished_at_bjt']}的首尾一致owner快照：{snap['owned_item_count']}个项目、{snap['owned_collection_count']}个个人合集。源码、候选、个人安装、公开发布和私密已上传分别记录；上传失败保留实际线上旧版。",
           f"Online state uses the stable owner snapshot at {snap['finished_at_bjt']}: {snap['owned_item_count']} items and {snap['owned_collection_count']} personal collection. Source, candidate, installation, public and private uploads are separate; failed updates retain observed older versions.",'',
           f"当前公开{pub['published_mod_ids']}个Mod ID，非公开已上传{pub['private_uploaded_mod_ids']}个（其中原生验证{pub['verified_private_mod_ids']}个），暂缓{pub['held_patches']}项。公开补丁合集{dist['published_collection_mod_count']}项；本地选择{dist['candidate_collection_mod_count']}项，另{dist['EX_package_companion_mod_count']}项随EX。既有更新失败{pub['failed_existing_updates']}项。",
           f"There are {pub['published_mod_ids']} publicly available Mod IDs and {pub['private_uploaded_mod_ids']} nonpublic uploaded IDs ({pub['verified_private_mod_ids']} natively verified), plus {pub['held_patches']} held patches. The public patch item contains {dist['published_collection_mod_count']} submods; the local selection has {dist['candidate_collection_mod_count']}, with {dist['EX_package_companion_mod_count']} separate EX companions. {pub['failed_existing_updates']} existing updates failed.", '',
           '私密上传不代表已公开，也不代表完整游戏内验收。原生验证仅核对提交回执、文案、元数据树哈希、字节数、标签、预览和依赖；没有重新下载远端逐文件SHA。',
           'Private upload does not establish public availability or complete gameplay acceptance. Native verification covers submit receipts, text, metadata tree identity, byte totals, tags, preview and dependencies; no new remote per-file SHA download was performed.','',
           '## 仓库入口 | Repository entries','',
           '| 仓库 / Repository | 中英名称 / Bilingual title | Mod ID数 / Count | Git状态 / Git state |','| --- | --- | ---: | --- |']
    for repo in index['repositories']:
        label='['+repo['slug']+']('+repo['repository']+')' if repo['repository'] else '`'+repo['local_directory_name']+'`'
        state='远端已配置 / remote configured' if repo['repository'] else '本地待建远端 / local only'
        lines.append('| '+label+' | '+md_escape(repo['title_zh']+' / '+repo['title_en'])+' | '+str(repo['mod_count'])+' | '+state+' |')
    lines += ['', '## 版本与发布状态 | Versions and publication','',
              '个人列表示安装文件，不等于存档启用。线上列显示实际Workshop版本，私密版本只在状态中标作私密；本地候选并不自动等于线上内容。',
              'Personal means installed files, not save enablement. Workshop versions retain actual visibility; local candidates do not automatically equal uploaded contents.','',
              '| Mod ID | 名称 / Title | 源码 / Source | 本地候选 / Candidate | 个人 / Personal | Workshop版本 / Version | 状态 / Status |','| --- | --- | --- | --- | --- | --- | --- |']
    labels={'unpublished_new_main_mod':'新主模组未上传 / new main, not uploaded','unpublished_new_patch':'新补丁未上传 / new patch, not uploaded',
            'published_update_pending':'公开旧版待更新 / public update pending','published_update_failed':'更新失败保留旧版 / update failed; old public version',
            'update_failed_pending_node_switch':'更新失败待用户切节点 / failed; waiting for user node switch',
            'published_source_version_matches':'已公开同版本 / public same version','verified_public_current':'原生验证已公开 / verified public',
            'verified_private_candidate':'原生验证私密候选 / verified private candidate','private_uploaded_pending_verification':'私密上传待验证 / private upload, verification pending',
            'created_private_pending_upload':'已建私密条目待上传 / private item created','created_pending_upload':'已建条目待上传 / item created',
            'published_in_EX_package':'EX同包已公开 / public with EX','held_pending_upstream_redistribution_review':'暂缓分发 / held'}
    for row in index['mods']:
        values=['`'+row['mod_id']+'`',row['title_zh']+' / '+row['title_en'],row['source_version'],row['candidate']['version'],row['personal_runtime_version'],row['workshop_version'],labels[row['publication_status']]]
        lines.append('| '+' | '.join(md_escape(x) for x in values)+' |')
    lines += ['', '## 依赖与证据边界 | Dependencies and evidence limits','',
              '[机器可读索引 / Machine-readable index](project-index.json)保留53项实际mod.info入口、SHA256、require/loadModAfter及原生回执摘要。所有源入口均为各仓库相对路径；绝对机器路径仅在本地路由/回执中。',
              'The JSON records actual mod.info entries, SHA256, require/loadModAfter and native receipt evidence. Source entries are repository-relative; absolute machine paths remain only in local routing and receipts.','',
              '公开、私密、失败和候选状态按当前实际visibility与成功回执交叉判定，不能从Git仓库创建或上传操作推断玩法验收。个人灌溉、负重和搜索的版本差异保留，不为版本齐平改安装。',
              'Public, private, failed and candidate states follow observed visibility and successful receipts. Repository creation/upload does not establish gameplay acceptance. Personal version differences are retained without deployment for version parity.','',
              '11月3日原索引及11月6日发布前索引均已逐字节保留。本工具只更新两个索引，不改个人模组、启用顺序、配置、存档、Git提交或工坊内容。',
              'The November 3 index and November 6 prepublication index are preserved verbatim. This tool writes only the two indexes; it changes no personal mods, order, settings, saves, Git commits or Workshop content.','']
    return '\n'.join(lines)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for flag in ['local-map','main-audit','history-index','workshop-snapshot']:
        parser.add_argument('--'+flag,required=True,type=Path)
    parser.add_argument('--native-receipts',type=Path,help='Dedicated actual native publisher receipt directory; required to confirm changed payloads')
    parser.add_argument('--pending-retry',type=Path,help='Explicit failed-update record awaiting the user node switch; does not mark the update complete')
    parser.add_argument('--check',action='store_true',help='Validate and compare existing public indexes without writing')
    args=parser.parse_args()
    at=read_json(OUTPUTS[0])['generated_at_bjt'] if args.check else datetime.now(timezone(timedelta(hours=8))).isoformat()
    result=build(args,at);json_text=json.dumps(result,ensure_ascii=False,indent=2)+'\n';md_text=markdown(result)
    need(not re.search(r'[A-Z]:[\\/]',json_text+md_text),'Absolute Windows paths must not enter public indexes')
    if args.check:
        need(OUTPUTS[0].read_text(encoding='utf-8')==json_text and OUTPUTS[1].read_text(encoding='utf-8')==md_text,'Existing index differs from current source/snapshot/native receipts')
    else:
        OUTPUTS[0].write_text(json_text,encoding='utf-8',newline='\n');OUTPUTS[1].write_text(md_text,encoding='utf-8',newline='\n')
    print(json.dumps({'result':'PASS','mode':'check' if args.check else 'generate','mods':len(result['mods']),'repositories':len(result['repositories']),
                      'publication_counts':result['publication_counts'],'distribution':result['workshop_patch_distribution'],'outputs':[str(x) for x in OUTPUTS]},ensure_ascii=False,indent=2))

if __name__=='__main__':main()
