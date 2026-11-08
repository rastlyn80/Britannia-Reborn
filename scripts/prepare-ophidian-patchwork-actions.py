"""Pin the fitted actions and retained assets for bodies 86 and 309."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'ophidian_patchwork_actions'
CLASSES = {86: ['OphidianWarrior', 'OphidianKnight'], 309: ['PatchworkSkeleton']}
ROUTES = {
    86: {'2': 'Death', '3': 'Death2', '4': 'Attack', '5': 'BardicheLowSweep', '6': 'BardicheHighChop',
         '11': 'BardicheDip', '15': 'BardicheHighRecoil', '16': 'BardicheLowBrace', '17': 'Fidget',
         '18': 'BardicheGripShift'},
    309: {'11': 'Fidget', '15': 'WideArmRecoil', '16': 'WideArmRecoil', '17': 'Fidget', '18': 'ReachAndHitch'},
}
FITTED = {86: (3, 5, 6, 15, 16, 18), 309: (15, 18)}
EXTRAS = {86: [15, 16, 18, 2, 3], 309: [15, 16, 18]}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha, read_bake = (HELPERS[key] for key in ('read', 'sha', 'read_bake'))


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/ophidian-patchwork-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base.get('classic_action_categories', {}).items() <= routes.items()
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        assert refs.keys() == routes.keys()
        if body == 86:
            assert base['authored_action_reference'].items() <= refs['11'].items()
        else:
            assert refs['11']['directional_payload_sha256'] == refs['17']['directional_payload_sha256'] == (
                base['legacy_slot11_evidence']['payload_signature'])
            assert refs['15']['directional_payload_sha256'] == refs['16']['directional_payload_sha256']
        stem, baked = bake_scenes(body)
        assets, scenes = {}, {}
        for treatment, old in base['assets'].items():
            path = f'local-art/creatures/{stem}-{treatment}.scn'
            digest = sha(VIEWER / path)
            source = sha(VIEWER / old.removeprefix('res://'))
            assert source == base['asset_sha256'][treatment] and baked[treatment] == {'source': source, 'scene': digest}
            assets[treatment], scenes[treatment] = 'res://' + path, digest
        descriptions = {routes[str(slot)]: f'Fitted original rig motion referenced to Classic group {slot}'
                        for slot in FITTED[body]}
        candidate = dict(base, status='prepared', family=FAMILY, assets=assets, authored_action_scene_sha256=scenes,
                         classic_gesture_base_assets=base['assets'], classic_action_categories=routes,
                         classic_motion_references=refs, authored_action_reference=refs[str(FITTED[body][0])],
                         native_extra_classic_actions=EXTRAS[body], native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                         authored_replacements=base.get('authored_replacements', {}) | descriptions)
        if body == 86:
            visual = VIEWER / 'Presentation/OphidianActionsVisual.gd'
            candidate.update(presentation_script='res://Presentation/OphidianActionsVisual.gd',
                             presentation_script_sha256=sha(visual),
                             collapse_renderer_dependencies={name: sha(visual.with_name(name + '.gd'))
                                                             for name in ('SourceArmedLizardmanVisual',
                                                                          'CreatureFallPlayback', 'SourceGroundLookup')})
        rows.append(candidate)
    return rows, CLASSES


def bake_scenes(body):
    if body == 309:
        stem = 'patchwork-skeleton-actions'
        files = (f'bake-{stem}.gd', 'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd')
        return stem, read_bake(stem, files)[str(body)]
    stem = 'ophidian-bardiche-actions'
    bake = read(VIEWER / f'local-art/creatures/{stem}-bake.json')
    inputs = [ROOT / 'scripts' / name for name in (f'bake-{stem}.gd', 'bake-ophidian-bardiche.gd',
              'bake-skeleton-axe-trial.gd', 'bake-troll-weapons-trial.gd', 'ophidian-bardiche-clearance.gd')]
    inputs.append(VIEWER / 'Presentation/SourceGroundLookup.gd')
    assert bake['inputs'] == {path.name: sha(path) for path in inputs}
    return stem, bake['scenes']
