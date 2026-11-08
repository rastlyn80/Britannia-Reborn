"""Prepare body-specific Classic actions on the retained Hopper, Fan Dancer and Blood Elemental rigs."""
import base64
import hashlib
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'hopper_fan_blood_actions'
CLASSES = {302: ['SkitteringHopper'], 247: ['FanDancer'], 159: ['BloodElemental']}
ROUTES = {
    302: {'3': 'Death', '5': 'Attack2', '6': 'Attack2', '15': 'HopperRecoil', '16': 'HopperRecoil',
          '18': 'HopperStretch'},
    247: {'3': 'Death2', '15': 'BlockRight', '16': 'FanGuardLeft', '17': 'FanFlourish', '18': 'Fidget'},
    159: {'3': 'Death2', '7': 'BloodOverhead', '8': 'BloodHeldReach', '15': 'BloodRecoilRight',
          '16': 'BloodRecoilLeft', '18': 'BloodReach'},
}
AUTHORED = {
    302: {'HopperRecoil', 'HopperStretch'},
    247: {'FanGuardLeft', 'FanFlourish'},
    159: {'BloodOverhead', 'BloodHeldReach', 'BloodRecoilRight', 'BloodRecoilLeft', 'BloodReach'},
}
RENDERERS = {
    302: ('HopperActionsVisual', 'TerathanActionsVisual', 'OccurrenceCreatureVisual'),
    247: ('FanDancerActionsVisual', 'FanDancerVisual', 'FanDancerSupport'),
    159: ('BloodElementalActionsVisual', 'SourceBloodElementalVisual', 'SourceFluidElementalVisual',
          'SourceVariantPoseEntry', 'SourceElementalVisual'),
}
TREATMENTS = ('original', 'rounded', 'modern')
helpers = runpy.run_path(str(SCRIPTS / 'prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
scan = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))['original_mul_groups']


def source_groups():
    pins = read(SCRIPTS / 'hopper-fan-blood-frame-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in pins['definitions']}
    for name, target in (('Body.def', 16), ('Corpse.def', 51)):
        rows = [line.split('#', 1)[0].split() for line in (data / name).read_text(encoding='latin-1').splitlines()]
        assert [row for row in rows if row and row[0] == '159'] == [['159', f'{{{target}}}', '37']]
    groups, _, _ = scan(data, {int(source) for source in pins['sources']})
    for body, spec in pins['sources'].items():
        found = {str(row['group']): row for row in groups if row['body'] == int(body)}
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
    return pins['sources']


def assert_duplicate_fan_blocks(path):
    gltf = read(path)
    buffers = []
    for buffer in gltf['buffers']:
        uri = buffer['uri']
        buffers.append(base64.b64decode(uri.split(',', 1)[1]) if uri.startswith('data:')
                       else (path.parent / uri).read_bytes())

    def values(index):
        accessor = gltf['accessors'][index]
        view = gltf['bufferViews'][accessor['bufferView']]
        width = {'SCALAR': 4, 'VEC3': 12, 'VEC4': 16}[accessor['type']]
        assert accessor['componentType'] == 5126 and view.get('byteStride', width) == width
        offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        return buffers[view['buffer']][offset:offset + width * accessor['count']]

    def channels(name):
        motion, = (item for item in gltf['animations'] if item['name'] == name)
        result = {}
        for channel in motion['channels']:
            target = channel['target']
            sampler = motion['samplers'][channel['sampler']]
            result[(target['node'], target['path'])] = (values(sampler['input']), values(sampler['output']))
        assert len(result) == 61
        return result

    assert channels('BlockRight') == channels('BlockLeft')


def reference(body, source, slot):
    pin = source['groups'][slot]
    return dict(body=body, group=int(slot), archive=source['archive'], graphic=source['graphic'],
                frames=pin['counts'][0], directions=list(range(5)),
                directional_payload_sha256=pin['directions_sha256'])


def prepared(entries):
    sources = source_groups()
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        stem = {302: 'skittering-hopper', 247: 'fan-dancer', 159: 'blood-elemental'}[body] + '-distinct-actions'
        bake = read(ART / f'{stem}-bake.json')
        assert 'bake-hopper-fan-blood-actions.gd' in bake['inputs']
        for name, digest in bake['inputs'].items():
            path, = (folder / name for folder in (SCRIPTS, VIEWER / 'Presentation') if (folder / name).is_file())
            assert sha(path) == digest, name
        assets, retained, scenes = {}, {}, {}
        for treatment in TREATMENTS:
            original = base['assets'][treatment]
            replacement = f'res://local-art/creatures/{stem}-{treatment}.scn'
            old, new = sha(VIEWER / original[6:]), sha(VIEWER / replacement[6:])
            assert old == base['asset_sha256'][treatment]
            assert bake['scenes'][str(body)][treatment] == {'source': old, 'scene': new}
            assets[treatment], retained[treatment], scenes[treatment] = replacement, original, new
        if body == 247:
            assert_duplicate_fan_blocks(VIEWER / retained['original'][6:])
        source = sources[str(16 if body == 159 else body)]
        references = {slot: reference(body, source, slot) for slot in routes}
        renderer = RENDERERS[body][0]
        dependencies = (*RENDERERS[body], 'SourceSpaceFallPlayback', 'CreatureFallPlayback', 'SourceGroundLookup')
        row = dict(base, family=FAMILY, status='prepared', assets=assets, classic_gesture_base_assets=retained,
                   authored_action_scene_sha256=scenes, authored_action_reference=references['3'],
                   classic_action_categories=base['classic_action_categories'] | routes, classic_motion_references=references,
                   native_extra_classic_actions=[3, 15, 16, 18], native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                   authored_replacements=base.get('authored_replacements', {}) | {
                       clip: f'Fitted on the retained source rig for Classic group {slot}' for slot, clip in routes.items()
                       if clip in AUTHORED[body]
                   },
                   presentation_script=f'res://Presentation/{renderer}.gd',
                   presentation_script_sha256=sha(VIEWER / f'Presentation/{renderer}.gd'),
                   collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd') for name in dependencies})
        if body == 302:
            row['grounded_gestures'] = ['Attack2', 'HopperRecoil', 'HopperStretch']
        if body == 159:
            row['classic_definition_sources'] = {'mobile': 16, 'corpse': 51}
            row['classic_corpse_references'] = {slot: reference(51, sources['51'], slot) for slot in ('2', '3')}
        rows.append(row)
    return rows, CLASSES
