"""Bind distinct Classic Gaman gestures to exact clips from the Mondain's Legacy 3D client."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {248: ['Gaman']}
FAMILY = 'gaman_gestures'
ROUTES = {'9': 'Fidget', '10': 'Alert'}
PINS = {
    '9': ('anim4.mul', 203, 5, [0, 1, 2, 3, 4], '68abd9c819503efc36ecd93547b30074fdf739237954feb053ae3aaee2be7eed'),
    '10': ('anim4.mul', 203, 3, [0, 1, 2, 3, 4], '1e25d73a4e5a72ad5a4fce2f58d5494ddda554427653b8a8ff0e480ef58aeac8'),
}
CLIPS = {
    'Fidget': ('Wild_Guar_Fidget1.grn', 'c11f15cfbd391d1b67fa6137402a95fafb035179f1471bafe4842fb31b51924f'),
    'Alert': ('Wild_Guar_Alert.grn', '564be0ee1980176ce734fd6fe43bedda5146b635d52cd5fa2642dca0db9c22c8'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepared(entries):
    base, = (row for row in entries if row['kind'] == 'wild_guar' and row['status'] == 'validated'
             and [identity['body'] for identity in row['bodies']] == [248])
    ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8-sig'))
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    refs = {slot: reference(ledger, 248, int(slot), pin) for slot, pin in PINS.items()}
    for treatment, path in base['assets'].items():
        assert sha(ROOT / 'Viewer' / path.removeprefix('res://')) == base['asset_sha256'][treatment]
    visual = ROOT / 'Viewer' / base['presentation_script'].removeprefix('res://')
    assert sha(visual) == base['presentation_script_sha256']
    for slot, label in ROUTES.items():
        filename, digest = CLIPS[label]
        source = f'Client/Models/Animals/{filename}'
        assert base['clip_sources'][label] == source
        assert sha(ROOT / 'work/creatures/late-client-inputs/gaman-source/Client' / filename) == digest
        refs[slot].update(retained_clip=label, recovered_member=source, recovered_sha256=digest)
    candidate = dict(base, status='prepared', family=FAMILY, native_extra_classic_actions=[10],
                     native_constructor_hues={'Gaman': 0}, classic_motion_references=refs,
                     authored_action_scene_sha256=base['asset_sha256'],
                     classic_action_categories=base.get('classic_action_categories', {}) | ROUTES,
                     authored_action_reference=refs['10'])
    return [candidate], CLASSES
