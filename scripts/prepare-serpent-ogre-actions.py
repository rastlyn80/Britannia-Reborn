"""Verify fitted actions and the retained Pillage and FaceWipe routes."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'serpent_ogre_actions'
CLASSES = {21: ['GiantSerpent'], 1: ['Ogre']}
ROUTES = {
    21: {2: 'Death', 3: 'Death2', 4: 'CoilSnap', 5: 'Attack', 6: 'LongStrike', 10: 'Hit',
         11: 'Pillage', 15: 'NeckDrawback', 16: 'LowNeckRecoil', 17: 'Fidget', 18: 'TailRipple'},
    1: {2: 'Death', 3: 'Death2', 4: 'OverheadHammer', 5: 'Attack', 6: 'HighUppercut', 10: 'Hit',
        11: 'FaceWipe', 15: 'ShoulderTurn', 16: 'ChestBrace', 17: 'Fidget', 18: 'ShoulderScratch'},
}
METHODS = {
    21: {'Death2': 'Fitted rising neck, roll and settle', 'CoilSnap': 'Fitted twisting snap from the coil',
         'LongStrike': 'Fitted forward extension of the neck chain', 'NeckDrawback': 'Fitted raised neck recoil',
         'LowNeckRecoil': 'Fitted low recoil', 'TailRipple': 'Fitted wave of the trailing coil'},
    1: {'Death2': 'Fitted backward collapse on the original rig', 'OverheadHammer': 'Fitted overhead swing with release',
        'HighUppercut': 'Fitted low wind-up and upward strike', 'ShoulderTurn': 'Fitted turned shoulder recoil',
        'ChestBrace': 'Fitted inward guard recoil', 'ShoulderScratch': 'Fitted hand lift to the near shoulder'},
}


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    baked = read_bake('serpent-ogre-actions', ('bake-serpent-ogre-actions.gd', 'bake-troll-actions.gd',
                                             'bake-skeleton-actions.gd'))
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/serpent-ogre-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base['classic_action_categories']['11'] == routes[11]
        refs = {slot: reference(ledger, body, int(slot), ('anim.mul', body, frames, digest))
                for slot, (frames, digest) in pins[str(body)].items()}
        assert set(refs) == {str(slot) for slot in routes}
        assert all(refs[slot] == previous for slot, previous in base.get('classic_motion_references', {}).items())
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            source = base['assets'][treatment]
            original = sha(VIEWER / source.removeprefix('res://'))
            assert original == base['asset_sha256'][treatment]
            file = f'serpent-ogre-actions-{body}-{treatment}.scn'
            scenes[treatment] = sha(ART / file)
            assert baked[str(body)][treatment] == {'source': original, 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + file
        modern, = (record for record in ledger['original_new_protocol_actions']
                   if record['body'] == body and record['type'] == 14)
        assert (modern['mode'], modern['subaction'], modern['groups']) == (0, -1, [11])
        assert not modern['groups_with_uop_frame_headers']
        visual = 'Presentation/' + ('GiantSpiderActionsVisual.gd' if body == 21 else 'SourceQuadrupedCollapseVisual.gd')
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual),
                   authored_action_scene_sha256=scenes, authored_action_reference=refs['2'],
                   classic_motion_references=refs, native_extra_classic_actions=[2, 3, 10, 15, 16, 18],
                   classic_action_categories={str(slot): clip for slot, clip in routes.items()},
                   new_action_categories=base.get('new_action_categories', {}) | {'14': routes[11]},
                   new_action_reference={key: modern[key] for key in ('body', 'type', 'mode', 'subaction', 'groups')},
                   authored_replacements=base.get('authored_replacements', {}) | METHODS[body])
        if body == 21:
            row['native_constructor_hue_ranges'] = {'GiantSerpent': [[2001, 2018]]}
        else:
            row['native_constructor_hues'] = {'Ogre': 0}
        rows.append(row)
    return rows, CLASSES
