"""Export Gazer Larva's original affine rig and nine source motions."""
import base64
import importlib.util
import json
import math
from pathlib import Path
import struct

SCRIPTS = Path(__file__).resolve().parent
CLIPS = {'idle': 'Idle', 'walk': 'Walk', 'run': 'Run', 'attack1': 'Attack',
         'attack2': 'Attack2', 'attack3': 'Attack3', 'gethit': 'Hit', 'die1': 'Death', 'fidget': 'Fidget'}


def module(name, file):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def matrix(values):
    return [list(values[index:index + 3]) for index in range(0, 9, 3)]


def bind_pose(model, td, affine, factors):
    bones = model['bones']
    local = []
    factored = []
    for bone, values in zip(bones, model['source_scale_shear'], strict=True):
        shear = matrix(values)
        rotation = td.unit(bone['rotation'])
        left, scale, right, _ = factors.factor(shear)
        local.append((affine.multiply(factors.rotation(rotation), shear), bone['translation']))
        factored.append({'position': bone['translation'], 'left': td.qmul(rotation, left),
                         'scale': scale, 'right': right})

    world = {}
    visiting = set()

    def transform(index):
        if index in world:
            return world[index]
        assert index not in visiting
        visiting.add(index)
        basis, point = local[index]
        parent = bones[index]['parent']
        if parent != index:
            parent_basis, parent_point = transform(parent)
            basis = affine.multiply(parent_basis, basis)
            point = [a + b for a, b in zip(affine.vector(parent_basis, point), parent_point)]
        visiting.remove(index)
        world[index] = basis, point
        return world[index]

    inverse = []
    for index in range(len(bones)):
        basis, point = transform(index)
        inverted = affine.inverse(basis)
        inverse.append({'basis': inverted, 'position': [-value for value in affine.vector(inverted, point)]})
    return local, {'bind_poses': factored, 'inverse_bind': inverse}


def check_hierarchy(animation, bones, bind_local, factors):
    indices = {bone['name']: index for index, bone in enumerate(bones)}
    clip_bones = animation['bones']
    for index, bone in enumerate(clip_bones):
        name = bone['name']
        if name not in indices:
            assert not any(other['parent'] == index for i, other in enumerate(clip_bones) if i != index)
            continue
        source_parent = clip_bones[bone['parent']]['name']
        mesh_parent = bones[bones[indices[name]]['parent']]['name']
        if source_parent != mesh_parent:
            assert (name, source_parent, mesh_parent) == ('bip 01', '__root', 'granny_master')
            basis, position = bind_local[indices[mesh_parent]]
            assert factors.error(basis, factors.identity()) < 1e-7 and max(map(abs, position)) < 1e-7


def main():
    source = module('gazer_source', 'prepare-gazer-larva-source.py')
    pins = source.inputs()
    src = source.SOURCE
    work = source.WORK / 'owned-source'
    tools = source.pipeline()
    model, _ = source.decode((src / 'Models/Monsters/swarm_lod2.grn').read_bytes(), pins['parts'], tools)
    export_model(model, tools.td, src, work, source.MANIFEST, stem='swarm',
                 output='swarm-full-affine.gltf', scale=1.3, node_name='OriginalSwarmAndCards')


