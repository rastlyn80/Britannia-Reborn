# SPDX-License-Identifier: GPL-3.0-or-later
"""Recover the local Third Dawn Pack Llama, including its rigid original load."""
import argparse
from base64 import b64decode
from copy import deepcopy
from hashlib import sha256
import json
from pathlib import Path
import runpy
from struct import iter_unpack, pack, unpack, unpack_from
from types import SimpleNamespace


STUDY = Path(__file__).resolve().parent
ROOT = next(parent for parent in STUDY.parents if (parent / 'scripts/import-third-dawn.py').is_file())
RESEARCH = ROOT / 'work/third-dawn/late-source-research'
SOURCE = 'llamas_llama_pack_lod2.grn'
ATLAS = 'llamas_llama_v04.tga'
ATTACHMENT = 'llamas_pack_load'
CLIPS = {
    'Idle': 'idle', 'Walk': 'walk', 'Run': 'run', 'Attack': 'attack1',
    'Hit': 'gethit', 'Death': 'die1', 'Fidget': 'fidget',
}
MOTION_HASHES = {
    'idle': 'd32d8bc3351788a3fb478413574495dd330d13773abab73caabc4a89e4d92db8',
    'walk': '7b10aa0210ee75f441d4ef1be75f094bacbde899c8bfd1a5ea061d7179ce2db5',
    'run': 'cc197444db0574648d95998ce31c4c24468c9be69c343161fc271e767a085184',
    'attack1': '4708506c2cbd431479b5bad1d4ad6041aeba6228dfe3b65b7810708bcd4787f2',
    'gethit': 'c1af0031a51d5a57237cbc3579ccebc268f415a6c2413972c06a7647a830ba0f',
    'die1': '4a630c7a36019ea1dbe04cbff6977c855f64e5f2ca533444450bab60e203c4e2',
    'fidget': 'da07c67d5bc801e2952f249bacca261a984dd66ac658f44a9c4c97b9bf411101',
}


def digest(data):
    return sha256(data).hexdigest()


def pinned(path, expected):
    data = path.read_bytes()
    if digest(data) != expected:
        raise ValueError(f'Unexpected original member {path.name}')
    return data


