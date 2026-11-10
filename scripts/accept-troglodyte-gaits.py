# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify and install Troglodyte's source-backed locomotion and native stance."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
import shutil


ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
INDEX = VIEWER / 'local-art/creatures/accepted-index.json'
WORK = ROOT / 'work/creatures/native-form-audit'
CANDIDATES = WORK / 'enhanced-source-gaps'
SEALED = ROOT / 'work/creatures/troglodyte-gaits/accepted'
RENDERER = 'res://Presentation/TroglodyteModesVisual.gd'
GROUPS = {22: 'TroglodytePeaceWalk', 24: 'TroglodyteSprint', 25: 'ReadyStance'}
FRAME_PINS = {
    22: 'd24c58c681578668e70d3d9cb9978081814a874e6c8eb1017c6cdc0ec99f96ea',
    24: '8c6c366564e3cc7c271c7267be0fc28ea74252b941d4f764530707b042a6b683',
    25: '370a018703ab8311fab5234c7ce1966354ca2d3712cc7f2123d4fcae0774db66',
}
PROOFS = {
    'client.json': CANDIDATES / 'troglodyte-gaits-evidence.json',
    'native.json': WORK / 'troglodyte-gaits-native.json',
    'native-runtime.json': WORK / 'troglodyte-gaits-native-runtime.json',
}
IDENTITIES = {'Troglodyte': 0, 'Lurg': 1109}


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def checked_source():
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    reader = runpy.run_path(str(ROOT / 'scripts/uo-human-sequences.py'))
    name_hash = runpy.run_path(str(ROOT / 'scripts/audit-classic-parity.py'))['name_hash']
    sequence, = reader['inspect'](data / 'AnimationSequence.uop', {267})
    combat, peace = sequence['modes']
    assert (combat['mode'], peace['mode']) == (0, 1)
    assert peace['fallback_mode'] == 0 and peace['transitions'] == [{'target_mode': 0, 'group': 28}]
    for mode, expected in ((combat, [1, 0, 24]), (peace, [25, 22, 24])):
        assert [row['action'] for row in mode['movement']] == [0, 1, 2]
        assert [row['one_handed_group'] for row in mode['movement']] == expected
        assert [row['two_handed_group'] for row in mode['movement']] == expected
    lengths = {row['old_group']: row['frame_count'] for row in sequence['replacements']}
    assert all(lengths[group] == 9 for group in GROUPS)
    paths = {name_hash(f'build/animationlegacyframe/000267/{group:02d}.bin'): group for group in GROUPS}
    actual = {paths[key]: hashlib.sha256(raw).hexdigest()
              for key, raw in reader['payloads'](data / 'AnimationFrame1.uop', paths)}
    assert actual == FRAME_PINS
    return {'archive': 'AnimationFrame1.uop', 'mode_graph': [combat['movement'], peace['movement']],
            'frames': {str(group): {'sha256': actual[group], 'per_direction': lengths[group]} for group in GROUPS}}


