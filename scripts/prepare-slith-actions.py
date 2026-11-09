"""Prepare Slith's distinct actions from pinned UOP references and retained rig assets."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
import struct

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'slith_actions'
BODY = 734
CLASSES = {BODY: ['Slith', 'StoneSlith', 'ToxicSlith']}
GROUPS = {
    0: 'Walk', 1: 'Idle', 2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Attack2', 10: 'Hit',
    15: 'SlithSideRecoil', 23: 'SlithScent', 24: 'Run', 25: 'ReadyStance',
    26: 'SlithThreatLow', 27: 'SlithThreatRise', 28: 'SlithSettle',
}
FITTED = (3, 5, 15, 23, 26, 27, 28)
MODERN = {0: 4, 2: 15, 3: 2, 4: 10, 5: 26, 8: 28, 11: 4, 14: 25, 15: 23}
TREATMENTS = ('original', 'rounded', 'modern')
BAKE_INPUTS = ('bake-slith-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd',
               'test-quadruped-actions.gd')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def source_groups():
    pins = read(SCRIPTS / 'slith-action-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['body'] == BODY
    assert pins['archives'] == {name: sha(data / name) for name in ('AnimationSequence.uop', 'AnimationFrame3.uop')}
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    record, = reader['inspect'](data / 'AnimationSequence.uop', {BODY})
    assert not record.get('parse_blocker') and record['unparsed_bytes'] == 0 and record == pins['sequence']

    name_hash = runpy.run_path(str(SCRIPTS / 'audit-classic-parity.py'))['name_hash']
    names = {name_hash(f'build/animationlegacyframe/{BODY:06d}/{group:02d}.bin'): group for group in range(80)}
    frames = {}
    for digest, payload in reader['payloads'](data / 'AnimationFrame3.uop', names):
        group = names[digest]
        count, start = struct.unpack_from('<II', payload, 32)
        assert str(group) not in frames and count and count % 5 == 0 and start + count * 16 < len(payload)
        for index in range(count):
            offset = start + index * 16
            group_id, frame_id, _, pixels = struct.unpack_from('<HHQI', payload, offset)
            assert group_id == group and frame_id == index + 1
            assert start + count * 16 <= offset + pixels <= len(payload) - 524
        frames[str(group)] = [count, hashlib.sha256(payload).hexdigest()]
    assert frames == pins['frames'] and set(map(int, frames)) == set(GROUPS) | {22}
    return pins


def prepared(entries):
    pins = source_groups()
    base, = (row for row in entries if row['status'] == 'validated'
             and [int(identity['body']) for identity in row['bodies']] == [BODY])
    assert base['kind'] == 'lizards_komodo_dragon' and base['family'] == 'slith'
    assert base['classic_action_categories']['11'] == base['new_action_categories']['14'] == 'ReadyStance'
    assert base['uop_redirect_native_sha256'] and base['authored_action_reference']['uop_group'] == 25

    bake = read(ART / 'slith-actions-bake.json')
    assert bake['inputs'] == {name: sha(SCRIPTS / name) for name in BAKE_INPUTS}
    assets = {name: f'res://local-art/creatures/slith-actions-{name}.scn' for name in TREATMENTS}
    scenes = {name: sha(VIEWER / path[6:]) for name, path in assets.items()}
    assert bake['scenes'] == {name: {'source': sha(VIEWER / base['assets'][name][6:]), 'scene': scenes[name]}
                              for name in TREATMENTS}
    assert {name: proof['source'] for name, proof in bake['scenes'].items()} == base['asset_sha256']

    def reference(slot, group):
        count, digest = pins['frames'][str(group)]
        return dict(body=BODY, group=slot, uop_group=group, archive='AnimationFrame3.uop',
                    frame_headers=count, payload_sha256=digest)

    redirects = {row['old_group']: row['new_group'] for row in pins['sequence']['replacements']
                 if not row['frame_count']}
    classic_groups = {slot: redirects.get(slot, slot) for slot in range(22)}
    references = {str(slot): reference(slot, group) for slot, group in classic_groups.items()}
    categories = {str(slot): GROUPS[group] for slot, group in classic_groups.items()}
    assert all(categories[slot] == clip for slot, clip in base['classic_action_categories'].items())
    renderer = 'Presentation/SlithActionsVisual.gd'
    dependencies = ('SlithActionsVisual', 'TerathanActionsVisual', 'SourceSpaceFallPlayback',
                    'CreatureFallPlayback', 'SourceGroundLookup')
    row = dict(base, status='prepared', family=FAMILY, assets=assets,
               classic_gesture_base_assets=base['assets'], authored_action_scene_sha256=scenes,
               authored_action_base_sha256=base['asset_sha256'],
               authored_action_reference=references['15'], classic_motion_references=references,
               classic_action_categories=categories,
               new_action_categories={str(kind): GROUPS[group] for kind, group in MODERN.items()},
               native_extra_classic_actions=[0, 1, 2, 3, 9, 10, 13, 14, 15, 16, 18, 21],
               grounded_gestures=[GROUPS[group] for group in FITTED if group != 3],
               authored_replacements=base['authored_replacements'] | {
                   GROUPS[group]: f'Fitted on the retained Third Dawn rig from Slith UOP group {group}'
                   for group in FITTED},
               slith_uop_group_clips={str(group): clip for group, clip in GROUPS.items()},
               slith_sequence_sha256=pins['archives']['AnimationSequence.uop'],
               presentation_script=f'res://{renderer}', presentation_script_sha256=sha(VIEWER / renderer),
               collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd') for name in dependencies})
    return [row], CLASSES


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    rows, _ = prepared(read(ART / 'accepted-index.json')['entries'])
    output = ROOT / 'work/creatures' / FAMILY / 'prepared-client.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print('SLITH: verified 15 UOP frame groups, 22 Classic selections and three retained treatments')


if __name__ == '__main__':
    main()
