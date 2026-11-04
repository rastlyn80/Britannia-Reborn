"""Bind the distinct Mongbat fidgets to the previously accepted WingSettle scenes."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {39: ['GreaterMongbat', 'Mongbat', 'StrongMongbat']}
GROUPS = {
    '11': ('WingSettle', '97ad0db8b2e9ed02714dd1063f7b165c760319e49299628ebaee5b6c044bfa45'),
    '17': ('MongbatArmLift', '6e1406a85fa01e4a8237eda133c6123587a2250aed84b25af1603fd1529b40d0'),
    '18': ('Fidget2', '6198ef5c96df724df77025984872e77bb50244e086152f186fdaa8be9833d3c7'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == 'mongbats_mongbat'
             and [identity['body'] for identity in row['bodies']] == [39])
    assert base['classic_gesture_native_sha256'] and base['classic_action_categories']['11'] == GROUPS['11'][0]
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    references = {slot: reference(ledger, 39, int(slot), ('anim.mul', 39, 5, digest))
                  for slot, (_, digest) in GROUPS.items()}
    art = ROOT / 'Viewer/local-art/creatures'
    bake = read(art / 'mongbat-fidgets-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-mongbat-fidgets.gd')
    assert bake['aim_solver'] == sha(ROOT / 'scripts/bake-classic-gesture-trials.gd')
    assets, scenes = {}, {}
    for treatment in ('original', 'rounded', 'modern'):
        source = f'mul-gesture-39-{treatment}.scn'
        output = f'mongbat-fidgets-{treatment}.scn'
        assert base['assets'][treatment] == 'res://local-art/creatures/' + source
        assert sha(art / source) == base['asset_sha256'][treatment]
        scenes[treatment] = sha(art / output)
        assert bake['scenes'][treatment] == {'source': base['asset_sha256'][treatment], 'scene': scenes[treatment]}
        assets[treatment] = 'res://local-art/creatures/' + output
    for name, digest in base['art_dependency_sha256'].items():
        assert sha(art / name) == digest
    renderer = 'Presentation/SourceGroundedGestureVisual.gd'
    row = dict(base, status='prepared', family='mongbat_fidgets', assets=assets,
               classic_gesture_base_assets=base['assets'], grounded_gestures=[GROUPS['17'][0], GROUPS['18'][0]],
               presentation_script='res://' + renderer, presentation_script_sha256=sha(ROOT / 'Viewer' / renderer),
               authored_action_scene_sha256=scenes, authored_action_reference=references['17'],
               classic_motion_references=references,
               classic_action_categories=base['classic_action_categories'] | {
                   slot: clip for slot, (clip, _) in GROUPS.items()},
               authored_replacements=base['authored_replacements'] | {
                   'MongbatArmLift': 'Short arm lift with folded wings, following Classic group 17',
                   'Fidget2': 'Overhead reach with folded wings, following Classic group 18'})
    return [row], CLASSES
