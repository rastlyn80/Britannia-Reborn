"""Seal and activate the isolated Restless Soul on-foot route witness."""

import argparse
import json
from pathlib import Path
import runpy

HERE = Path(__file__).resolve().parent
RECIPE = runpy.run_path(str(HERE / 'prepare-restless-soul-actions.py'))
SHARED = runpy.run_path(str(HERE / 'accept-khaldun-actions.py'))
ROOT, sha, read, FAMILY, SLOTS = (RECIPE[key] for key in ('ROOT', 'sha', 'read', 'FAMILY', 'SLOTS'))
INDEX = SHARED['INDEX']
BASE = SHARED['BASE']
WORK = ROOT / 'work/creatures' / FAMILY
REPORT = ROOT / 'outputs/creatures' / FAMILY / 'live.json'


def checked_ghost(candidates_path, report_path, runtime_path):
    candidates, report, runtime = map(read, (candidates_path, report_path, runtime_path))
    assert report['prepared_trial'] and report['failures'] == 0 and report['checks'] > 0
    assert sha(candidates_path) == report['candidate_sha256'] == runtime['candidate_sha256']
    assert sha(report_path) == runtime['report_sha256']
    for key, name in {
        'test_sha256': 'Viewer/Network/RestlessSoulActionsLive.gd',
        'base_test_sha256': 'Viewer/Network/KhaldunDoomLive.gd',
        'fixture_sha256': 'Server/HorseIntegrationFixtures/CreatureFixtures.cs',
        'extension_sha256': 'Server/HorseIntegrationFixtures/KhaldunActionFixtures.cs',
    }.items():
        assert report[key] == sha(ROOT / name)
        if name.startswith('Server/'):
            assert report[key] == runtime['build_inputs_sha256'][name]
    candidate, = (item for item in candidates if item['body'] == 970)
    row = candidate['presentation']
    base = read(BASE)['models'][1]
    assert row['bodies'] == base['bodies'] and row['kind'] == 'restless_soul'
    assert candidate['native_class'] == 'RestlessSoul'
    assert row['family'] == FAMILY and row['status'] == 'prepared'
    assert row['presentation_script'] == base['presentation_script']
    assert set(row['assets']) == {'original', 'rounded', 'modern'}
    pins = row['art_dependency_sha256'] | {row['presentation_script']: row['presentation_script_sha256']}
    for asset, digest in pins.items():
        path = (ROOT / 'Viewer' / asset.removeprefix('res://')).resolve()
        assert path.is_relative_to(ROOT / 'Viewer') and sha(path) == digest
    assert set(map(int, row['action_witness_frames'])) == SLOTS
    for treatment, asset in row['assets'].items():
        assert asset == f'res://local-art/creatures/{FAMILY}/restless-soul-{treatment}.scn'
        assert sha(ROOT / 'Viewer' / asset.removeprefix('res://')) == row['asset_sha256'][treatment]
    for slot, label in base['classic_action_categories'].items():
        if int(slot) not in SLOTS:
            assert row['classic_action_categories'][slot] == label
    records = [entry for entry in report['records'] if entry['body'] == 970]
    assert len(records) == 2 and {entry['female'] for entry in records} == {False, True}
    for record in records:
        assert record['native_class'] == 'RestlessSoul' and not record['corpse_suppressed'] and record['explicit_attack']
        assert record['constructor_hue'] == base['native_constructor_hues']['RestlessSoul']
        actions = {str(action['group']): action for action in record['classic_actions']}
        assert len(actions) == len(record['classic_actions']) and set(actions) == set(row['action_witness_frames'])
        for slot, action in actions.items():
            assert action['clip'] == row['classic_action_categories'][slot]
            packets = action['packets']
            assert len(packets) == 2 and packets[0] == packets[1]
            packet = packets[0]
            assert packet['body'] == 970 and packet['action'] == int(slot) and packet['protocol'] == 'classic'
            assert packet['frames'] == row['action_witness_frames'][slot]
    authored = {row['classic_action_categories'][slot]: 'Retargeted and fitted to the registered Classic ghost views'
                for slot in row['action_witness_frames']}
    return dict(row, status='validated', authored_clips=authored, restless_soul_native_sha256=sha(report_path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('check-evidence', 'activate', 'check-active'))
    mode = parser.parse_args().mode
    paths = (WORK / 'candidates.json', REPORT, WORK / 'native-runtime.json')
    sealed = WORK / 'on-foot-acceptance'
    saved = tuple(sealed / path.name for path in paths)
    active = checked_ghost(*(saved if mode == 'check-active' else paths))
    if mode != 'check-active':
        candidate, = (item for item in read(paths[0]) if item['body'] == 970)
        assert candidate['presentation'] == RECIPE['prepared']()[0][1]
    if mode == 'check-evidence':
        print('RESTLESS SOUL: 17 exact Classic on-foot routes and both isolated client records')
        return
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    entries = index['entries']
    position, = (i for i, entry in enumerate(entries) if any(identity['body'] == 970 for identity in entry['bodies']))
    run_active = SHARED['run_active_test']
    if mode == 'check-active':
        if entries[position].get('restless_soul_mount_sha256'):
            mounted = runpy.run_path(str(HERE / 'accept-restless-soul-mounted.py'))
            active = mounted['sealed_row']()
        assert entries[position] == active
        run_active('--active-ghost', 2499)
        return
    assert entries[position] == dict(read(BASE)['models'][1], status='validated')
    sealed.mkdir(parents=True, exist_ok=True)
    for source, target in zip(paths, saved):
        target.write_bytes(source.read_bytes())
    assert checked_ghost(*saved) == active
    entries[position] = active
    published = (json.dumps(index, indent=2) + '\n').encode('utf-8')
    assert INDEX.read_bytes() == previous
    replace_index = SHARED['replace_index']
    replace_index(published)
    try:
        run_active('--active-ghost', 2499)
        assert INDEX.read_bytes() == published
    except BaseException:
        if INDEX.read_bytes() == published:
            replace_index(previous)
        raise
    print('RESTLESS SOUL: 17 fitted Classic on-foot routes active locally')


if __name__ == '__main__':
    main()
