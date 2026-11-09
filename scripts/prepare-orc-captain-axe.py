"""Decode the pinned Third Dawn Orc Lord axe into private Orc Captain bake inputs."""

import hashlib
import json
from pathlib import Path
import runpy


SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
SOURCE = ROOT / 'work/third-dawn/late-source-research/uoaos-source/Models'
OUTPUT = ROOT / 'work/creatures/orc_captain_actions'
MESH = 'Others/weapon_orc_lord_axe_lod2.grn'
ATLAS = 'Maps/weapons_512b.tga'
INPUT_HASHES = {
    MESH: 'b342bc101a36327e8a2d799c5eb076f0372893ac9cd41f3acf5b679c457683c9',
    ATLAS: '6b6db69ff83ce1950113b4c10965a42e730eb4887fab16e11ccfb064f661f720',
}


def prepare():
    inputs = {name: (SOURCE / name).read_bytes() for name in INPUT_HASHES}
    for name, data in inputs.items():
        assert hashlib.sha256(data).hexdigest() == INPUT_HASHES[name], name
    pipeline = runpy.run_path(str(SCRIPTS / 'prepare-creatures.py'))
    reader = pipeline['td']
    mesh, parts, _ = pipeline['rigid'].read_rigid_parts(inputs[MESH], reader, excluded_names=())
    part, = parts
    assert part['name'] == 'org_lord_axe_mesh' and len(mesh['points']) == 44
    assert len(mesh['polygons']) == 82 and mesh['textures'] == [Path(ATLAS).name]
    corners = []
    for face, uv_indices in zip(mesh['polygons'], mesh['texture_polygons'], strict=True):
        for corner in (0, 2, 1):
            position = mesh['points'][face[corner]]
            normal = mesh['normals'][face[corner + 3]]
            uv = mesh['uv_sets'][-1][uv_indices[corner]][:2]
            corners.append([*position, *normal, *uv])
    atlas = reader.png_from_tga(inputs[ATLAS])
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'axe-corners.json').write_text(json.dumps(corners) + '\n', encoding='utf-8')
    (OUTPUT / 'axe-atlas.png').write_bytes(atlas)
    print(f'Orc Captain axe: {len(corners)} corners, {len(mesh["polygons"])} triangles, local inputs only')


if __name__ == '__main__':
    prepare()
