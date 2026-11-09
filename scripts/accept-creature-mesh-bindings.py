"""Install three checked mesh-local skin repairs without discarding older action evidence."""

import argparse
import hashlib
from itertools import product
import json
from pathlib import Path
import runpy
import shutil


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
PROOFS = ROOT / 'work/creatures/mesh-bindings/accepted-native'
TRIALS = {
    'centaur_bow_trial': {
        'classes': {101: {'Centaur', 'Twaulo'}}, 'checks': 372,
        'script': 'work/creatures/centaur-bow-trial/isolated-client/Network/CentaurBowNativeLive.gd',
        'fixture': 'work/creatures/centaur-bow-trial/fixtures/CreatureFixtures.cs',
    },
    'doom_binding_trial': {
        'classes': {311: {'ShadowKnight'}, 314: {'Ravager'}}, 'checks': 348,
        'script': 'work/creatures/mul-motion-review/classic-gesture-bridge/DoomBindingNativeLive.gd',
        'fixture': 'Server/HorseIntegrationFixtures/CreatureFixtures.cs',
    },
}
TREATMENTS = ('original', 'rounded', 'modern')
BODY_FILES = {101: 'centaur-binding-trial/centaur-skin-actions-',
              311: 'doom-binding-trial/doom-skin-311-actions-',
              314: 'doom-binding-trial/doom-skin-314-actions-'}
BOW = 'res://local-art/creatures/centaur-bow/weapon-bow-original.gltf'
BOW_SHA = '339076ed72db7854039179e03a6516284077bfb09491573f30c11af86a4bf85c'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def resource(path):
    assert path.startswith('res://') and '..' not in Path(path.removeprefix('res://')).parts
    return ROOT / 'Viewer' / path.removeprefix('res://')


def body_id(row):
    return int(row['bodies'][0]['body']) if len(row['bodies']) == 1 else -1


def evidence_paths(trial, sealed):
    work = PROOFS / trial if sealed else ROOT / 'work/creatures' / trial
    report = work / 'live.json' if sealed else ROOT / 'outputs/creatures' / trial / 'live.json'
    test = work / 'client-test.gd' if sealed else ROOT / TRIALS[trial]['script']
    return report, work / 'native-runtime.json', work / 'candidates.json', test


def checked_native(trial, sealed):
    rule = TRIALS[trial]
    report_path, runtime_path, candidates_path, test_path = evidence_paths(trial, sealed)
    report, runtime, candidates = map(read, (report_path, runtime_path, candidates_path))
    if not sealed:
        assert report['accepted_index_sha256'] == sha(INDEX)
    assert not report['failures'] and not report['prepared_trial'] and report['checks'] == rule['checks']
    assert sha(report_path) == runtime['report_sha256']
    assert sha(candidates_path) == report['candidate_sha256'] == runtime['candidate_sha256']
    assert sha(test_path) == report['test_sha256']
    assert report['base_test_sha256'] == sha(ROOT / 'Viewer/Network/CreatureLive.gd')
    assert report['fixture_sha256'] == runtime['build_inputs_sha256'][rule['fixture']]
    if not sealed:
        assert report['fixture_sha256'] == sha(ROOT / rule['fixture'])
    assert runtime['assemblies_sha256']['Server.dll'] == sha(ROOT / 'Server/runtime/Server.dll')
    content = ROOT / 'Server/ModernUO/Distribution/Assemblies/UOContent.dll'
    assert runtime['assemblies_sha256']['Assemblies/UOContent.dll'] == runtime['reviewed_content_sha256'] == sha(content)
    classes = {(body, name) for body, names in rule['classes'].items() for name in names}
    assert len(candidates) == len(classes) and {(int(row['body']), row['native_class']) for row in candidates} == classes
    expected = {(body, name, female) for (body, name), female in product(classes, (False, True))}
    records = report['records']
    assert len(records) == len(expected) and {(int(row['body']), row['native_class'], row['female']) for row in records} == expected
    for row in records:
        assert row['native_state'] == 'constructor' and row['death_clip'] == 'Death'
        assert not row['corpse_suppressed'] and not row['native_death_refused'] and row['actions']
        for action in row['actions']:
            assert action['owner_clip'] == action['observer_clip'] and action['owner_clip']
            assert action['owner_packet'] == action['observer_packet']
    assert set(report['binding_inputs']) == set(map(str, rule['classes']))
    return report['binding_inputs'], sha(report_path)


