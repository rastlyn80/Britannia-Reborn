"""Verify the isolated receipt and activate the reviewed Spectral Armour actions."""

import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work/creatures/khaldun_actions'
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
REPORT = ROOT / 'outputs/creatures/khaldun_actions/live.json'
BASE = ROOT / 'Viewer/local-art/creatures/khaldun_doom/preparation.json'
TEST = ROOT / 'scripts/test-khaldun-actions.gd'
PREPARE = runpy.run_path(str(ROOT / 'scripts/prepare-khaldun-actions.py'))
read, sha = PREPARE['read'], PREPARE['sha']


def checked_spectral(candidates_path, report_path, runtime_path):
    runtime, candidates, report = map(read, (runtime_path, candidates_path, report_path))
    assert sha(candidates_path) == report['candidate_sha256'] == runtime['candidate_sha256']
    assert sha(report_path) == runtime['report_sha256']
    assert report['prepared_trial'] and report['failures'] == 0 and report['checks'] > 0
    for key, name in {
        'test_sha256': 'Viewer/Network/KhaldunActionsLive.gd',
        'base_test_sha256': 'Viewer/Network/KhaldunDoomLive.gd',
        'fixture_sha256': 'Server/HorseIntegrationFixtures/CreatureFixtures.cs',
        'extension_sha256': 'Server/HorseIntegrationFixtures/KhaldunActionFixtures.cs',
    }.items():
        assert report[key] == sha(ROOT / name)
        if name.startswith('Server/'):
            assert report[key] == runtime['build_inputs_sha256'][name]
    witness, = (candidate for candidate in candidates if candidate['body'] == 637)
    assert witness['native_class'] == 'SpectralArmour'
    row = witness['presentation']
    base = read(BASE)['models'][0]
    assert row['bodies'] == base['bodies']
    assert row['kind'] == base['kind'] == 'spectral_armour'
    assert row['family'] == 'khaldun_actions' and row['status'] == 'prepared'
    assert row['presentation_script'] == 'res://Presentation/SpectralArmourVisual.gd'
    pins = row['art_dependency_sha256'] | {row['presentation_script']: row['presentation_script_sha256']}
    for asset, digest in pins.items():
        path = (ROOT / 'Viewer' / asset.removeprefix('res://')).resolve()
        assert path.is_relative_to(ROOT / 'Viewer') and sha(path) == digest
    assert set(row['action_witness_frames']) == {slot for slot, clip in base['classic_action_categories'].items() if not clip}
    for treatment, asset in row['assets'].items():
        assert asset == 'res://local-art/creatures/khaldun_actions/spectral-scimitar.scn'
        assert sha(ROOT / 'Viewer' / asset.removeprefix('res://')) == row['asset_sha256'][treatment]
    for slot, clip in base['classic_action_categories'].items():
        assert not clip or row['classic_action_categories'][slot] == clip
    records = [entry for entry in report['records'] if entry['body'] == 637]
    assert len(records) == 2 and {entry['female'] for entry in records} == {False, True}
    for record in records:
        assert record['native_class'] == 'SpectralArmour' and record['corpse_suppressed'] and record['explicit_attack']
        assert record['constructor_hue'] == base['native_constructor_hues']['SpectralArmour']
        actions = {str(action['group']): action for action in record['classic_actions']}
        assert len(actions) == len(record['classic_actions']) and set(actions) == set(row['action_witness_frames'])
        for slot, action in actions.items():
            assert action['clip'] == row['classic_action_categories'][slot]
            packets = action['packets']
            assert len(packets) == 2 and packets[0] == packets[1]
            packet = packets[0]
            assert packet['body'] == 637 and packet['action'] == int(slot) and packet['protocol'] == 'classic'
            assert packet['frames'] == row['action_witness_frames'][slot]
    authored = row['authored_clips'] | {
        row['classic_action_categories'][slot]: 'Scimitar reconstructed from registered Classic silhouettes'
        for slot in row['action_witness_frames']
    }
    return dict(row, status='validated', authored_clips=authored, khaldun_native_sha256=sha(report_path))


def replace_index(content):
    temporary = INDEX.with_suffix('.khaldun.pending')
    temporary.write_bytes(content)
    temporary.replace(INDEX)


def run_active_test(flag='--active-spectral', poses=3822):
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    result = subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
                             str(TEST), '--', flag],
                            cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
                            capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    print(output.strip())
    assert result.returncode == 0 and 'ERROR:' not in output and f'KHALDUN ROUTES PASS: {poses}' in output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('check-evidence', 'activate', 'check-active'))
    mode = parser.parse_args().mode
    paths = (WORK / 'candidates.json', REPORT, WORK / 'native-runtime.json')
    sealed = WORK / 'spectral-acceptance'
    saved = tuple(sealed / path.name for path in paths)
    base = dict(read(BASE)['models'][0], status='validated')
    row = checked_spectral(*(saved if mode == 'check-active' else paths))
    if mode != 'check-active':
        models = PREPARE['stage']()['models']
        candidate, = (item for item in read(paths[0]) if item['body'] == 637)
        assert candidate['presentation'] == models[0]
    if mode == 'check-evidence':
        print('SPECTRAL ACTIONS: 26 exact Classic routes and both isolated client records')
        return
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    entries = index['entries']
    position, = (i for i, entry in enumerate(entries) if any(identity['body'] == 637 for identity in entry['bodies']))
    if mode == 'check-active':
        assert entries[position] == row
        run_active_test()
        return
    assert entries[position] == base, 'Existing Spectral Armour route differs from its sealed predecessor'
    sealed.mkdir(parents=True, exist_ok=True)
    for source, target in zip(paths, saved):
        target.write_bytes(source.read_bytes())
    assert checked_spectral(*saved) == row
    entries[position] = row
    published = (json.dumps(index, indent=2) + '\n').encode('utf-8')
    assert INDEX.read_bytes() == previous
    replace_index(published)
    try:
        run_active_test()
        assert INDEX.read_bytes() == published
    except BaseException:
        if INDEX.read_bytes() == published:
            replace_index(previous)
        raise
    print('SPECTRAL ACTIONS: 26 fitted Classic routes active locally')


if __name__ == '__main__':
    main()
