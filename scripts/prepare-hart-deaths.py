"""Seal the two Great Hart deaths on the retained stag rig."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
VISUAL = 'Presentation/SourceQuadrupedCollapseVisual.gd'
REFERENCES = {
    4: (3, '4f15b77d73876f40353c37a1dfe979a9f50af706f170df6605fd6fb1289b6ad0'),
    8: (6, '05e40b0d5aee96a6ea0ef408a9b81beeec400936cde4b50cf5a6706956b7bd05'),
    12: (6, 'fb3b7fa40071691a88c703278333b543aa92f45739e9b2718ecbf0fe643fdcf2'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == 'deer_stag'
             and [identity['body'] for identity in row['bodies']] == [234])
    assert base['classic_gesture_native_sha256'] and not base.get('classic_gesture_batch')
    bake = read(VIEWER / 'local-art/creatures/hart-death-bake.json')
    for key, path in {
        'recipe': ROOT / 'scripts/bake-hart-deaths.gd',
        'baker': ROOT / 'scripts/bake-quadruped-actions.gd',
        'arm_solver': VIEWER / 'Presentation/WaterElementalFidgets.gd',
        'skin_solver': VIEWER / 'Presentation/SourceGroundLookup.gd',
    }.items():
        assert bake[key] == sha(path)
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    groups = {str(slot): reference(ledger, 234, slot, ('anim.mul', 234, frames, digest))
              for slot, (frames, digest) in REFERENCES.items()}
    assert groups['4'] == base['classic_motion_references']['4']
    assets, scenes = {}, {}
    for treatment, source in base['assets'].items():
        target = f'local-art/creatures/hart-death-{treatment}.scn'
        source_digest = sha(VIEWER / source.removeprefix('res://'))
        assert source_digest == base['asset_sha256'][treatment]
        scenes[treatment] = sha(VIEWER / target)
        assert bake['scenes'][treatment] == {'source': source_digest, 'scene': scenes[treatment]}
        assets[treatment] = 'res://' + target
    clips = dict(base['clip_sources'])
    clips['RecoveredDeath'] = clips.pop('Death')
    row = dict(base, status='prepared', family='hart_deaths', assets=assets, clip_sources=clips,
               presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
               authored_action_scene_sha256=scenes, authored_action_reference=groups['8'],
               classic_motion_references=base['classic_motion_references'] | groups,
               native_extra_classic_actions=[4, 8, 12],
               classic_action_categories=base['classic_action_categories'] | {'8': 'Death', '12': 'Death2'},
               authored_replacements=base['authored_replacements'] | {
                   'Death': 'Fitted rear and side collapse with folded legs and settled antlers',
                   'Death2': 'Fitted head-first fall and opposite roll with settled antlers'})
    return [row], {234: ['GreatHart', 'EnragedHart']}