def checked_proofs(paths, hashes, require_index=False):
    client = read(paths['client.json'])
    native = read(paths['native.json'])
    receipt = read(paths['native-runtime.json'])
    assert client['sha256'] == native['assets'] == hashes
    renderer_hash = sha(VIEWER / RENDERER.removeprefix('res://'))
    assert client['renderer_sha256'] == native['renderer_sha256'] == renderer_hash
    assert client['test_sha256'] == sha(ROOT / 'scripts/test-troglodyte-gaits.gd')
    assert native['test_sha256'] == sha(WORK / 'NativeCreatureModesLive.gd')
    assert receipt['report_sha256'].lower() == sha(paths['native.json'])
    assert receipt['server_sha256'].lower() == sha(ROOT / 'Server/runtime/Server.dll')
    assert receipt['content_sha256'].lower() == sha(ROOT / 'Server/runtime/Assemblies/UOContent.dll')
    if require_index:
        assert native['accepted_index_sha256'] == sha(INDEX)
    assert (client['terrain_poses'], client['static_corpses']) == (1647, 3)
    assert .0004 < client['minimum_gap'] <= client['maximum_gap'] < .02
    assert client['flat_idle_sole_gap'] < .02 and client['largest_loop_seam'] < .001
    assert native['checks'] == 63 and len(native['records']) == 2
    assert {row['class']: row['hue'] for row in native['records']} == IDENTITIES
    for row in native['records']:
        assert len(row['attacks']) == len(row['visual_modes']) == len(row['packet_order']) == 2
        for packet, modes, order in zip(row['attacks'], row['visual_modes'], row['packet_order']):
            action = packet['action']
            assert action['serial'] == row['serial'] and action['body'] == 267
            assert action['protocol'] == 'classic' and action['action'] in (4, 5, 6)
            assert packet['clip'] == {4: 'Attack', 5: 'Attack2', 6: 'Attack3'}[action['action']]
            assert modes[0] == modes[-1] == 'ReadyStance' and packet['clip'] in modes
            if order.index('combat') < order.index('attack'):
                assert 'TroglodyteOpenReach' in modes
    assert any('TroglodyteOpenReach' in modes for row in native['records'] for modes in row['visual_modes'])
    return {'renderer_sha256': renderer_hash, 'baker_sha256': sha(ROOT / 'scripts/bake-troglodyte-gaits.gd'),
            'proof_sha256': {name: sha(path) for name, path in paths.items()}}


def checked_row(base, paths, scene_files, require_index=False):
    assert base['kind'] == 'troglodyte' and [identity['body'] for identity in base['bodies']] == [267]
    assert 'troglodyte_enhanced' in base and 'troglodyte_gaits' not in base
    assets = {treatment: f'res://local-art/creatures/troglodyte-gaits-{treatment}.scn' for treatment in base['assets']}
    hashes = {treatment: sha(path) for treatment, path in scene_files.items()}
    metadata = checked_proofs(paths, hashes, require_index)
    layer = {'base': base, 'source': checked_source(), 'group_clips': {str(k): v for k, v in GROUPS.items()}, **metadata}
    descriptions = {clip: f'Fitted to the five registered source directions for group {group}'
                    for group, clip in GROUPS.items()}
    return dict(base, assets=assets, asset_sha256=hashes, authored_action_scene_sha256=hashes,
                presentation_script=RENDERER, presentation_script_sha256=metadata['renderer_sha256'],
                archive_grounded_gestures=base['archive_grounded_gestures'] + list(GROUPS.values()),
                authored_replacements=base['authored_replacements'] | descriptions, troglodyte_gaits=layer)


def without_gaits(row):
    base = row['troglodyte_gaits']['base']
    proofs = {name: SEALED / name for name in PROOFS}
    scenes = {key: VIEWER / uri.removeprefix('res://') for key, uri in row['assets'].items()}
    assert checked_row(base, proofs, scenes) == row
    return base


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    original = INDEX.read_bytes()
    index = json.loads(original)
    row, = (row for row in index['entries'] if row['kind'] == 'troglodyte')
    if 'troglodyte_gaits' in row:
        without_gaits(row)
    elif args.activate:
        sources = {key: CANDIDATES / f'troglodyte-gaits-{key}.scn' for key in row['assets']}
        replacement = checked_row(row, PROOFS, sources, require_index=True)
        for key, uri in replacement['assets'].items():
            target = VIEWER / uri.removeprefix('res://')
            temporary = target.with_suffix('.scn.pending')
            shutil.copyfile(sources[key], temporary)
            temporary.replace(target)
        SEALED.mkdir(parents=True, exist_ok=True)
        for name, path in PROOFS.items():
            shutil.copyfile(path, SEALED / name)
        assert without_gaits(replacement) == row
        index['entries'][index['entries'].index(row)] = replacement
        temporary = INDEX.with_suffix('.troglodyte-gaits.pending')
        temporary.write_text(json.dumps(index, indent=2) + '\n', encoding='utf-8')
        if INDEX.read_bytes() != original:
            raise SystemExit('The creature index changed during verification')
        temporary.replace(INDEX)
    else:
        raise SystemExit('The verified gait package has not been activated')
    print('TROGLODYTE GAITS: verified source groups, terrain, corpse and native modes')


if __name__ == '__main__':
    main()
