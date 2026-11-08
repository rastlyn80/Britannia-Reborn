"""Prepare the original Ratman sword and pin Classic Ratman Mage and Lava Serpent motions."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
SWORD_DIR = ROOT / 'work/creatures/ratman-mage-sword'
SWORD = 'uotdb/uotd/Models/Others/Weapon_RatMan_Sword_LOD2.grn'
ATLAS = 'uotdb/uotd/Models/Maps/weapons_512b.tga'
SWORD_PIN = 'd27edbbc28ad78e4417b4c81717977460f678e1e8f8b37cfb95c0cdcbd307a7c'
ATLAS_PIN = '9a037ac506a1b5ed990ee029898af6d35c2a052ced560e27dcfaa40e876bdf49'
FAMILY = 'ratman_lava_actions'
CLASSES = {143: ['RatmanMage'], 90: ['LavaSerpent']}
ROUTES = {143: {'11': 'MageStoop', '15': 'MageBladeRise', '16': 'MageBladeBrace', '18': 'MageGuardLook'},
          90: {'3': 'Death2', '4': 'CoilSnap', '6': 'LongStrike', '15': 'NeckDrawback',
               '16': 'LowNeckRecoil', '18': 'TailRipple'}}
MODELS = {143: ('ratman-mage', 45, 'RatmanMageActionsVisual'), 90: ('lava-serpent', 21, 'LavaSerpentActionsVisual')}
EXTRAS = {143: [15, 16, 18], 90: [3, 15, 16, 18]}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha = (HELPERS[key] for key in ('read', 'sha'))


def extract_sword():
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        raw, texture = archive.read(SWORD), archive.read(ATLAS)
    assert hashlib.sha256(raw).hexdigest() == SWORD_PIN
    assert hashlib.sha256(texture).hexdigest() == ATLAS_PIN
    importer = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
    rigid = runpy.run_path(str(ROOT / 'scripts/prepare-lizardman-weapons.py'))['rigid_mesh_corners']
    SWORD_DIR.mkdir(parents=True, exist_ok=True)
    model = SWORD_DIR / Path(SWORD).name
    model.write_bytes(raw)
    corners = json.dumps(rigid(importer['parse'], model, SWORD_PIN, 46, 80)).encode('ascii')
    (SWORD_DIR / 'corners.json').write_bytes(corners)
    (SWORD_DIR / 'atlas.png').write_bytes(importer['png_from_tga'](texture))
    print('RATMAN SWORD: 46 source vertices, 80 triangles and the original atlas')


def merged_ground():
    measured = read(ART / 'lava-serpent-actions-curves.json')
    base = read(ART / 'serpents_snake_giant_silver-ground.json')
    assert measured['recipe'] == sha(ROOT / 'scripts/bake-lava-serpent-action-ground.gd')
    assert measured['sample_rate'] == base['sample_rate'] == 960
    assert measured['curves'].keys() == base['treatments'].keys() == measured['scenes'].keys()
    for treatment, clips in measured['curves'].items():
        assert measured['scenes'][treatment] == sha(ART / f'lava-serpent-actions-{treatment}.scn')
        existing = base['treatments'][treatment]['clips']
        assert clips.keys() == set(ROUTES[90].values()) and not (existing.keys() & clips.keys())
        existing.update(clips)
    return base


def references(ledger, data, body, source_body, pins):
    if body == 143:
        rows = runpy.run_path(str(ROOT / 'scripts/build-creature-actions.py'))['original_mul_groups'](data, {45})[0]
    else:
        rows = ledger['original_mul_group_candidates']
    results = {}
    for slot, (archive, graphic, frames, digest) in pins.items():
        row, = (item for item in rows if item['body'] == source_body and item['group'] == int(slot))
        directions = row['directions']
        assert (row['archive'], row['graphic'], row['mobtype_prefers_uop']) == (archive, graphic, False)
        assert [item['direction'] for item in directions] == list(range(5))
        assert {item['frames'] for item in directions} == {frames}
        assert hashlib.sha256(''.join(item['payload_sha256'] for item in directions).encode('ascii')).hexdigest() == digest
        results[slot] = dict(body=source_body, group=int(slot), archive=archive, graphic=graphic, frames=frames,
                             directions=list(range(5)), directional_payload_sha256=digest)
    return results


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    pins = read(ROOT / 'scripts/ratman-lava-frame-pins.json')
    assert all(sha(data / name) == digest for name, digest in pins['definition_archives'].items())
    ground = ART / 'lava-serpent-actions-ground.json'
    assert read(ground) == merged_ground()
    active = read(ART / 'accepted-index.json')['entries']
    donor, = (row for row in active if row['status'] == 'validated' and row['bodies'][0]['body'] == 21)
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated' and row['bodies'][0]['body'] == body)
        name, source_body, visual = MODELS[body]
        redirects = [row for row in ledger['original_definition_redirect_candidates'] if row['body'] == body]
        assert [(item['scope'], item['graphic']) for item in redirects] == [('mobile', source_body), ('corpse', source_body)]
        assert not base.get('classic_action_categories')
        refs = references(ledger, data, body, source_body, pins['groups'][str(body)])
        assert refs.keys() == routes.keys()
        if body == 143:
            bake = read(SWORD_DIR / 'bake.json')
            inputs = {name: sha(ROOT / 'scripts' / name) for name in (
                'bake-ratman-mage-actions.gd', 'ratman-sword-clearance.gd', 'bake-ophidian-bardiche.gd',
                'bake-skeleton-axe-trial.gd', 'bake-troll-weapons-trial.gd', 'test-quadruped-actions.gd')}
            inputs.update({name: sha(SWORD_DIR / name) for name in ('corners.json', 'atlas.png')})
            assert bake['inputs'] == inputs and sha(SWORD_DIR / Path(SWORD).name) == SWORD_PIN
        else:
            bake = read(ART / 'lava-serpent-actions-bake.json')
            assert bake['recipe'] == sha(ROOT / 'scripts/bake-lava-serpent-actions.gd')
        assets, scenes = {}, {}
        for treatment, old in base['assets'].items():
            source = sha(VIEWER / old.removeprefix('res://'))
            scene = f'{name}-actions-{treatment}.scn'
            digest = sha(ART / scene)
            expected = {'source': source, 'scene': digest}
            if body == 90:
                expected['donor'] = sha(VIEWER / donor['assets'][treatment].removeprefix('res://'))
                assert expected['donor'] == donor['asset_sha256'][treatment]
            assert source == base['asset_sha256'][treatment] and bake['scenes'][treatment] == expected
            assets[treatment], scenes[treatment] = 'res://local-art/creatures/' + scene, digest
        methods = {clip: f'Original-rig motion referenced to Classic body {source_body} group {slot}'
                   for slot, clip in routes.items()}
        candidate = dict(base, status='prepared', family=FAMILY, assets=assets, authored_action_scene_sha256=scenes,
                         classic_gesture_base_assets=base['assets'], classic_action_categories=routes,
                         classic_motion_references=refs, classic_motion_definition_sources=redirects,
                         authored_action_reference=dict(refs['15'], body=body, source_body=source_body),
                         native_extra_classic_actions=EXTRAS[body], native_constructor_hues=dict.fromkeys(CLASSES[body], 0),
                         authored_replacements=base.get('authored_replacements', {}) | methods,
                         presentation_script=f'res://Presentation/{visual}.gd',
                         presentation_script_sha256=sha(VIEWER / f'Presentation/{visual}.gd'))
        if body == 90:
            candidate.update(ground_lookup='res://local-art/creatures/lava-serpent-actions-ground.json',
                             ground_lookup_sha256=sha(ground))
        else:
            candidate['archived_held_prop'] = {'geometry': {SWORD: SWORD_PIN}, 'texture': {ATLAS: ATLAS_PIN}}
        rows.append(candidate)
    return rows, CLASSES


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_mutually_exclusive_group(required=True)
    commands.add_argument('--extract-sword', action='store_true')
    commands.add_argument('--merge-ground', action='store_true')
    args = parser.parse_args()
    if args.extract_sword:
        extract_sword()
    else:
        (ART / 'lava-serpent-actions-ground.json').write_text(json.dumps(merged_ground(), separators=(',', ':')), encoding='utf-8')
