"""Install the three source-backed Troglodyte motions after validating their local evidence."""

import argparse
import hashlib
from itertools import product
import json
from pathlib import Path
import runpy
import shutil


SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
FAMILY = 'troglodyte_enhanced_01'
NATIVE = ROOT / 'work/creatures/troglodyte-enhanced/native'
EVIDENCE = ROOT / 'work/creatures' / FAMILY
WORK = ROOT / 'work/creatures/native-form-audit/enhanced-source-gaps'
SEALED = EVIDENCE / 'accepted'
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
ROUTES = {'8': (28, 'TroglodyteOpenReach'), '11': (4, 'TroglodyteHighSweep'),
          '15': (23, 'TroglodyteLowRecoil')}
# The same Classic-compatible type 8 packet already has a proven Pillage
# route. Keep the Enhanced group fitted until the client can distinguish it.
ACTIVE_ROUTES = ('11', '15')
PAYLOADS = {
    4: (45, '2e24759c6e4668bc9d5e9295a862bc2ca5663f260e42927b61e3711957888569'),
    23: (40, 'e3ac1d804a734ee945e4dccf7054593b0ec6de06bd885d75be1c4fbae49edb9e'),
    28: (35, '068c979cd9efe5e2a983b2c16febe66daaf66f3c4553b1c4bda4eab01c995f04'),
}
IDENTITIES = {'Troglodyte': 0, 'Lurg': 1109}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def checked_source():
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    names = runpy.run_path(str(SCRIPTS / 'audit-classic-parity.py'))['name_hash']
    points = runpy.run_path(str(SCRIPTS / 'prepare-halberd-uop-fit.py'))['sprite_points']
    heights = runpy.run_path(str(SCRIPTS / 'prepare-preferred-uop-actions.py'))['registered_heights']
    sequence, = reader['inspect'](data / 'AnimationSequence.uop', {267})
    modes = {mode['mode']: mode for mode in sequence['modes']}
    assert sorted(modes) == [0, 1] and modes[1]['fallback_mode'] == 0
    for packet, (group, _) in ROUTES.items():
        options = [action for action in modes[0]['new_protocol_actions'] if action['type'] == int(packet)]
        assert len(options) == 1 and options[0]['subaction'] == -1 and set(options[0]['groups']) == {group}
        assert not any(action['type'] == int(packet) for action in modes[1]['new_protocol_actions'])
    choices = [next(row['groups'] for row in mode['new_protocol_actions'] if row['type'] == 5)
               for mode in modes.values()]
    assert choices == [[26, 27], [26]]
    hashes = {names(f'build/animationlegacyframe/000267/{group:02d}.bin'): group for group in PAYLOADS}
    measured = {}
    for digest, raw in reader['payloads'](data / 'AnimationFrame1.uop', hashes):
        group = hashes[digest]
        count, pin = PAYLOADS[group]
        assert hashlib.sha256(raw).hexdigest() == pin
        samples = heights(raw, group, {'frame_headers': count}, points)
        measured[group] = {'frame_count': count, 'sha256': pin, 'median_registered_height': samples}
    assert measured.keys() == PAYLOADS.keys()
    return measured


def checked_wire(folder, report_path, require_index):
    receipt = read(folder / 'native-runtime.json')
    report = read(report_path)
    assert report['prepared_trial'] and report['checks'] == 115 and report['failures'] == 0
    if require_index:
        assert report['accepted_index_sha256'] == sha(INDEX)
    assert report['candidate_sha256'] == receipt['candidate_sha256'] == sha(folder / 'candidates.json')
    assert receipt['report_sha256'] == sha(report_path)
    assert report['test_sha256'] == sha(NATIVE / 'ClassicGestureBridgeLive.gd')
    assert report['routes_sha256'] == sha(NATIVE / FAMILY / 'routes.json')
    assert report['dispatcher_sha256'] == sha(ROOT / 'Viewer/Presentation/NativeMobileActions.gd')
    fixture = NATIVE / 'fixture/ClassicWireFixtures.cs'
    assert receipt['build_inputs_sha256'][fixture.relative_to(ROOT).as_posix()] == sha(fixture)
    for name in ('Server.dll', 'Assemblies/UOContent.dll'):
        assert receipt['assemblies_sha256'][name] == sha(ROOT / 'Server/runtime' / name)
    assert receipt['selector_sha256'] == sha(NATIVE / 'prepare-bridge-fixtures.py')
    assert receipt['runner_sha256'] == sha(NATIVE / 'test-native-bridge.ps1')
    candidates = read(folder / 'candidates.json')
    candidate = candidates[0]['presentation']
    assert {row['native_class'] for row in candidates} == IDENTITIES.keys() and len(candidates) == len(IDENTITIES)
    assert all(row['presentation'] == candidate for row in candidates)
    for treatment, path in candidate['assets'].items():
        assert sha(ROOT / 'Viewer' / path.removeprefix('res://')) == candidate['asset_sha256'][treatment]
    actors = {record['serial']: record for record in report['records']}
    assert len(actors) == len(report['records']) == 4
    assert {(record['native_class'], record['female']) for record in actors.values()} == set(product(IDENTITIES, (False, True)))
    assert all(row['body'] == 267 and row['native_hue'] == IDENTITIES[row['native_class']] for row in actors.values())
    tested = set()
    for witness in report['classic_wire_witnesses']:
        serial, kind, mode = witness['serial'], witness['type'], witness['mode']
        record = actors[serial]
        assert record['female'] == witness['female'] and witness['body'] == 267
        assert witness['clip'] == ROUTES[str(kind)][1] and len(witness['packets']) == 2
        for packet in witness['packets']:
            assert (packet['serial'], packet['body'], packet['type'], packet['subaction'], packet['variation'], packet['protocol']) == (
                serial, 267, kind, 0, mode, 'new')
        tested.add((serial, str(kind), mode))
    assert len(report['classic_wire_witnesses']) == len(tested) == 24
    assert tested == set(product(actors, ROUTES, (0, 1)))
    return candidate, {'checks': report['checks'], 'witnesses': len(tested), 'report_sha256': sha(report_path),
                       'runtime_sha256': sha(folder / 'native-runtime.json')}


