"""Read-only Granny 1 -> local glTF experiment. No game assets are distributed.

python scripts/import-third-dawn.py --archive PATH/TO/uotdb.zip
Independent implementation of the chunk layout documented by Iris2's
grannyparser.h / grannyloader_i2.h. No proprietary DLL or executable is used.
Supported scope: single-mesh human/ogre bodies from Third Dawn Alpha Build 35.
"""
import argparse
import base64
import bisect
import binascii
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]


def require(ok, message):
    if not ok:
        raise ValueError(message)


def chunks(data):
    """Yield bounded chunk payloads and their ancestor types (descendant counts)."""
    require(len(data) >= 96, 'Truncated GRN main header')
    magic, count = struct.unpack_from('<II', data, 64)
    require(magic == 0xCA5E0000 and 96 + count * 20 <= len(data), 'Invalid GRN main table')
    lists = [struct.unpack_from('<5I', data, 96 + i * 20) for i in range(count)]
    for i, item in enumerate(lists):
        off = item[2]
        end = lists[i + 1][2] if i + 1 < count else len(data)
        require(0 <= off <= end <= len(data) and off + 16 <= end, 'Invalid GRN list bounds')
        n = struct.unpack_from('<I', data, off)[0]
        require(off + 16 + n * 12 <= end, 'Truncated GRN chunk table')
        entries = [struct.unpack_from('<III', data, off + 16 + j * 12) for j in range(n)]
        parents = []
        for j, (kind, relative, descendants) in enumerate(entries):
            following = entries[j + 1][1] if j + 1 < n else end - off
            require(kind & 0xFFFF0000 == 0xCA5E0000, 'Invalid GRN chunk tag')
            require(16 + n * 12 <= relative <= following <= end - off, 'Invalid GRN payload bounds')
            require(descendants <= n - j - 1, 'Invalid GRN descendant count')
            yield kind, data[off + relative:off + following], [p[0] for p in parents]
            parents = [[k, remaining - 1] for k, remaining in parents if remaining > 1]
            if descendants:
                parents.append([kind, descendants])


def finite(values):
    require(all(math.isfinite(x) for x in values), 'Non-finite GRN numeric value')


def indexed_scene_leaf_alias(bones, params, tie_objects, bone_objects, request):
    """Disambiguate one explicit exporter leaf without dropping joints/tracks."""
    require(set(request) == {'leaf_index', 'primary_index', 'parent_index', 'bone_count', 'source_label'}, 'Explicit indexed scene-leaf contract required')
    leaf, primary, parent = (request[k] for k in ['leaf_index', 'primary_index', 'parent_index'])
    require(all(type(i) is int and 0 <= i < len(bones) for i in [leaf, primary, parent]) and len({leaf, primary, parent}) == 3, 'Invalid scene-leaf indices')
    require(len(bones) == len(bone_objects) == request['bone_count'], 'Scene-leaf skeleton count changed')
    require(bones[leaf]['parent'] == bones[primary]['parent'] == parent and bones[parent]['parent'] == parent, 'Scene-leaf must share the primary scene parent')
    require(not any(b['parent'] == leaf for b in bones) and any(b['parent'] == primary for b in bones), 'Scene-leaf cannot replace a rig ancestor')
    for index in [leaf, primary]:
        require(bones[index]['translation'] == [0., 0., 0.] and bones[index]['rotation'] == [0., 0., 0., 1.], 'Scene-leaf rest transform changed')
        require(0 < bone_objects[index] <= len(tie_objects), 'Scene-leaf binding outside object ties')
        require(0 < tie_objects[bone_objects[index] - 1] <= len(params), 'Scene-leaf object outside property table')
        require(params[tie_objects[bone_objects[index] - 1] - 1]['__objectname'] == request['source_label'], 'Scene-leaf original label changed')
    require(bone_objects[leaf] != bone_objects[primary], 'Scene-leaf requires distinct original object identities')
    return {bone_objects[leaf] - 1: 'unretained_auxiliary_scene_' + str(leaf)}


