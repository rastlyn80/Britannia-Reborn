"""Prepare the local original Third Dawn bow used by Centaur and Twaulo."""

import hashlib
import json
from pathlib import Path
import runpy
import zipfile


root = Path(__file__).resolve().parents[1]
source = root / 'work/third-dawn/uotdb.zip'
output = root / 'Viewer/local-art/creatures/centaur-bow'
recipe = runpy.run_path(str(root / 'scripts/prepare-creatures.py'))
td = recipe['td']
members = {
    'uotdb/uotd/Models/Others/Weapon_Bow_LOD2.grn': '6bc7068bdfae66dfc7362ada9e96473c2563015b03f625fec6d10fd69bd27b9e',
    'uotdb/uotd/Models/Maps/weapons_512.tga': '9a037ac506a1b5ed990ee029898af6d35c2a052ced560e27dcfaa40e876bdf49',
}

with source.open('rb') as stream:
    assert hashlib.file_digest(stream, 'sha256').hexdigest() == recipe['helper'].audit.ARCHIVE_HASH
with zipfile.ZipFile(source) as archive:
    mesh, atlas = (archive.read(name) for name in members)
    for data, digest in zip((mesh, atlas), members.values(), strict=True):
        assert hashlib.sha256(data).hexdigest() == digest
    rows = archive.read('uotdb/uotd/Models/MODELS.TXT').decode('latin-1').splitlines()
    bow, = (row.split() for row in rows if row.endswith('\tWeapon_Bow'))
    assert bow == ['649', '4', '0', '0', '0', '1.2', '1.2', '1.2', 'Weapon_Bow']

model = td.parse(mesh, scene_root_names=True)
assert not model['weights'] and model['ties'] == [1] and model['textures'] == ['weapons_512.tga']
assert len(model['bones']) == 2 and model['bones'][1]['name'] == 'weapon_bow'
model['weights'] = [[(0, 1.)] for _ in model['points']]
model, _ = recipe['normalise_bind'](mesh, model)
depth = [point[2] for point in model['points']]
output.mkdir(parents=True, exist_ok=True)
asset = output / 'weapon-bow-original.gltf'
stats = td.export_gltf(model, {}, td.png_from_tga(atlas), asset, (max(depth) - min(depth)) * float(bow[5]))
assert stats['triangles'] == 92
print(json.dumps({'members': members, 'original_model_id': 649, 'asset_sha256': hashlib.sha256(asset.read_bytes()).hexdigest(),
                  'triangles': stats['triangles'], 'source_points': len(model['points'])}, indent=2))
