"""Pin source groups and the fitted Earth Elemental, Gazer and Imp scenes."""

import hashlib
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'earth_gazer_imp_actions'
CLASSES = {14: ['EarthElemental', 'SummonedEarthElemental', 'PlagueSpawn'], 22: ['Gazer'], 74: ['Imp']}
MODELS = {14: ('earth-elemental', 'earth', 'EarthAssemblyActionsVisual'),
          22: ('gazer', 'gazer', 'GazerActionsVisual'), 74: ('imp', 'imp', 'SourceQuadrupedCollapseVisual')}
ROUTES = {
    14: {2: 'Death', 3: 'Death2', 4: 'StoneReach', 5: 'Attack', 6: 'OverheadSmash', 10: 'Hit',
         11: 'StoneGesture', 12: 'Assemble', 15: 'StoneHunch', 16: 'StoneBrace', 17: 'Fidget', 18: 'HeavyShift'},
    22: {2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'Attack2', 6: 'EyeVolley', 17: 'Fidget', 18: 'EyeSpread'},
    74: {2: 'Death', 3: 'Death', 4: 'Attack', 5: 'Attack', 6: 'Attack', 10: 'Hit', 11: 'WingTwitch',
         15: 'ShoulderRecoil', 16: 'ShoulderRecoil', 17: 'WingTwitch', 18: 'Fidget2'},
}
EXTRAS = {14: [2, 3, 10, 15, 16, 18], 22: [2, 3, 18], 74: [2, 3, 10, 15, 16]}
FITTED = {14: (3, 4, 6, 15, 16, 18), 22: (3, 6, 18), 74: (15,)}


def reference(ledger, body, slot, pin):
    archive, graphic, frames, directions, digest = pin
    group, = (row for row in ledger['original_mul_group_candidates']
              if (row['body'], row['group']) == (body, slot) and 'matching_classic_route' in row)
    records = group['directions']
    assert (group['archive'], group['graphic'], group['mobtype_prefers_uop']) == (archive, graphic, False)
    assert [item['direction'] for item in records] == directions
    assert {item['frames'] for item in records} == {frames}
    hashes = ''.join(item['payload_sha256'] for item in records).encode('ascii')
    assert hashlib.sha256(hashes).hexdigest() == digest
    return dict(body=body, group=slot, archive=archive, graphic=graphic, directions=directions,
                frames=frames, directional_payload_sha256=digest)


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/earth-gazer-imp-frame-pins.json')
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        name, baker, visual = MODELS[body]
        recipe = read_bake(f'{name}-actions', (f'bake-{baker}-actions.gd', 'bake-zombie-actions.gd',
                                             'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))
        categories = {str(slot): clip for slot, clip in routes.items()}
        assert base.get('classic_action_categories', {}).items() <= categories.items()
        refs = {slot: reference(ledger, body, int(slot), value) for slot, value in pins[str(body)].items()}
        assert set(refs) == set(categories)
        for slot, previous in base.get('classic_motion_references', {}).items():
            assert previous.items() <= refs[slot].items()
            refs[slot] = previous
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            origin = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            source = sha(VIEWER / origin.removeprefix('res://'))
            assert source == base['asset_sha256'][treatment]
            file = f'{name}-actions-{treatment}.scn'
            scenes[treatment] = sha(ART / file)
            assert recipe[str(body)][treatment] == {'source': source, 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + file
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   authored_action_scene_sha256=scenes, authored_action_reference=refs['2'],
                   classic_motion_references=refs, native_extra_classic_actions=EXTRAS[body],
                   classic_action_categories=categories,
                   authored_replacements=base.get('authored_replacements', {}) | {
                       routes[slot]: f'Fitted original-rig motion from Classic group {slot}' for slot in FITTED[body]})
        if body != 14:
            row['native_constructor_hues'] = {CLASSES[body][0]: 0}
        path = f'Presentation/{visual}.gd'
        row.update(presentation_script='res://' + path, presentation_script_sha256=sha(VIEWER / path))
        if body == 22:
            path = 'Presentation/GazerEyeFlash.gdshader'
            row['gazer_flash_sha256'] = sha(VIEWER / path)
        if body in (14, 74):
            original, = (record for record in ledger['original_new_protocol_actions']
                         if record['body'] == body and record['type'] == 14)
            assert (original['mode'], original['subaction'], original['groups']) == (0, -1, [11])
            assert not original['groups_with_uop_frame_headers']
            row.update(new_action_categories=base.get('new_action_categories', {}) | {'14': routes[11]},
                       new_action_reference={key: original[key] for key in ('body', 'type', 'mode', 'subaction', 'groups')})
        rows.append(row)
    return rows, CLASSES