def parse(data, animations_only=False, scene_root_names=False, skip_unskinned_helpers=False, scale_shear_tracks=False, retained_bone_names=None, auxiliary_scene_leaf=None, max_influences=4):
    require(max_influences in (4, 8), 'Skin layout must explicitly select four or eight influences')
    result = dict(points=[], normals=[], uv_sets=[], polygons=[], texture_polygons=[],
                  bones=[], weights=[], ties=[], tracks=[])
    texts, objects, tie_objects, bone_objects, texture_ids = [], [], [], [], []
    key = None
    entries=list(chunks(data))
    if skip_unskinned_helpers:
        groups=[];active=None
        for index,(kind,payload,ancestors) in enumerate(entries):
            if kind==0xCA5E0601:
                active=[];groups.append(active)
            if 0xCA5E0601 in ancestors and active is not None:active.append(index)
        skinned=[];drop=set()
        for group in groups:
            weight=[entries[i][1] for i in group if entries[i][0]==0xCA5E0702]
            require(len(weight)==1 and len(weight[0])>=12,'One bounded skin header per mesh required')
            count=struct.unpack_from('<I',weight[0])[0]
            if count:skinned.append(group);continue
            points=[entries[i][1] for i in group if entries[i][0]==0xCA5E0801]
            require(len(points)==1 and len(points[0])==8*12 and not any(entries[i][0]==0xCA5E0803 for i in group),'Only untextured eight-vertex helper boxes may be omitted')
            drop.update(group)
        require(len(skinned)==1,'Exactly one skinned body is required; rigid/multipart artwork needs a dedicated importer')
        helper_indices=[i for i,(kind,payload,_) in enumerate(entries)
                        if kind==0xCA5E0E06 and len(payload)==52 and struct.unpack_from('<I',payload)[0]==12]
        require(len(helper_indices)==len(groups)-1,'Helper boxes need matching untextured face-index tables')
        drop.update(helper_indices)
        entries=[entry for i,entry in enumerate(entries) if i not in drop]
    for kind, payload, ancestors in entries:
        # Animation files may embed multiple reference meshes. Explicit track
        # extraction ignores their geometry while retaining bounded chunk,
        # object-name and finite/timed animation validation. Model parsing
        # remains strict and single-mesh by default.
        if animations_only and kind in (0xCA5E0801,0xCA5E0802,0xCA5E0803,0xCA5E0901,0xCA5E0E06,0xCA5E0702):continue
        root = ancestors[0] if ancestors else None
        if kind == 0xCA5E0200:
            n, _ = struct.unpack_from('<II', payload)
            strings = payload[8:].split(b'\0')
            require(n < len(strings), 'Unterminated GRN strings')
            texts.append([s.decode('latin1').lower() for s in strings[:n]])
        elif kind == 0xCA5E0F00 and root == 0xCA5E0F03:
            objects.append({})
        elif kind == 0xCA5E0F01 and root == 0xCA5E0F03:
            key = struct.unpack('<I', payload)[0]
        elif kind == 0xCA5E0F02 and root == 0xCA5E0F03:
            _, value = struct.unpack('<II', payload)
            require(objects and key is not None, 'GRN property without object')
            objects[-1][key] = value
        elif kind == 0xCA5E0F04 and root == 0xCA5E0B01:
            tie_objects.append(struct.unpack('<I', payload)[0])
        elif kind == 0xCA5E0C02:
            bone_objects += list(struct.unpack('<' + 'I' * (len(payload) // 4), payload))
        elif kind == 0xCA5E0C0A:
            require(len(payload) == 32, 'Invalid GRN bone tie')
            result['ties'].append(struct.unpack_from('<I', payload)[0])
        elif kind == 0xCA5E0F04 and root == 0xCA5E0304:
            texture_ids.append(struct.unpack('<I', payload)[0])
        elif kind in (0xCA5E0801, 0xCA5E0802, 0xCA5E0803):
            raw = payload[4:] if kind == 0xCA5E0803 else payload
            require(len(raw) % 12 == 0, 'Invalid GRN vector buffer')
            vectors = list(struct.iter_unpack('<3f', raw))
            for v in vectors:
                finite(v)
            if kind == 0xCA5E0803:
                result['uv_sets'].append(vectors)
            else:
                slot = 'points' if kind == 0xCA5E0801 else 'normals'
                require(not result[slot], 'Only single-mesh GRN is supported')
                result[slot] = vectors
        elif kind == 0xCA5E0901:
            require(len(payload) % 24 == 0, 'Invalid GRN triangle buffer')
            result['polygons'] += list(struct.iter_unpack('<6I', payload))
        elif kind == 0xCA5E0E06:
            n = struct.unpack_from('<I', payload)[0]
            require(n > 0 and (len(payload) - 4) in (n * 16, n * 28), 'Unsupported texture-index layout')
            width = (len(payload) - 4) // n // 4
            for row in struct.iter_unpack('<' + 'I' * width, payload[4:]):
                result['texture_polygons'].append(row[2::2] if width == 7 else row[1:])
        elif kind == 0xCA5E0506:
            require(len(payload) == 68, 'Invalid GRN bone size')
            parent, *v = struct.unpack('<I16f', payload)
            finite(v)
            result['bones'].append(dict(parent=parent, translation=v[:3], rotation=v[3:7]))
        elif kind == 0xCA5E0702:
            n, _, _ = struct.unpack_from('<3I', payload)
            pos = 12
            require(n <= len(payload) // 4, 'Invalid GRN weight count')
            for _ in range(n):
                count = struct.unpack_from('<I', payload, pos)[0]
                pos += 4
                require(0 < count <= max_influences and pos + count * 8 <= len(payload), 'Unsupported GRN vertex influences')
                pairs = [struct.unpack_from('<If', payload, pos + k * 8) for k in range(count)]
                pos += count * 8
                require(all(math.isfinite(w) and w >= 0 for _, w in pairs), 'Invalid skin weight')
                require(abs(sum(w for _, w in pairs) - 1) < 0.001, 'Unnormalised skin weights')
                result['weights'].append(pairs)
            require(pos == len(payload), 'Unconsumed GRN skin bytes')
        elif kind == 0xCA5E1204:
            header = struct.unpack_from('<13I', payload)
            counts = header[6:9]
            scale_width=9 if scale_shear_tracks else 3
            require(52 + sum(counts) * 4 + counts[0] * 12 + counts[1] * 16 + counts[2] * scale_width * 4 <= len(payload), 'Truncated animation track')
            pos, times = 52, []
            for count in counts:
                t = list(struct.unpack_from('<' + 'f' * count, payload, pos))
                finite(t)
                require(t == sorted(t) and all(x >= 0 for x in t), 'Invalid key times')
                pos += count * 4
                times.append(t)
            track = dict(id=header[0])
            for slot, width, count, ts in zip(['translation', 'rotation', 'scale_shear' if scale_shear_tracks else 'scale'], [3, 4, scale_width], counts, times):
                values = [list(struct.unpack_from('<' + 'f' * width, payload, pos + k * width * 4)) for k in range(count)]
                for value in values:
                    finite(value)
                pos += count * width * 4
                track[slot] = dict(times=ts, values=values)
            result['tracks'].append(track)
    require(len(texts) == 2, 'Expected copyright and object GRN string tables')
    strings = texts[1]
    require(all(k < len(strings) and v < len(strings) for obj in objects for k, v in obj.items()), 'GRN string index out of range')
    params = [{strings[k]: strings[v] for k, v in obj.items()} for obj in objects]
    aliases = {}
    if auxiliary_scene_leaf is not None:
        require(animations_only, 'Indexed scene-leaf repair is animation-only')
        aliases = indexed_scene_leaf_alias(result['bones'], params, tie_objects, bone_objects, auxiliary_scene_leaf)
        result['indexed_auxiliary_scene_aliases'] = aliases

    def object_name(index):
        if index in aliases:
            return aliases[index]
        name = params[tie_objects[index] - 1]['__objectname']
        # Granny exporters used several labels for the same scene root.
        is_master = (name.startswith('master_') or name in ['master', 'granny_master']) if scene_root_names else 'master' in name
        return 'granny_master' if is_master else re.sub(r'[^a-z0-9_ -]', '_', name)

    for i, bone in enumerate(result['bones']):
        require(bone['parent'] < len(result['bones']), 'Bone parent outside skeleton')
        bone['name'] = object_name(bone_objects[i] - 1)
    names=[b['name'] for b in result['bones']]
    duplicates={name for name in names if names.count(name)>1}
    if duplicates and animations_only and retained_bone_names is not None:
        normal=lambda name:name.replace('_','')
        retained={normal(name) for name in retained_bone_names}
        require(not any(normal(name) in retained for name in duplicates),'Duplicate bone names')
        # This opt-in applies only to exporter subtrees that the target mesh
        # does not use. Never omit an ancestor of a retained source joint.
        require(all(normal(result['bones'][b['parent']]['name']) in retained
                    for b in result['bones'] if normal(b['name']) in retained),
                'Duplicate auxiliary repair cannot omit an intermediary')
        result['omitted_duplicate_auxiliary_names']=sorted(duplicates)
        for i,bone in enumerate(result['bones']):
            if bone['name'] in duplicates:bone['name']+='__unretained_'+str(i)
    require(len(set(b['name'] for b in result['bones'])) == len(result['bones']), 'Duplicate bone names')
    for track in result['tracks']:
        track['name'] = object_name(track['id'] - 1)
    if result.get('omitted_duplicate_auxiliary_names'):
        result['tracks']=[track for track in result['tracks'] if track['name'] not in duplicates]
    result['textures'] = [params[i - 1]['__filename'].replace('\\', '/').rsplit('/', 1)[-1] for i in texture_ids]
    return result


def png_from_tga(data):
    """Bounded true-colour TGA (raw/RLE) decoder; preserve file origin explicitly."""
    require(len(data) >= 18, 'Truncated TGA')
    idlen, cmap, kind = data[:3]
    w, h, depth, flags = struct.unpack_from('<HHBB', data, 12)
    require(cmap == 0 and kind in (2, 10) and depth in (24, 32) and 0 < w * h <= 16777216, 'Unsupported TGA')
    stride, pos, pixels = depth // 8, 18 + idlen, []
    while len(pixels) < w * h:
        packet = data[pos] if kind == 10 else 0
        if kind == 10:
            pos += 1
        count = (packet & 127) + 1
        require(len(pixels) + count <= w * h, 'TGA run exceeds image')
        for k in range(1 if packet & 128 else count):
            require(pos + stride <= len(data), 'Truncated TGA pixels')
            b, g, r = data[pos:pos + 3]
            a = data[pos + 3] if stride == 4 else 255
            pos += stride
            pixels.extend([(r, g, b, a)] * (count if packet & 128 else 1))
    rows = [pixels[y * w:(y + 1) * w] for y in range(h)]
    if not flags & 32:
        rows.reverse()
    if flags & 16:
        rows = [row[::-1] for row in rows]
    raw = b''.join(b'\0' + bytes(v for pixel in row for v in pixel) for row in rows)

    def chunk(tag, payload):
        return struct.pack('>I', len(payload)) + tag + payload + struct.pack('>I', binascii.crc32(tag + payload) & 0xFFFFFFFF)

    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')


def qmul(a, b):
    x, y, z, w = a
    X, Y, Z, W = b
    return (w * X + x * W + y * Z - z * Y, w * Y - x * Z + y * W + z * X,
            w * Z + x * Y - y * X + z * W, w * W - x * X - y * Y - z * Z)


def rotate(q, p):
    return qmul(qmul(q, (*p, 0)), (-q[0], -q[1], -q[2], q[3]))[:3]


def unit(q):
    length = math.sqrt(sum(v * v for v in q))
    require(length > 0.00001, 'Zero quaternion')
    return [v / length for v in q]


def export_gltf(model, animations, texture, output, height, floor_sample_rate=30, preserve_vertical_clips=(), preserve_hover_clips=(), preserve_waterline_clips=(), measure_motion_bounds=False, max_influences=4):
    require(max_influences in (4, 8), 'Skin layout must explicitly select four or eight influences')
    require(30<=floor_sample_rate<=240,'Floor sampling must stay within 30..240 Hz')
    require(not set(preserve_vertical_clips)&set(preserve_hover_clips),'Clip cannot use both flight and source-hover policies')
    require(not set(preserve_waterline_clips)&(set(preserve_vertical_clips)|set(preserve_hover_clips)),'Waterline clips cannot use land/air support policies')
    if preserve_waterline_clips:
        require(set(preserve_waterline_clips)==set(animations),'Aquatic actors must declare a waterline policy for every clip')
    bones, globals_ = model['bones'], {}

    def global_bone(i, visiting=None):
        if i in globals_:
            return globals_[i]
        visiting = set() if visiting is None else visiting
        require(i not in visiting, 'Cyclic skeleton')
        visiting.add(i)
        bone = bones[i]
        q, t = unit(bone['rotation']), bone['translation']
        if bone['parent'] != i:
            pq, pt = global_bone(bone['parent'], visiting)
            t = [a + b for a, b in zip(rotate(pq, t), pt)]
            q = qmul(pq, q)
        globals_[i] = q, t
        return q, t

    inverse = []
    for i in range(len(bones)):
        q, t = global_bone(i)
        iq = [-q[0], -q[1], -q[2], q[3]]
        it = rotate(iq, [-v for v in t])
        columns = [rotate(iq, p) for p in [(1, 0, 0), (0, 1, 0), (0, 0, 1)]]
        inverse.append([*columns[0], 0, *columns[1], 0, *columns[2], 0, *it, 1])
    data = bytearray()
    gltf = dict(asset=dict(version='2.0', generator='Britannia Reborn local Granny experiment'),
                scene=0, scenes=[dict(nodes=[0])], nodes=[], meshes=[], skins=[],
                bufferViews=[], accessors=[], animations=[])

    def accessor(values, kind, component=5126):
        require(values, 'Empty glTF buffer')
        width = dict(SCALAR=1, VEC2=2, VEC3=3, VEC4=4, MAT4=16)[kind]
        rows = [[v] for v in values] if width == 1 else values
        while len(data) % 4:
            data.append(0)
        start = len(data)
        fmt = 'f' if component == 5126 else 'H'
        for row in rows:
            require(len(row) == width, 'Invalid glTF element')
            data.extend(struct.pack('<' + fmt * width, *row))
        view = len(gltf['bufferViews'])
        gltf['bufferViews'].append(dict(buffer=0, byteOffset=start, byteLength=len(data) - start))
        acc = dict(bufferView=view, componentType=component, count=len(values), type=kind)
        if kind in ('VEC3', 'SCALAR'):
            acc['min'] = [min(row[i] for row in rows) for i in range(width)]
            acc['max'] = [max(row[i] for row in rows) for i in range(width)]
        gltf['accessors'].append(acc)
        return len(gltf['accessors']) - 1

    points, normals, uv, joints, weights = [], [], [], [], []
    extra_joints, extra_weights = [], []
    require(len(model['weights']) == len(model['points']), 'Skin/point count mismatch')
    require(len(model['texture_polygons']) == len(model['polygons']), 'Texture/triangle count mismatch')
    require(1 <= len(model['uv_sets']) <= 2, 'Expected UV or colour/UV vector tables')
    for pi, poly in enumerate(model['polygons']):
        for corner in range(3):
            vi, ni = poly[corner], poly[corner + 3]
            require(vi < len(model['points']) and ni < len(model['normals']), 'Triangle index outside mesh')
            points.append(model['points'][vi])
            normals.append(model['normals'][ni])
            ti = model['texture_polygons'][pi][corner]
            u, v, _ = model['uv_sets'][-1][ti]
            uv.append((u, v))
            pairs = model['weights'][vi]
            require(0 < len(pairs) <= max_influences, 'Source influences exceed the selected glTF skin layout')
            js = [model['ties'][index] for index, _ in pairs]
            require(all(j < len(bones) for j in js), 'Weight bone outside skeleton')
            padded_joints = js + [0] * (max_influences - len(js))
            padded_weights = [w for _, w in pairs] + [0] * (max_influences - len(pairs))
            joints.append(padded_joints[:4])
            weights.append(padded_weights[:4])
            if max_influences == 8:
                extra_joints.append(padded_joints[4:])
                extra_weights.append(padded_weights[4:])
    zmin, zmax = min(p[2] for p in points), max(p[2] for p in points)
    scale = height / (zmax - zmin)
    # Granny Z-up -> glTF/Godot Y-up. The visual root owns scale/grounding;
    # neither skeleton animation nor source root motion can move a game entity.
    gltf['nodes'] = [dict(name='VisualRoot', rotation=[-math.sqrt(.5), 0, 0, math.sqrt(.5)],
                          scale=[scale] * 3, children=[1]),
                     dict(name='SourceSpace', translation=[0, 0, 0 if preserve_waterline_clips else -zmin], children=[])]
    for i, b in enumerate(bones):
        gltf['nodes'].append(dict(name=b['name'], translation=b['translation'], rotation=unit(b['rotation'])))
        parent = 1 if b['parent'] == i else b['parent'] + 2
        gltf['nodes'][parent].setdefault('children', []).append(i + 2)
    meshnode = len(gltf['nodes'])
    gltf['nodes'].append(dict(name='Body', mesh=0, skin=0))
    gltf['nodes'][1]['children'].append(meshnode)
    gltf['skins'] = [dict(name='NativeRig', inverseBindMatrices=accessor(inverse, 'MAT4'), joints=list(range(2, 2 + len(bones))))]
    attributes = dict(POSITION=accessor(points, 'VEC3'), NORMAL=accessor(normals, 'VEC3'),
                      TEXCOORD_0=accessor(uv, 'VEC2'), JOINTS_0=accessor(joints, 'VEC4', 5123), WEIGHTS_0=accessor(weights, 'VEC4'))
    if max_influences == 8:
        attributes.update(JOINTS_1=accessor(extra_joints, 'VEC4', 5123), WEIGHTS_1=accessor(extra_weights, 'VEC4'))
    gltf['meshes'] = [dict(name='NativeBody', primitives=[dict(attributes=attributes, material=0, mode=4)])]
    gltf['images'] = [dict(uri='data:image/png;base64,' + base64.b64encode(texture).decode())]
    gltf['textures'] = [dict(source=0)]
    gltf['materials'] = [dict(name='OriginalAlbedo', doubleSided=True, pbrMetallicRoughness=dict(
        baseColorTexture=dict(index=0), metallicFactor=0, roughnessFactor=.9))]
    byname = {b['name']: i for i, b in enumerate(bones)}
    clip_report = {}
    for name, anim in animations.items():
        clip = dict(name=name, channels=[], samplers=[])
        matched, missing = [], []
        streams = {}
        source_bones = {b['name']: (i, b) for i, b in enumerate(anim['bones'])}
        source_global_q = {}

        def animation_global_q(i):
            if i not in source_global_q:
                b = anim['bones'][i]
                q = unit(b['rotation'])
                if b['parent'] != i:
                    q = qmul(animation_global_q(b['parent']), q)
                source_global_q[i] = q
            return source_global_q[i]

        for track in anim['tracks']:
            if track['name'] not in byname:
                missing.append(track['name'])
                continue
            bi = byname[track['name']]
            si, sb = source_bones[track['name']]
            matched.append(track['name'])
            for path, kind in [('translation', 'VEC3'), ('rotation', 'VEC4')]:
                stream = track[path]
                if not stream['times']:
                    continue
                values = stream['values']
                if path == 'rotation':
                    # These are absolute local orientations. The animation
                    # skeleton's stored pose is already posed, not a neutral
                    # reference to subtract (doing so erases the idle stance).
                    values = [unit(q) for q in values]
                    for k in range(1, len(values)):
                        if sum(a * b for a, b in zip(values[k - 1], values[k])) < 0:
                            values[k] = [-v for v in values[k]]
                if path == 'translation' and track['name'].replace('_','') == 'bip01':
                    target_parent_q = global_bone(bones[bi]['parent'])[0] if bones[bi]['parent'] != bi else [0, 0, 0, 1]
                    source_parent_q = animation_global_q(sb['parent']) if sb['parent'] != si else [0, 0, 0, 1]
                    iq = [-source_parent_q[0], -source_parent_q[1], -source_parent_q[2], source_parent_q[3]]
                    anchor = rotate(target_parent_q, bones[bi]['translation'])
                    # Some human clips have a ~6 m authoring offset and a
                    # rotated master. Re-anchor the pelvis in source world
                    # coordinates, retaining vertical bob but stripping XY.
                    corrected = []
                    for v in values:
                        delta = rotate(source_parent_q, [v[j] - sb['translation'][j] for j in range(3)])
                        corrected.append(list(rotate(iq, [anchor[0], anchor[1], anchor[2] + delta[2]])))
                    values = corrected
                sampler = dict(input=accessor(stream['times'], 'SCALAR'), output=accessor(values, kind), interpolation='LINEAR')
                streams[(bi, path)] = (stream['times'], values)
                clip['channels'].append(dict(sampler=len(clip['samplers']), target=dict(node=bi + 2, path=path)))
                clip['samplers'].append(sampler)
        # Some coarse bodies omit toe/hair leaves. Never drop an unmatched
        # intermediary: only leaves absent from the mesh rig may be skipped.
        for omitted in missing:
            indices = [i for i, b in enumerate(anim['bones']) if b['name'] == omitted]
            require(len(indices) == 1 and not any(b['parent'] == indices[0] and j != indices[0] for j, b in enumerate(anim['bones'])),
                    'Unmapped intermediary animation bone: ' + omitted)
        # Bake a presentation-only floor correction from the *deformed mesh*,
        # not just the hip joint. Clips from different authoring scenes have
        # different stance offsets. This is an in-place review body, not IK.
        duration = max(t[-1] for t, _ in streams.values())

        def sample(bi, path, time):
            if (bi, path) not in streams:
                return bones[bi][path]
            times, values = streams[(bi, path)]
            i = bisect.bisect_right(times, time)
            if i == 0:
                return values[0]
            if i == len(times):
                return values[-1]
            alpha = (time - times[i - 1]) / max(1e-8, times[i] - times[i - 1])
            a, b = values[i - 1], values[i]
            # Slerp, matching glTF quaternion LINEAR interpolation.
            if path == 'rotation':
                dot = min(1.0, max(-1.0, sum(x * y for x, y in zip(a, b))))
                if dot < .9995:
                    theta = math.acos(dot)
                    aa, bb = math.sin((1 - alpha) * theta) / math.sin(theta), math.sin(alpha * theta) / math.sin(theta)
                    return unit([aa * x + bb * y for x, y in zip(a, b)])
                return unit([(1 - alpha) * x + alpha * y for x, y in zip(a, b)])
            return [(1 - alpha) * x + alpha * y for x, y in zip(a, b)]

        times = [min(duration, i / floor_sample_rate) for i in range(math.ceil(duration * floor_sample_rate) + 1)]
        if floor_sample_rate!=30:
            # Fast source falls can cross a narrow extremum between uniform
            # samples. Retain their original joint key times as well.
            times=sorted(set(times)|{time for ts,_ in streams.values() for time in ts})
        offsets = []
        maximum_diagonal=0.
        for time in times:
            posed = {}

            def pose(i):
                if i not in posed:
                    b = bones[i]
                    q, t = sample(i, 'rotation', time), sample(i, 'translation', time)
                    if b['parent'] != i:
                        pq, pt = pose(b['parent'])
                        t = [x + y for x, y in zip(rotate(pq, t), pt)]
                        q = qmul(pq, q)
                    posed[i] = q, t
                return posed[i]

            lowest = math.inf
            lower=[math.inf]*3;upper=[-math.inf]*3
            for vi, point in enumerate(model['points']):
                height_sum = 0.0
                point_sum=[0.,0.,0.]
                for tie, weight in model['weights'][vi]:
                    bi = model['ties'][tie]
                    rq, rt = globals_[bi]
                    local = rotate([-rq[0], -rq[1], -rq[2], rq[3]], [x - y for x, y in zip(point, rt)])
                    pq, pt = pose(bi)
                    transformed=rotate(pq, local)
                    height_sum += (transformed[2] + pt[2]) * weight
                    if measure_motion_bounds:
                        for axis in range(3):point_sum[axis]+=(transformed[axis]+pt[axis])*weight
                lowest = min(lowest, height_sum)
                if measure_motion_bounds:
                    for axis in range(3):lower[axis]=min(lower[axis],point_sum[axis]);upper[axis]=max(upper[axis],point_sum[axis])
            if measure_motion_bounds:maximum_diagonal=max(maximum_diagonal,math.sqrt(sum((hi-lo)**2 for lo,hi in zip(lower,upper)))*scale)
            offsets.append([0, 0, -lowest])
        if name in preserve_waterline_clips:
            # Native sea mobiles are anchored at the water surface. Their
            # source tentacles/fins may extend below it; never lift the entire
            # actor every frame to make its lowest point walk on the water.
            offsets=[[0,0,0] for _ in offsets]
        elif name in preserve_hover_clips:
            # An explicitly selected floating source keeps its positive
            # authoring-space clearance and vertical motion. Lift only when
            # the deformed underside crosses the ground; do not pin tentacles.
            offsets=[[0,0,max(0.,value[2])] for value in offsets]
        elif name in preserve_vertical_clips:
            # Flying motion must retain the source rise/fall, rather than pin
            # its lowest vertex to the floor on every frame. Land ends at the
            # surface; takeoff starts there. Sustained flight has clearance.
            anchor=offsets[-1 if name=='Land' else 0][2]
            if name in ['Fly','HitInAir']:anchor=max(value[2] for value in offsets)
            if name in ['Fly','HitInAir']:anchor+=height*.15/scale
            offsets=[[0,0,max(anchor,value[2]) if name in ['TakeOff','Land'] else anchor] for value in offsets]
        clip['channels'].append(dict(sampler=len(clip['samplers']), target=dict(node=1, path='translation')))
        clip['samplers'].append(dict(input=accessor(times, 'SCALAR'), output=accessor(offsets, 'VEC3'), interpolation='LINEAR'))
        gltf['animations'].append(clip)
        clip_report[name] = dict(matched_tracks=len(matched), missing=missing, floor_samples=len(times),
                                 floor_sample_rate=floor_sample_rate,floor_policy='native_waterline' if name in preserve_waterline_clips else 'source_hover' if name in preserve_hover_clips else 'source_vertical' if name in preserve_vertical_clips else 'grounded',floor_offset_range=[min(v[2] for v in offsets), max(v[2] for v in offsets)])
        if measure_motion_bounds:clip_report[name]['measured_max_pose_diagonal_m']=maximum_diagonal
    gltf['buffers'] = [dict(byteLength=len(data), uri='data:application/octet-stream;base64,' + base64.b64encode(data).decode())]
    output.write_text(json.dumps(gltf, separators=(',', ':')))
    return dict(source_points=len(model['points']), triangles=len(model['polygons']), bones=len(bones),
                height_m=height, source_z=[zmin, zmax], scale=scale, clips=clip_report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    args = parser.parse_args()
    out = ROOT / 'Viewer/local-art/third-dawn'
    out.mkdir(parents=True, exist_ok=True)
    archive_hash = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    manifest = dict(source=str(args.archive.resolve()), archive_sha256=archive_hash,
                    source_url='https://zuluarchive.com/static/files/uotdb.zip',
                    format_reference='https://github.com/kblaschke/Iris2/tree/c3f53748f3366d6716e89c9aa94a6743a72edc6e',
                    provenance='Preserved Third Dawn 2.0.4 Alpha Build 35; proprietary EA/Origin game data; no redistribution grant',
                    converter_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), models={})
    with zipfile.ZipFile(args.archive) as z:
        names = {n.lower(): n for n in z.namelist()}
        prefix = 'uotdb/uotd/models/'
        jobs = [('human', 'humans/h_male', 1.8), ('ogre', 'monsters/ogres_ogre', 2.8)]
        for label, stem, height in jobs:
            inputs = []

            def read(suffix):
                name = names[prefix + stem + suffix + '.grn']
                data = z.read(name)
                inputs.append(dict(path=name, sha256=hashlib.sha256(data).hexdigest()))
                return parse(data)

            model = read('_lod2')
            animations = {clip: read('_idle1' if label == 'human' and clip == 'Idle' else '_' + clip.lower()) for clip in ['Idle', 'Walk', 'Run']}
            require(len(set(model['textures'])) == 1, 'Only one material is supported')
            texture_path = next(n for n in z.namelist() if n.rsplit('/', 1)[-1].lower() == model['textures'][0])
            raw = z.read(texture_path)
            inputs.append(dict(path=texture_path, sha256=hashlib.sha256(raw).hexdigest()))
            texture = png_from_tga(raw)
            report = export_gltf(model, animations, texture, out / (label + '.gltf'), height)
            report['inputs'] = inputs
            report['output_sha256'] = hashlib.sha256((out / (label + '.gltf')).read_bytes()).hexdigest()
            manifest['models'][label] = report
            print(label, report['source_points'], 'points', report['triangles'], 'triangles', report['bones'], 'bones')
    (out / 'provenance.json').write_text(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
