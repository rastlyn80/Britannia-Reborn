"""Extract the original Bone Knight props and the reviewed Cyclops mallet donor."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'work/creatures/mul-motion-review/bone-knight-props'
ARCHIVE = ROOT / 'work/third-dawn/uotdb.zip'
OTHER = 'uotdb/uotd/Models/Others/'
MAPS = 'uotdb/uotd/Models/Maps/'
WEAPONS = ('weapons_512b.tga', '9a037ac506a1b5ed990ee029898af6d35c2a052ced560e27dcfaa40e876bdf49')
SHIELDS = ('shields.tga', '4c108560e18200513867bf2316742687edc4335b17955016a8c1603777405def')
PROPS = {
    'scimitar': ('Weapon_Skeleton_Scimitar_LOD2.grn',
                 '3262725cbbcf5325cf848068d376c3698df5bdf1cbac6ca6d0bd1f34cb29e189', 65, 122, WEAPONS),
    'wooden_shield': ('shield_wooden_LOD2.grn',
                      'b6a6732ce205e79b9e23b24ee82b72648f77360ecc5793cf5750724dc242f2f4', 22, 18, SHIELDS),
    'mallet': ('Weapon_Troll_Maul_LOD2.grn',
               'c07f3cf2bd9df3ce8e10aadfda9e60cc2f7f01b23e305b20b777b265d74b6b6d', 34, 60, WEAPONS),
}


def sha(value):
    return hashlib.sha256(value).hexdigest()


def checked_inputs():
    with ZipFile(ARCHIVE) as archive:
        for name, (member, digest, point_count, triangle_count, (atlas, atlas_digest)) in PROPS.items():
            mesh, texture = archive.read(OTHER + member), archive.read(MAPS + atlas)
            if sha(mesh) != digest or sha(texture) != atlas_digest:
                raise ValueError(f'Unexpected Third Dawn source for {name}')
            yield name, mesh, texture, dict(member=OTHER + member, sha256=digest, atlas=MAPS + atlas,
                                            atlas_sha256=atlas_digest, points=point_count, triangles=triangle_count)


def components(model):
    neighbors = [set() for _ in model['points']]
    for polygon in model['polygons']:
        for index in polygon[:3]:
            neighbors[index].update(polygon[:3])
    remaining = set(range(len(neighbors)))
    while remaining:
        pending = [remaining.pop()]
        connected = set()
        while pending:
            index = pending.pop()
            if index not in connected:
                connected.add(index)
                pending.extend(neighbors[index] - connected)
        remaining -= connected
        yield connected


def prepare():
    reader = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    receipt = {}
    for name, mesh, texture, evidence in checked_inputs():
        model = reader['parse'](mesh)
        assert not model['weights'] and model['textures'] == [Path(evidence['atlas']).name]
        assert len(model['points']) == evidence['points'] and len(model['polygons']) == evidence['triangles']
        keep = set(range(evidence['points']))
        if name == 'mallet':
            # Retain the original full wooden haft. Its separate irregular
            # head is replaced by the barrel and bands seen in the Classic frames.
            haft, = (group for group in components(model) if len(group) == 16)
            assert min(model['points'][index][1] for index in haft) < -0.28
            keep = haft
        corners = []
        for polygon, uv in zip(model['polygons'], model['texture_polygons'], strict=True):
            if polygon[0] not in keep:
                continue
            assert set(polygon[:3]) <= keep
            for index in (0, 2, 1):
                corners.append([*model['points'][polygon[index]], *model['normals'][polygon[index + 3]],
                                *model['uv_sets'][-1][uv[index]][:2]])
        geometry = json.dumps(corners).encode('ascii')
        atlas = reader['png_from_tga'](texture)
        (OUTPUT / f'{name}-corners.json').write_bytes(geometry)
        (OUTPUT / f'{name}-atlas.png').write_bytes(atlas)
        receipt[name] = evidence | dict(retained_triangles=len(corners) // 3,
                                        corners_sha256=sha(geometry), png_sha256=sha(atlas))
    (OUTPUT / 'bake-inputs.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print({name: entry['retained_triangles'] for name, entry in receipt.items()})


if __name__ == '__main__':
    prepare()
