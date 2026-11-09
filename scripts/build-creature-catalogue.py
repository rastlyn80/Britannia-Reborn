"""Local creature work board: preparation, validated art and native evidence."""
import collections,hashlib,html,importlib.util,json,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures'
OUT=ROOT/'outputs/creatures'
def read(path,default=None):return json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else default
def keys(file,name):
    match=re.search(r'const '+name+r'\s*:?=\s*\{(.*?)\}',file.read_text(),re.S)
    return {int(value,16) for value in re.findall(r'(0x[\da-fA-F]+)\s*:',match.group(1))} if match else set()
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    if (ROOT/'Server/runtime/Data/Spawns').exists():
        subprocess.run([sys.executable,'-B',str(ROOT/'scripts/build-creature-priority.py')],check=True)
    source=read(ART/'source-index.json');accepted=read(ART/'accepted-index.json',{'entries':[]})['entries']
    public=[row for row in read(ROOT/'Viewer/Art/Creatures/index.json',{'entries':[]})['entries'] if row.get('status')=='validated']
    prepared={};families={};model_families={}
    for path in sorted(ART.glob('*/preparation.json')):
        report=read(path)
        for model in report['models']:
            family=model.get('family') or report.get('family')
            assert family, f'Missing preparation family: {path}: {model["kind"]}'
            prepared[model['kind']]=model;model_families[model['kind']]=family
    for kind,model in prepared.items():
        families.setdefault(model_families[kind],{'models':[]})['models'].append(model)
    routed={int(identity['body']):row for row in public+accepted if not row.get('mount_only') for identity in row['bodies']}
    item_routes={int(row['mount_item']): {'kind':row['kind'], 'art_keys':[int(body['body']) for body in row['bodies']],
                                        'live_reports':[]} for row in public+accepted if row.get('mount_only')}
    spec=importlib.util.spec_from_file_location('catalogue_priority',ROOT/'scripts/build-creature-priority.py')
    priority=importlib.util.module_from_spec(spec);spec.loader.exec_module(priority)
    human_routes=priority.human_npc_routes(ROOT)
    existing=set()
    registry=ROOT/'Viewer/Presentation/EquineRegistry.gd'
    for name in ['BODIES','COMPATIBILITY','DISTINCT']:existing|=keys(registry,name)
    existing|=keys(ROOT/'Viewer/Presentation/MountVisual.gd','BODIES')|keys(ROOT/'Viewer/Presentation/AnimalVisual.gd','BODIES')
    live={};live_classes={};reports=[]
    for path in [OUT/'all/live.json',*OUT.glob('*/live.json'),*(ROOT/'outputs/ostard-riding').glob('*live.json'),
                 ROOT/'outputs/ostard-riding/live-validation.json',ROOT/'outputs/equines/live-validation.json',ROOT/'outputs/equines/ordinary-horse-live.json',
                 ROOT/'outputs/horse-session/live-validation.json',ROOT/'outputs/ostard-riding/llama-completion-live.json']:
        if not path.exists() or str(path) in reports:continue
        report=read(path)
        if report.get('failures')!=0:continue
        reports.append(str(path))
        for record in report.get('records',[]):
            if not record.get('ethereal',False):
                body=int(record['body']);live.setdefault(body,[]).append(str(path.relative_to(ROOT)))
                name = priority.named_native_class(record, path)
                if name:live_classes.setdefault(body,set()).add(name)
            elif record.get('ride_permitted') and int(record.get('mount_item',0)) in item_routes:
                evidence=item_routes[int(record['mount_item'])]['live_reports']
                relative=str(path.relative_to(ROOT))
                if relative not in evidence:evidence.append(relative)
    targets=[];special=[]
    for value,sources in source['native_literal_bodies'].items():
        body=int(value);profile=source['native_profiles'].get(value,'')
        unusual={637:'equipment',970:'empty'}.get(body)
        if not unusual and profile not in ['animal','monster','sea']:continue
        native_group='/'.join(sources[0]['path'].replace('\\','/').split('/')[3:-1])
        (special if unusual else targets).append({'body':body,'profile':unusual or profile,'native_group':native_group,'sources':sources,
                        'presentation':routed[body]['kind'] if body in routed else human_routes.get(body,'previously integrated horse/ostard/ki-rin/llama/bovine' if body in existing else None),
                        'live_reports':live.get(body,[]),'tested_native_constructors':sorted(live_classes.get(body,set()))})
    # The literal scanner cannot resolve Utility.Random(125, 2). These two
    # prepared identities carry exact source pins and real constructor receipts.
    catalogued = {row['body'] for row in targets + special}
    for body in (125, 126):
        model = routed.get(body, {})
        if body in catalogued or 'EvilMageLord' not in live_classes.get(body, set()):
            continue
        bindings = [identity for identity in model.get('bodies', []) if int(identity['body']) == body]
        if len(bindings) != 1 or bindings[0].get('native_class') != 'EvilMageLord':
            continue
        sources = bindings[0]['native_sources']
        assert sources and all(hashlib.sha256((ROOT / 'Server/ModernUO' / item['path']).read_bytes()).hexdigest()
                               == item['sha256'] for item in sources)
        special.append({'body': body, 'profile': 'monster', 'native_group': 'Humanoid/Magic', 'sources': sources,
                        'presentation': model['kind'], 'live_reports': live[body],
                        'tested_native_constructors': ['EvilMageLord'], 'source_scope': bindings[0]['native_identity_scope']})
    targets.sort(key=lambda row:(row['native_group'],row['body']))
    special.sort(key=lambda row:row['body'])
    counts={'bounded_native_literal_bodies':len(targets),'routed_native_literals':sum(bool(row['presentation']) for row in targets),
            'with_native_evidence':sum(bool(row['live_reports']) for row in targets),'new_validated_source_forms':len(accepted),
            'new_body_routes':len(routed),'specialized_human_npc_routes':len(human_routes),'human_npc_with_native_evidence':sum(body in live for body in human_routes),'licensed_public_source_forms':len(public),'prepared_source_forms':sum(row['status']=='prepared' for row in prepared.values()),'blocked_source_forms':sum(row['status']!='prepared' for row in prepared.values()),
            'named_native_constructor_pairs_with_evidence':sum(len(row['tested_native_constructors']) for row in targets)}
    scope='Bounded pinned-server literal Body assignments, RandomList, simple conditional literal branches and base-mount calls; not every dynamic constructor result or the full modern-client body catalogue. Source forms, body routes and live evidence are separate. Named constructors list positive evidence in passing reports only: a tested body is not proof of every class sharing it, and older receipts may lack class names. Proprietary-derived art stays local; no redistribution grant.'
    counts['mounted_item_only_routes']=len(item_routes)
    counts['additional_native_body_types']=len(special)
    counts['additional_routed_native_body_types']=sum(bool(row['presentation']) for row in special)
    counts['additional_native_body_types_with_live_evidence']=sum(bool(row['live_reports']) for row in special)
    counts['additional_named_native_constructor_pairs_with_evidence']=sum(len(row['tested_native_constructors']) for row in special)
    spell_forms = [
        {'body': int(identity['body']), 'name': identity['name'], 'presentation': row['kind'],
         'source': row.get('spell_form_source') or row['fitted_spell_form_source']}
        for row in accepted if row.get('spell_form_source') or row.get('fitted_spell_form_source')
        for identity in row['bodies']
    ]
    counts['player_spell_creature_routes'] = len(spell_forms)
    (OUT/'catalogue.json').write_text(json.dumps({'counts':counts,'server_pin':source['server_pin'],'native_targets':targets,
                                                'additional_native_targets':special,
                                                'player_spell_creature_routes':spell_forms,
                                                'mounted_item_only_routes':item_routes,'preparation':prepared,'scope':scope},indent=2),encoding='utf-8')
    cards=[];atlases=[];materials=[]
    if public:
        cards.append('<section><h2>Distributable licensed replacements</h2>'+''.join('<p>'+html.escape(row['kind'])+' — '+html.escape(row['license'])+'; <a href="'+html.escape(row['source'],quote=True)+'">exact source</a>. Authored category motions, native evidence listed below.</p>' for row in public)+'</section>')
    for family in sorted(families):
        models=families[family]['models'];validated=[row for row in accepted if row['family']==family]
        snippets=[]
        for row in models:
            kind=row['kind'];path=OUT/family/kind/'walk-side.png';image=''
            if path.exists():image=f'<a href="{family}/{kind}/walk-side.png"><img loading="lazy" src="{family}/{kind}/walk-side.png" alt="{html.escape(kind)} comparison"></a>'
            status='Motion and rendering checked' if any(v['kind']==kind for v in validated) else 'Prepared trial' if row['status']=='prepared' else 'Needs material/effect work' if row.get('pending_render_feature') else 'Needs repair'
            blocker=row.get('blocker') or row.get('pending_render_feature')
            snippets.append(f'<h3>{html.escape(kind.replace("_"," "))} — {status}</h3>'+image+(f'<p>{html.escape(blocker)}</p>' if blocker else ''))
            atlas=ART/(kind+'-albedo-v1.png');prompt=atlas.with_suffix('.prompt.txt')
            if atlas.exists() and prompt.exists():atlases.append({'kind':kind,'image':str(atlas),'sha256':hashlib.sha256(atlas.read_bytes()).hexdigest(),'exact_prompt_file':str(prompt),'prompt':prompt.read_text(encoding='utf-8-sig'),'mode':row.get('generation_mode','built-in imagegen source atlas edit'),'source_atlas_status':row.get('source_atlas_status','See source preparation inputs'),'technical_guide':row.get('technical_guide')})
            if row.get('mineral_surface'):
                materials.append({'kind':kind,'family':family,'surface':row['mineral_surface'],'art_dependency_sha256':row['art_dependency_sha256']})
                snippets.append('<p>Photographic mineral maps: <a href="'+html.escape(row['mineral_surface']['source'],quote=True)+'">'+html.escape(row['mineral_surface']['source_set'])+'</a> (CC0); authored colour and reflectance. Exact map hashes and recipes: <a href="material-provenance.json">material provenance</a>.</p>')
        cards.append('<section><h2>'+html.escape(family)+' / '+str(len(validated))+' validated source forms</h2><details><summary>Models, comparisons and repairs</summary>'+''.join(snippets)+'</details></section>')
    rows=''.join('<tr><td>0x%X</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%(row['body'],html.escape(row['native_group']),html.escape(row['presentation'] or 'Needs replacement'),'Native evidence' if row['live_reports'] else 'Not live-certified',html.escape(', '.join(row['tested_native_constructors']) or 'No named constructor in these receipts')) for row in targets+special)
    (OUT/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><title>Britannia Reborn / creature work board</title><style>body{background:#20303a;color:#e9edef;font:17px system-ui;max-width:1440px;margin:24px auto;padding:15px}img{max-width:100%;height:auto}summary{cursor:pointer}section{margin:30px 0}table{border-collapse:collapse;width:100%}td,th{text-align:left;border-bottom:1px solid #52616b;padding:9px}a{color:#dfce95}p{line-height:1.5}</style><h1>Britannia Reborn / creature work board</h1><p>Prepared trials, validated art and real server checks remain separate. The creature programme continues through every family; gaps stay visible.</p><p>'''+html.escape(str(counts))+'''</p><p>'''+html.escape(scope)+'''</p>'''+''.join(cards)+'''<details><summary>Bounded native body checklist</summary><table><tr><th>Body</th><th>Native source group</th><th>Presentation</th><th>Server checks</th><th>Named constructors exercised</th></tr>'''+rows+'''</table></details><p><a href="catalogue.json">Detailed catalogue</a> · <a href="actions.html">Action ledger</a> · <a href="frequency.html">Occurrence work order</a> · <a href="../corpses/index.html">Corpse graphic variants</a> · <a href="atlas-provenance.json">Saved texture paths and exact prompts</a></p></html>''',encoding='utf-8')
    (OUT/'atlas-provenance.json').write_text(json.dumps({'atlases':atlases,'scope':'Generated edits of proprietary-derived local inputs, not redistributable assets. Exact prompts and workspace output paths retained.'},indent=2),encoding='utf-8')
    (OUT/'material-provenance.json').write_text(json.dumps({'materials':materials,'scope':'Exact photographic sources, CC0 licenses, authors, map URLs/hashes and authored settings. Source creature geometry/UVs remain proprietary-derived local inputs.'},indent=2),encoding='utf-8')
    print('CREATURE WORK BOARD:',counts)
if __name__=='__main__':main()
