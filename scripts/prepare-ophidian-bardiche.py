"""Prepare the archived Ophidian body prop in the private workspace."""

import hashlib
import json
from pathlib import Path
import runpy
from tempfile import TemporaryDirectory
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'work/creatures/ophidian-bardiche'
ARCHIVE = ROOT / 'work/third-dawn/uotdb.zip'
WEAPON = 'uotdb/uotd/Models/Others/Weapon_Ophidian_Warrior_Bardiche_LOD2.grn'
WEAPON_SHA = '07a43f8b674419d078cc0c7fe956b06eec50bd9d47e431345634a7f21937e72a'
ATLAS = 'uotdb/uotd/Models/Maps/weapons_512b.tga'
ATLAS_SHA = '9a037ac506a1b5ed990ee029898af6d35c2a052ced560e27dcfaa40e876bdf49'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_members():
    with ZipFile(ARCHIVE) as archive:
        weapon, atlas = archive.read(WEAPON), archive.read(ATLAS)
    if sha(weapon) != WEAPON_SHA or sha(atlas) != ATLAS_SHA:
        raise ValueError('Ophidian bardiche or its same-archive atlas changed')
    return weapon, atlas


def prepare():
    importer = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
    rigid = runpy.run_path(str(ROOT / 'scripts/prepare-lizardman-weapons.py'))
    weapon, atlas = checked_members()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=OUTPUT) as folder:
        member = Path(folder) / Path(WEAPON).name
        member.write_bytes(weapon)
        corners = rigid['rigid_mesh_corners'](importer['parse'], member, WEAPON_SHA, 35, 54)
    corners_json = json.dumps(corners).encode('ascii')
    atlas_png = importer['png_from_tga'](atlas)
    (OUTPUT / 'corners.json').write_bytes(corners_json)
    (OUTPUT / 'atlas.png').write_bytes(atlas_png)
    receipt = dict(member=WEAPON, sha256=WEAPON_SHA, atlas=ATLAS, atlas_sha256=ATLAS_SHA,
                   points=35, triangles=54, corners_sha256=sha(corners_json), png_sha256=sha(atlas_png))
    (OUTPUT / 'source.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('OPHIDIAN BARDICHE: 35 source points, 54 triangles and same-archive atlas')


if __name__ == '__main__':
    prepare()
