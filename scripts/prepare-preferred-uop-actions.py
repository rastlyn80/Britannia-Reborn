"""Verify the preferred UOP frames and the retained Gargoyle and Parrot rigs."""

import hashlib
import json
from pathlib import Path
import runpy
from statistics import median
import struct


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
WORK = ROOT / 'work/creatures/preferred-uop-actions'
FAMILY = 'preferred_uop_verified_01'
PINS = SCRIPTS / 'preferred-uop-action-pins.json'
PACKAGE = runpy.run_path(str(SCRIPTS / 'creature-action-package.py'))
read, sha = PACKAGE['read'], PACKAGE['sha']
CLASSES = {753: 'EnslavedGargoyle', 831: 'Parrot'}
CLIPS = {
    753: {'11': 'Pillage', '15': 'UopGargoyleGuard', '23': 'UopGargoyleStand', '26': 'Idle',
          '27': 'UopGargoyleLunge', '28': 'UopGargoyleStep'},
    831: {'25': 'Idle', '26': 'UopParrotWingTuck'},
}
FITTED = {753: ('15', '23', '27', '28'), 831: ('26',)}
ROUTES = {753: {'2': '15', '8': '28', '14': '11', '15': '23'},
          831: dict.fromkeys(('2', '8', '11', '14', '15'), '25')}
RENDERERS = {753: 'ArchiveSourcePreservingGestureVisual.gd', 831: 'ArchiveOccurrenceGestureVisual.gd'}
BAKE_INPUTS = ('bake-preferred-uop-actions.gd', 'preferred-uop-action-pins.json',
               'bake-swamp-widow-juka-actions.gd', 'bake-zombie-actions.gd',
               'bake-troll-actions.gd', 'bake-skeleton-actions.gd')


def registered_heights(raw, group, proof, points):
    count, table = struct.unpack_from('<II', raw, 32)
    assert count == proof['frame_headers'] and count % 5 == 0 and 40 <= table <= len(raw) - count * 16
    offsets = []
    for frame, position in enumerate(range(table, table + count * 16, 16), 1):
        stored_group, frame_id, _, offset = struct.unpack_from('<HHQI', raw, position)
        assert stored_group == group and frame_id == frame
        offsets.append(position + offset)
    ordered = sorted(set(offsets))
    assert table + count * 16 <= ordered[0] < ordered[-1] < len(raw)
    ends = dict(zip(ordered, ordered[1:] + [len(raw)]))
    heights = []
    for offset in offsets:
        height = [y for _, y, _ in points(raw, offset, ends[offset])]
        heights.append(max(height) - min(height) + 1)
    stride = count // 5
    return [int(median(heights[index::stride])) for index in range(stride)]


def checked_source():
    pins = read(PINS)
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['inputs'] == {name: sha(data / name) for name in pins['inputs']}
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    name_hash = runpy.run_path(str(SCRIPTS / 'audit-classic-parity.py'))['name_hash']
    points = runpy.run_path(str(SCRIPTS / 'prepare-halberd-uop-fit.py'))['sprite_points']
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    _, _, flags = ledger['original_mul_groups'](data, CLASSES.keys())
    sequence = {row['animation_ref']: row for row in reader['inspect'](data / 'AnimationSequence.uop', CLASSES.keys())}
    assert sequence.keys() == CLASSES.keys()
    for body, groups in CLIPS.items():
        proof = pins['bodies'][str(body)]
        assert list(flags[body]) == proof['mobtypes'] and flags[body][1] & 0x10000
        assert groups.keys() == proof['frames'].keys()
        packets = ROUTES[body].keys() | {'5'}
        modes = [{key: mode[key] for key in ('mode', 'default_group', 'fallback_mode', 'transitions')}
                 | {'packet_groups': {str(row['type']): row['groups'] for row in mode['new_protocol_actions']
                                      if str(row['type']) in packets and row['subaction'] == -1}}
                 for mode in sequence[body]['modes']]
        assert modes == proof['modes']
        for kind, group in ROUTES[body].items():
            assert set(modes[0]['packet_groups'][kind]) == {int(group)}
            assert all(mode['fallback_mode'] == 0 and kind not in mode['packet_groups'] for mode in modes[1:])
        assert modes[0]['packet_groups']['5'] != modes[1]['packet_groups']['5'] and '5' not in ROUTES[body]
        names = {name_hash(f'build/animationlegacyframe/{body:06d}/{int(group):02d}.bin'): group for group in groups}
        archives = {frame['archive'] for frame in proof['frames'].values()}
        checked = set()
        for archive in archives:
            for digest, raw in reader['payloads'](data / archive, names):
                group = names[digest]
                pin = proof['frames'][group]
                assert pin['archive'] == archive and hashlib.sha256(raw).hexdigest() == pin['payload_sha256']
                assert registered_heights(raw, int(group), pin, points) == pin['median_registered_height']
                checked.add(group)
        assert checked == groups.keys()
    return pins


def prepared(entries):
    checked_source()
    inputs = PACKAGE['bake_input_hashes'](BAKE_INPUTS)
    result = []
    for body, groups in CLIPS.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        assert 'preferred_uop_native_sha256' not in base
        source_hashes = base.get('asset_sha256') or base['authored_action_scene_sha256']
        before, assets, scenes = PACKAGE['checked_scenes'](dict(base, asset_sha256=source_hashes),
                                                           body, f'preferred-uop-{body}-actions', inputs)
        new_routes = {kind: groups[group] for kind, group in ROUTES[body].items()}
        authored = {groups[group]: f'Fitted on the retained rig from the five registered UOP directions for group {group}'
                    for group in FITTED[body]}
        renderer = 'res://Presentation/' + RENDERERS[body]
        result.append(dict(base, status='prepared', family=FAMILY, assets=assets, asset_sha256=scenes,
                           preferred_uop_base_assets=before, preferred_uop_base_sha256=source_hashes,
                           uop_motion_packet_groups=ROUTES[body],
                           authored_replacements=base.get('authored_replacements', {}) | authored,
                           new_action_categories=base.get('new_action_categories', {}) | new_routes,
                           presentation_script=renderer, presentation_script_sha256=sha(VIEWER / renderer[6:]),
                           archive_grounded_gestures=sorted(authored), archive_align_gesture_slope=True))
    return result


if __name__ == '__main__':
    index = read(VIEWER / 'local-art/creatures/accepted-index.json')
    rows = prepared(index['entries'])
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / 'prepared-client.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print('PREFERRED UOP ACTIONS: eight exact groups and both retained rigs verified')
