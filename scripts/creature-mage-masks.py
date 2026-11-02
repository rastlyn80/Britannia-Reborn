"""Authored garment regions on the original mage's integral costume.

Only COLOR_0 is appended. Geometry, UVs, rig and motions remain untouched.
Parent-face assignments avoid bleeding footwear dyes onto foot-weighted hems.
"""
import base64
import copy
import math
import struct


def accessor(doc, index):
    item = doc['accessors'][index]
    view = doc['bufferViews'][item['bufferView']]
    uri = doc['buffers'][view['buffer']]['uri']
    assert uri.startswith('data:application/octet-stream;base64,')
    raw = base64.b64decode(uri.split(',', 1)[1], validate=True)
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[item['type']]
    fmt = '<' + {5126: 'f', 5125: 'I', 5123: 'H', 5121: 'B'}[item['componentType']] * count
    size = struct.calcsize(fmt)
    offset = view.get('byteOffset', 0) + item.get('byteOffset', 0)
    stride = view.get('byteStride', size)
    assert stride >= size and 0 < item['count'] <= 1_000_000
    assert offset >= 0 and offset + (item['count'] - 1) * stride + size <= len(raw)
    return [struct.unpack_from(fmt, raw, offset + i * stride) for i in range(item['count'])]


def children(triangle):
    a, b, c = triangle
    ab, bc, ca = [tuple((x + y) / 2 for x, y in zip(u, v)) for u, v in [(a, b), (b, c), (c, a)]]
    return [(a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)]


def apply(original, refined):
    result = copy.deepcopy(refined)
    assert len(original['meshes']) == len(result['meshes']) == 1
    assert len(original['meshes'][0]['primitives']) == len(result['meshes'][0]['primitives']) == 1
    source = original['meshes'][0]['primitives'][0]
    target = result['meshes'][0]['primitives'][0]
    assert source.get('mode', 4) == target.get('mode', 4) == 4
    attrs, old = target['attributes'], source['attributes']
    assert 'COLOR_0' not in attrs
    positions = accessor(result, attrs['POSITION'])
    old_positions = accessor(original, old['POSITION'])
    joints = accessor(original, old['JOINTS_0'])
    weights = accessor(original, old['WEIGHTS_0'])
    old_uvs = accessor(original, old['TEXCOORD_0'])
    uvs = accessor(result, attrs['TEXCOORD_0'])
    assert len(positions) == len(old_positions) * 16 and len(old_positions) % 3 == 0
    for doc, primitive, count in [(original, source, len(old_positions)), (result, target, len(positions))]:
        assert 'indices' not in primitive or [r[0] for r in accessor(doc, primitive['indices'])] == list(range(count))
    names = [original['nodes'][j]['name'] for j in original['skins'][0]['joints']]
    colors, roles, max_uv_error = [], {}, 0.
    for face in range(len(old_positions) // 3):
        rows = range(face * 3, face * 3 + 3)
        totals = {'hand': [], 'head': [], 'foot': []}
        for i in rows:
            totals['hand'].append(sum(w for j, w in zip(joints[i], weights[i]) if ' hand' in names[j] or ' finger' in names[j]))
            totals['head'].append(sum(w for j, w in zip(joints[i], weights[i]) if names[j] == 'bip01 head'))
            totals['foot'].append(sum(w for j, w in zip(joints[i], weights[i]) if ' foot' in names[j] or ' toe' in names[j]))
        shoe = max(old_positions[i][2] for i in rows) < .135 and sum(totals['foot']) / 3 > .5
        protected = sum(totals['hand']) / 3 > .6 or sum(totals['head']) / 3 > .5
        role = 'shoes' if shoe else 'skin' if protected else 'robe'
        roles[role] = roles.get(role, 0) + 1
        expected = [child for first in children([old_uvs[i] for i in rows]) for child in children(first)]
        for local, expected_uv in enumerate(v for triangle in expected for v in triangle):
            i = face * 48 + local
            max_uv_error = max(max_uv_error, math.dist(uvs[i], expected_uv))
            assert max_uv_error < .00001, 'Source subdivision face/UV order changed'
            cap = max(0., min(1., (positions[i][2] - 1.675) / .035)) if sum(totals['head']) / 3 > .5 else 0.
            colors.append((float(role == 'robe'), cap, float(role == 'shoes'), 1.))
    raw = struct.pack('<' + 'f' * len(colors) * 4, *(v for row in colors for v in row))
    buffer_index, view_index, attribute_index = len(result['buffers']), len(result['bufferViews']), len(result['accessors'])
    result['buffers'].append({'byteLength': len(raw), 'uri': 'data:application/octet-stream;base64,' + base64.b64encode(raw).decode()})
    result['bufferViews'].append({'buffer': buffer_index, 'byteLength': len(raw)})
    result['accessors'].append({'bufferView': view_index, 'componentType': 5126, 'count': len(colors), 'type': 'VEC4'})
    attrs['COLOR_0'] = attribute_index
    assert all(result[k] == refined[k] for k in ['nodes', 'skins', 'animations']) and result['buffers'][:-1] == refined['buffers']
    return result, {'original_face_roles': roles, 'maximum_parent_uv_error': max_uv_error,
                    'policy': 'Whole original face role repeated over exactly sixteen UV-verified subdivision children. Shoes: maximum source Z <0.135m and mean distal weight >0.5. Hand/head faces protected. Cap height/dark-texel mask is authored. Integral costume remains after item removal; this is no recovered native clothing mask.'}