def decode(reader, rigid, raw, donor):
    chunks = list(reader.chunks(raw))
    require = reader.require
    string_table, object_id, key = -1, 0, None
    mesh, material = -1, None
    duplicate_objects, mesh_ids = [], []
    filtered = {True: [], False: []}
    original_names = {}
    for tag, payload, parents in chunks:
        if tag == 0xca5e0200:
            string_table += 1
            if string_table == 1:
                count, = unpack_from('<I', payload)
                strings = payload[8:].split(b'\0')
                require(count < len(strings), 'Pack Llama object strings are incomplete')
                name_index = count
                payload = pack('<I', count + 1) + payload[4:8] + b'\0'.join(
                    strings[:count] + [ATTACHMENT.encode('ascii'), b''])
        elif parents and parents[0] == 0xca5e0f03:
            if tag == 0xca5e0f00:
                object_id += 1
            elif tag == 0xca5e0f01:
                key, = unpack('<I', payload)
            elif tag == 0xca5e0f02 and strings[key].lower() == b'__objectname':
                slot, value = unpack('<II', payload)
                original_names[object_id] = strings[value].decode('latin1')
                if object_id in (1, 34):
                    require(strings[value] == b'Llamas_Llama_pack', 'Unexpected load object name')
                    duplicate_objects.append(object_id)
                    payload = pack('<II', slot, name_index)
        if tag == 0xca5e0601:
            mesh += 1
        if tag == 0xca5e0f04 and 0xca5e0601 in parents:
            mesh_ids.append(unpack('<I', payload)[0])
        if tag == 0xca5e0e02:
            material, count = unpack('<II', payload)
            require(material in (0, 1) and count == 1, 'Unexpected Pack Llama material layout')
        elif tag == 0xca5e0e04 and 0xca5e0e02 in parents:
            require(unpack('<I', payload) == (0,), 'Both surfaces must reference the one declared atlas')
        entry = (tag, payload, parents)
        if tag == 0xca5e0601 or 0xca5e0601 in parents:
            filtered[mesh == 1].append(entry)
        elif tag in (0xca5e0e02, 0xca5e0e06):
            filtered[material == 1].append(entry)
        else:
            for target in filtered.values():
                target.append(entry)
    require(duplicate_objects == [1, 34] and mesh_ids == [34, 33]
            and original_names[9] == 'llamas_llama_pack', 'Original object identities changed')
    namespace = reader.parse.__globals__
    original_chunks = namespace['chunks']
    try:
        namespace['chunks'] = lambda _: iter(filtered[True])
        body = reader.parse(raw, scene_root_names=True)
    finally:
        namespace['chunks'] = original_chunks
    tie, = [i for i, bone in enumerate(body['ties']) if body['bones'][bone]['name'] == ATTACHMENT]
    load_bone = body['ties'][tie]
    require(tie == 0 and load_bone == 5 and body['bones'][body['bones'][load_bone]['parent']]['name'] == 'bip01 spine',
            'Pack attachment must retain its exact tie to the spine')

    part_reader = SimpleNamespace(
        chunks=lambda _: iter(filtered[False]), parse=lambda *_args, **_opts: body,
        require=require, finite=reader.finite)
    load, _, report = rigid.read_rigid_parts(raw, part_reader, excluded_names=())
    require(body['textures'] == [ATLAS] and len(body['bones']) == 30
            and (len(body['points']), len(body['polygons'])) == (120, 362)
            and (len(load['points']), len(load['polygons'])) == (20, 36)
            and len(body['uv_sets']) == len(load['uv_sets']) == 1,
            'Pack Llama surface or skeleton contract changed')
    # The skinned table is byte-identical to the ordinary llama. Its local
    # palette follows the dedicated rigid load in the Pack Llama's global ties.
    skin_tag = 0xca5e0702
    body_skin, = [payload for tag, payload, _ in filtered[True] if tag == skin_tag]
    donor_skin, = [payload for tag, payload, _ in reader.chunks(donor) if tag == skin_tag]
    ordinary = reader.parse(donor, scene_root_names=True)
    pack_palette = [body['bones'][bone]['name'] for bone in body['ties'][1:]]
    donor_palette = [ordinary['bones'][bone]['name'] for bone in ordinary['ties']]
    require(body_skin == donor_skin and pack_palette == donor_palette and body['polygons'] == ordinary['polygons']
            and body['uv_sets'] == ordinary['uv_sets'] and load['weights'] == [[(tie, 1.)]] * 20,
            'The source local body palette no longer matches the ordinary llama')
    body['weights'] = [[(index + 1, weight) for index, weight in row] for row in body['weights']]
    require(all(0 < index < len(body['ties']) for row in body['weights'] for index, _ in row),
            'Pack Llama body skin escaped its declared palette')
    report['body_palette'] = {'local_weights_sha256': digest(body_skin), 'offset_into_shared_ties': 1,
                              'named_skin_joints': pack_palette}
    return body, load, report


def with_load(body, load):
    body = deepcopy(body)
    point_offset = len(body['points'])
    normal_offset = len(body['normals'])
    uv_offset = len(body['uv_sets'][0])
    body['points'].extend(load['points'])
    body['normals'].extend(load['normals'])
    body['uv_sets'][0].extend(load['uv_sets'][0])
    body['polygons'].extend(tuple(i + point_offset for i in face[:3]) + tuple(i + normal_offset for i in face[3:])
                            for face in load['polygons'])
    body['texture_polygons'].extend(tuple(i + uv_offset for i in face) for face in load['texture_polygons'])
    load_bone, = {load['ties'][index] for row in load['weights'] for index, _ in row}
    body['weights'].extend([[(body['ties'].index(load_bone), 1.)]] * len(load['points']))
    return body


def refine_body(body):
    smooth = runpy.run_path(str(ROOT / 'scripts/third-dawn-subdivide.py'))['refine']
    strengths = []
    for influences in body['weights']:
        names = [body['bones'][body['ties'][index]]['name'] for index, weight in influences if weight > .20]
        if any(' foot' in name or ' hand' in name for name in names):
            strengths.append(0.)
        elif any('head' in name for name in names):
            strengths.append(.55)
        else:
            strengths.append(1.)
    return smooth(body, levels=2, maximum=.03, strengths=strengths, weight_smoothing=.15)


