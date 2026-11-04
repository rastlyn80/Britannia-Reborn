"""Extract the exact original Skeletal Mage staff and check the local action bake."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'work/creatures/mul-motion-review/skeletal-mage-staff'
KIND = 'skeletons_skeleton_mage'
CLASSES = {148: ['BoneMagi', 'SkeletalMage']}
SOURCES = {
    'uotdb/uotd/Models/Others/Weapon_Skeleton_Mage_Staff_LOD2.grn':
        '5f3c0b9aa52f414d58c2e234edef29fa3711a66f2229c6f3ce36753e406236a6',
    'uotdb/uotd/Models/Maps/weapons_512b.tga':
        '9a037ac506a1b5ed990ee029898af6d35c2a052ced560e27dcfaa40e876bdf49',
}
REFERENCES = {
    '11': '7044744f0cd5a6133355b53381ff083b563c6d90e386c5f2d9a57ebc20075289',
    '17': 'ce17e8b8d529cc74f0449aa86a7ae2d96986a0790a81c77cb1426be65c94f37c',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def staff_inputs():
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        mesh, atlas = (archive.read(name) for name in SOURCES)
    assert [sha(mesh), sha(atlas)] == list(SOURCES.values())
    reader = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
    model = reader['parse'](mesh)
    assert not model['weights'] and model['textures'] == ['weapons_512b.tga']
    assert len(model['points']) == 13 and len(model['polygons']) == 18
    corners = []
    for polygon, uv in zip(model['polygons'], model['texture_polygons'], strict=True):
        for i in (0, 2, 1):
            corners.append([*model['points'][polygon[i]], *model['normals'][polygon[i + 3]],
                            *model['uv_sets'][-1][uv[i]][:2]])
    return {'staff-corners.json': json.dumps(corners).encode('ascii'),
            'staff-atlas.png': reader['png_from_tga'](atlas)}


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == KIND
             and [identity['body'] for identity in row['bodies']] == [148])
    bake = read(PRIVATE / 'bake.json')
    deps = ('scripts/bake-skeletal-mage-staff.gd', 'scripts/skeletal-mage-staff-clearance.gd',
            'scripts/bake-ophidian-staff-gestures.gd', 'scripts/bake-skeleton-axe-trial.gd',
            'scripts/bake-troll-weapons-trial.gd', 'scripts/ophidian-bardiche-clearance.gd',
            'Viewer/Presentation/LichGrip.gd')
    assert bake['scripts'] == {name: sha((ROOT / name).read_bytes()) for name in deps}
    assert bake['inputs'] == {name: sha(data) for name, data in staff_inputs().items()}
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    references = {slot: reference(ledger, 148, int(slot), ('anim2.mul', 23, 5, digest))
                  for slot, digest in REFERENCES.items()}
    assets, scenes = {}, {}
    art = ROOT / 'Viewer/local-art/creatures'
    for treatment in ('original', 'rounded', 'modern'):
        file = f'skeletal-mage-staff-{treatment}.scn'
        source = sha((art / f'{KIND}-{treatment}.gltf').read_bytes())
        scenes[treatment] = sha((art / file).read_bytes())
        assert source == base['asset_sha256'][treatment]
        assert bake['forms'][treatment] == {'source': source, 'scene': scenes[treatment]}
        assets[treatment] = f'res://local-art/creatures/{file}'
    visual = 'Presentation/SourceHeldPropsVisual.gd'
    row = dict(base, status='prepared', family='skeletal_mage_staff', assets=assets,
               authored_action_scene_sha256=scenes, authored_action_reference=references['11'],
               classic_motion_references=references,
               classic_action_categories=base.get('classic_action_categories', {}) | {
                   '11': 'MageStaffCheck', '17': 'Fidget'},
               authored_replacements=base.get('authored_replacements', {}) | {
                   'MageStaffCheck': 'Authored head check on the held recovered idle'},
               source_body_props={'SkeletonMageStaff': SOURCES},
               presentation_script=f'res://{visual}',
               presentation_script_sha256=sha((ROOT / 'Viewer' / visual).read_bytes()))
    return [row], CLASSES


if __name__ == '__main__':
    PRIVATE.mkdir(parents=True, exist_ok=True)
    for name, data in staff_inputs().items():
        (PRIVATE / name).write_bytes(data)
    print('Recovered exact 18-triangle Skeletal Mage staff and original atlas')
