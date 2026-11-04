"""Extract the original Ophidian Mage staff and its local atlas."""

import hashlib
import json
from pathlib import Path
import runpy
from tempfile import TemporaryDirectory
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'work/creatures/mul-motion-review/ophidian-staff'
STAFF = 'uotdb/uotd/Models/Others/Weapon_Ophidian_Mage_Staff_LOD2.grn'
STAFF_SHA = '31e988912ffdcfb046801f73c9b86b5aaea8de5a4b94cbcee3add396eaadde09'
ATLAS = 'uotdb/uotd/Models/Maps/weapons_512b.tga'
ATLAS_SHA = '9a037ac506a1b5ed990ee029898af6d35c2a052ced560e27dcfaa40e876bdf49'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_source():
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        staff, atlas = archive.read(STAFF), archive.read(ATLAS)
    if sha(staff) != STAFF_SHA or sha(atlas) != ATLAS_SHA:
        raise ValueError('The Ophidian staff or its same-archive atlas changed')
    return staff, atlas


def prepare():
    importer = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
    rigid = runpy.run_path(str(ROOT / 'scripts/prepare-lizardman-weapons.py'))
    staff, atlas = checked_source()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=OUTPUT) as folder:
        member = Path(folder) / Path(STAFF).name
        member.write_bytes(staff)
        corners = rigid['rigid_mesh_corners'](importer['parse'], member, STAFF_SHA, 33, 62)
    geometry = json.dumps(corners).encode('ascii')
    texture = importer['png_from_tga'](atlas)
    (OUTPUT / 'corners.json').write_bytes(geometry)
    (OUTPUT / 'atlas.png').write_bytes(texture)
    source = dict(staff=STAFF, sha256=STAFF_SHA, atlas=ATLAS, atlas_sha256=ATLAS_SHA,
                  points=33, triangles=62, corners_sha256=sha(geometry), png_sha256=sha(texture))
    (OUTPUT / 'source.json').write_text(json.dumps(source, indent=2) + '\n', encoding='utf-8')
    print('OPHIDIAN STAFF: exact 33-point, 62-triangle mesh and original atlas')


if __name__ == '__main__':
    prepare()
