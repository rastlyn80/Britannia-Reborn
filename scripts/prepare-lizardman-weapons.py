#!/usr/bin/env python3
"""Prepare local rigid Third Dawn weapon geometry for Lizardman fitting trials."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'Viewer/local-art/creatures'
ATLAS_SHA256 = '6b6db69ff83ce1950113b4c10965a42e730eb4887fab16e11ccfb064f661f720'
# Classic directional sprites associate these two forms with bodies 35 and 36.
WEAPONS = {
    'Spear': ('8b1befe047290eb19e9d35f1f6402274515e05b9ba3408962202bd5925aab4ea', 16, 28),
    'Mace': ('7485e8326f7a82d2dbfa19b9db2e4b99b844444bcd324ed9c54dca8a657edf3f', 47, 90),
}


def pinned_bytes(path, digest):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != digest:
        raise ValueError(f'Unexpected source hash: {path.name}')
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Local extracted Third Dawn Client/Models directory')
    source = parser.parse_args().source
    granny = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
    atlas = granny['png_from_tga'](pinned_bytes(source / 'Maps/Weapons_512b.tga', ATLAS_SHA256))
    meshes = {}
    for form, (digest, vertices, triangles) in WEAPONS.items():
        name = f'Weapon_Lizard_Man_{form}_Lod2.grn'
        model = granny['parse'](pinned_bytes(source / 'Others' / name, digest))
        if (len(model['points']) != vertices or len(model['polygons']) != triangles
                or model['weights'] or model['textures'] != ['weapons_512b.tga']):
            raise ValueError(f'Unexpected rigid weapon structure: {name}')
        corners = []
        for poly, tex in zip(model['polygons'], model['texture_polygons'], strict=True):
            # Godot front faces are clockwise; the source importer emits glTF winding.
            for index in (0, 2, 1):
                position = model['points'][poly[index]]
                normal = model['normals'][poly[index + 3]]
                uv = model['uv_sets'][-1][tex[index]][:2]
                corners.append([*position, *normal, *uv])
        meshes[form] = corners
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'lizardman-weapon-trial.png').write_bytes(atlas)
    (OUTPUT / 'lizardman-weapon-trial.json').write_text(json.dumps(meshes), encoding='utf-8')
    print('Lizardman weapon trial: exact source atlas, 28 spear and 90 mace triangles.')


if __name__ == '__main__':
    main()
