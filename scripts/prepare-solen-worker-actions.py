"""Check the original Solen worker motion sources and prepare exact local scene routes."""
import hashlib
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'solen_worker_actions'
CLASSES = {781: ['RedSolenWorker'], 805: ['BlackSolenWorker']}
CONSTRUCTOR_HUES = {781: {'RedSolenWorker': 0}, 805: {'BlackSolenWorker': 0x453}}
ROUTES = {2: 'Death', 3: 'Death', 11: 'Fidget', 15: 'WorkerBrace', 16: 'WorkerBrace',
          17: 'Fidget', 18: 'Fidget2'}
TREATMENTS = ('original', 'rounded', 'modern')
RENDERERS = ('SolenWorkerActionsVisual', 'SourceSolenVisual', 'SourceSolenSupport',
             'SourceSolenMaterial', 'SourceSpaceFallPlayback', 'CreatureFallPlayback', 'SourceGroundLookup')
helpers = runpy.run_path(str(SCRIPTS / 'prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))


def source_groups():
    pins = read(SCRIPTS / 'solen-worker-frame-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in pins['definitions']}
    records, _, flags = ledger['original_mul_groups'](data, CLASSES.keys())
    assert pins['mobtypes'] == {str(body): list(value) for body, value in flags.items()}
    redirects, _ = ledger['original_definition_redirects'](data, CLASSES.keys(), records, {})
    for body in CLASSES:
        groups = {str(row['group']): row for row in records if row['body'] == body}
        assert groups.keys() == pins['groups'].keys()
        assert pins['redirects'][str(body)] == {row['scope']: [row['graphic'], row['legacy_hue']]
                                               for row in redirects if row['body'] == body}
        for slot, row in groups.items():
            assert all(row[key] == pins[key] for key in ('archive', 'graphic', 'layout'))
            assert not row['mobtype_prefers_uop']
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert pins['groups'][slot] == [[item['frames'] for item in directions], hashlib.sha256(hashes).hexdigest()]
    for first, second in pins['aliases']:
        assert ROUTES[first] == ROUTES[second]
    return pins


def prepared(entries):
    pins = source_groups()
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated' and row['family'] == 'solen_workers'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        bake = read(ART / f'solen-worker-{body}-actions-bake.json')
        assert 'bake-solen-worker-actions.gd' in bake['inputs']
        for name, digest in bake['inputs'].items():
            path, = (folder / name for folder in (SCRIPTS, VIEWER / 'Presentation') if (folder / name).is_file())
            assert sha(path) == digest, name
        assets, retained, scenes = {}, {}, {}
        for treatment in TREATMENTS:
            original = f"res://local-art/creatures/{base['kind']}-{treatment}.gltf"
            scene = f'res://local-art/creatures/solen-worker-{body}-actions-{treatment}.scn'
            old, new = sha(VIEWER / original[6:]), sha(VIEWER / scene[6:])
            assert old == base['asset_sha256'][treatment]
            assert bake['scenes'][str(body)][treatment] == {'source': old, 'scene': new}
            assets[treatment], retained[treatment], scenes[treatment] = scene, original, new
        references = {str(slot): dict(body=body, source_body=body, group=slot, archive=pins['archive'],
                                      graphic=pins['graphic'], frames=pins['groups'][str(slot)][0][0],
                                      directions=list(range(5)), directional_payload_sha256=pins['groups'][str(slot)][1])
                      for slot in ROUTES}
        renderer = f'Presentation/{RENDERERS[0]}.gd'
        motions = base.get('authored_replacements', {}) | {
            'WorkerBrace': 'Fitted head, mandible, antenna and arm reaction on the original Solen rig.'}
        rows.append(dict(base, status='prepared', family=FAMILY, assets=assets,
                         classic_gesture_base_assets=retained, authored_action_scene_sha256=scenes,
                         authored_action_reference=references['15'], classic_motion_references=references,
                         classic_action_categories=base.get('classic_action_categories', {}) | {
                             str(slot): clip for slot, clip in ROUTES.items()},
                         native_extra_classic_actions=[2, 3, 15, 16], native_constructor_hues=CONSTRUCTOR_HUES[body],
                         authored_replacements=motions, classic_definition_redirects=pins['redirects'][str(body)],
                         presentation_script=f'res://{renderer}', presentation_script_sha256=sha(VIEWER / renderer),
                         collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                         for name in RENDERERS}))
    return rows, CLASSES
