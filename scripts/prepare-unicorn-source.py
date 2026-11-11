# SPDX-License-Identifier: GPL-3.0-or-later
"""Recover the original living Unicorn and its head-bound horn."""
import argparse
from hashlib import sha256
import json
from math import hypot, isfinite
from pathlib import Path
import runpy
from struct import iter_unpack, pack, unpack
from types import SimpleNamespace


HERE = Path(__file__).resolve().parent
ROOT = next(parent for parent in HERE.parents if (parent / 'scripts/import-third-dawn.py').is_file())
MODELS = ROOT / 'work/third-dawn/late-source-research/uoaos-source/Models'
BODY = 'equines_unicorn_lod2.grn'
DONOR = 'equines_horse_dappled_brown_lod2.grn'
ATLAS = 'equines_unicorn.tga'
CLIPS = dict(Idle='idle', Walk='walk', Run='run', Attack='attack1', Hit='gethit', Death='die1', Fidget='fidget', Eat='eat')


def cross(a, b, c):
    ux, uy, uz = (end - start for start, end in zip(a, b))
    vx, vy, vz = (end - start for start, end in zip(a, c))
    return uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx


def decode(reader, rigid, raw, donor):
    mesh = -1
    group = None
    by_surface = {True: [], False: []}
    surfaces = [{}, {}]
    for tag, payload, parents in reader.chunks(raw):
        if tag == 0xca5e0601:
            mesh += 1
        if 0xca5e0601 in parents:
            surfaces[mesh][tag] = payload
        if tag == 0xca5e0e02:
            group, count = unpack('<II', payload)
            reader.require(group in (0, 1) and count == 1, 'Unexpected unicorn atlas layout')
        entry = tag, payload, parents
        if tag == 0xca5e0601 or 0xca5e0601 in parents:
            by_surface[mesh == 0].append(entry)
        elif tag in (0xca5e0e02, 0xca5e0e06):
            by_surface[group == 1].append(entry)
        else:
            for selected in by_surface.values():
                selected.append(entry)

    parse_environment = reader.parse.__globals__
    original_chunks = parse_environment['chunks']
    try:
        parse_environment['chunks'] = lambda _: iter(by_surface[True])
        body = reader.parse(raw, scene_root_names=True)
    finally:
        parse_environment['chunks'] = original_chunks
    horse = reader.parse(donor, scene_root_names=True)
    source_header = 0xca5e0702
    donor_skin, = [data for tag, data, _ in reader.chunks(donor) if tag == source_header]
    rig_names = [body['bones'][joint]['name'] for joint in body['ties']]
    donor_names = [horse['bones'][joint]['name'] for joint in horse['ties']]
    horn_joint = body['ties'][0]
    parent = body['bones'][horn_joint]['parent']
    reader.require(rig_names[0] == 'cone01' and horn_joint == 10 and body['bones'][parent]['name'] == 'bip01 head'
                   and rig_names[1:] == donor_names and surfaces[0][source_header] == donor_skin,
                   'The unicorn body palette or horn parent changed')
    body['weights'] = [[(index + 1, weight) for index, weight in row] for row in body['weights']]

    positions = list(iter_unpack('<3f', surfaces[1][0xca5e0801]))
    source_normals = list(iter_unpack('<3f', surfaces[1][0xca5e0802]))
    faces = list(iter_unpack('<6I', surfaces[1][0xca5e0901]))
    reader.require((len(positions), len(source_normals), len(faces)) == (7, 10, 9)
                   and all(not any(isfinite(value) for value in normal) for normal in source_normals),
                   'The original horn normal repair contract changed')
    winding = 0.
    for face in body['polygons']:
        triangle = cross(*(body['points'][index] for index in face[:3]))
        winding += sum(sum(a * b for a, b in zip(triangle, body['normals'][index])) for index in face[3:])
    reader.require(abs(winding) > 1.e-6, 'The body cannot establish the original face winding')
    sign = 1. if winding > 0. else -1.
    sums = [[0., 0., 0.] for _ in source_normals]
    degenerate, used = [], set()
    for face_index, face in enumerate(faces):
        normal = cross(*(positions[index] for index in face[:3]))
        if hypot(*normal) <= 1.e-7:
            degenerate.append(face_index)
            continue
        used.update(face[3:])
        for index in face[3:]:
            for axis in range(3):
                sums[index][axis] += normal[axis]
    reader.require(degenerate == [0, 2, 4, 6, 7, 8] and all(hypot(*sums[i]) > 1.e-7 for i in used),
                   'A visible horn normal has no usable incident face')
    repaired = b''.join(pack('<3f', *(sign * value / hypot(*normal) for value in normal)) if i in used
                        else pack('<3f', 0., 0., 1.) for i, normal in enumerate(sums))
    chunks = [(tag, repaired if tag == 0xca5e0802 and 0xca5e0601 in parents else payload, parents)
              for tag, payload, parents in by_surface[False]]
    part_reader = SimpleNamespace(chunks=lambda _: iter(chunks), parse=lambda *_a, **_kw: body,
                                  require=reader.require, finite=reader.finite)
    horn, _, report = rigid.read_rigid_parts(raw, part_reader, excluded_names=())
    reader.require(body['textures'] == [ATLAS] and horn['weights'] == [[(0, 1.)]] * 7
                   and len(body['points']) == 223 and len(body['polygons']) == 442 and len(body['bones']) == 38,
                   'The source living Unicorn geometry changed')
    report.update(body_palette_offset=1, horn_invalid_normal_count=10,
                  original_zero_area_horn_faces=degenerate,
                  horn_normal_method='Area-weighted incident faces with body-verified source winding. Four normal entries referenced only by rigid, zero-area faces use placeholders.')
    return body, horn, report


