"""Recover the later-client cast on the original private Gargoyle rig."""

import hashlib
from pathlib import Path
import runpy
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
RESEARCH = ROOT / 'work/third-dawn/late-source-research'
STEM = 'gargoyles_gargoyle'
CAST_MEMBER = f'Models/Monsters/{STEM}_cast2.grn'
CAST_SHA = 'c768363d9cb1ffa97e7f7a4f856bbd914afb6b59993ff59183c38058eb65c591'
CAB_SHA = '307a6b91c4d5459080d1fe8a74ae4fe0b91dea8a21a2866ca91e7dc7ba92f1a8'
MESH_SHA = 'e3cab199481bec1006c85900f256f80ba63a3f2235816e5a86508b2e68ed8f4b'
ATLAS_SHA = '041278f061fa9692fe2e0fd444906e27dbe3cad05d36dbc3e0fe7f86f73fc282'


def verify_bytes(data, expected, source):
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError(f'Gargoyle source differs from its pinned hash: {source}')
    return data


def source_cast():
    cabinet = RESEARCH / 'uoaos-cabinets/client11.cab'
    verify_bytes(cabinet.read_bytes(), CAB_SHA, cabinet.name)
    return verify_bytes((RESEARCH / 'uoaos-source' / CAST_MEMBER).read_bytes(), CAST_SHA, CAST_MEMBER)


def prepare():
    pipeline = runpy.run_path(str(ROOT / 'scripts/prepare-creatures.py'))
    td = pipeline['td']
    cast = source_cast()
    mesh_name = f'uotdb/uotd/Models/Monsters/{STEM}_lod2.grn'
    atlas_name = 'uotdb/uotd/Models/Maps/Gargoyles_gargoyle.tga'
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        mesh = verify_bytes(archive.read(mesh_name), MESH_SHA, mesh_name)
        atlas = td.png_from_tga(verify_bytes(archive.read(atlas_name), ATLAS_SHA, atlas_name))
    model = td.parse(mesh, scene_root_names=True)
    model, _ = pipeline['normalise_bind'](mesh, model)
    model, _ = pipeline['visible_vertices'](model)
    motion = td.parse(cast, animations_only=True, scene_root_names=True, scale_shear_tracks=True)
    motion, _ = pipeline['normalise_bind'](cast, motion)
    motion, omitted = pipeline['helper'].match_animation(motion, model)
    if len(motion['tracks']) != 54 or omitted:
        raise ValueError('Age of Shadows Gargoyle cast no longer matches all retained tracks')
    height = 1.2 * (max(p[2] for p in model['points']) - min(p[2] for p in model['points']))
    td.export_gltf(model, {'Cast': motion}, atlas, ART / 'gargoyle-4-cast-donor.gltf', height,
                   floor_sample_rate=120)
    print('GARGOYLE 4: 54 recovered cast tracks match the Third Dawn rig')


if __name__ == '__main__':
    prepare()
