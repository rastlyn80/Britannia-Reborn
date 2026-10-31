"""Local protocol/action ledger, with original sequence metadata kept separate.

Routable protocol slots are not an original-action completion percentage.
AnimationSequence records are metadata, not decoded animation frame pixels.
"""
import argparse,ast,hashlib,html,importlib.util,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures';OUT=ROOT/'outputs/creatures'

def sha(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def renderer_maps():
    path=ROOT/'Viewer/Presentation/CreatureVisual.gd';text=path.read_text()
    classic=re.findall(r'clip=str\((\{[^\n]+?\})\.get\(action,',text)
    modern=re.search(r'clip=str\((\{[^\n]+?\})\.get\(int\(request.get\("type"',text)
    fallback=re.search(r'var replacement:=(\{[^\n]+?\})',text)
    assert len(classic)==2 and modern and fallback,'Renderer action maps changed; review the ledger reader'
    return {'small':ast.literal_eval(classic[0]),'large':ast.literal_eval(classic[1]),
            'new':ast.literal_eval(modern[1]),'fallback':ast.literal_eval(fallback[1])},sha(path)

def resolve(model,label,fallback):
    available=set(model['stats']['original']['clips'])|{'Eat','LieDown'}
    resolved=label;visited=set()
    while resolved not in available and resolved in fallback and resolved not in visited:
        visited.add(resolved);resolved=fallback[resolved]
    if resolved not in available:return {'requested':label,'resolved':None,'status':'Missing replacement'}
    if resolved!=label:status='Runtime category substitute'
    elif label in model.get('authored_replacements',{}):status='Authored category motion'
    elif label in model.get('category_aliases',{}):status='Prepared clip alias'
    elif label in model.get('clip_sources',{}):status='Recovered source clip'
    else:status='Runtime authored pose/category'
    return {'requested':label,'resolved':resolved,'status':status,
            'source_member':model.get('clip_sources',{}).get(resolved),
            'declared_alias':model.get('category_aliases',{}).get(resolved),
            'authored_method':model.get('authored_replacements',{}).get(resolved)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--data-dir',type=Path);args=parser.parse_args()
    catalogue=json.loads((OUT/'catalogue.json').read_text())
    models=json.loads((ART/'accepted-index.json').read_text())['entries']
    public=ROOT/'Viewer/Art/Creatures/index.json'
    if public.exists():models=[row for row in json.loads(public.read_text())['entries'] if row.get('status')=='validated']+models
    maps,renderer_sha=renderer_maps();rows=[];native={}
    for model in models:
        for identity in model['bodies']:
            body=identity['body'];native[body]=model
            profile=identity.get('native_profile') or model['profile']
            for protocol,groups in [('classic',maps['small' if profile in ['animal','sea'] else 'large']),('new',maps['new'])]:
                for group,label in groups.items():
                    rows.append({'body':body,'family':model['family'],'kind':model['kind'],'native_profile':profile,
                                 'protocol':protocol,'group_or_type':group,**resolve(model,label,maps['fallback'])})
    data=args.data_dir
    config=ROOT/'Server/runtime/Configuration/modernuo.json'
    if data is None and config.exists():
        directories=json.loads(config.read_text(encoding='utf-8-sig')).get('dataDirectories',[])
        if directories:data=Path(directories[0])
    sequence=[];archives=[]
    if data and (data/'AnimationSequence.uop').exists():
        spec=importlib.util.spec_from_file_location('creature_sequences',ROOT/'scripts/uo-human-sequences.py')
        reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
        path=data/'AnimationSequence.uop'
        allowed={r['body'] for r in catalogue['native_targets']}
        sequence=reader.inspect(path,allowed)
        archives.append({'name':path.name,'sha256':sha(path),'bytes':path.stat().st_size})
    original=[];new_actions=[]
    for record in sequence:
        body=record['animation_ref'];model=native.get(body)
        groups=maps['small' if (model and model['profile'] in ['animal','sea']) else 'large']
        for source in record['replacements']:
            group=source['old_group'];label=groups.get(group)
            original.append({'body':body,**source,
                             'generic_replacement':resolve(model,label,maps['fallback']) if model and label else None})
        for mode in record['modes']:
            for action in mode['new_protocol_actions']:
                label=maps['new'].get(action['type'])
                new_actions.append({'body':body,'mode':mode['mode'],**action,
                    'generic_model':model['kind'] if model else None,
                    'replacement':resolve(model,label,maps['fallback']) if model and label else None,
                    'scope':'Type route only; exact per-body mode/subaction/variation fidelity requires separate tests.'})
    counts={'generic_models':len(models),'generic_body_routes':len(native),'protocol_slots':len(rows),
            'routable_slots':sum(r['resolved'] is not None for r in rows),
            'missing_protocol_slots':sum(r['resolved'] is None for r in rows),
            'original_sequence_records':len(sequence),'original_sequence_parse_blockers':sum(bool(r.get('parse_blocker')) or r['unparsed_bytes']!=0 for r in sequence),
            'original_new_protocol_entries':len(new_actions),
            'original_new_entries_without_generic_route':sum(bool(r['generic_model']) and not (r['replacement'] and r['replacement']['resolved']) for r in new_actions)}
    scope=('Generic creature renderer protocol slots only; distinct from original per-body required actions and choreography quality. '
           'Source clips, aliases, authored motions and missing routes remain explicit. Original UOP sequence metadata is recorded separately; '
           'frame pixels and final MUL/DEF/UOP availability/precedence are not decoded here. Humans and earlier mount/bovine action ledgers are separate.')
    report={'counts':counts,'scope':scope,'renderer_sha256':renderer_sha,'archives':archives,'routes':rows,
            'original_sequence_metadata':sequence,'original_group_links':original,'original_new_protocol_actions':new_actions}
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'actions.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    table=''.join('<tr><td>0x%X</td><td>%s</td><td>%s %s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%
        (r['body'],html.escape(r['kind']),r['protocol'],r['group_or_type'],r['requested'],r['resolved'] or '—',r['status']) for r in rows)
    (OUT/'actions.html').write_text('<!doctype html><meta charset="utf-8"><title>Creature action ledger</title><style>body{background:#20303a;color:#eee;font:16px system-ui;padding:24px}td,th{padding:8px;border-bottom:1px solid #64717a;text-align:left}a{color:#dfce95}</style><h1>Creature action ledger</h1><p>'+html.escape(scope)+'</p><p>'+html.escape(str(counts))+'</p><p><a href="actions.json">Full evidence and original sequence metadata</a> · <a href="index.html">Creature work board</a></p><table><tr><th>Body</th><th>Source form</th><th>Protocol slot</th><th>Requested category</th><th>Replacement</th><th>Evidence kind</th></tr>'+table+'</table>',encoding='utf-8')
    print('CREATURE ACTION LEDGER:',counts)
if __name__=='__main__':main()
