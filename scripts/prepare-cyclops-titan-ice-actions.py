"""Prepare the next three Classic overlays without changing the active registry."""
from pathlib import Path
import hashlib
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
FAMILY = 'cyclops_titan_ice_actions'
CLASSES = {75:['Cyclops'], 76:['Titan'], 161:['IceElemental']}
TREATMENTS = ('original', 'rounded', 'modern')
helpers = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha = helpers['read'], helpers['sha']
scan = runpy.run_path(str(ROOT / 'scripts/build-creature-actions.py'))['original_mul_groups']
STEMS = {75:'cyclops-actions', 76:'titan-actions', 161:'ice-elemental-actions'}
VISUAL = {75:'CyclopsActionsVisual', 76:'TitanActionsVisual', 161:'IceElementalActionsVisual'}
BASE_RENDERERS = {
    75: ('SourceHeldPropsVisual', 'SourceArmedLizardmanVisual'),
    76: ('SourceGroundedGestureVisual',),
    161: ('SourceIceElementalVisual', 'SourceIceElementalSupport', 'SourcePoseEntry'),
}
NEW = {
    75:{'Death2','MalletSideSweep','MalletLunge','MalletHighBrace','MalletRearBrace','MalletCheck'},
    76:{'TitanBrace','TitanOath'},
    161:{'IceArmDraw','IceForearmGuard','IceWeightShift'},
}


def source_groups():
    pins = read(SCRIPTS / 'cyclops-titan-ice-frame-pins.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert pins['definitions'] == {name:sha(data / name) for name in pins['definitions']}
    sources = {spec['source_body'] for spec in pins['bodies'].values()}
    found, _, _ = scan(data, sources)
    for body, spec in pins['bodies'].items():
        origin = spec['source_body']
        rows = {str(row['group']):row for row in found if row['body'] == origin}
        assert rows.keys() == spec['groups'].keys()
        for slot, pin in spec['groups'].items():
            row = rows[slot]
            directions = row['directions']
            hashes = ''.join(direction['payload_sha256'] for direction in directions)
            assert row['layout'] == 'large' and not row['mobtype_prefers_uop']
            assert pin == dict(archive=row['archive'], graphic=row['graphic'],
                               counts=[d['frames'] for d in directions],
                               facings=[d['direction'] for d in directions],
                               directions_sha256=hashlib.sha256(hashes.encode('ascii')).hexdigest())
        yield int(body), spec


def prepared(entries):
    rows = []
    for body, source in source_groups():
        base, = (row for row in entries if row['status'] == 'validated'
                 and {item['body'] for item in row['bodies']} == {body})
        stem = STEMS[body]
        bake = read(ART / (stem + '-bake.json'))
        pinned_scenes = bake['scenes'] if body == 75 else bake['scenes'][str(body)]
        for name, digest in bake['inputs'].items():
            path, = (folder / name for folder in (SCRIPTS, VIEWER / 'Presentation') if (folder / name).is_file())
            assert sha(path) == digest, name
        retained, scenes, assets = {}, {}, {}
        for treatment in TREATMENTS:
            original = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            replacement = f'res://local-art/creatures/{stem}-{treatment}.scn'
            old = sha(VIEWER / original[6:])
            new = sha(VIEWER / replacement[6:])
            assert old == base['asset_sha256'][treatment]
            assert pinned_scenes[treatment] == {'source':old, 'scene':new}
            retained[treatment], scenes[treatment], assets[treatment] = original, new, replacement
        references = {slot: dict(pin, body=source['source_body'], group=int(slot))
                      for slot, pin in source['groups'].items() if slot in source['routes']}
        principal = references['3' if body == 75 else '18']
        if body == 161:
            principal = dict(principal, source_body=source['source_body'])
        principal = dict(principal, body=body, frames=principal['counts'][0],
                         directional_payload_sha256=principal['directions_sha256'])
        renderer = f'Presentation/{VISUAL[body]}.gd'
        routes = source['routes']
        authored = {clip:f'Fitted on the retained rig using Classic group {slot}'
                    for slot, clip in routes.items() if clip in NEW[body]}
        extra = {75:[3,15,16,18], 76:[2,3,15,16,18], 161:[2,3,15,16,18]}[body]
        dependencies = (VISUAL[body], *BASE_RENDERERS[body], 'SourceSpaceFallPlayback',
                        'CreatureFallPlayback', 'SourceGroundLookup')
        row = dict(base, family=FAMILY, status='prepared', assets=assets,
                   classic_gesture_base_assets=retained, authored_action_scene_sha256=scenes,
                   classic_action_categories=base['classic_action_categories'] | routes,
                   authored_replacements=base.get('authored_replacements', {}) | authored,
                   classic_motion_references=references, authored_action_reference=principal,
                   native_extra_classic_actions=extra, native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                   collapse_renderer_dependencies={name: sha(VIEWER / f'Presentation/{name}.gd') for name in dependencies},
                   presentation_script=f'res://{renderer}', presentation_script_sha256=sha(VIEWER / renderer))
        if body == 76:
            row['grounded_gestures'] = ['Attack2', 'Fidget', 'TitanBrace', 'TitanOath']
        if body == 161:
            ground = ART / 'ice-elemental-ground.json'
            original_ground = VIEWER / base['ground_lookup'][6:]
            before, after = read(original_ground), read(ground)
            assert after['overlay']['base_sha256'] == sha(original_ground)
            assert after['overlay']['scenes'] == scenes and after['overlay']['samples'] == 5079
            for treatment in TREATMENTS:
                original_curves = before['treatments'][treatment]['clips']
                overlay_curves = after['treatments'][treatment]['clips']
                assert {clip:overlay_curves[clip] for clip in original_curves} == original_curves
                assert set(overlay_curves) - original_curves.keys() == NEW[body]
            row.update(ground_lookup=f'res://local-art/creatures/{ground.name}',
                       ground_lookup_sha256=sha(ground))
        rows.append(row)
    return rows, CLASSES


if __name__ == '__main__':
    candidates, classes = prepared(read(ART / 'accepted-index.json')['entries'])
    print('Prepared candidates with sealed prior scenes, frame signatures and ground curves:', classes)