def main(models, output_dir):
    pack = runpy.run_path(str(HERE / 'recover-pack-llama.py'))
    existing = runpy.run_path(str(ROOT / 'scripts/prepare-distinct-mounts.py'))
    reader = existing['td']
    rigid = SimpleNamespace(**runpy.run_path(str(ROOT / 'scripts/creature-rigid-parts.py')))
    pinned = pack['pinned']
    raw = pinned(models / 'Animals' / BODY, 'fc1260cec60eb628f712dc1edf5efe720e8ae7276ad9785173a3512fd4c26b2d')
    donor = pinned(models / 'Animals' / DONOR, 'b1d6dcecdee141e047c3503f53c41ba0f6f31fef843bedcd09c7811b6b6d301c')
    atlas = pinned(models / 'Maps' / ATLAS, '2ef56bccbda91f33cd4ba52d0aecb8229a1cab650eb3474a3a1c61e8d4eee071')
    body, horn, report = decode(reader, rigid, raw, donor)
    animations, motion_sources = {}, {}
    for clip, suffix in CLIPS.items():
        name = f'equines_horse_dappled_brown_{suffix}.grn'
        motion = (models / 'Animals' / name).read_bytes()
        source = reader.parse(motion, animations_only=True, scene_root_names=True)
        animations[clip], _ = existing['match_animation'](source, body)
        motion_sources[name] = sha256(motion).hexdigest()
    modern, refinement = pack['refine_body'](body)
    png = reader.png_from_tga(atlas)
    exports = {}
    for label, skin in [('original', body), ('modern', modern)]:
        output = output_dir / f'unicorn-{label}.gltf'
        stats = reader.export_gltf(pack['with_load'](skin, horn), animations, png, output,
                                   height=2.18, floor_sample_rate=120)
        exports[label] = {'stats': stats, 'sha256': sha256(output.read_bytes()).hexdigest()}
    report.update(body=122, source_sha256=sha256(raw).hexdigest(), atlas_sha256=sha256(atlas).hexdigest(),
                  motions=motion_sources, refinement=refinement, exports=exports,
                  scope='Private original mesh and atlas with the table-linked body 200 motions.')
    (output_dir / 'unicorn-recovery.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('Unicorn: 451 original triangles, 7081 modern triangles, eight donor motions, original rigid horn retained')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'work/magical-equines/122')
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    main(args.models, args.output_dir)