def fitted(base, folder, report_path, client_path, require_index=False):
    source = checked_source()
    candidate, wire = checked_wire(folder, report_path, require_index)
    assert base['kind'] == 'troglodyte' and [b['body'] for b in base['bodies']] == [267]
    assert base['classic_gesture_batch'] == 'quagmire_through_exodus_actions'
    names = {key: clip for key, (_, clip) in ROUTES.items()}
    source_assets = base['assets']
    source_hashes = {key: sha(ROOT / 'Viewer' / path.removeprefix('res://')) for key, path in source_assets.items()}
    assert source_hashes == base['asset_sha256'] == base['authored_action_scene_sha256']
    assert not base['new_action_categories'].keys() & names.keys()
    assert candidate == dict(base, status='prepared', family=FAMILY, assets=candidate['assets'],
                             asset_sha256=candidate['asset_sha256'],
                             new_action_categories=base['new_action_categories'] | names,
                             archive_grounded_gestures=base['archive_grounded_gestures'] + list(names.values()))
    for treatment in ('original', 'rounded', 'modern'):
        assert candidate['assets'][treatment] == f'res://local-art/creatures/troglodyte-enhanced-{treatment}.scn'
    client = read(client_path)
    assert client['scenes'] == candidate['asset_sha256']
    assert client['test_sha256'] == sha(SCRIPTS / 'test-troglodyte-enhanced.gd')
    assert (client['routes'], client['terrain'], client['corpses']) == (36, 1674, 3)
    assert client['minimum_gap'] > .0019
    groups = {kind: str(ROUTES[kind][0]) for kind in ACTIVE_ROUTES}
    authored = {clip: f'Fitted to the five registered Enhanced UOP directions for group {group}'
                for group, clip in ROUTES.values()}
    layer = {'source_assets': source_assets, 'source_sha256': source_hashes, 'archive': 'AnimationFrame1.uop',
             'groups': source, 'wire': wire, 'client_sha256': sha(client_path),
             'retained_classic_wire': {'8': 'Pillage'},
             'baker_sha256': sha(SCRIPTS / 'bake-troglodyte-enhanced.gd')}
    # JSON object keys are strings on disk.
    layer['groups'] = {str(group): proof for group, proof in source.items()}
    return dict(candidate, status='validated', family=base['family'],
                authored_action_scene_sha256=candidate['asset_sha256'],
                authored_replacements=base['authored_replacements'] | authored,
                new_action_categories=base['new_action_categories'] | {kind: names[kind] for kind in ACTIVE_ROUTES},
                uop_motion_packet_groups=base.get('uop_motion_packet_groups', {}) | groups,
                troglodyte_enhanced=layer)


def without_fit(row):
    if 'troglodyte_gaits' in row:
        without_gaits = runpy.run_path(str(SCRIPTS / 'accept-troglodyte-gaits.py'))['without_gaits']
        row = without_gaits(row)
    base = read(SEALED / 'base.json')
    assert fitted(base, SEALED, SEALED / 'live.json', SEALED / 'client.json') == row
    return base


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true', help='Install the checked local scenes')
    args = parser.parse_args()
    previous = INDEX.read_bytes()
    index = json.loads(previous)
    row, = (row for row in index['entries'] if row['status'] == 'validated' and row['kind'] == 'troglodyte')
    if 'troglodyte_enhanced' in row:
        without_fit(row)
        print('TROGLODYTE ENHANCED: active and verified')
        return
    if not args.activate:
        raise SystemExit('The verified Troglodyte scenes have not been activated')
    report = ROOT / 'outputs/creatures' / FAMILY / 'live.json'
    client = WORK / 'troglodyte-client.json'
    replacement = fitted(row, EVIDENCE, report, client, require_index=True)
    SEALED.mkdir(parents=True, exist_ok=True)
    for source, name in ((report, 'live.json'), (client, 'client.json'),
                         (EVIDENCE / 'native-runtime.json', 'native-runtime.json'), (EVIDENCE / 'candidates.json', 'candidates.json')):
        shutil.copyfile(source, SEALED / name)
    (SEALED / 'base.json').write_text(json.dumps(row, indent=2) + '\n', encoding='utf-8')
    assert without_fit(replacement) == row
    temporary = INDEX.with_suffix('.troglodyte.tmp')
    index['entries'][index['entries'].index(row)] = replacement
    temporary.write_text(json.dumps(index, indent=2) + '\n', encoding='utf-8')
    if INDEX.read_bytes() != previous:
        raise SystemExit('The local creature index changed during verification')
    temporary.replace(INDEX)
    print('TROGLODYTE ENHANCED: two source groups active, open reach kept for the Enhanced route')


if __name__ == '__main__':
    main()
