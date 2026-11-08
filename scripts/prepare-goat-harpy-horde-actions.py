"""Validate the six occurrence-ordered Classic action packages."""
import hashlib
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'goat_harpy_horde_actions'
CLASSES = {
    88: ['MountainGoat'], 87: ['OphidianMatriarch'], 79: ['LichLord'],
    149: ['Succubus', 'Szavetra'], 73: ['StoneHarpy'], 776: ['HordeMinion', 'HordeMinionFamiliar'],
}
ROUTES = {
    88: {4: 'LookSide', 5: 'Attack', 6: 'Attack2', 8: 'Death', 9: 'Fidget', 10: 'Fidget2', 12: 'Death2'},
    87: {3: 'Death2', 6: 'MatriarchTailStrike', 15: 'MatriarchOverheadBrace',
         16: 'MatriarchRecoil', 18: 'MatriarchTailLift'},
    79: {3: 'Death2', 13: 'LordCastingReach', 15: 'LordFreeHandGuard',
         16: 'LordStaffRaise', 18: 'LordShoulderTurn'},
    149: {2: 'Death', 3: 'Death', 4: 'Attack', 5: 'Attack', 6: 'Attack',
          11: 'Fidget', 15: 'SuccubusWingRecoil', 16: 'SuccubusWingRecoil', 17: 'Fidget', 18: 'SuccubusWingLift'},
    73: {2: 'Death', 3: 'Death2', 4: 'Attack', 5: 'RaisedWingKick', 6: 'WingRush', 11: 'Wingbeat',
         15: 'WingTuckRecoil', 16: 'WideWingRecoil', 17: 'Fidget', 18: 'FeatherFlick',
         19: 'Fly', 20: 'Land', 21: 'AirDeath'},
    776: {3: 'Death2', 15: 'HordeBrace', 16: 'HordeBrace', 18: 'HordeGlance'},
}
EXTRAS = {
    88: [4, 6, 8, 12], 87: [3, 15, 16, 18], 79: [3, 13, 15, 16, 18],
    149: [2, 3, 15, 16, 18], 73: [2, 3, 15, 16, 18, 21], 776: [3, 15, 16, 18],
}
NAMES = {
    88: ('mountain-goat', 'mountain-goat', 'TerathanActionsVisual'),
    87: ('matriarch', 'matriarch', 'TerathanActionsVisual'),
    79: ('lich-lord', 'lich-lord', 'LichLordActionsVisual'),
    149: ('succubus', 'succubus-horde', 'TerathanActionsVisual'),
    73: ('stone-harpy', 'stone-harpy', 'StoneHarpyActionsVisual'),
    776: ('horde-minion', 'succubus-horde', 'HopperActionsVisual'),
}
GROUNDED = {
    88: ['LookSide', 'Attack', 'Attack2', 'Fidget', 'Fidget2'],
    87: ['MatriarchTailStrike', 'MatriarchOverheadBrace', 'MatriarchRecoil', 'MatriarchTailLift'],
    79: ['LordCastingReach', 'LordFreeHandGuard', 'LordStaffRaise', 'LordShoulderTurn'],
    149: ['SuccubusWingRecoil', 'SuccubusWingLift'],
    73: ['Attack', 'Fidget', 'RaisedWingKick', 'WingRush', 'WingTuckRecoil', 'WideWingRecoil', 'FeatherFlick', 'Land'],
    776: ['HordeBrace', 'HordeGlance'],
}
AUTHORED = {
    88: [4, 5, 6, 8, 10, 12], 87: list(ROUTES[87]), 79: list(ROUTES[79]),
    149: [15, 18], 73: [3, 5, 6, 11, 15, 16, 18, 21], 776: [3, 15, 18],
}
RENDERER_INPUTS = {
    79: ('LichActionsVisual', 'LichVisual', 'LichMaterial', 'LichGrip', 'MeasuredCreatureSupport'),
    73: ('HarpyActionsVisual', 'MongbatActionsVisual', 'SourceGroundedGestureVisual'),
    776: ('TerathanActionsVisual',),
}
TREATMENTS = ('original', 'rounded', 'modern')
helpers = runpy.run_path(str(SCRIPTS / 'prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))


def check_frames():
    pins = read(SCRIPTS / 'goat-harpy-horde-frame-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in pins['definitions']}
    graphics = {int(body) for body in pins['sources']}
    records, _, flags = ledger['original_mul_groups'](data, graphics | CLASSES.keys())
    assert pins['mobtypes'] == {str(body): list(value) for body, value in flags.items()}
    assert {row['body'] for row in records} == graphics
    redirects, _ = ledger['original_definition_redirects'](data, set(CLASSES), records, {})
    for body, declared in pins['redirects'].items():
        assert declared == {
            row['scope']: {'graphic': row['graphic'], 'hue': row['legacy_hue']}
            for row in redirects if row['body'] == int(body)
        }
    for body, source in pins['sources'].items():
        rows = {str(row['group']): row for row in records if row['body'] == int(body)}
        assert rows.keys() == source['groups'].keys()
        for slot, row in rows.items():
            assert all(row[key] == source[key] for key in ('archive', 'graphic', 'layout'))
            assert not row['mobtype_prefers_uop']
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert source['groups'][slot] == {
                'counts': [item['frames'] for item in directions],
                'directions_sha256': hashlib.sha256(hashes).hexdigest(),
            }
    return pins


def motion_reference(body, source_body, source, slot):
    pin = source['groups'][str(slot)]
    return dict(body=body, source_body=source_body, group=slot, archive=source['archive'],
                graphic=source['graphic'], frames=pin['counts'][0], directions=list(range(5)),
                directional_payload_sha256=pin['directions_sha256'])


def prepared(entries):
    pins = check_frames()
    rows = []
    for body, names in CLASSES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and any(identity['body'] == body for identity in row['bodies']))
        identity, = (item for item in base['bodies'] if item['body'] == body)
        stem, recipe, renderer = NAMES[body]
        bake = read(ART / f'{stem}-actions-bake.json')
        assert f'bake-{recipe}-actions.gd' in bake['inputs']
        for name, digest in bake['inputs'].items():
            path, = (folder / name for folder in (SCRIPTS, VIEWER / 'Presentation') if (folder / name).is_file())
            assert sha(path) == digest, name
        assets, retained, scenes = {}, {}, {}
        for treatment in TREATMENTS:
            original = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            scene = f'res://local-art/creatures/{stem}-actions-{treatment}.scn'
            old, new = sha(VIEWER / original[6:]), sha(VIEWER / scene[6:])
            assert old == base['asset_sha256'][treatment]
            expected = {'source': old, 'scene': new}
            if body == 73:
                harpy = read(ART / 'harpy-actions-bake.json')['scenes'][treatment]
                donor_rest = sha(ART / f'harpies_harpy-{treatment}.gltf')
                donor = sha(ART / f'harpy-actions-{treatment}.scn')
                assert donor == harpy['scene']
                expected.update(donor=donor, donor_rest=donor_rest)
            assert bake['scenes'][str(body)][treatment] == expected
            assets[treatment], retained[treatment], scenes[treatment] = scene, original, new
        if body == 79:
            assert sha(VIEWER / base['staff_asset'][6:]) == base['staff']['asset_sha256']
        source_body = pins['source_for'][str(body)]
        source = pins['sources'][str(source_body)]
        routes = ROUTES[body]
        references = {str(slot): motion_reference(body, source_body, source, slot) for slot in routes}
        deps = (renderer, 'SourceGroundLookup', *RENDERER_INPUTS.get(body, ()))
        if body not in (73, 79):
            deps += ('SourceSpaceFallPlayback', 'CreatureFallPlayback')
        methods = base.get('authored_replacements', {}) | {
            routes[slot]: f'{"Transferred from the matching Harpy rig" if body == 73 else "Fitted on the retained rig"}'
                          f' for Classic group {slot}' for slot in AUTHORED[body]
        }
        clip_sources = dict(base['clip_sources'])
        if body == 88:
            for clip in ('Attack', 'Death'):
                clip_sources['Recovered' + clip] = clip_sources.pop(clip)
        row = dict(base, bodies=[identity], family=FAMILY, status='prepared', assets=assets,
                   clip_sources=clip_sources, classic_gesture_base_assets=retained,
                   authored_action_scene_sha256=scenes, authored_action_reference=next(iter(references.values())),
                   classic_action_categories=base.get('classic_action_categories', {}) | {
                       str(slot): clip for slot, clip in routes.items()
                   },
                   classic_motion_references=references, native_extra_classic_actions=EXTRAS[body],
                   grounded_gestures=GROUNDED.get(body, []),
                   native_constructor_hues=dict.fromkeys(names, 0), authored_replacements=methods,
                   classic_definition_redirects=pins['redirects'][str(body)],
                   presentation_script=f'res://Presentation/{renderer}.gd',
                   presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
                   collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd') for name in deps})
        rows.append(row)
    return rows, CLASSES