def export_model(model, td, src, work, manifest, *, stem, output, scale, node_name):
    source = module('gazer_source', 'prepare-gazer-larva-source.py')
    affine = module('gazer_affine', 'creature-affine.py')
    factors = module('gazer_factors', 'gazer-affine-factors.py')
    work.mkdir(parents=True, exist_ok=True)
    (work / 'prepared').mkdir(exist_ok=True)
    bones = model['bones']
    bind_local, fixture = bind_pose(model, td, affine, factors)
    sha = source.sha
    g = {'asset': {'version': '2.0', 'generator': 'Private exact-matrix Swarm factor experiment'}, 'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [], 'buffers': [], 'bufferViews': [], 'accessors': [], 'animations': []}
    binary = bytearray()

    def accessor(rows, kind, component=5126, target=None):
        widths = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
        width = widths[kind]
        if kind == 'SCALAR':
            rows = [[v] for v in rows]
        assert rows and all((len(v) == width and all((math.isfinite(x) for x in v)) for v in rows))
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        fmt = 'f' if component == 5126 else 'H'
        flat = [x for row in rows for x in row]
        binary.extend(struct.pack('<' + fmt * len(flat), *flat))
        view = {'buffer': 0, 'byteOffset': offset, 'byteLength': len(binary) - offset}
        if target:
            view['target'] = target
        vi = len(g['bufferViews'])
        g['bufferViews'].append(view)
        record = {'bufferView': vi, 'componentType': component, 'count': len(rows), 'type': kind}
        if kind in ['SCALAR', 'VEC3']:
            record.update(min=[min((v[i] for v in rows)) for i in range(width)], max=[max((v[i] for v in rows)) for i in range(width)])
        g['accessors'].append(record)
        return len(g['accessors']) - 1

    def mat4(b, t):
        return [b[0][0], b[1][0], b[2][0], 0.0, b[0][1], b[1][1], b[2][1], 0.0, b[0][2], b[1][2], b[2][2], 0.0, *t, 1.0]
    g['nodes'] = [{'name': 'VisualRoot', 'rotation': [-math.sqrt(0.5), 0.0, 0.0, math.sqrt(0.5)], 'scale': [scale] * 3, 'children': [1]}, {'name': 'SourceSpace', 'children': []}]
    for i, (bone, pose) in enumerate(zip(bones, fixture['bind_poses'])):
        helper = 2 + i * 2
        leaf = helper + 1
        g['nodes'].append({'name': '__matrix_factor_' + str(i), 'translation': pose['position'], 'rotation': pose['left'], 'scale': pose['scale'], 'children': [leaf]})
        g['nodes'].append({'name': bone['name'], 'rotation': pose['right']})
    for i, bone in enumerate(bones):
        parent = 1 if bone['parent'] == i else 2 + bone['parent'] * 2 + 1
        g['nodes'][parent].setdefault('children', []).append(2 + i * 2)
    body = len(g['nodes'])
    g['nodes'].append({'name': node_name, 'mesh': 0, 'skin': 0})
    g['nodes'][1]['children'].append(body)
    inverse = []
    for i, bind in enumerate(fixture['inverse_bind']):
        right = factors.rotation(fixture['bind_poses'][i]['right'])
        ib = bind['basis']
        ip = bind['position']
        inverse.append(mat4(affine.multiply(right, ib), affine.vector(right, ip)))
        inverse.append(mat4(ib, ip))
    g['skins'] = [{'name': f'{len(bones)} source joints through{len(bones) * 2} TRS factors' if stem == 'swarm'
                  else f'{len(bones)} source joints through {len(bones) * 2} TRS factors',
                  'joints': list(range(2, 2 + len(bones) * 2)), 'skeleton': 2,
                  'inverseBindMatrices': accessor(inverse, 'MAT4')}]
    positions = []
    normals = []
    uvs = []
    indices = []
    weights = []
    for face, texture in zip(model['polygons'], model['texture_polygons']):
        for c in range(3):
            point = face[c]
            positions.append(model['points'][point])
            normals.append(model['normals'][face[c + 3]])
            uvs.append(model['uv_sets'][0][texture[c]][:2])
            pairs = model['weights'][point]
            assert 0 < len(pairs) <= 4
            indices.append([model['ties'][tie] * 2 + 1 for tie, _ in pairs] + [0] * (4 - len(pairs)))
            weights.append([weight for _, weight in pairs] + [0.0] * (4 - len(pairs)))
    attributes = {name: accessor(data, kind, component, 34962) for name, data, kind, component in [('POSITION', positions, 'VEC3', 5126), ('NORMAL', normals, 'VEC3', 5126), ('TEXCOORD_0', uvs, 'VEC2', 5126), ('JOINTS_0', indices, 'VEC4', 5123), ('WEIGHTS_0', weights, 'VEC4', 5126)]}
    g['meshes'] = [{'name': f"Original{len(model['points'])}points{len(model['polygons'])}triangles", 'primitives': [{'attributes': attributes, 'material': 0, 'mode': 4}]}]
    png = td.png_from_tga((src / 'Models/Maps' / (stem + '_256.tga')).read_bytes())
    g['images'] = [{'uri': 'data:image/png;base64,' + base64.b64encode(png).decode()}]
    g['textures'] = [{'source': 0}]
    g['materials'] = [{'name': 'OriginalRGBA', 'doubleSided': True, 'alphaMode': 'MASK', 'alphaCutoff': 0.12, 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0, 'roughnessFactor': 0.8}}]
    reports = []
    for suffix, label in CLIPS.items():
        path = src / 'Models/Monsters' / (stem + '_' + suffix + '.grn')
        raw = path.read_bytes()
        animation = td.parse(raw, animations_only=True, scene_root_names=True, scale_shear_tracks=True)
        check_hierarchy(animation, bones, bind_local, factors)
        defaults = {b['name']: b for b in animation['bones']}
        tracks = {track['name']: track for track in animation['tracks']}
        default_s = {b['name']: list(v) for b, v in zip(animation['bones'], [struct.unpack('<I16f', buf)[8:] for tag, buf, _ in td.chunks(raw) if tag == 3395159302])}
        keys = {t for track in tracks.values() for stream in ['translation', 'rotation', 'scale_shear'] for t in track[stream]['times']}
        length = max(keys)
        count = math.ceil(length * 240.0)
        times = sorted({struct.unpack('<f', struct.pack('<f', t))[0] for t in keys | {min(length, i / 240.0) for i in range(count + 1)}})
        input_ = accessor(times, 'SCALAR')
        streams = [{'position': [], 'left': [], 'scale': [], 'right': []} for _ in bones]
        previous = {}
        last_left = {}
        last_right = {}
        maximum_reconstruction = 0.0
        for time in times:
            for i, bone in enumerate(bones):
                name = bone['name']
                default = defaults.get(name, bone)
                track = tracks.get(name)
                position = affine.sample(track['translation'], time, default['translation']) if track else default['translation']
                rotation = td.unit(affine.sample(track['rotation'], time, default['rotation'], rotation=True) if track else default['rotation'])
                shear = affine.sample(track['scale_shear'], time, default_s[name]) if track else model['source_scale_shear'][i]
                left, scale, right, error = factors.factor(matrix(shear), previous.get(name))
                previous[name] = (left, right)
                maximum_reconstruction = max(maximum_reconstruction, error)
                combined = td.qmul(rotation, left)
                if i in last_left and sum((a * b for a, b in zip(combined, last_left[i]))) < 0.0:
                    combined = [-v for v in combined]
                if i in last_right and sum((a * b for a, b in zip(right, last_right[i]))) < 0.0:
                    right = [-v for v in right]
                last_left[i] = combined
                last_right[i] = right
                streams[i]['position'].append(position)
                streams[i]['left'].append(combined)
                streams[i]['scale'].append(scale)
                streams[i]['right'].append(right)
        clip = {'name': label, 'channels': [], 'samplers': []}
        for i, stream in enumerate(streams):
            for node, path_, values, kind in [(i * 2 + 2, 'translation', stream['position'], 'VEC3'), (i * 2 + 2, 'rotation', stream['left'], 'VEC4'), (i * 2 + 2, 'scale', stream['scale'], 'VEC3'), (i * 2 + 3, 'rotation', stream['right'], 'VEC4')]:
                clip['channels'].append({'sampler': len(clip['samplers']), 'target': {'node': node, 'path': path_}})
                clip['samplers'].append({'input': input_, 'output': accessor(values, kind), 'interpolation': 'LINEAR'})
        g['animations'].append(clip)
        reports.append({'clip': label, 'source_file': path.name, 'source_sha256': sha(path), 'samples': len(times), 'duration_s': length, 'tracks': len(clip['channels']), 'maximum_matrix_factor_error': maximum_reconstruction})
        print('FULL AFFINE GLTF', label, len(times), 'samples', flush=True)
    g['buffers'] = [{'byteLength': len(binary), 'uri': 'data:application/octet-stream;base64,' + base64.b64encode(binary).decode()}]
    out = work / 'prepared' / output
    out.write_text(json.dumps(g, separators=(',', ':'), allow_nan=False) + '\n')
    report = {'gltf_sha256': sha(out), 'sample_rate_hz': 240, 'logical_joints': len(bones), 'render_joints': len(bones) * 2,
              'source_triangles': len(model['polygons']), 'animations': reports, 'manifest_sha256': sha(manifest),
              'exporter_sha256': sha(Path(__file__)), 'factor_recipe_sha256': sha(SCRIPTS / 'gazer-affine-factors.py')}
    (work / 'full-affine-export.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(stem.upper(), 'FULL AFFINE EXPORT:', out.stat().st_size, 'bytes')


if __name__ == '__main__':
    main()
