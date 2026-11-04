"""Local protocol/action ledger, with original sequence metadata kept separate.

Routable protocol slots are not an original-action completion percentage.
AnimationSequence records are metadata, not decoded animation frame pixels.
"""
import argparse,ast,hashlib,html,importlib.util,json,re,runpy,struct
from contextlib import ExitStack
from itertools import combinations
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
    assert len(classic)==3 and modern and fallback,'Renderer action maps changed; review the ledger reader'
    return {'small':ast.literal_eval(classic[0]),'sea':ast.literal_eval(classic[1]),'large':ast.literal_eval(classic[2]),
            'new':ast.literal_eval(modern[1]),'fallback':ast.literal_eval(fallback[1])},sha(path)

def original_frame_groups(data, allowed, reader):
    name_hash = runpy.run_path(str(ROOT/'scripts/audit-classic-parity.py'))['name_hash']
    # The reference client's loader probes 80 action names per body.
    names = {name_hash(f'build/animationlegacyframe/{body:06d}/{group:02d}.bin'): (body, group)
             for body in allowed for group in range(80)}
    records, archives = [], []
    for path in sorted(data.glob('AnimationFrame*.uop')):
        archives.append({'name': path.name, 'sha256': sha(path), 'bytes': path.stat().st_size})
        for digest, raw in reader.payloads(path, names):
            body, group = names[digest]
            count, start = struct.unpack_from('<II', raw, 32) if len(raw) >= 40 else (0, 0)
            valid = count > 0 and start >= 40 and start + count * 16 <= len(raw)
            records.append({'body': body, 'group': group, 'archive': path.name,
                            'payload_sha256': hashlib.sha256(raw).hexdigest(),
                            'frame_headers': count if valid else None})
    return sorted(records, key=lambda row: (row['body'], row['group'], row['archive'])), archives

def mul_layout(graphic, kind, flags):
    # Offsets are in 12-byte index entries, with five directions per group.
    if kind == 'SEA_MONSTER':
        return graphic * 110, 13, 'sea'
    extended = kind == 'MONSTER' or (kind == 'ANIMAL' and flags & 0x20)
    if extended and not flags & 0x440:
        return graphic * 110, 22, 'large'
    if (extended and flags & 0x40 and not flags & 0x400) or (kind == 'ANIMAL' and not extended):
        return (graphic - 200) * 65 + 22000, 13, 'small'
    return (graphic - 400) * 175 + 35000, 35, 'people'

def inferred_mul_kind(graphic, archive):
    if archive == 2:
        return 'MONSTER' if graphic < 200 else 'ANIMAL'
    if archive == 3:
        return 'ANIMAL' if graphic < 300 else 'MONSTER' if graphic < 400 else 'HUMAN'
    return 'MONSTER' if graphic < 200 else 'ANIMAL' if graphic < 400 else 'HUMAN'

