"""Check the original rigs and the fitted Zombie, Corpser and Gargoyle actions."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'zombie_corpser_gargoyle_actions'
CLASSES = {3: ['Zombie'], 8: ['Corpser'], 4: ['Gargoyle']}
NAMES = {3: 'zombie', 8: 'corpser', 4: 'gargoyle'}
VISUALS = {3: 'SourceQuadrupedCollapseVisual', 8: 'GiantSpiderActionsVisual', 4: 'MongbatActionsVisual'}
ROUTES = {
    3: {2: 'Death2', 3: 'Death', 4: 'BackhandReach', 5: 'Attack', 6: 'OverheadClaw', 10: 'Hit',
        11: 'ArmsRaise', 15: 'DoubleOver', 16: 'StaggerBack', 17: 'Fidget', 18: 'LookUp'},
    8: {2: 'Death2', 3: 'Death', 4: 'InwardHook', 5: 'Attack', 6: 'DoubleLash',
        12: 'Emerge', 17: 'Fidget', 18: 'TendrilCurl'},
    4: {2: 'Death', 3: 'Death2', 4: 'RaisedWingRake', 5: 'Attack', 6: 'ForwardWingPunch', 10: 'Hit',
        11: 'KneelingLunge', 12: 'Cast', 13: 'KneelingStagger', 15: 'CrouchRecoil',
        16: 'OpenWingGuard', 17: 'Fidget', 18: 'WingDip', 21: 'AirDeath'},
}
EXTRAS = {3: [2, 3, 10, 15, 16, 18], 8: [2, 3, 18], 4: [2, 3, 10, 13, 15, 16, 18, 21]}
FITTED = {3: (2, 4, 6, 15, 16, 18), 8: (2, 3, 4, 6, 18), 4: (3, 4, 6, 13, 15, 16, 18)}


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    common = ('bake-troll-actions.gd', 'bake-skeleton-actions.gd')
    recipes = {
        3: read_bake('zombie-actions', ('bake-zombie-actions.gd', *common)),
        8: read_bake('corpser-actions', ('bake-corpser-actions.gd', 'bake-zombie-actions.gd', *common)),
    }
    recipe = ROOT / 'scripts/prepare-gargoyle-air-death.py'
    source = runpy.run_path(str(recipe))
    donor = ART / 'gargoyle-air-death-donor.gltf'
    proof = read(ART / 'gargoyle-air-death-donor.json')
    assert proof['source_sha256'] == source['PINS'] and proof['recipe_sha256'] == sha(recipe)
    assert proof['gltf_sha256'] == sha(donor) and proof['stats']['clips']['AirDeath']['matched_tracks'] == 54
    bake = read(ART / 'gargoyle-actions-bake.json')
    inputs = [ROOT / 'scripts' / name for name in (
        'bake-gargoyle-actions.gd', 'bake-harpy-actions.gd', 'bake-mongbat-actions.gd', *common)]
    inputs.extend(VIEWER / 'Presentation' / name for name in ('WaterElementalFidgets.gd', 'SourceGroundLookup.gd'))
    assert bake['inputs'] == {path.name: sha(path) for path in [*inputs, donor]}
    recipes[4] = bake['scenes']

    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/zombie-corpser-gargoyle-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        categories = {str(slot): clip for slot, clip in routes.items()}
        assert base['profile'] == 'monster' and base['classic_action_categories'].items() <= categories.items()
        refs = {slot: reference(ledger, body, int(slot), ('anim.mul', body, frames, digest))
                for slot, (frames, digest) in pins[str(body)].items()}
        assert set(refs) == set(categories)
        for slot, previous in base.get('classic_motion_references', {}).items():
            assert previous.items() <= refs[slot].items()
            refs[slot] = previous
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            original = sha(VIEWER / base['assets'][treatment].removeprefix('res://'))
            assert original == base['asset_sha256'][treatment]
            file = f'{NAMES[body]}-actions-{treatment}.scn'
            scenes[treatment] = sha(ART / file)
            assert recipes[body][str(body)][treatment] == {'source': original, 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + file
        visual = f'Presentation/{VISUALS[body]}.gd'
        methods = {routes[slot]: f'Fitted original-rig motion from Classic group {slot}' for slot in FITTED[body]}
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual),
                   authored_action_scene_sha256=scenes, authored_action_reference=refs['2'],
                   classic_motion_references=refs, native_extra_classic_actions=EXTRAS[body],
                   classic_action_categories=categories, native_constructor_hues={CLASSES[body][0]: 0},
                   authored_replacements=base.get('authored_replacements', {}) | methods)
        if body == 8:
            emergence = base['corpser_emergence']
            row['authored_replacements']['RecoveredDeath'] = base['authored_replacements']['Death']
            assert emergence['baker_sha256'] == sha(VIEWER / 'Presentation/BakeCorpserEmergence.gd')
            group, = (record for record in ledger['original_mul_group_candidates']
                      if record['body'] == body and record['group'] == 12 and record['archive'] == 'anim.mul')
            assert group['directions'][1]['payload_sha256'] == emergence['reference_payload_sha256']
        if body == 4:
            modern, = (record for record in ledger['original_new_protocol_actions']
                       if record['body'] == body and record['type'] == 14)
            assert (modern['mode'], modern['subaction'], modern['groups']) == (0, -1, [11])
            assert not modern['groups_with_uop_frame_headers']
            row.update(classic_gesture_base_assets=base['assets'], grounded_gestures=['KneelingLunge', 'Cast'],
                       clip_sources=base['clip_sources'] | {'AirDeath': source['PREFIX'] + source['AIR_DEATH']},
                       new_action_categories=base.get('new_action_categories', {}) | {'14': 'KneelingLunge'},
                       new_action_reference={key: modern[key] for key in ('body', 'type', 'mode', 'subaction', 'groups')})
        rows.append(row)
    return rows, CLASSES
