"""Read-only creature work order from the configured world's native spawners.

Estimated slots are a capped probability-weighted capacity proxy, not a live
census, encounter rate, or exact equilibrium population. Coordinates stay out
of the generated report; raw spawn inputs and reports remain local.
"""
import argparse, collections, hashlib, html, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLASS = re.compile(r'\bpublic\s+(?P<mods>(?:(?:abstract|sealed|partial|static|new)\s+)*)class\s+(?P<name>\w+)(?:<[^>{}]+>)?\s*(?::\s*(?P<base>[\w.]+))?')

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def allocate(count, entries):
    """Share the common capacity by weight, redistributing saturated caps."""
    active = {i for i, e in enumerate(entries) if e.get('probability', 100) > 0 and e.get('maxCount', 1) > 0}
    remaining = max(0, count)
    result = [0.] * len(entries)
    while active and remaining > 1e-10:
        weight = sum(entries[i].get('probability', 100) for i in active)
        capped = {i for i in active if remaining * entries[i].get('probability', 100) / weight >= entries[i].get('maxCount', 1)}
        if not capped:
            for i in active:
                result[i] = remaining * entries[i].get('probability', 100) / weight
            break
        for i in capped:
            result[i] = entries[i].get('maxCount', 1)
            remaining -= result[i]
        active -= capped
    return result

def class_index(source):
    classes = {}
    paths = [p for project in ['UOContent', 'Server'] for p in (source / 'Projects' / project).rglob('*.cs')]
    for path in sorted(paths):
        if set(path.relative_to(source).parts) & {'obj', 'bin'}:
            continue
        text = path.read_text(encoding='utf-8-sig')
        for match in CLASS.finditer(text):
            name = match['name']
            row = classes.setdefault(name.casefold(), {'name': name, 'base': None, 'paths': [], 'abstract': False})
            if match['base']:
                parent = match['base'].rsplit('.', 1)[-1]
                if row['base'] not in [None, parent]:
                    row['ambiguous'] = True
                row['base'] = parent
            row['paths'].append(path.relative_to(source).as_posix())
            row['abstract'] |= 'abstract' in match['mods'].split()
    return classes

def ancestors(name, classes):
    chain = []
    while name and name.casefold() not in chain:
        key = name.casefold()
        chain.append(key)
        name = classes.get(key, {}).get('base')
    return chain

def source_files(folder, era, maps):
    return sorted(p for group in ['shared', era] for facet in maps
                  for p in (folder / group / facet).glob('*.json'))

def occurrences(files, maps):
    rows = {}; seen = set(); spawners = 0
    for path in files:
        for spawn in read(path):
            if str(spawn.get('map', '')).casefold() not in maps:
                continue
            key = (str(spawn['map']).casefold(), spawn['guid'])
            if key in seen:
                raise ValueError('Duplicate active spawner GUID; refuse double-counting')
            seen.add(key)
            spawners += 1
            entries = spawn.get('entries', [])
            shares = allocate(spawn.get('count', 0), entries)
            present = set()
            for entry, share in zip(entries, shares):
                if share <= 0:
                    continue
                name = entry['name']
                row = rows.setdefault(name.casefold(), {'name': name, 'estimated_slots': 0., 'spawn_locations': 0, 'files': set()})
                row['estimated_slots'] += share
                row['files'].add(path.name)
                present.add(name.casefold())
            for name in present:
                rows[name]['spawn_locations'] += 1
    return rows, spawners

def literal_registry(path, constant):
    match = re.search(r'const ' + constant + r'\s*:?=\s*\{(.*?)\}', path.read_text(encoding='utf-8'), re.S)
    return {int(v, 16) for v in re.findall(r'(0x[\da-fA-F]+)\s*:', match[1])} if match else set()