def original_mul_groups(data, allowed):
    mobtypes, conversions = {}, {}
    definitions = [('mobtypes.txt', mobtypes), ('Bodyconv.def', conversions)]
    inputs = []
    for name, target in definitions:
        path = data/name
        if not path.exists():
            continue
        inputs.append({'name': name, 'sha256': sha(path), 'bytes': path.stat().st_size})
        for line in path.read_text(encoding='utf-8-sig', errors='replace').splitlines():
            parts = line.split('#', 1)[0].split()
            if not parts or not parts[0].isdigit() or int(parts[0]) not in allowed:
                continue
            body = int(parts[0])
            if target is mobtypes and len(parts) >= 3:
                target[body] = (parts[1].upper(), int(parts[2], 16))
            elif target is conversions:
                target[body] = dict(enumerate(map(int, parts[1:6]), 2))
    records = []
    available = {
        archive: (data/f'{stem}.idx', data/f'{stem}.mul')
        for archive, stem in enumerate(('anim', 'anim2', 'anim3', 'anim4', 'anim5'), 1)
        if (data/f'{stem}.idx').exists() and (data/f'{stem}.mul').exists()
    }
    with ExitStack() as opened:
        for archive, (idx, mul) in available.items():
            inputs.append({'name': idx.name, 'sha256': sha(idx), 'bytes': idx.stat().st_size})
            table, size = idx.read_bytes(), mul.stat().st_size
            stream = opened.enter_context(mul.open('rb'))
            payload_hashes = {}
            for body in sorted(allowed):
                converted = conversions.get(body, {})
                if archive == 1 and any(file in available and graphic >= 0 for file, graphic in converted.items()):
                    continue
                graphic = body if archive == 1 else converted.get(archive, -1)
                if graphic < 0:
                    continue
                kind, flags = mobtypes.get(body, ('UNKNOWN', 0))
                if kind == 'UNKNOWN':
                    kind = inferred_mul_kind(graphic, archive)
                base, groups, layout = mul_layout(graphic, kind, flags)
                if base < 0 or (base + groups * 5) * 12 > len(table):
                    continue
                for group in range(groups):
                    directions = []
                    for direction in range(5):
                        slot = base + group * 5 + direction
                        offset, length, _ = struct.unpack_from('<iii', table, slot * 12)
                        if offset < 0 or length < 520 or offset + length > size:
                            continue
                        stream.seek(offset + 512)
                        frames, = struct.unpack('<I', stream.read(4))
                        if not 0 < frames <= (length - 516) // 4:
                            continue
                        offsets = struct.unpack(f'<{frames}I', stream.read(frames * 4))
                        if all(4 + frames * 4 <= start <= length - 520 for start in offsets):
                            span = (offset, length)
                            if span not in payload_hashes:
                                stream.seek(offset)
                                payload_hashes[span] = hashlib.sha256(stream.read(length)).hexdigest()
                            directions.append({'direction': direction, 'frames': frames,
                                               'offset': offset, 'bytes': length,
                                               'payload_sha256': payload_hashes[span]})
                    if directions:
                        records.append({'body': body, 'graphic': graphic, 'archive': mul.name,
                                        'layout': layout, 'group': group, 'directions': directions,
                                        'mobtype_prefers_uop': bool(flags & 0x10000)})
    return records, inputs, mobtypes

def original_uop_redirect_candidates(sequence, mobtypes, framed, classic_routes):
    candidates = []
    for record in sequence:
        body = record['animation_ref']
        kind, flags = mobtypes.get(body, ('UNKNOWN', 0))
        replacements = record['replacements']
        # The reference loader installs zero-frame redirects only for UOP
        # bodies, and skips redirect tables of these two sizes.
        if kind != 'MONSTER' or not flags & 0x10000 or len(replacements) in (48, 68) or record.get('parse_blocker'):
            continue
        for link in replacements:
            old, target = link['old_group'], link['new_group']
            route = classic_routes.get((body, old))
            if (not route or route['resolved'] is not None or route['native_profile'] != 'monster'
                    or link['frame_count'] != 0 or old == target or (body, target) not in framed):
                continue
            # A real destination record proves archive selection. A resolved
            # client category is still only a candidate for exact reuse.
            target_route = classic_routes.get((body, target), {})
            candidates.append({'body': body, 'classic_slot': old, 'kind': route['kind'],
                               'requested': route['requested'], 'uop_group': target,
                               'destination_clip': target_route.get('resolved')})
    return sorted(candidates, key=lambda row: (row['body'], row['classic_slot']))

def original_mul_shared_routes(mul_groups):
    """Find distinct stored Classic groups that play the same replacement."""
    by_source = {}
    for row in mul_groups:
        route = row.get('matching_classic_route')
        if not route or not route['resolved']:
            continue
        if [direction['direction'] for direction in row['directions']] != list(range(5)):
            continue
        key = (row['body'], row['archive'], row['graphic'], row['layout'], route['resolved'])
        by_source.setdefault(key, []).append(row)
    evidence = []
    for (body, archive, graphic, layout, clip), groups in sorted(by_source.items()):
        for first, second in combinations(sorted(groups, key=lambda row: row['group']), 2):
            if second['group'] in first.get('same_payload_groups', ()):
                continue
            evidence.append({'body': body, 'archive': archive, 'graphic': graphic, 'layout': layout,
                             'classic_slots': [first['group'], second['group']], 'replacement': clip})
    return evidence

