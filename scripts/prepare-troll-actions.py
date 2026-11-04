"""Pin the distinct Classic Troll clips and the newer kneeling action."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'troll_actions'
CLASSES = {53: ['Troll'], 54: ['Troll'], 55: ['FrostTroll']}
VISUAL = 'Presentation/SourceLizardActionsVisual.gd'
ROUTES = {2: 'Death2', 3: 'Death', 4: 'WideSwipe', 5: 'Attack', 6: 'RisingSweep',
          10: 'Hit', 11: 'KneelingSwing', 15: 'OverheadGuard', 16: 'ShoulderGuard',
          17: 'Fidget', 18: 'KnuckleCheck'}
METHODS = {
    'Death2': 'Fitted near-knee collapse with a raised hand before the fall',
    'WideSwipe': 'Fitted broad single-arm attack',
    'RisingSweep': 'Fitted low windup into an upward attack',
    'OverheadGuard': 'Fitted pivot away with a raised guard',
    'ShoulderGuard': 'Fitted opposite shoulder guard',
    'KnuckleCheck': 'Fitted forward hand and head movement',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    bake = read(VIEWER / 'local-art/creatures/troll-actions-bake.json')
    inputs = (
        ROOT / 'scripts/bake-troll-actions.gd',
        ROOT / 'scripts/bake-skeleton-actions.gd',
        VIEWER / 'Presentation/WaterElementalFidgets.gd',
        VIEWER / 'Presentation/SourceGroundLookup.gd',
    )
    assert bake['inputs'] == {path.name: sha(path) for path in inputs}
    pins = read(ROOT / 'scripts/troll-action-frame-pins.json')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base['classic_gesture_native_sha256'] and base['classic_action_categories']['11'] == 'KneelingSwing'
        assert {str(slot) for slot in ROUTES} == pins[str(body)].keys()
        references = {slot: reference(ledger, body, int(slot), ('anim.mul', body, frames, digest))
                      for slot, (frames, digest) in pins[str(body)].items()}
        assert references['11']['directional_payload_sha256'] == base['authored_action_reference']
        modern, = (entry for entry in ledger['original_new_protocol_actions']
                   if entry['body'] == body and entry['type'] == 14)
        assert (modern['mode'], modern['subaction'], modern['groups']) == (0, -1, [11])
        assert not modern['groups_with_uop_frame_headers']
        original, = (entry for entry in ledger['original_mul_group_candidates']
                     if (entry['body'], entry['group']) == (body, 11) and 'matching_classic_route' in entry)
        assert original['layout'] == 'large' and original['matching_classic_route']['resolved'] == 'KneelingSwing'
        assets, scenes = {}, {}
        for treatment, source in base['assets'].items():
            digest = sha(VIEWER / source.removeprefix('res://'))
            assert digest == base['asset_sha256'][treatment]
            target = f'local-art/creatures/troll-actions-{body}-{treatment}.scn'
            scenes[treatment] = sha(VIEWER / target)
            assert bake['scenes'][str(body)][treatment] == {'source': digest, 'scene': scenes[treatment]}
            assets[treatment] = 'res://' + target
        rows.append(dict(base, family=FAMILY, status='prepared', assets=assets,
                         presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
                         authored_action_scene_sha256=scenes, authored_action_reference=references['2'],
                         classic_motion_references=references, native_extra_classic_actions=[10, 15, 16, 18, 2, 3],
                         classic_action_categories=base['classic_action_categories'] |
                         {str(slot): label for slot, label in ROUTES.items()},
                         new_action_categories=base.get('new_action_categories', {}) | {'14': 'KneelingSwing'},
                         new_action_reference={key: modern[key] for key in ('body', 'type', 'mode', 'subaction', 'groups')},
                         authored_replacements=base['authored_replacements'] | METHODS))
    return rows, CLASSES