def missing_routes(bodies, routed, witnessed):
    # Mixed creature constructors can select the specialized human presenter.
    # Only this named constructor's actual human witnesses close those gaps;
    # generic creature routes and another class's human evidence cannot do so.
    return bodies - routed.keys() - (witnessed & {400, 401, 402, 403})

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--maps', nargs='+', default=['trammel'])
    parser.add_argument('--output', type=Path, default=ROOT / 'outputs/creatures/frequency.json')
    args = parser.parse_args()
    maps = {v.casefold() for v in args.maps}
    if not maps <= {'trammel', 'felucca', 'ilshenar', 'malas', 'tokuno', 'termur'}:
        parser.error('Unknown native facet')
    source = ROOT / 'Server/ModernUO'
    expansion_path = ROOT / 'Server/runtime/Configuration/expansion.json'
    expansion = read(expansion_path)
    era = 'post-uoml' if expansion['SupportedFeatures'].get('SA', False) else 'uoml'
    files = source_files(ROOT / 'Server/runtime/Data/Spawns', era, maps)
    if not files:
        raise ValueError('No active spawn definitions')
    classes = class_index(source)
    raw, count = occurrences(files, maps)
    art = ROOT / 'Viewer/local-art/creatures'
    index = read(art / 'source-index.json')
    accepted = read(art / 'accepted-index.json')['entries']
    public = ROOT / 'Viewer/Art/Creatures/index.json'
    if public.exists():accepted = [row for row in read(public)['entries'] if row.get('status')=='validated'] + accepted
    routed = {int(b['body']): row['kind'] for row in accepted for b in row['bodies']}
    for file, constants in [('EquineRegistry.gd', ['BODIES', 'COMPATIBILITY', 'DISTINCT']), ('MountVisual.gd', ['BODIES']), ('AnimalVisual.gd', ['BODIES'])]:
        for constant in constants:
            for body in literal_registry(ROOT / 'Viewer/Presentation' / file, constant):
                routed.setdefault(body, 'existing equine/llama/bovine route')
    paths_to_bodies = collections.defaultdict(set)
    for body, sources in index['native_literal_bodies'].items():
        for record in sources:
            paths_to_bodies[record['path'].replace('\\', '/')].add(int(body))
    witnessed = collections.defaultdict(set)
    body_evidence = set()
    for path in sorted((ROOT / 'outputs').glob('**/*live*.json')):
        report = read(path)
        if report.get('failures') != 0:
            continue
        for record in report.get('records', []):
            if 'body' not in record or record.get('ethereal'):
                continue
            body_evidence.add(int(record['body']))
            if record.get('native_class'):
                witnessed[record['native_class'].casefold()].add(int(record['body']))
    rows = []; excluded = []; unresolved = []
    human_groups = {'Vendors', 'Townfolk', 'Hireables', 'Healers', 'Guards'}
    for key, row in raw.items():
        chain = ancestors(row['name'], classes)
        if 'mobile' not in chain:
            (excluded if 'item' in chain else unresolved).append(row['name'])
            continue
        info = classes[key]
        human = any(set(p.split('/')) & human_groups for c in chain for p in classes.get(c, {}).get('paths', []))
        bodies = set(); mapping = 'unresolved'
        for c in chain:
            bodies = set().union(*(paths_to_bodies[p] for p in classes.get(c, {}).get('paths', [])))
            if bodies:
                mapping = 'literal source file' if c == key else 'inherited literal candidates'
                break
        human |= bool(bodies) and bodies <= {400, 401, 402, 403}
        missing = missing_routes(bodies, routed, witnessed[key])
        state = 'shared human graphics; race/cosmetics audit separate' if human else 'unrouted' if bodies and missing == bodies else 'partial route' if missing else 'body route present; fidelity/action work remains' if bodies else 'identity needs audit'
        row.update(estimated_slots=round(row['estimated_slots'], 6), files=sorted(row['files']),
                   body_candidates=sorted(bodies), body_mapping=mapping, missing_body_routes=sorted(missing),
                   graphics=state, human=human, witnessed_constructor_bodies=sorted(witnessed[key]),
                   specialized_human_bodies_with_native_evidence=sorted(bodies & witnessed[key] & {400,401,402,403}),
                   bodies_with_native_evidence=sorted(bodies & body_evidence), source_paths=info['paths'])
        rows.append(row)
    rows.sort(key=lambda r: (-r['estimated_slots'], -r['spawn_locations'], r['name'].casefold()))
    for rank, row in enumerate(rows, 1):
        row['rank'] = rank
    creatures = [r for r in rows if not r['human']]
    for rank, row in enumerate(creatures, 1):
        row['creature_rank'] = rank
    queue = [r['name'] for r in creatures if r['graphics'] in ['unrouted', 'partial route', 'identity needs audit']]
    result = {'maps': sorted(maps), 'era': era, 'server_pin': index['server_pin'], 'active_spawners': count,
              'scope': 'Configured spawn frequency, not a live full-world census. Rank by capped probability-weighted shared capacity; spawn-location counts are exact. Capacity is an exposure proxy, not an exact random draw expectation or equilibrium population. Items compete for slots before being excluded. Indirect camp/quest/summon spawns, death rates, terrain failures and manual placements are not counted. Existing routes are not final fidelity/action completion.',
              'inputs': {str(p.relative_to(ROOT)): sha(p) for p in [expansion_path, *files]},
              'rows': rows, 'next_unrouted_creatures': queue, 'excluded_items': sorted(excluded), 'unresolved_types': sorted(unresolved)}
    result['creature_work_order'] = [r['name'] for r in creatures]
    measured_bodies = {body for row in creatures for body in row['body_candidates']}
    result['unmeasured_native_bodies'] = [
        {'body': int(body), 'graphics': routed.get(int(body)), 'sources': sources,
         'occurrence': 'Not resolved to a directly configured spawn type; frequency unknown, not zero.'}
        for body, sources in sorted(index['native_literal_bodies'].items(), key=lambda pair: int(pair[0]))
        if index['native_profiles'].get(body) in ['animal', 'monster', 'sea'] and int(body) not in measured_bodies]
    result['source_index_sha256'] = sha(art / 'source-index.json')
    result['accepted_index_sha256'] = sha(art / 'accepted-index.json')
    if public.exists():result['public_index_sha256'] = sha(public)
    result['recipe_sha256'] = sha(Path(__file__))
    result['unresolved_occurrences'] = [{**raw[n.casefold()], 'files': sorted(raw[n.casefold()]['files'])} for n in sorted(unresolved)]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    table = ''.join('<tr><td>%s</td><td>%s</td><td>%s</td><td>%.1f</td><td>%s</td></tr>' %
                    (r['creature_rank'], html.escape(r['name']), r['spawn_locations'], r['estimated_slots'], html.escape(r['graphics'])) for r in creatures)
    args.output.with_suffix('.html').write_text('<!doctype html><meta charset="utf-8"><title>Creature occurrence order</title><style>body{background:#20303a;color:#e9edef;font:16px system-ui;margin:30px}td,th{text-align:left;padding:8px;border-bottom:1px solid #52616b}table{border-collapse:collapse}p{max-width:1000px;line-height:1.5}</style><h1>Creature work order: '+html.escape(', '.join(sorted(maps)))+'</h1><p>'+html.escape(result['scope'])+'</p><p>Next missing replacements: '+html.escape(', '.join(queue[:20]))+'</p><table><tr><th>Rank</th><th>Native type</th><th>Spawn locations</th><th>Estimated shared slots</th><th>Current graphics</th></tr>'+table+'</table>', encoding='utf-8')
    print('CREATURE OCCURRENCE ORDER:', count, 'active spawners;', len(creatures), 'non-human mobile types;', len(unresolved), 'unresolved types')
    print('NEXT MISSING REPLACEMENTS:', ', '.join(queue[:20]))

if __name__ == '__main__':
    main()
