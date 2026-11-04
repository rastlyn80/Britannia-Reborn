"""Check distinct action scenes for the original Wraith, Drake and Walrus rigs."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'wraith_drake_walrus_actions'
CLASSES = {26: ['Shade', 'Spectre', 'Spellbinder', 'Wraith'], 60: ['Drake'], 61: ['Drake'], 221: ['Walrus']}
DRAKE = {'2': 'Death', '3': 'Death2', '4': 'Attack', '6': 'WingRake', '10': 'Hit', '11': 'DragonDip',
         '12': 'DragonBreath', '15': 'FoldedFlinch', '16': 'LowWingGuard', '17': 'Fidget', '18': 'WingLift',
         '21': 'AirDeath'}
ROUTES = {
    26: {'2': 'Death', '3': 'Death2', '4': 'Attack', '6': 'OverheadRake', '10': 'Hit', '11': 'GhostSway',
         '15': 'ReachingRecoil', '16': 'RaisedGuard', '17': 'Fidget', '18': 'SpectralClutch'},
    60: DRAKE,
    61: DRAKE,
    221: {'4': 'FlipperAlert', '5': 'Attack', '6': 'TuskThrust', '8': 'Death',
          '9': 'Fidget', '10': 'HeadHitch', '12': 'Death2'},
}
EXTRAS = {26: [2, 3, 10, 15, 16, 18], 60: [2, 3, 10, 15, 16, 18, 21],
          61: [2, 3, 10, 15, 16, 18, 21], 221: [4, 6, 8, 10, 12]}
FITTED = {26: ('2', '6', '15', '16', '18'), 60: ('2', '6', '15', '16', '18', '21'),
          61: ('2', '6', '15', '16', '18', '21'), 221: ('4', '6', '10', '12')}


def prepared(entries):
    helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
    read, sha, read_bake = (helpers[name] for name in ('read', 'sha', 'read_bake'))
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/wraith-drake-walrus-frame-pins.json')
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base.get('classic_action_categories', {}).items() <= routes.items()
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        assert refs.keys() == routes.keys()
        for slot, prior in base.get('classic_motion_references', {}).items():
            assert prior.items() <= refs[slot].items()
            refs[slot] = prior
        if body == 26:
            assert base['authored_action_reference'].items() <= refs['11'].items()
        name = {26: 'wraith', 221: 'walrus'}.get(body, 'drake')
        stem = f'{name}-distinct-{body}' if name == 'drake' else f'{name}-distinct'
        visual = {'wraith': 'WraithActionsVisual', 'drake': 'DrakeActionsVisual', 'walrus': 'AlternateCollapseVisual'}[name]
        recipe = read_bake(f'{stem}-actions', (f'bake-{name}-distinct-actions.gd', 'bake-zombie-actions.gd',
                                              'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))[str(body)]
        assets, scenes, original_assets = {}, {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            path = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            source = sha(VIEWER / path.removeprefix('res://'))
            assert source == base['asset_sha256'][treatment]
            file = f'{stem}-actions-{treatment}.scn'
            scenes[treatment] = sha(ART / file)
            assert recipe[treatment] == {'source': source, 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + file
            original_assets[treatment] = path
        sources = dict(base['clip_sources'])
        if body != 221:
            sources['RecoveredDeath'] = sources.pop('Death')
            sources['Death2'] = sources['RecoveredDeath']
        hues = base['native_constructor_hues'] if body == 26 else {CLASSES[body][0]: 0}
        candidate = dict(base, status='prepared', family=FAMILY, assets=assets,
                         presentation_script=f'res://Presentation/{visual}.gd',
                         presentation_script_sha256=sha(VIEWER / f'Presentation/{visual}.gd'),
                         classic_gesture_base_assets=original_assets,
                         authored_action_scene_sha256=scenes,
                         authored_action_reference=refs['21' if name == 'drake' else ('2' if body == 26 else '12')],
                         classic_motion_references=refs, classic_action_categories=routes,
                         native_extra_classic_actions=EXTRAS[body], native_constructor_hues=hues,
                         clip_sources=sources, authored_replacements=base.get('authored_replacements', {}) | {
                             routes[slot]: f'Fitted motion on the original rig from Classic group {slot}'
                             for slot in FITTED[body]})
        if body != 221:
            dependencies = ('CreatureFallPlayback', 'SourceGroundLookup',
                            'SourceWraithVisual' if body == 26 else 'SourceDragonBreathVisual')
            candidate['collapse_renderer_dependencies'] = {
                key: sha(VIEWER / f'Presentation/{key}.gd') for key in dependencies}
        rows.append(candidate)
    return rows, CLASSES
