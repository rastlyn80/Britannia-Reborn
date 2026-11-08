"""Pin the original Classic frames and the local Ophidian and Terathan action scenes."""
import hashlib
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'ophidian_terathan_actions'
CLASSES = {70: ['TerathanWarrior'], 71: ['TerathanDrone'], 85: ['OphidianMage', 'OphidianArchmage']}
PINCER_ROUTES = {'3': 'Death2', '5': 'ForelegThrust', '6': 'PincerOverhead',
                 '15': 'PincerBrace', '16': 'PincerRecoil', '18': 'MandibleTwitch'}
STAFF_ROUTES = {'3': 'Death2', '5': 'StaffReel', '6': 'StaffSweep', '13': 'StaffFlare',
                '15': 'StaffFeint', '16': 'StaffGuard', '18': 'StaffSettle'}
TREATMENTS = ('original', 'rounded', 'modern')
helpers = runpy.run_path(str(SCRIPTS / 'prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
scan = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))['original_mul_groups']


def source_groups():
    pins = read(SCRIPTS / 'ophidian-terathan-frame-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in pins['definitions']}
    groups, _, _ = scan(data, set(CLASSES))
    for body in CLASSES:
        spec = pins['bodies'][str(body)]
        found = {str(row['group']): row for row in groups if row['body'] == body}
        assert found.keys() == spec['groups'].keys()
        for slot, pin in spec['groups'].items():
            row = found[slot]
            assert row['archive'] == spec['archive'] and row['graphic'] == spec['graphic']
            assert row['layout'] == 'large' and not row['mobtype_prefers_uop']
            directions = row['directions']
            assert [direction['direction'] for direction in directions] == list(range(5))
            hashes = ''.join(direction['payload_sha256'] for direction in directions)
            assert pin == dict(counts=[direction['frames'] for direction in directions],
                               directions_sha256=hashlib.sha256(hashes.encode('ascii')).hexdigest())
        yield body, spec


def prepared(entries):
    rows = []
    for body, source in source_groups():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        mage = body == 85
        routes = STAFF_ROUTES if mage else PINCER_ROUTES
        renderer = 'OphidianMageActionsVisual' if mage else 'TerathanActionsVisual'
        stem = 'ophidian-mage-distinct-actions' if mage else f'terathan-{body}-distinct-actions'
        recipe = 'bake-ophidian-mage-distinct-actions.gd' if mage else 'bake-terathan-distinct-actions.gd'
        bake = read(ART / f'{stem}-bake.json')
        assert recipe in bake['inputs']
        for name, digest in bake['inputs'].items():
            path, = (folder / name for folder in (SCRIPTS, VIEWER / 'Presentation') if (folder / name).is_file())
            assert sha(path) == digest, name
        scenes, assets, retained = {}, {}, {}
        for treatment in TREATMENTS:
            original = base['assets'][treatment]
            replacement = f'res://local-art/creatures/{stem}-{treatment}.scn'
            old, new = sha(VIEWER / original[6:]), sha(VIEWER / replacement[6:])
            assert old == base['asset_sha256'][treatment]
            assert bake['scenes'][str(body)][treatment] == {'source': old, 'scene': new}
            scenes[treatment], assets[treatment], retained[treatment] = new, replacement, original
        references = {}
        for slot in routes:
            pin = source['groups'][slot]
            references[slot] = dict(body=body, group=int(slot), archive=source['archive'], graphic=source['graphic'],
                                    frames=pin['counts'][0], directions=list(range(5)),
                                    directional_payload_sha256=pin['directions_sha256'])
        dependencies = (renderer, 'SourceSpaceFallPlayback', 'CreatureFallPlayback', 'SourceGroundLookup')
        if mage:
            dependencies += ('SourceOphidianStaffVisual', 'SourceArmedLizardmanVisual')
        row = dict(base, family=FAMILY, status='prepared', assets=assets, classic_gesture_base_assets=retained,
                   authored_action_scene_sha256=scenes, authored_action_reference=references['3'],
                   classic_action_categories=base['classic_action_categories'] | routes,
                   classic_motion_references=references,
                   grounded_gestures=[clip for slot, clip in routes.items() if slot != '3'],
                   authored_replacements=base.get('authored_replacements', {}) | {
                       clip: f'Fitted on the retained source rig for Classic group {slot}' for slot, clip in routes.items()
                   },
                   native_extra_classic_actions=[int(slot) for slot in routes if slot not in ('5', '6')],
                   native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                   collapse_renderer_dependencies={
                       name: sha(VIEWER / f'Presentation/{name}.gd') for name in dependencies
                   },
                   presentation_script=f'res://Presentation/{renderer}.gd',
                   presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'))
        rows.append(row)
    return rows, CLASSES
