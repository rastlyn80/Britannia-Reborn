"""Local creature work board: preparation, validated art and native evidence."""
import collections,hashlib,html,json,re,subprocess,sys
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
    prepared={};families={}
    for path in ART.glob('*/preparation.json'):
        report=read(path);families[report['family']]=report
        for model in report['models']:prepared[model['kind']]=model
    routed={int(identity['body']):row for row in public+accepted for identity in row['bodies']}
    existing=set()
    registry=ROOT/'Viewer/Presentation/EquineRegistry.gd'
    for name in ['BODIES','COMPATIBILITY','DISTINCT']:existing|=keys(registry,name)
    existing|=keys(ROOT/'Viewer/Presentation/MountVisual.gd','BODIES')|keys(ROOT/'Viewer/Presentation/AnimalVisual.gd','BODIES')
    live={};reports=[]
    for path in [OUT/'all/live.json',*OUT.glob('*/live.json'),*(ROOT/'outputs/ostard-riding').glob('*live.json'),
                 ROOT/'outputs/ostard-riding/live-validation.json',ROOT/'outputs/equines/live-validation.json',
                 ROOT/'outputs/horse-session/live-validation.json',ROOT/'outputs/ostard-riding/llama-completion-live.json']:
        if not path.exists() or str(path) in reports:continue
        report=read(path)
        if report.get('failures')!=0:continue
        reports.append(str(path))
        for record in report.get('records',[]):
            if not record.get('ethereal',False):live.setdefault(int(record['body']),[]).append(str(path.relative_to(ROOT)))
    targets=[]
    for value,sources in source['native_literal_bodies'].items():
        body=int(value);profile=source['native_profiles'].get(value,'')
        if profile not in ['animal','monster','sea']:continue
        native_group='/'.join(sources[0]['path'].replace('\\','/').split('/')[3:-1])
        targets.append({'body':body,'profile':profile,'native_group':native_group,'sources':sources,
                        'presentation':routed[body]['kind'] if body in routed else 'previously integrated horse/ostard/ki-rin/llama/bovine' if body in existing else None,
                        'live_reports':live.get(body,[])})
    targets.sort(key=lambda row:(row['native_group'],row['body']))
    counts={'bounded_native_literal_bodies':len(targets),'routed_native_literals':sum(bool(row['presentation']) for row in targets),
            'with_native_evidence':sum(bool(row['live_reports']) for row in targets),'new_validated_source_forms':len(accepted),
            'new_body_routes':len(routed),'licensed_public_source_forms':len(public),'prepared_source_forms':sum(row['status']=='prepared' for row in prepared.values()),'blocked_source_forms':sum(row['status']!='prepared' for row in prepared.values())}
    scope='Bounded pinned-server literal Body assignments, RandomList, simple conditional literal branches and base-mount calls; not every dynamic constructor result or the full modern-client body catalogue. Source forms, body routes and live evidence are separate. Proprietary-derived art stays local; no redistribution grant.'
    (OUT/'catalogue.json').write_text(json.dumps({'counts':counts,'server_pin':source['server_pin'],'native_targets':targets,'preparation':prepared,'scope':scope},indent=2),encoding='utf-8')
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
    rows=''.join('<tr><td>0x%X</td><td>%s</td><td>%s</td><td>%s</td></tr>'%(row['body'],html.escape(row['native_group']),html.escape(row['presentation'] or 'Needs replacement'),'Native evidence' if row['live_reports'] else 'Not live-certified') for row in targets)
    (OUT/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><title>Britannia Reborn / creature work board</title><style>body{background:#20303a;color:#e9edef;font:17px system-ui;max-width:1440px;margin:24px auto;padding:15px}img{max-width:100%;height:auto}summary{cursor:pointer}section{margin:30px 0}table{border-collapse:collapse;width:100%}td,th{text-align:left;border-bottom:1px solid #52616b;padding:9px}a{color:#dfce95}p{line-height:1.5}</style><h1>Britannia Reborn / creature work board</h1><p>Prepared trials, validated art and real server checks remain separate. The creature programme continues through every family; gaps stay visible.</p><p>'''+html.escape(str(counts))+'''</p><p>'''+html.escape(scope)+'''</p>'''+''.join(cards)+'''<details><summary>Bounded native body checklist</summary><table><tr><th>Body</th><th>Native source group</th><th>Presentation</th><th>Server checks</th></tr>'''+rows+'''</table></details><p><a href="catalogue.json">Detailed catalogue</a> · <a href="actions.html">Action ledger</a> · <a href="frequency.html">Occurrence work order</a> · <a href="../corpses/index.html">Corpse graphic variants</a> · <a href="atlas-provenance.json">Saved texture paths and exact prompts</a></p></html>''',encoding='utf-8')
    (OUT/'atlas-provenance.json').write_text(json.dumps({'atlases':atlases,'scope':'Generated edits of proprietary-derived local inputs, not redistributable assets. Exact prompts and workspace output paths retained.'},indent=2),encoding='utf-8')
    (OUT/'material-provenance.json').write_text(json.dumps({'materials':materials,'scope':'Exact photographic sources, CC0 licenses, authors, map URLs/hashes and authored settings. Source creature geometry/UVs remain proprietary-derived local inputs.'},indent=2),encoding='utf-8')
    print('CREATURE WORK BOARD:',counts)
if __name__=='__main__':main()
