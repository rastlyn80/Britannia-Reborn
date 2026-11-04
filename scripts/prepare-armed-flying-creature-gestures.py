"""Pin fitted Juka Warrior, Balron and Bone Magi actions."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
LOCAL = VIEWER / 'local-art/creatures'
FAMILY = 'armed_flying_creature_gestures'
CLASSES = {764: ['JukaWarrior'], 40: ['Balron'], 148: ['BoneMagi', 'SkeletalMage']}
STEMS = {764: 'juka-warrior', 40: 'balron', 148: 'bone-magi'}
ROUTES = {
    764: {'4': 'Attack', '6': 'StepSlash', '11': 'Fidget', '14': 'Cast2',
          '15': 'JukaStagger', '16': 'JukaStagger', '17': 'Fidget', '18': 'JukaShoulderCheck'},
    40: {'2': 'Death', '3': 'Death', '4': 'Attack', '6': 'BalronRake', '10': 'Hit',
         '11': 'Fidget', '12': 'DaemonCast', '13': 'BalronStagger', '15': 'BalronGuard',
         '16': 'BalronGuard', '17': 'Fidget', '18': 'BalronPause', '21': 'AirDeath'},
    148: {'4': 'Attack', '5': 'StaffPush', '6': 'StaffSlash', '10': 'Hit',
          '11': 'MageStaffCheck', '15': 'StaffRecoil', '16': 'StaffRecoil', '17': 'Fidget', '18': 'StaffRaise'},
}
FITTED = {764: (6, 15, 18), 40: (6, 13, 15, 18, 21), 148: (5, 6, 15, 18)}
EXTRAS = {764: [15, 16, 18], 40: [2, 3, 10, 13, 15, 16, 18, 21], 148: [10, 15, 16, 18]}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha, read_bake = (HELPERS[key] for key in ('read', 'sha', 'read_bake'))


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/armed-flying-creature-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base.get('classic_action_categories', {}).items() <= routes.items()
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        expected = routes.keys() - {'14'} if body == 764 else routes.keys()
        assert refs.keys() == expected
        if body == 764:
            assert base['classic_action_categories']['14'] == 'Cast2'
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
        if body == 40:
            visual = 'Presentation/VampireBatFallVisual.gd'
            candidate.update(presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual),
                             collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                             for name in ('CreatureFallPlayback', 'SourceGroundLookup')})
        rows.append(candidate)
    return rows, CLASSES


def bake_scenes(stem, body):
    recipe = f'bake-{stem}.gd'
    if body == 764:
        return read_bake(stem, (recipe, 'bake-zombie-actions.gd', 'bake-troll-actions.gd',
                                'bake-skeleton-actions.gd'))[str(body)]
    bake = read(LOCAL / f'{stem}-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts' / recipe)
    return bake['scenes']
