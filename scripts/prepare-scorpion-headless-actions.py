"""Check the fitted Scorpion and Headless One scenes and original action groups."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'scorpion_headless_actions'
CLASSES = {48: ['Scorpion'], 31: ['HeadlessOne']}
VISUAL = 'Presentation/AlternateCollapseVisual.gd'
ROUTES = {
    48: {2: 'Death2', 3: 'Death', 4: 'Attack', 5: 'Attack2', 6: 'ClawSnap', 10: 'Hit', 11: 'ClawDraw',
         15: 'LowRecoil', 16: 'RaisedClawRecoil', 17: 'Fidget', 18: 'TailCheck'},
    31: {2: 'Death2', 3: 'Death', 10: 'Hit', 11: 'Pillage', 15: 'BackGuard', 16: 'ShoulderHunch',
         17: 'Fidget', 18: 'LowSwing'},
}
FITTED = {48: (2, 6, 15, 16, 18), 31: (2, 15, 16, 18)}


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/scorpion-headless-frame-pins.json')
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        name = 'scorpion' if body == 48 else 'headless'
        baked = read_bake(f'{name}-actions', (f'bake-{name}-actions.gd', 'bake-zombie-actions.gd',
                                            'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))[str(body)]
        categories = {str(slot): clip for slot, clip in routes.items()}
        assert base.get('classic_action_categories', {}).items() <= categories.items()
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        assert set(refs) == set(categories)
        for slot, previous in base.get('classic_motion_references', {}).items():
            assert previous.items() <= refs[slot].items()
            refs[slot] = previous
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            origin = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            source = sha(VIEWER / origin.removeprefix('res://'))
            assert source == base['asset_sha256'][treatment]
            filename = f'{name}-actions-{treatment}.scn'
            scenes[treatment] = sha(ART / filename)
            assert baked[treatment] == {'source': source, 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + filename
        row = dict(base, status='prepared', family=FAMILY, assets=assets,
                   presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
                   authored_action_scene_sha256=scenes, authored_action_reference=refs['2'],
                   classic_motion_references=refs, native_extra_classic_actions=[2, 3, 10, 15, 16, 18],
                   classic_action_categories=categories,
                   authored_replacements=base.get('authored_replacements', {}) | {
                       routes[slot]: f'Fitted original-rig motion from Classic group {slot}' for slot in FITTED[body]})
        if body == 48:
            row['native_constructor_hues'] = {'Scorpion': 0}
        else:
            row['native_constructor_hue_ranges'] = {'HeadlessOne': [[1002, 1058]]}
        rows.append(row)
    return rows, CLASSES
