"""Seal the mounted trial and layer only its seven Classic routes over the on-foot package."""

import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess

HERE = Path(__file__).resolve().parent
RECIPE = runpy.run_path(str(HERE / 'prepare-restless-soul-mounted.py'))
FOOT = runpy.run_path(str(HERE / 'accept-restless-soul-actions.py'))
ROOT, sha, read, FAMILY, SLOTS = (RECIPE[key] for key in ('ROOT', 'sha', 'read', 'FAMILY', 'SLOTS'))
INDEX = FOOT['INDEX']
WORK = ROOT / 'work/creatures' / FAMILY
REPORT = ROOT / 'outputs/creatures' / FAMILY / 'live.json'
RECEIPT = (WORK / 'candidates.json', REPORT, WORK / 'native-runtime.json')
SEALED = tuple(WORK / 'mounted-acceptance' / path.name for path in RECEIPT)
MARKER = 'restless_soul_mount_sha256'


def foot_row():
    return FOOT['checked_ghost'](*(FOOT['WORK'] / 'on-foot-acceptance' / name
                                  for name in ('candidates.json', 'live.json', 'native-runtime.json')))


def checked_mounted(candidates_path, report_path, runtime_path):
    candidates, report, runtime = map(read, (candidates_path, report_path, runtime_path))
    assert report['prepared_trial'] and report['failures'] == 0 and report['checks'] > 0
    assert sha(candidates_path) == report['candidate_sha256'] == runtime['candidate_sha256']
    assert sha(report_path) == runtime['report_sha256']
    for key, name in {
        'test_sha256': 'Viewer/Network/RestlessSoulMountedLive.gd',
        'base_test_sha256': 'Viewer/Network/KhaldunDoomLive.gd',
        'fixture_sha256': 'Server/HorseIntegrationFixtures/CreatureFixtures.cs',
        'extension_sha256': 'Server/HorseIntegrationFixtures/KhaldunActionFixtures.cs',
        'mount_fixture_sha256': 'Server/HorseIntegrationFixtures/RestlessSoulMountFixtures.cs',
    }.items():
        assert report[key] == sha(ROOT / name)
        if name.startswith('Server/'):
            assert report[key] == runtime['build_inputs_sha256'][name]
    candidate, = (item for item in candidates if item['body'] == 970)
    row = candidate['presentation']
    base = foot_row()
    assert candidate['native_class'] == 'RestlessSoul' and row['kind'] == base['kind']
    assert row['family'] == FAMILY and row['status'] == 'prepared'
    for field in ('bodies', 'assets', 'asset_sha256', 'native_constructor_hues'):
        assert row[field] == base[field]
    assert row['presentation_script'] == 'res://Presentation/RestlessSoulMountedVisual.gd'
    assert set(row['mounted_assets']) == set(base['assets'])
    pins = row['art_dependency_sha256'] | {row['presentation_script']: row['presentation_script_sha256']}
    pins.update({asset: row['mounted_asset_sha256'][treatment]
                 for treatment, asset in row['mounted_assets'].items()})
    for asset, digest in pins.items():
        path = (ROOT / 'Viewer' / asset.removeprefix('res://')).resolve()
        assert path.is_relative_to(ROOT / 'Viewer') and sha(path) == digest
    assert set(map(int, row['action_witness_frames'])) == set(SLOTS)
    assert row['classic_action_categories'] == base['classic_action_categories'] | {
        str(slot): label for slot, label in SLOTS.items()
    }
    records = [entry for entry in report['records'] if entry['body'] == 970]
    assert len(records) == 2 and {entry['female'] for entry in records} == {False, True}
    for record in records:
        assert record['native_class'] == 'RestlessSoul' and not record['corpse_suppressed']
        assert record['constructor_hue'] == base['native_constructor_hues']['RestlessSoul']
        mounted = record['mount']
        assert mounted['dismount_remount'] and mounted['moved'] and mounted['dye'] == 0x47e
        assert mounted['native_death_state'] == 'UCCREATURE|ghost-mount|death|1|0|1'
        first, second = mounted['death']
        assert first == second and first['corpse'] > 0 and first['on_foot'] and first['clip'] == 'Death'
        actions = {action['group']: action for action in record['classic_actions']}
        assert len(actions) == len(record['classic_actions']) and set(actions) == set(SLOTS)
        for slot, label in SLOTS.items():
            action = actions[slot]
            assert action['clip'] == label
            first, second = action['packets']
            assert first == second and first['body'] == 970 and first['protocol'] == 'classic'
            assert first['action'] == slot and first['frames'] == row['action_witness_frames'][str(slot)]
    methods = {label: 'Mounted donor animation on the retained split robe' for label in SLOTS.values()}
    methods[SLOTS[29]] = 'Authored seated urging gesture from the five registered Classic frames'
    overlay = {key: row[key] for key in ('family', 'classic_action_categories', 'mounted_assets',
               'mounted_asset_sha256', 'presentation_script', 'presentation_script_sha256', 'art_dependency_sha256')}
    return base | overlay | {MARKER: sha(report_path), 'mounted_action_witness_frames': row['action_witness_frames'],
                              'authored_clips': base['authored_clips'] | methods}


def sealed_row():
    return checked_mounted(*SEALED)


def run_active():
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    result = subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
                             str(HERE / 'test-restless-soul-mounted.gd'), '--', '--active'],
                            cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
                            capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    print(output.strip())
    assert result.returncode == 0 and 'ERROR:' not in output and 'RESTLESS SOUL MOUNTED PASS: 1575' in output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('check-evidence', 'activate', 'check-active'))
    mode = parser.parse_args().mode
    row = sealed_row() if mode == 'check-active' else checked_mounted(*RECEIPT)
    if mode != 'check-active':
        candidate, = (item for item in read(RECEIPT[0]) if item['body'] == 970)
        assert candidate['presentation'] == RECIPE['prepared']()[0][1]
    if mode == 'check-evidence':
        print('RESTLESS SOUL MOUNTED: seven exact packet routes and both native mount lifecycle records')
        return
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    entries = index['entries']
    position, = (i for i, entry in enumerate(entries) if any(identity['body'] == 970 for identity in entry['bodies']))
    if mode == 'check-active':
        assert entries[position] == row
        run_active()
        return
    assert entries[position] == foot_row()
    SEALED[0].parent.mkdir(parents=True, exist_ok=True)
    for source, target in zip(RECEIPT, SEALED):
        target.write_bytes(source.read_bytes())
    assert sealed_row() == row
    entries[position] = row
    published = (json.dumps(index, indent=2) + '\n').encode('utf-8')
    assert INDEX.read_bytes() == previous
    replace = FOOT['SHARED']['replace_index']
    replace(published)
    try:
        run_active()
        FOOT['SHARED']['run_active_test']('--active-ghost', 2499)
        assert INDEX.read_bytes() == published
    except BaseException:
        if INDEX.read_bytes() == published:
            replace(previous)
        raise
    print('RESTLESS SOUL MOUNTED: seven fitted Classic routes active locally')


if __name__ == '__main__':
    main()
