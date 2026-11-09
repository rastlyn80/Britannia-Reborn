"""Validate the source-backed Stone Gargoyle, Bake Kitsune and Gazer Larva action scenes."""
import hashlib
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'gargoyle_kitsune_larva_actions'
CLASSES = {67: ['StoneGargoyle'], 246: ['BakeKitsune'], 778: ['GazerLarva']}
ROUTES = {
    67: {2: 'Death', 3: 'Death', 4: 'Attack', 5: 'Attack', 6: 'Attack', 11: 'Fidget',
         15: 'StoneWingRecoil', 16: 'StoneWingRecoil', 17: 'Fidget', 18: 'StoneArmCheck',
         19: 'Fly', 20: 'TakeOff', 21: 'StoneSettle'},
    246: {8: 'Death', 9: 'Fidget', 10: 'KitsuneCall', 12: 'Death2'},
    778: {2: 'Death', 3: 'Death', 11: 'Fidget', 15: 'LarvaRecoil',
          16: 'LarvaRecoil', 17: 'Fidget', 18: 'LarvaTilt'},
}
EXTRAS = {67: [2, 3, 15, 16, 18, 21], 246: [8, 10, 12], 778: [2, 3, 15, 16, 18]}
NAMES = {
    67: ('stone-gargoyle-distinct-actions', 'stone-gargoyle-distinct-actions', 'StoneGargoyleActionsVisual'),
    246: ('bake-kitsune-call', 'kitsune-call', 'HopperActionsVisual'),
    778: ('gazer_larva/swarm-distinct-actions', 'gazer-larva-distinct-actions', 'GazerLarvaActionsVisual'),
}
GROUNDED = {67: ['StoneWingRecoil', 'StoneArmCheck', 'StoneSettle'], 246: ['KitsuneCall']}
FITTED = {67: [15, 18, 21], 246: [10], 778: [15, 18]}
RENDERERS = {
    67: ['StoneGargoyleActionsVisual', 'TerathanActionsVisual', 'SourceSpaceFallPlayback',
         'CreatureFallPlayback', 'SourceGroundLookup'],
    246: ['HopperActionsVisual', 'TerathanActionsVisual', 'SourceSpaceFallPlayback',
          'CreatureFallPlayback', 'SourceGroundLookup'],
    778: ['GazerLarvaActionsVisual', 'SourceGazerLarvaVisual'],
}
TREATMENTS = ('original', 'rounded', 'modern')
helpers = runpy.run_path(str(SCRIPTS / 'prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))


def check_frames():
    pins = read(SCRIPTS / 'gargoyle-kitsune-larva-frame-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in pins['definitions']}
    records, _, flags = ledger['original_mul_groups'](data, CLASSES.keys())
    assert pins['mobtypes'] == {str(body): list(value) for body, value in flags.items()}
    assert {row['body'] for row in records} == CLASSES.keys()
    redirects, _ = ledger['original_definition_redirects'](data, CLASSES.keys(), records, {})
    for body, expected in pins['redirects'].items():
        assert expected == {row['scope']: [row['graphic'], row['legacy_hue']]
                            for row in redirects if row['body'] == int(body)}
    for body, source in pins['sources'].items():
        groups = {str(row['group']): row for row in records if row['body'] == int(body)}
        assert groups.keys() == source['groups'].keys()
        for slot, row in groups.items():
            assert all(row[key] == source[key] for key in ('archive', 'graphic', 'layout'))
            assert not row['mobtype_prefers_uop']
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert source['groups'][slot] == [
                [item['frames'] for item in directions], hashlib.sha256(hashes).hexdigest()]
        routes = ROUTES[int(body)]
        for first, second in source['aliases']:
            assert routes[first] == routes[second]
    return pins


def prepared(entries):
    pins = check_frames()
    rows = []
    for body, names in CLASSES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        stem, recipe, renderer = NAMES[body]
        bake = read(ART / f'{stem}-bake.json')
        assert f'bake-{recipe}.gd' in bake['inputs']
        for name, digest in bake['inputs'].items():
            path, = (folder / name for folder in (SCRIPTS, VIEWER / 'Presentation', ART)
                     if (folder / name).is_file())
            assert sha(path) == digest, name
        assets, retained, scenes = {}, {}, {}
        for treatment in TREATMENTS:
            # The affine Larva has the original mesh and one refined treatment.
            variant = 'original' if body == 778 and treatment == 'rounded' else treatment
            source = base['assets'][variant]
            scene = f'res://local-art/creatures/{stem}-{variant}.scn'
            old, new = sha(VIEWER / source[6:]), sha(VIEWER / scene[6:])
            assert old == base['asset_sha256'][variant]
            assert bake['scenes'][variant] == {'source': old, 'scene': new}
            assets[treatment], retained[treatment], scenes[treatment] = scene, source, new
        source = pins['sources'][str(body)]
        references = {
            str(slot): dict(body=body, source_body=body, group=slot, archive=source['archive'],
                            graphic=source['graphic'], frames=source['groups'][str(slot)][0][0],
                            directions=list(range(5)),
                            directional_payload_sha256=source['groups'][str(slot)][1])
            for slot in ROUTES[body]
        }
        motions = base.get('authored_replacements', {}) | {
            ROUTES[body][slot]: f'Fitted on the retained rig for Classic group {slot}' for slot in FITTED[body]
        }
        if body == 67:
            motions['AirDeath'] = 'Recovered matching Third Dawn gargoyle motion for a death received during flight'
        rows.append(dict(
            base, family=FAMILY, status='prepared', assets=assets,
            classic_gesture_base_assets=retained, authored_action_scene_sha256=scenes,
            authored_action_reference=references[str(FITTED[body][0])], classic_motion_references=references,
            classic_action_categories=base.get('classic_action_categories', {}) | {
                str(slot): clip for slot, clip in ROUTES[body].items()},
            native_extra_classic_actions=EXTRAS[body], grounded_gestures=GROUNDED.get(body, []),
            native_constructor_hues=dict.fromkeys(names, 0), authored_replacements=motions,
            classic_definition_redirects=pins['redirects'][str(body)],
            presentation_script=f'res://Presentation/{renderer}.gd',
            presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
            collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                            for name in RENDERERS[body]},
        ))
    return rows, CLASSES
