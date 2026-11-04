"""Verify fitted Alligator and Lich scenes against the pinned source groups."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'alligator_lich_actions'
CLASSES = {202: ['Alligator'], 24: ['Lich']}
NAMES = {202: ('alligator', 'AlternateCollapseVisual'), 24: ('lich', 'LichActionsVisual')}
ROUTES = {
    202: {4: 'Alert', 5: 'Attack', 6: 'JawLunge', 8: 'Death', 9: 'Fidget', 10: 'SlowLook', 12: 'Death2'},
    24: {2: 'Death', 3: 'Death2', 10: 'Hit', 13: 'StaffStagger', 15: 'HandGuard', 16: 'StaffBrace',
         17: 'Fidget', 18: 'StaffShift'},
}
EXTRAS = {202: [4, 6, 8, 10, 12], 24: [2, 3, 10, 13, 15, 16, 18]}
FITTED = {202: (4, 6, 8, 10), 24: (3, 13, 15, 16, 18)}


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/alligator-lich-frame-pins.json')
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        name, visual = NAMES[body]
        visual_path = f'Presentation/{visual}.gd'
        recipe = read_bake(f'{name}-actions', (f'bake-{name}-actions.gd', 'bake-zombie-actions.gd',
                                             'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))[str(body)]
        categories = {str(slot): clip for slot, clip in routes.items()}
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        assert set(refs) == set(categories)
        previous_routes = base.get('classic_action_categories', {})
        assert all(slot not in categories or categories[slot] == clip for slot, clip in previous_routes.items())
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            origin = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            source = sha(VIEWER / origin.removeprefix('res://'))
            assert source == base['asset_sha256'][treatment]
            filename = f'{name}-actions-{treatment}.scn'
            scenes[treatment] = sha(ART / filename)
            assert recipe[treatment] == {'source': source, 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + filename
        methods = {routes[slot]: f'Fitted original-rig motion from Classic group {slot}' for slot in FITTED[body]}
        sources = dict(base['clip_sources'])
        if body == 202:
            sources['RecoveredDeath'] = sources.pop('Death')
            sources['Death2'] = sources['RecoveredDeath']
        elif body == 24:
            assert sha(VIEWER / base['staff_asset'].removeprefix('res://')) == base['staff']['asset_sha256']
        row = dict(base, status='prepared', family=FAMILY, assets=assets, clip_sources=sources,
                   presentation_script='res://' + visual_path, presentation_script_sha256=sha(VIEWER / visual_path),
                   authored_action_scene_sha256=scenes, authored_action_reference=refs['8' if body == 202 else '2'],
                   classic_motion_references=refs, native_extra_classic_actions=EXTRAS[body],
                   classic_action_categories=previous_routes | categories,
                   native_constructor_hues={CLASSES[body][0]: 0},
                   authored_replacements=base.get('authored_replacements', {}) | methods)
        rows.append(row)
    return rows, CLASSES