def separate_load(path, skin_faces):
    """Name the two original surfaces while sharing their buffers and atlas."""
    model = json.loads(path.read_text(encoding='utf-8'))
    mesh, = model['meshes']
    combined, = mesh['primitives']
    end = skin_faces * 3
    binary = b64decode(model['buffers'][0]['uri'].split(',', 1)[1])
    skin_attributes, load_attributes = {}, {}
    for name, index in combined['attributes'].items():
        full = model['accessors'][index]
        view = model['bufferViews'][full['bufferView']]
        stride = view['byteLength'] // full['count']
        if full['count'] - end != 36 * 3 or stride not in (8, 12, 16):
            raise ValueError(f'Unexpected joint or vertex buffer for {name}')
        skin_attributes[name] = index
        load_attributes[name] = len(model['accessors'])
        start = view['byteOffset']
        split = start + stride * end
        attachment = dict(full, count=full['count'] - end, byteOffset=stride * end)
        if 'min' in full:
            for accessor, segment in [(full, binary[start:split]),
                                      (attachment, binary[split:start + view['byteLength']])]:
                coordinates = list(zip(*iter_unpack('<3f', segment), strict=True))
                accessor['min'] = [min(axis) for axis in coordinates]
                accessor['max'] = [max(axis) for axis in coordinates]
        model['accessors'].append(attachment)
        full['count'] = end
    body, = model['materials']
    body['name'] = 'Third Dawn Llama Coat'
    load = deepcopy(body)
    load['name'] = 'Third Dawn Pack Leather'
    load['pbrMetallicRoughness']['roughnessFactor'] = .96
    model['materials'].append(load)
    mesh['primitives'] = [dict(combined, attributes=skin_attributes), dict(combined, attributes=load_attributes, material=1)]
    path.write_text(json.dumps(model, separators=(',', ':')), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models', type=Path, default=RESEARCH / 'uoaos-source/Models',
                        help='Private extracted Third Dawn Models directory with Animals and Maps')
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'work/pack-llama-preparation',
                        help='Private directory for the recovered and refined scenes')
    args = parser.parse_args()
    reader = SimpleNamespace(**runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py')))
    rigid = SimpleNamespace(**runpy.run_path(str(ROOT / 'scripts/creature-rigid-parts.py')))
    raw = pinned(args.models / 'Animals' / SOURCE, '799f3406a179a399ef33278acc5b74b6b9a8a450f205de29650284e2fd03107b')
    atlas = pinned(args.models / 'Maps' / ATLAS, '7371923db2869ad19f3890041fe830b86a2d40b3e965e073c53cbf017e3cf42e')
    donor = pinned(args.models / 'Animals/llamas_llama_lod2.grn',
                   'f120709d45964ca7225682e0fab86490a2822cc5249e328f9aa59f108ffa1452')
    body, load, report = decode(reader, rigid, raw, donor)
    motion_data, motion_hashes = {}, {}
    for clip, suffix in CLIPS.items():
        filename = f'llamas_llama_{suffix}.grn'
        data = pinned(args.models / 'Animals' / filename, MOTION_HASHES[suffix])
        motion_data[clip] = reader.parse(data, animations_only=True, scene_root_names=True)
        motion_hashes[filename] = digest(data)
    refined, refinement = refine_body(body)
    texture = reader.png_from_tga(atlas)
    exports = {}
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for treatment, skin in [('original', body), ('modern', refined)]:
        output = args.output_dir / f'pack-llama-{treatment}.gltf'
        metrics = reader.export_gltf(with_load(skin, load), motion_data, texture, output, height=1.95,
                                     floor_sample_rate=120)
        separate_load(output, len(skin['polygons']))
        exports[treatment] = {'metrics': metrics, 'sha256': digest(output.read_bytes())}
    report['parts'][0]['body_face_start'] = len(body['polygons'])
    report.update(
        native_body=292, source=dict(member=SOURCE, sha256=digest(raw), cabinet='uoaos/UOTD/models/animals/client8.cab',
                                     cabinet_sha256='155fe820d8c0e2a08650f81ec037829bed49aeca74efd2a07479a907287a1afc'),
        atlas=dict(member=ATLAS, sha256=digest(atlas), cabinet='uoaos/UOTD/models/maps/client10.cab',
                   cabinet_sha256='92e9b23c0c226a0d20af5402af7624b188d3bf6e1c4adb510c9d0575d2daa1d9'),
        motion_sha256=motion_hashes, geometry=dict(points=140, triangles=398, bones=30),
        exports=exports, refinement=refinement, derived_art='Private original assets, excluded from distribution.',
    )
    (args.output_dir / 'pack-llama-source.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('Pack Llama: 398 source triangles, 5828 modern triangles, 30 joints, seven motions, original 36-triangle load retained')


if __name__ == '__main__':
    main()
