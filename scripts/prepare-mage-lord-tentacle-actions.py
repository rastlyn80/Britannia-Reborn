"""Bind the Evil Mage Lord and Swamp Tentacle action trials to their exact sources."""

import hashlib
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'mage_lord_tentacle_actions'
CLASSES = {125: ['EvilMageLord'], 126: ['EvilMageLord'], 66: ['SwampTentacle']}
MAGE = {'5': 'RaisedCast', '6': 'RaisedCast', '11': 'ReadyHand', '15': 'WardRecoil',
        '16': 'WardRecoil', '17': 'ReadyHand', '18': 'StafflessBend'}
SWAMP = {'3': 'Death2', '6': 'DoubleWhip', '18': 'CurlAndRise'}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha, read_bake = (HELPERS[key] for key in ('read', 'sha', 'read_bake'))
TREATMENTS = ('original', 'rounded', 'modern')


def source_references():
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    pins = read(ROOT / 'scripts/mage-lord-tentacle-frame-pins.json')
    assert pins['definitions'] == {name: sha(data / name) for name in pins['definitions']}
    definitions = [line.split('#', 1)[0].split() for line in (data / 'Bodyconv.def').read_text(errors='replace').splitlines()]
    assert [parts for parts in definitions if parts and parts[0] in ('125', '126')] == [
        ['125', '21', '-1', '-1', '-1', '-1'], ['126', '21', '-1', '-1', '-1', '-1']]
    for name in ('Body.def', 'Corpse.def'):
        lines = (data / name).read_text(errors='replace').splitlines()
        assert [line.split('#', 1)[0].split() for line in lines if line.split()[:1] == ['66']] == [['66', '{8}', '61']]
    reader = runpy.run_path(str(ROOT / 'scripts/build-creature-actions.py'))['original_mul_groups']
    rows, _, _ = reader(data, {8, 125, 126})
    references = {}
    for body in CLASSES:
        source = 8 if body == 66 else body
        wanted = pins['groups']['8' if body == 66 else 'mage_lord']
        groups = {}
        for slot, (archive, graphic, frames, digest) in wanted.items():
            row, = (record for record in rows if (record['body'], record['group']) == (source, int(slot)))
            directions = row['directions']
            assert (row['archive'], row['graphic'], row['layout'], row['mobtype_prefers_uop']) == (archive, graphic, 'large', False)
            assert [direction['direction'] for direction in directions] == list(range(5))
            assert {direction['frames'] for direction in directions} == {frames}
            payloads = ''.join(direction['payload_sha256'] for direction in directions).encode('ascii')
            assert hashlib.sha256(payloads).hexdigest() == digest
            groups[slot] = dict(body=source, group=int(slot), archive=archive, graphic=graphic, frames=frames,
                                directions=list(range(5)), directional_payload_sha256=digest)
        references[body] = groups
    return references


def prepared(entries):
    references = source_references()
    mage_bake = read_bake('evil-mage-lord-actions', ('bake-evil-mage-lord-actions.gd', 'bake-occurrence-gestures.gd',
                         'bake-zombie-actions.gd', 'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))['125']
    swamp_bake = read(ART / 'swamp-tentacle-actions-bake.json')
    swamp_inputs = (ROOT / 'scripts/bake-swamp-tentacle-actions.gd', ROOT / 'scripts/test-quadruped-actions.gd',
                    VIEWER / 'Presentation/SourceGroundLookup.gd')
    assert swamp_bake['inputs'] == {path.name: sha(path) for path in swamp_inputs}
    rows = []
    for body in CLASSES:
        swamp = body == 66
        stem = 'swamp-tentacle' if swamp else 'evil-mage-lord'
        base, = (row for row in entries if row['status'] == 'validated' and any(i['body'] == body for i in row['bodies']))
        expected = ('flails_swamp_tentacles', {66, 129}) if swamp else ('mages_evil_mage_master', {125, 126})
        assert (base['kind'], {identity['body'] for identity in base['bodies']}) == expected
        identity, = (record for record in base['bodies'] if record['body'] == body)
        routes = SWAMP if swamp else MAGE
        previous = base.get('classic_action_categories', {})
        assert not routes.keys() & previous.keys() and references[body].keys() == routes.keys()
        assert swamp or previous == {'12': 'Cast2', '14': 'Cast2'}
        assets, scenes, originals = {}, {}, {}
        for treatment in TREATMENTS:
            old = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            target = f'local-art/creatures/{stem}-actions-{treatment}.scn'
            original = sha(VIEWER / old.removeprefix('res://'))
            digest = sha(VIEWER / target)
            bake = swamp_bake['scenes'] if swamp else mage_bake
            assert original == base['asset_sha256'][treatment] and bake[treatment] == {'source': original, 'scene': digest}
            assets[treatment], scenes[treatment], originals[treatment] = 'res://' + target, digest, old
        source = references[body]['3' if swamp else '6']
        fitted = {clip: f'Fitted on the retained rig using Classic group {slot}' for slot, clip in routes.items()}
        row = dict(base, bodies=[identity], status='prepared', family=FAMILY, assets=assets,
                   authored_action_scene_sha256=scenes, classic_gesture_base_assets=originals,
                   classic_action_categories=previous | routes, classic_motion_references=references[body],
                   authored_action_reference=dict(source, body=body, source_body=8) if swamp else source,
                   native_extra_classic_actions=[3, 18] if swamp else [15, 16, 18],
                   native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                   authored_replacements=base.get('authored_replacements', {}) | fitted)
        visual = 'SwampTentacleActionsVisual' if swamp else 'EvilMageLordActionsVisual'
        parent = 'CreatureVisual' if swamp else 'SourceMageVisual'
        paths = {name: sha(VIEWER / f'Presentation/{name}.gd') for name in (
            visual, parent, 'SourceSpaceFallPlayback', 'CreatureFallPlayback', 'SourceGroundLookup')}
        row.update(presentation_script=f'res://Presentation/{visual}.gd',
                   presentation_script_sha256=paths[visual], collapse_renderer_dependencies=paths)
        rows.append(row)
    return rows, CLASSES
