"""Verify the original Daemon rig and separate ground and airborne actions."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'daemon_wyvern_polar_actions'
CLASSES = {9: ['Daemon'], 62: ['Wyvern'], 213: ['PolarBear']}
ROUTES = {'2': 'Death', '3': 'Death2', '4': 'Attack', '6': 'LowRake', '10': 'Hit',
          '11': 'DaemonWingCheck', '12': 'DaemonCast', '13': 'WingShoulderStagger',
          '15': 'ChestGuard', '16': 'LowForearmGuard', '17': 'Fidget', '18': 'TailPause', '21': 'AirDeath'}
FITTED = ('3', '6', '13', '15', '16', '18', '21')


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    base, = (row for row in entries if row['status'] == 'validated'
             and [identity['body'] for identity in row['bodies']] == [9])
    assert base['classic_action_categories'].items() <= ROUTES.items()
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    pins = read(ROOT / 'scripts/daemon-distinct-frame-pins.json')
    refs = {slot: reference(ledger, 9, int(slot), pin) for slot, pin in pins.items()}
    assert refs.keys() == ROUTES.keys()
    for slot, old in base['classic_motion_references'].items():
        assert old.items() <= refs[slot].items()
        refs[slot] = old
    recipe = read_bake('daemon-distinct-actions', ('bake-daemon-distinct-actions.gd', 'bake-zombie-actions.gd',
                                                  'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))['9']
    assets, scenes = {}, {}
    for treatment, path in base['assets'].items():
        source = sha(VIEWER / path.removeprefix('res://'))
        assert source == base['asset_sha256'][treatment]
        name = f'daemon-distinct-actions-{treatment}.scn'
        scenes[treatment] = sha(ART / name)
        assert recipe[treatment] == {'source': source, 'scene': scenes[treatment]}
        assets[treatment] = 'res://local-art/creatures/' + name
    visual = 'Presentation/DaemonActionsVisual.gd'
    dependencies = ('MongbatActionsVisual', 'SourceGroundedGestureVisual', 'SourceGroundLookup')
    candidate = dict(base, status='prepared', family=FAMILY, assets=assets,
                     presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual),
                     collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd') for name in dependencies},
                     authored_action_scene_sha256=scenes, authored_action_reference=refs['21'],
                     classic_gesture_base_assets=base['assets'], grounded_gestures=['Hit'],
                     classic_motion_references=refs, classic_action_categories=ROUTES,
                     native_extra_classic_actions=[2, 3, 10, 13, 15, 16, 18, 21], native_constructor_hues={'Daemon': 0},
                     authored_replacements=base.get('authored_replacements', {}) | {
                         ROUTES[slot]: f'Fitted motion on the original rig from Classic group {slot}' for slot in FITTED})
    return [candidate, *prepare_wyvern_polar(entries, ledger, read, sha, read_bake, reference)], CLASSES


def prepare_wyvern_polar(entries, ledger, read, sha, read_bake, reference):
    routes_by_body = {
        62: {'2': 'Death', '3': 'Death2', '10': 'Hit', '11': 'Fidget', '15': 'WingRecoil',
             '16': 'WingRecoil', '17': 'Fidget', '18': 'WingRear', '21': 'AirDeath'},
        213: {'4': 'MuzzleLift', '5': 'PolarRearStrike', '6': 'Attack', '8': 'Death',
              '9': 'Fidget', '10': 'HindCrouch', '12': 'Death2'},
    }
    pins_by_body = read(ROOT / 'scripts/wyvern-polar-frame-pins.json')
    rows = []
    for body, routes in routes_by_body.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base.get('classic_action_categories', {}).items() <= routes.items()
        name = 'wyvern' if body == 62 else 'polar-bear'
        helpers = (('bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd') if body == 62
                   else ('bake-dog-bear-actions.gd', 'bake-quadruped-actions.gd'))
        recipe = read_bake(f'{name}-distinct-actions', (f'bake-{name}-distinct-actions.gd', *helpers))[str(body)]
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins_by_body[str(body)].items()}
        assert refs.keys() == routes.keys()
        assets, scenes, original_assets = {}, {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            path = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            source = sha(VIEWER / path.removeprefix('res://'))
            assert source == base['asset_sha256'][treatment]
            file = f'{name}-distinct-actions-{treatment}.scn'
            scenes[treatment] = sha(ART / file)
            assert recipe[treatment] == {'source': source, 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + file
            original_assets[treatment] = path
        visual = 'DaemonActionsVisual' if body == 62 else 'AlternateCollapseVisual'
        candidate = dict(base, status='prepared', family=FAMILY, assets=assets,
                         presentation_script=f'res://Presentation/{visual}.gd',
                         presentation_script_sha256=sha(VIEWER / f'Presentation/{visual}.gd'),
                         classic_gesture_base_assets=original_assets,
                         authored_action_scene_sha256=scenes, authored_action_reference=refs['21' if body == 62 else '12'],
                         classic_motion_references=refs, classic_action_categories=routes,
                         native_extra_classic_actions=[2, 3, 10, 15, 16, 18, 21] if body == 62 else [4, 6, 8, 10, 12],
                         native_constructor_hues={CLASSES[body][0]: 0})
        if body == 62:
            deps = ('MongbatActionsVisual', 'SourceGroundedGestureVisual', 'SourceGroundLookup')
            candidate.update(grounded_gestures=['Hit'],
                             collapse_renderer_dependencies={key: sha(VIEWER / f'Presentation/{key}.gd') for key in deps})
            candidate['authored_replacements'] = base.get('authored_replacements', {}) | {
                'Death2': 'Separate collapse using the recovered Wyvern rig',
                'AirDeath': 'Seven-frame airborne posture followed by a grounded continuation',
                'WingRecoil': 'Fitted recoil for pixel-identical Classic groups 15 and 16',
                'WingRear': 'Fitted raised neck and wing sweep from Classic group 18',
            }
        else:
            sources = dict(base['clip_sources'])
            sources['RecoveredAttack'] = sources.pop('Attack')
            candidate.update(clip_sources=sources, authored_replacements=base.get('authored_replacements', {}) | {
                'Attack': 'Recovered strike with a measured pelvis floor correction',
                'MuzzleLift': 'Fitted alert muzzle lift from Classic group 4',
                'PolarRearStrike': 'Fitted upright strike from Classic group 5',
                'HindCrouch': 'Fitted hind-leg crouch from Classic group 10',
                'Death2': 'Fitted forward sprawl from Classic group 12',
            })
        rows.append(candidate)
    return rows
