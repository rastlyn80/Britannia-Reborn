"""Pin fitted actions on the original Copper Elemental and Kaze Kemono rigs."""

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'copper_kaze_actions'
CLASSES = {110: ['DullCopperElemental'], 196: ['KazeKemono']}
MODELS = {110: ('dull-copper', 14), 196: ('kaze-kemono', 196)}
ROUTES = {
    110: {'15': 'CopperRecoil', '16': 'CopperBrace', '17': 'Fidget', '18': 'CopperShift'},
    196: {'15': 'KazeDoubleFlinch', '16': 'KazeForearmGuard', '17': 'Fidget', '18': 'KazeForwardSway'},
}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha, read_bake = (HELPERS[key] for key in ('read', 'sha', 'read_bake'))


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/copper-kaze-frame-pins.json')
    assert pins['definition_archives'] == {item['name']: item['sha256'] for item in ledger['archives']
                                          if item['name'] in pins['definition_archives']}
    redirects = [row for row in ledger['original_definition_redirect_candidates'] if row['body'] == 110]
    assert [(r['scope'], r['definition'], r['line'], r['graphic'], r['legacy_hue'],
             r['source_indexed_frames'], r['target_indexed_frames']) for r in redirects] == [
        ('mobile', 'Body.def', 56, 14, 2419, False, True), ('corpse', 'Corpse.def', 57, 14, 2419, False, True)]
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base.get('classic_action_categories', {}).items() <= routes.items()
        name, source_body = MODELS[body]
        stem = f'{name}-actions'
        refs = {slot: reference(ledger, source_body, int(slot), pin) for slot, pin in pins['groups'][str(body)].items()}
        assert refs.keys() == routes.keys()
        bake = read_bake(stem, (f'bake-{stem}.gd', 'bake-zombie-actions.gd',
                                'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))[str(body)]
        assets, scenes, originals = {}, {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            old = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            target = f'local-art/creatures/{stem}-{treatment}.scn'
            digest = sha(VIEWER / target)
            source = sha(VIEWER / old.removeprefix('res://'))
            assert source == base['asset_sha256'][treatment] and bake[treatment] == {'source': source, 'scene': digest}
            assets[treatment], scenes[treatment], originals[treatment] = 'res://' + target, digest, old
        extras = [15, 16, 18]
        descriptions = {routes[str(slot)]: f'Fitted gesture from Classic body {source_body} group {slot}' for slot in extras}
        action_reference = refs['15'] if body == source_body else dict(refs['15'], body=body, source_body=source_body)
        candidate = dict(base, status='prepared', family=FAMILY, assets=assets, authored_action_scene_sha256=scenes,
                         classic_gesture_base_assets=originals, classic_action_categories=routes,
                         classic_motion_references=refs, authored_action_reference=action_reference,
                         native_extra_classic_actions=extras, native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                         authored_replacements=base.get('authored_replacements', {}) | descriptions)
        if body == 110:
            visual = VIEWER / 'Presentation/DullCopperActionsVisual.gd'
            candidate.update(presentation_script='res://Presentation/DullCopperActionsVisual.gd',
                             presentation_script_sha256=sha(visual), classic_motion_definition_sources=redirects)
        rows.append(candidate)
    return rows, CLASSES
