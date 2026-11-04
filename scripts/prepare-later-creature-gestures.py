"""Pin fitted Bone Knight, Vampire Bat, Pixie and Plague Beast actions."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
LOCAL = VIEWER / 'local-art/creatures'
FAMILY = 'later_creature_gestures'
CLASSES = {57: ['BoneKnight'], 317: ['VampireBat', 'VampireBatFamiliar'],
           128: ['Pixie'], 775: ['PlagueBeast', 'PlagueBeastLord']}
STEMS = {57: 'bone-knight', 317: 'vampire-bat', 128: 'pixie', 775: 'plague-beast'}
ROUTES = {
    57: {'4': 'Attack', '5': 'ShieldSideCut', '6': 'ShieldOvercut', '10': 'Hit', '11': 'KnightDip',
         '15': 'ShieldDuck', '16': 'BladeParry', '17': 'Fidget', '18': 'BladeSalute'},
    317: {'2': 'Death', '3': 'Death', '11': 'BatWingCheck', '15': 'BankRecoil', '16': 'BankRecoil',
          '17': 'Fidget', '18': 'WingPulse', '20': 'BatSettle', '21': 'AirDeath'},
    128: {'11': 'Fidget', '15': 'PixieFlinch', '16': 'PixieFlinch', '17': 'Fidget', '18': 'PixieSpiral'},
    775: {'11': 'Fidget', '15': 'MassRecoil', '16': 'MassRecoil', '17': 'Fidget', '18': 'TendrilRipple'},
}
FITTED = {57: (5, 6, 15, 16, 18), 317: (15, 18, 21), 128: (15, 18), 775: (15, 18)}
EXTRAS = {57: [10, 15, 16, 18], 317: [15, 16, 18, 2, 3, 21], 128: [15, 16, 18], 775: [15, 16, 18]}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha, read_bake = (HELPERS[key] for key in ('read', 'sha', 'read_bake'))


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/later-creature-gesture-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base.get('classic_action_categories', {}).items() <= routes.items()
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        assert refs.keys() == routes.keys()
        for slot, old in base.get('classic_motion_references', {}).items():
            assert old.items() <= refs[slot].items()
            refs[slot] = old
        stem = STEMS[body] + '-distinct-actions'
        bake = bake_scenes(stem, body)
        assets, scenes, originals = {}, {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            old = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            source = sha(VIEWER / old.removeprefix('res://'))
            scene = f'{stem}-{treatment}.scn'
            digest = sha(LOCAL / scene)
            assert source == base['asset_sha256'][treatment] and bake[treatment] == {'source': source, 'scene': digest}
            assets[treatment] = 'res://local-art/creatures/' + scene
            scenes[treatment] = digest
            originals[treatment] = old
        added = {routes[str(slot)]: f'Fitted original rig motion referenced to Classic group {slot}' for slot in FITTED[body]}
        candidate = dict(base, status='prepared', family=FAMILY, assets=assets, authored_action_scene_sha256=scenes,
                         classic_gesture_base_assets=originals, classic_action_categories=routes,
                         classic_motion_references=refs, authored_action_reference=refs[str(FITTED[body][0])],
                         native_extra_classic_actions=EXTRAS[body],
                         native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                         authored_replacements=base.get('authored_replacements', {}) | added)
        if body == 57:
            visual = 'Presentation/BoneKnightActionsVisual.gd'
            candidate.update(presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual),
                             grounded_gestures=[routes[str(slot)] for slot in FITTED[body]],
                             collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                             for name in ('SourceHeldPropsVisual', 'SourceArmedLizardmanVisual',
                                                                          'SourceGroundLookup')})
        if body == 317:
            visual = 'Presentation/VampireBatFallVisual.gd'
            candidate.update(presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual),
                             collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                             for name in ('CreatureFallPlayback', 'SourceGroundLookup')})
        rows.append(candidate)
    return rows, CLASSES


def bake_scenes(stem, body):
    recipe = f'bake-{stem}.gd'
    if body == 128:
        return read_bake(stem, (recipe, 'bake-zombie-actions.gd', 'bake-troll-actions.gd',
                                'bake-skeleton-actions.gd'))[str(body)]
    bake = read(LOCAL / f'{stem}-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts' / recipe)
    return bake['scenes']
