"""Verify the original frame references and the three retained creature rigs."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'pig_reaper_harpy_actions'
CLASSES = {203: ['Pig'], 47: ['Reaper'], 30: ['Harpy']}
KINDS = {203: 'pig', 47: 'reaper', 30: 'harpy'}
ROUTES = {
    203: {4: 'LookSide', 5: 'Attack', 6: 'Attack2', 8: 'Death', 9: 'Fidget', 10: 'Fidget2', 12: 'Death2'},
    47: {2: 'Death', 3: 'Death2', 4: 'BranchRake', 5: 'Attack', 6: 'OppositeSweep', 10: 'Hit',
         11: 'TrunkBend', 15: 'LeftBarkRecoil', 16: 'RightBarkRecoil', 17: 'Fidget', 18: 'CrownShake'},
    30: {2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'RaisedWingKick', 6: 'WingRush', 10: 'Hit',
         11: 'Wingbeat', 15: 'WingTuckRecoil', 16: 'WideWingRecoil', 17: 'Fidget', 18: 'FeatherFlick',
         19: 'Fly', 20: 'Land', 21: 'AirDeath'},
}
EXTRAS = {203: [4, 6, 8, 12], 47: [2, 3, 10, 15, 16, 18], 30: [2, 3, 10, 15, 16, 18, 21]}
VISUALS = {203: 'SourceQuadrupedCollapseVisual', 47: 'GiantSpiderActionsVisual', 30: 'HarpyActionsVisual'}
METHODS = {
    203: {'Attack': 'Recovered Pig strike with fitted floor clearance', 'Attack2': 'Fitted short snout drive',
          'LookSide': 'Fitted lateral head turn', 'Fidget2': 'Fitted quick head dip',
          'Death': 'Fitted belly-first collapse on the Pig stance', 'Death2': 'Fitted side collapse'},
    47: {'Attack': 'Recovered Reaper strike with one leaf pivot corrected',
         'BranchRake': 'Fitted left branch rake', 'OppositeSweep': 'Fitted right branch sweep',
         'Death2': 'Fitted side collapse with upper branch follow-through',
         'LeftBarkRecoil': 'Fitted left trunk and branch recoil', 'RightBarkRecoil': 'Fitted right trunk and branch recoil',
         'CrownShake': 'Fitted sway of the crown and upper branches'},
    30: {'RaisedWingKick': 'Fitted wing lift and talon strike', 'WingRush': 'Fitted low wing sweep',
         'Death2': 'Fitted grounded entry into the latter part of the recovered fall',
         'WingTuckRecoil': 'Fitted wing tuck', 'WideWingRecoil': 'Fitted wide wing recoil',
         'FeatherFlick': 'Fitted brief bilateral feather flick',
         'AirDeath': 'Recovered Third Dawn airborne death with a sampled vertical clearance correction'},
}


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/pig-reaper-harpy-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    common = ('bake-troll-actions.gd', 'bake-skeleton-actions.gd')
    scenes_by_body = {
        203: read_bake('pig-actions', ('bake-pig-actions.gd', 'bake-grazers-grizzly-actions.gd',
                                     'bake-dog-bear-actions.gd', 'bake-quadruped-actions.gd')),
        47: read_bake('reaper-actions', ('bake-reaper-actions.gd', *common)),
    }
    recipe = ROOT / 'scripts/prepare-harpy-air-death.py'
    donor = ART / 'harpy-air-death-donor.gltf'
    proof = read(ART / 'harpy-air-death-donor.json')
    assert proof['source_sha256'] == runpy.run_path(str(recipe))['PINS']
    assert proof['recipe_sha256'] == sha(recipe) and proof['gltf_sha256'] == sha(donor)
    assert proof['stats']['clips']['AirDeath']['matched_tracks'] == 31
    bake = read(ART / 'harpy-actions-bake.json')
    inputs = [ROOT / 'scripts' / name for name in ('bake-harpy-actions.gd', 'bake-mongbat-actions.gd', *common)]
    inputs.extend(VIEWER / 'Presentation' / name for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd'))
    assert bake['inputs'] == {path.name: sha(path) for path in [*inputs, donor]}
    scenes_by_body[30] = bake['scenes']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        kind = KINDS[body]
        refs = {slot: reference(ledger, body, int(slot), ('anim.mul', body, frames, digest))
                for slot, (frames, digest) in pins[str(body)].items()}
        assert set(refs) == {str(slot) for slot in routes}
        for slot, previous in base.get('classic_motion_references', {}).items():
            assert refs[slot] == previous
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            source = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            original = sha(VIEWER / source.removeprefix('res://'))
            assert original == base['asset_sha256'][treatment]
            file = f'{kind}-actions-{treatment}.scn'
            scenes[treatment] = sha(ART / file)
            assert scenes_by_body[body][treatment] == {'source': original, 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + file
        clips = dict(base['clip_sources'])
        if body in (47, 203):
            clips['RecoveredAttack'] = clips.pop('Attack')
        if body == 203:
            clips['RecoveredDeath'] = clips.pop('Death')
        visual = f'Presentation/{VISUALS[body]}.gd'
        row = dict(base, family=FAMILY, status='prepared', assets=assets, clip_sources=clips,
                   native_constructor_hues={CLASSES[body][0]: 0},
                   presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual),
                   authored_action_scene_sha256=scenes, authored_action_reference=refs['8' if body == 203 else '2'],
                   classic_motion_references=refs, native_extra_classic_actions=EXTRAS[body],
                   classic_action_categories={str(slot): clip for slot, clip in routes.items()},
                   authored_replacements=base.get('authored_replacements', {}) | METHODS[body])
        if body == 30:
            modern, = (record for record in ledger['original_new_protocol_actions']
                       if record['body'] == body and record['type'] == 14)
            assert (modern['mode'], modern['subaction'], modern['groups']) == (0, -1, [11])
            assert not modern['groups_with_uop_frame_headers']
            row.update(classic_gesture_base_assets=base['assets'], grounded_gestures=[],
                       new_action_categories=base.get('new_action_categories', {}) | {'14': 'Wingbeat'},
                       new_action_reference={key: modern[key] for key in ('body', 'type', 'mode', 'subaction', 'groups')})
            clips['AirDeath'] = 'uotdb/uotd/Models/Monsters/harpies_harpy_dieinair.grn'
        rows.append(row)
    return rows, CLASSES