def resolve(model,label,fallback):
    authored=model.get('authored_replacements',{}) | model.get('authored_clips',{})
    if model['kind'] in ('energy_vortex', 'sand_vortex'):
        # Both local scenes are built by the same GDScript baker.
        baker=(ROOT/'Viewer/Presentation/BakeEnergyVortex.gd').read_text()
        clip_table=re.search(r'const CLIPS := \{(.*?)\n\}',baker,re.S)
        assert clip_table,'Vortex clip declaration changed'
        authored |= dict.fromkeys(re.findall(r'"(\w+)": \[',clip_table[1]),'Shared vortex shell bake')
    available=(set(model.get('stats',{}).get('original',{}).get('clips',{}))
               | set(model.get('clip_sources',{})) | set(authored) | {'Eat','LieDown'})
    resolved=label;visited=set()
    while resolved not in available and resolved in fallback and resolved not in visited:
        visited.add(resolved);resolved=fallback[resolved]
    if resolved not in available:return {'requested':label,'resolved':None,'status':'Missing replacement'}
    if resolved!=label:status='Runtime category substitute'
    elif label in authored:status='Authored category motion'
    elif label in model.get('category_aliases',{}):status='Prepared clip alias'
    elif label=='LieDown':status='Runtime copy of Death clip'
    elif label in model.get('clip_sources',{}):status='Recovered source clip'
    else:status='Runtime authored pose/category'
    return {'requested':label,'resolved':resolved,'status':status,
            'source_member':model.get('clip_sources',{}).get(resolved),
            'declared_alias':model.get('category_aliases',{}).get(resolved) or ('Death' if label=='LieDown' else None),
            'authored_method':authored.get(resolved)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--data-dir',type=Path);args=parser.parse_args()
    catalogue=json.loads((OUT/'catalogue.json').read_text())
    models=json.loads((ART/'accepted-index.json').read_text())['entries']
    public=ROOT/'Viewer/Art/Creatures/index.json'
    if public.exists():models=[row for row in json.loads(public.read_text())['entries'] if row.get('status')=='validated']+models
    maps,renderer_sha=renderer_maps();rows=[];native={}
    for model in models:
        for identity in model['bodies']:
            body=int(identity['body']);native[body]=model
            profile=identity.get('native_profile') or model['profile']
            for protocol,groups in [('classic',maps['small' if profile=='animal' else 'sea' if profile=='sea' else 'large']),('new',maps['new'])]:
                if protocol=='classic':
                    overrides = model.get('classic_action_categories', {}) | model.get('classic_action_categories_by_body', {}).get(str(body), {})
                    groups = groups | {int(key): value for key, value in overrides.items()}
                if protocol=='new':groups={**groups,**{int(key):value for key,value in model.get('new_action_categories',{}).items()}}
                for group,label in groups.items():
                    rows.append({'body':body,'family':model['family'],'kind':model['kind'],'native_profile':profile,
                                 'protocol':protocol,'group_or_type':group,**resolve(model,label,maps['fallback'])})
    data=args.data_dir
    config=ROOT/'Server/runtime/Configuration/modernuo.json'
    if data is None and config.exists():
        directories=json.loads(config.read_text(encoding='utf-8-sig')).get('dataDirectories',[])
        if directories:data=Path(directories[0])
    sequence=[];archives=[];frame_groups=[];mul_groups=[];mobtypes={}
    if data:
        spec=importlib.util.spec_from_file_location('creature_sequences',ROOT/'scripts/uo-human-sequences.py')
        reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
        path=data/'AnimationSequence.uop'
        allowed={r['body'] for r in catalogue['native_targets']}
        if path.exists():
            sequence=reader.inspect(path,allowed)
            archives.append({'name':path.name,'sha256':sha(path),'bytes':path.stat().st_size})
        frame_groups, frame_archives=original_frame_groups(data, allowed, reader)
        archives.extend(frame_archives)
        mul_groups, mul_inputs, mobtypes=original_mul_groups(data, allowed)
        archives.extend(mul_inputs)
    framed={(row['body'],row['group']) for row in frame_groups if row['frame_headers'] is not None}
    classic_routes = {(row['body'], row['group_or_type']): row for row in rows if row['protocol'] == 'classic'}
    redirect_candidates = original_uop_redirect_candidates(sequence, mobtypes, framed, classic_routes)
    native_layouts = {'monster': 'large', 'animal': 'small', 'sea': 'sea'}
    mul_equivalents = {}
    for row in mul_groups:
        route = classic_routes.get((row['body'], row['group']))
        if (route and not row['mobtype_prefers_uop']
                and native_layouts.get(route['native_profile']) == row['layout']):
            row['matching_classic_route'] = {field: route[field] for field in ('requested', 'resolved', 'status')}
        if len(row['directions']) == 5:
            signature = tuple(direction['payload_sha256'] for direction in row['directions'])
            key = (row['body'], row['archive'], row['graphic'], row['layout'], signature)
            mul_equivalents.setdefault(key, []).append(row)
    for matches in mul_equivalents.values():
        if len(matches) < 2:
            continue
        for row in matches:
            row['same_payload_groups'] = [match['group'] for match in matches if match is not row]
    shared_routes = original_mul_shared_routes(mul_groups)
    original=[];new_actions=[]
    for record in sequence:
        body=record['animation_ref'];model=native.get(body)
        # AnimationSequence UOP group IDs are not the classic low/sea wire
        # slots (dolphin metadata includes canonical swimming groups 22..28).
        # Keep that evidence unresolved rather than labelling a breach death.
        groups=maps['large'] if model and model['profile']=='monster' else {}
        for source in record['replacements']:
            group=source['old_group'];label=groups.get(group)
            original.append({'body':body,**source,
                             'generic_replacement':resolve(model,label,maps['fallback']) if model and label else None,
                             'interpretation':'High-group category inference only; frame availability/precedence not decoded' if groups else 'Canonical UOP-to-native wire group interpretation unresolved'})
        for mode in record['modes']:
            for action in mode['new_protocol_actions']:
                label=(model.get('new_action_categories',{}).get(str(action['type'])) if model else None) or maps['new'].get(action['type'])
                if model and model['profile']=='sea' and action['type']==0 and mode['mode']%2:label='Attack2'
                new_actions.append({'body':body,'mode':mode['mode'],**action,
                    'groups_with_uop_frame_headers':[group for group in action['groups'] if (body,group) in framed],
                    'generic_model':model['kind'] if model else None,
                    'replacement':resolve(model,label,maps['fallback']) if model and label else None,
                    'scope':'Type route only; exact per-body mode/subaction/variation fidelity requires separate tests.'})
    # Keep the broad protocol ledger separate from work backed by an installed
    # frame record. A numeric UOP match still needs a wire-category review.
    frame_gaps = {}
    for row in mul_groups:
        route = row.get('matching_classic_route')
        if route is not None and route['resolved'] is None:
            key = (row['body'], row['group'])
            frame_gaps.setdefault(key, []).append({
                'archive': row['archive'], 'evidence': 'Matching classic MUL layout',
                'graphic': row['graphic'], 'directions': len(row['directions']),
            })
    for row in frame_groups:
        key = (row['body'], row['group'])
        route = classic_routes.get(key)
        if row['frame_headers'] is not None and route is not None and route['resolved'] is None:
            frame_gaps.setdefault(key, []).append({
                'archive': row['archive'], 'evidence': 'Canonical UOP group with same numeric slot',
                'frame_headers': row['frame_headers'],
            })
    source_frame_gaps = [
        {'body': body, 'classic_slot': slot, 'kind': classic_routes[body, slot]['kind'],
         'requested': classic_routes[body, slot]['requested'], 'sources': sources}
        for (body, slot), sources in sorted(frame_gaps.items())
    ]
    counts={'generic_models':len(models),'generic_body_routes':len(native),'protocol_slots':len(rows),
            'routable_slots':sum(r['resolved'] is not None for r in rows),
            'missing_protocol_slots':sum(r['resolved'] is None for r in rows),
            'unresolved_slots_with_source_frame_evidence':len(source_frame_gaps),
            'mul_shared_replacement_candidate_pairs':len({(row['body'], *row['classic_slots']) for row in shared_routes}),
            'unresolved_classic_uop_redirect_candidates':len(redirect_candidates),
            'unresolved_classic_uop_redirects_with_routable_destination':sum(
                row['destination_clip'] is not None for row in redirect_candidates),
            'original_sequence_records':len(sequence),'original_sequence_parse_blockers':sum(bool(r.get('parse_blocker')) or r['unparsed_bytes']!=0 for r in sequence),
            'original_new_protocol_entries':len(new_actions),
            'original_uop_frame_groups':len(framed),
            'original_uop_frame_bodies':len({body for body,group in framed}),
            'original_uop_frame_header_blockers':sum(row['frame_headers'] is None for row in frame_groups),
            'original_mul_group_candidates':len(mul_groups),
            'original_mul_candidate_bodies':len({row['body'] for row in mul_groups}),
            'original_mul_candidates_with_matching_classic_slots':sum('matching_classic_route' in row for row in mul_groups),
            'original_mul_candidates_with_identical_group_payloads':sum('same_payload_groups' in row for row in mul_groups),
            'original_new_entries_without_generic_model':sum(not r['generic_model'] for r in new_actions),
            'original_new_entries_with_generic_route':sum(bool(r['replacement'] and r['replacement']['resolved']) for r in new_actions),
            'original_new_entries_total_without_generic_route':sum(not (r['replacement'] and r['replacement']['resolved']) for r in new_actions),
            'original_new_entries_without_generic_route':sum(bool(r['generic_model']) and not (r['replacement'] and r['replacement']['resolved']) for r in new_actions)}
    assert counts['original_new_entries_with_generic_route']+counts['original_new_entries_total_without_generic_route']==len(new_actions)
    assert counts['original_new_entries_without_generic_model']+counts['original_new_entries_without_generic_route']==counts['original_new_entries_total_without_generic_route']
    scope=('Generic creature renderer protocol slots only; distinct from original per-body required actions and choreography quality. '
           'Source clips, aliases, authored motions and missing routes remain explicit. Original UOP sequence metadata is recorded separately; '
           'UOP frame headers are inventoried by canonical group. MUL candidates use direct and Bodyconv slots; they do not establish Body.def or UOP precedence. '
           'Shared replacement candidates compare ordered payload hashes across five stored directions. Different hashes prompt a visual comparison. Frame pixels are not decoded. Humans and earlier mount/bovine action ledgers are separate. '
           'The historical original_new_entries_without_generic_route counter covers already routed bodies only; the explicit total counter also includes entries on bodies without any generic model. '
           'Those bodies can include specialized human/mount presenters; this is not a global missing-animation total or choreography completion percentage.')
    report={'counts':counts,'scope':scope,'renderer_sha256':renderer_sha,'archives':archives,'routes':rows,
            'original_sequence_metadata':sequence,'original_group_links':original,
            'original_uop_frame_groups':frame_groups,'original_mul_group_candidates':mul_groups,
            'source_frame_gaps':source_frame_gaps,
            'original_mul_shared_replacement_candidates':shared_routes,
            'original_uop_redirect_candidates':redirect_candidates,
            'original_new_protocol_actions':new_actions}
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'actions.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    table=''.join('<tr><td>0x%X</td><td>%s</td><td>%s %s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%
        (r['body'],html.escape(r['kind']),r['protocol'],r['group_or_type'],r['requested'],r['resolved'] or '—',r['status']) for r in rows)
    (OUT/'actions.html').write_text('<!doctype html><meta charset="utf-8"><title>Creature action ledger</title><style>body{background:#20303a;color:#eee;font:16px system-ui;padding:24px}td,th{padding:8px;border-bottom:1px solid #64717a;text-align:left}a{color:#dfce95}</style><h1>Creature action ledger</h1><p>'+html.escape(scope)+'</p><p>'+html.escape(str(counts))+'</p><p><a href="actions.json">Full evidence and original sequence metadata</a> · <a href="index.html">Creature work board</a></p><table><tr><th>Body</th><th>Source form</th><th>Protocol slot</th><th>Requested category</th><th>Replacement</th><th>Evidence kind</th></tr>'+table+'</table>',encoding='utf-8')
    print('CREATURE ACTION LEDGER:',counts)
if __name__=='__main__':main()
