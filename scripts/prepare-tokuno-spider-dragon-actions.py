"""Pin fitted Yomotsu Warrior, Dread Spider and Dragon actions."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
LOCAL = VIEWER / 'local-art/creatures'
FAMILY = 'tokuno_spider_dragon_actions'
CLASSES = {245: ['YomotsuWarrior'], 11: ['DreadSpider'],
           12: ['Dragon', 'GreaterDragon'], 59: ['Dragon', 'GreaterDragon']}
DRAGON_ROUTES = {'2': 'Death', '3': 'Death2', '6': 'WingRake', '11': 'DragonDip', '12': 'DragonBreath',
                 '15': 'FoldedFlinch', '16': 'LowWingGuard', '18': 'WingLift', '21': 'AirDeath'}
ROUTES = {
    245: {'11': 'Fidget', '15': 'YomotsuRecoil', '16': 'YomotsuRecoil', '17': 'WeaponRest', '18': 'Fidget'},
    11: {'2': 'Death', '3': 'Death2', '11': 'Fidget', '15': 'DreadReach', '16': 'DreadReach',
         '17': 'Fidget', '18': 'DreadRock'},
    12: DRAGON_ROUTES, 59: DRAGON_ROUTES,
}
EXTRAS = {245: [15, 16, 18], 11: [15, 16, 18, 2, 3],
          12: [15, 16, 18, 2, 3, 21], 59: [15, 16, 18, 2, 3, 21]}
FITTED = {245: (15, 17), 11: (3, 15, 18), 12: (2, 6, 15, 16, 18, 21), 59: (2, 6, 15, 16, 18, 21)}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha, read_bake = (HELPERS[key] for key in ('read', 'sha', 'read_bake'))


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/tokuno-spider-dragon-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and any(identity['body'] == body for identity in row['bodies']))
        identity, = (item for item in base['bodies'] if item['body'] == body)
        previous = base.get('classic_action_categories', {}) | base.get('classic_action_categories_by_body', {}).get(str(body), {})
        assert previous.items() <= routes.items()
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        assert refs.keys() == routes.keys()
        for slot, old in base.get('classic_motion_references', {}).items():
            assert old.items() <= refs[slot].items()
            refs[slot] = old
        stem, baked = bake_scenes(body)
        assets, scenes, originals = {}, {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            old = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            scene = f'{stem}-{treatment}.scn'
            digest = sha(LOCAL / scene)
            source = sha(VIEWER / old.removeprefix('res://'))
            assert source == base['asset_sha256'][treatment] and baked[treatment] == {'source': source, 'scene': digest}
            assets[treatment], scenes[treatment], originals[treatment] = 'res://local-art/creatures/' + scene, digest, old
        descriptions = {routes[str(slot)]: f'Fitted original rig motion referenced to Classic group {slot}'
                        for slot in FITTED[body]}
        if body in (12, 59):
            descriptions['Death2'] = 'Retained original Dragon ground collapse, assigned to Classic group 3'
        candidate = dict(base, bodies=[identity], status='prepared', family=FAMILY, assets=assets,
                         authored_action_scene_sha256=scenes, classic_gesture_base_assets=originals,
                         classic_action_categories=routes, classic_motion_references=refs,
                         authored_action_reference=refs[str(FITTED[body][0])], native_extra_classic_actions=EXTRAS[body],
                         native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                         authored_replacements=base.get('authored_replacements', {}) | descriptions)
        if body != 245:
            visual = 'DreadSpiderActionsVisual' if body == 11 else 'DrakeActionsVisual'
            parent = 'VampireBatFallVisual' if body == 11 else 'SourceDragonBreathVisual'
            candidate.update(presentation_script=f'res://Presentation/{visual}.gd',
                             presentation_script_sha256=sha(VIEWER / f'Presentation/{visual}.gd'),
                             collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                             for name in (parent, 'CreatureFallPlayback', 'SourceGroundLookup')})
        rows.append(candidate)
    return rows, CLASSES


def bake_scenes(body):
    if body == 11:
        stem = 'dread-spider-distinct-actions'
        bake = read(LOCAL / f'{stem}-bake.json')
        inputs = [ROOT / 'scripts' / name for name in (
            f'bake-{stem}.gd', 'bake-giant-spider-actions.gd', 'bake-quadruped-actions.gd')]
        inputs.append(VIEWER / 'Presentation/SourceGroundLookup.gd')
        assert bake['inputs'] == {path.name: sha(path) for path in inputs}
        return stem, bake['scenes']
    animal = 'yomotsu-warrior' if body == 245 else 'original-dragon'
    stem = f'{animal}-distinct-actions' if body == 245 else f'{animal}-distinct-{body}-actions'
    files = (f'bake-{animal}-distinct-actions.gd', 'bake-zombie-actions.gd',
             'bake-troll-actions.gd', 'bake-skeleton-actions.gd')
    return stem, read_bake(stem, files)[str(body)]