def compose(base, inputs, native_sha, renderer_path=None):
    body = body_id(base)
    assets = {treatment: 'res://local-art/creatures/' + BODY_FILES[body] + treatment + '.scn'
              for treatment in TREATMENTS}
    digests = {treatment: sha(resource(path)) for treatment, path in assets.items()}
    renderer = 'res://Presentation/CentaurBowVisual.gd' if body == 101 else base['presentation_script']
    script_sha = sha(renderer_path or resource(renderer))
    assert inputs == {'scenes': digests, 'renderer': script_sha}
    dependencies = dict(base.get('art_dependency_sha256', {}))
    if body == 101:
        assert sha(resource(BOW)) == BOW_SHA
        dependencies[BOW] = BOW_SHA
    return dict(base, assets=assets, asset_sha256=digests, art_dependency_sha256=dependencies,
                presentation_script=renderer, presentation_script_sha256=script_sha,
                mesh_binding_native_sha256=native_sha)


def checked_rows(bases, sealed):
    assert {body_id(base) for base in bases} == BODY_FILES.keys() and len(bases) == len(BODY_FILES)
    results = {}
    for trial in TRIALS:
        inputs, native_sha = checked_native(trial, sealed)
        for base in bases:
            body = body_id(base)
            if str(body) in inputs:
                results[body] = compose(base, inputs[str(body)], native_sha)
    return [results[body] for body in BODY_FILES]


def retained(row):
    if 'mesh_binding_native_sha256' not in row:
        return row
    body = body_id(row)
    base, = (item for item in read(PROOFS / 'base-rows.json') if body_id(item) == body)
    trial, = (name for name, rule in TRIALS.items() if body in rule['classes'])
    report_path, _, _, _ = evidence_paths(trial, True)
    native_sha = sha(report_path)
    assert row == compose(base, read(report_path)['binding_inputs'][str(body)], native_sha)
    return base


def test_client():
    run_client = runpy.run_path(str(ROOT / 'scripts/prepare-creature-uop-redirects.py'))['run_client']
    run_client('res://../scripts/test-centaur-mesh-binding.gd', ['--active'])
    run_client('res://../scripts/test-doom-creature-actions.gd', ['--active'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    original = INDEX.read_bytes()
    index = json.loads(original)
    current = [row for row in index['entries'] if row['status'] == 'validated' and body_id(row) in BODY_FILES]
    if args.check_active:
        assert sorted(current, key=body_id) == checked_rows(read(PROOFS / 'base-rows.json'), True)
        test_client()
        print('MESH LOCAL BINDINGS: active and verified')
        return
    assert not any('mesh_binding_native_sha256' in row for row in current)
    rows = checked_rows(current, False)
    for trial in TRIALS:
        destination = PROOFS / trial
        destination.mkdir(parents=True, exist_ok=True)
        for name, path in zip(('live.json', 'native-runtime.json', 'candidates.json', 'client-test.gd'), evidence_paths(trial, False), strict=True):
            shutil.copyfile(path, destination / name)
    (PROOFS / 'base-rows.json').write_text(json.dumps(current, indent=2) + '\n', encoding='utf-8')
    index['entries'] = [row for row in index['entries'] if row not in current] + rows
    assert INDEX.read_bytes() == original
    pending = INDEX.with_suffix('.mesh-bindings.pending')
    updated = (json.dumps(index, indent=2) + '\n').encode()
    pending.write_bytes(updated)
    pending.replace(INDEX)
    try:
        assert rows == checked_rows(current, True)
        test_client()
        assert INDEX.read_bytes() == updated
    except BaseException:
        if INDEX.read_bytes() == updated:
            pending.write_bytes(original)
            pending.replace(INDEX)
        raise
    print('MESH LOCAL BINDINGS: activated and verified')


if __name__ == '__main__':
    main()
