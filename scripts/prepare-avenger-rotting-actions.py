"""Check the original motion references for Terathan Avenger and Rotting Corpse."""
import hashlib
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'avenger_rotting_actions'
CLASSES = {152: ['TerathanAvenger'], 155: ['RottingCorpse', 'UnfrozenMummy']}
HUES = {152: {'TerathanAvenger': 0}, 155: {'RottingCorpse': 0, 'UnfrozenMummy': 0x480}}
ROUTES = {
    152: {2: 'Death', 3: 'Death', 4: 'Attack', 5: 'Attack2', 6: 'Attack2', 10: 'Hit', 11: 'Fidget',
          15: 'AvengerPincerRecoil', 16: 'AvengerPincerRecoil', 17: 'Fidget', 18: 'AvengerThreat'},
    155: {2: 'Death2', 3: 'Death', 4: 'BackhandReach', 5: 'Attack', 6: 'OverheadClaw', 10: 'Hit',
          11: 'ArmsRaise', 15: 'DoubleOver', 16: 'StaggerBack', 17: 'Fidget', 18: 'LookUp'},
}
EXTRAS = {152: [2, 3, 10, 15, 16, 18], 155: [2, 3, 10, 14, 15, 16, 18]}
RENDERERS = {152: ('TerathanActionsVisual',), 155: ('RottingCorpseActionsVisual', 'SourcePreservingCreatureVisual')}
NAMES = {152: 'terathan-avenger', 155: 'rotting-corpse'}
FITTED = {152: [15, 18], 155: [2, 4, 6, 11, 15, 16, 18]}
TREATMENTS = ('original', 'rounded', 'modern')
helpers = runpy.run_path(str(SCRIPTS / 'prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))


def source_groups():
    pins = read(SCRIPTS / 'avenger-rotting-frame-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name: sha(data / name) for name in pins['definitions']}
    owners = set(CLASSES) | {row['source_body'] for row in pins['sources'].values()}
    records, _, flags = ledger['original_mul_groups'](data, owners)
    assert pins['mobtypes'] == {str(body): list(value) for body, value in flags.items()}
    assert {row['body'] for row in records} == {3, 152}
    redirects, _ = ledger['original_definition_redirects'](data, CLASSES, records, {})
    for body, spec in pins['sources'].items():
        groups = {str(row['group']): row for row in records if row['body'] == spec['source_body']}
        assert groups.keys() == spec['groups'].keys()
        assert pins['redirects'][body] == {row['scope']: [row['graphic'], row['legacy_hue']]
                                           for row in redirects if row['body'] == int(body)}
        for slot, row in groups.items():
            assert all(row[key] == spec[key] for key in ('archive', 'graphic', 'layout'))
            assert not row['mobtype_prefers_uop']
            directions = row['directions']
            assert [item['direction'] for item in directions] == list(range(5))
            hashes = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
            assert spec['groups'][slot] == [[item['frames'] for item in directions], hashlib.sha256(hashes).hexdigest()]
        for first, second in spec['aliases']:
            assert ROUTES[int(body)][first] == ROUTES[int(body)][second]
    return pins


def prepared(entries):
    pins = source_groups()
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated'
                 and [int(identity['body']) for identity in row['bodies']] == [body])
        stem = NAMES[body] + '-actions'
        bake = read(ART / f'{stem}-bake.json')
        assert f'bake-{stem}.gd' in bake['inputs']
        for name, digest in bake['inputs'].items():
            path, = (folder / name for folder in (SCRIPTS, VIEWER / 'Presentation') if (folder / name).is_file())
            assert sha(path) == digest, name
        assets, retained, scenes = {}, {}, {}
        for treatment in TREATMENTS:
            original = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            scene = f'res://local-art/creatures/{stem}-{treatment}.scn'
            old, new = sha(VIEWER / original[6:]), sha(VIEWER / scene[6:])
            assert old == (base['asset_sha256'][treatment] if body == 152 else
                           base['saved_scenes'][treatment]['scene_sha256'])
            assert bake['scenes'][str(body)][treatment] == {'source': old, 'scene': new}
            assets[treatment], retained[treatment], scenes[treatment] = scene, original, new
        source = pins['sources'][str(body)]
        references = {str(slot): dict(body=body, source_body=source['source_body'], group=slot,
                                      archive=source['archive'], graphic=source['graphic'],
                                      frames=source['groups'][str(slot)][0][0], directions=list(range(5)),
                                      directional_payload_sha256=source['groups'][str(slot)][1])
                      for slot in ROUTES[body]}
        renderer = f'Presentation/{RENDERERS[body][0]}.gd'
        dependencies = RENDERERS[body] + ('SourceSpaceFallPlayback', 'CreatureFallPlayback', 'SourceGroundLookup')
        rows.append(dict(base, status='prepared', family=FAMILY, assets=assets,
                         classic_gesture_base_assets=retained, authored_action_scene_sha256=scenes,
                         authored_action_reference=references[str(FITTED[body][0])], classic_motion_references=references,
                         classic_action_categories=base.get('classic_action_categories', {}) | {
                             str(slot): clip for slot, clip in ROUTES[body].items()},
                         native_extra_classic_actions=EXTRAS[body], native_constructor_hues=HUES[body],
                         grounded_gestures=['Attack', 'Attack2', 'Hit', 'Fidget', 'AvengerPincerRecoil', 'AvengerThreat']
                         if body == 152 else [],
                         authored_replacements=base.get('authored_replacements', {}) | {
                             ROUTES[body][slot]: f'Fitted on the retained rig for Classic group {slot}'
                             for slot in FITTED[body]},
                         classic_definition_redirects=pins['redirects'][str(body)],
                         presentation_script=f'res://{renderer}', presentation_script_sha256=sha(VIEWER / renderer),
                         collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd')
                                                         for name in dependencies}))
    return rows, CLASSES
