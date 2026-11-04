"""Fit scimitar roll against the support envelopes of the stored Classic silhouettes."""

import base64
import json
import math
from pathlib import Path
import runpy
from statistics import mean, median, quantiles
import struct

M = runpy.run_path(str(Path(__file__).with_name('fit-spectral-landmarks.py')))
REVIEW = M['TOOLS']['OUTPUT']
ART = M['ROOT'] / 'Viewer/local-art/creatures/khaldun_doom/spectral-scimitar.gltf'
GUARD = (0.0, 0.057, 0.0)
NORMALS = M['ANGLES'][:4]
ROLL_COUNT = 24


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, scale):
    return tuple(v * scale for v in a)


def cross(a, b):
    x, y, z = a
    p, q, r = b
    return (y * r - z * q, z * p - x * r, x * q - y * p)


def unit(vector):
    return mul(vector, 1 / math.sqrt(dot(vector, vector)))


def frame_basis(axis):
    x = (1, 0, 0) if abs(axis[0]) < .85 else (0, 0, 1)
    x = unit(sub(x, mul(axis, dot(x, axis))))
    return x, axis, cross(x, axis)


def blade_geometry():
    model = M['TOOLS']['read'](ART)
    index = model['meshes'][0]['primitives'][0]['attributes']['POSITION']
    accessor = model['accessors'][index]
    view = model['bufferViews'][accessor['bufferView']]
    raw = base64.b64decode(model['buffers'][view['buffer']]['uri'].split(',', 1)[1])
    start = view['byteOffset'] + accessor.get('byteOffset', 0)
    points = sorted(set(struct.iter_unpack('<3f', raw[start:start + accessor['count'] * 12])))
    assert len(points) == 48
    tip = max(points, key=lambda point: point[1])
    axis = sub(tip, GUARD)
    basis = frame_basis(unit(axis))
    return [tuple(dot(sub(point, GUARD), direction) for direction in basis) for point in points], basis, math.sqrt(dot(axis, axis))


def envelope(points):
    results = []
    for x, y in NORMALS:
        values = [x * p + y * q for p, q in points]
        results.extend((min(values), max(values)))
    return results


def sprite_envelope(frame):
    image, cx, cy = frame
    points = [(x - cx + .5, y - image.height - cy + .5)
              for y in range(image.height) for x in range(image.width) if image.getpixel((x, y))[3]]
    assert points
    return envelope(points)


def world(item):
    x, y, z = item['point']
    return (x, y, -z)


def candidate(hilt, axis, angle, vertices, targets, pitch):
    x, _, z = frame_basis(axis)
    p = add(mul(x, math.cos(angle)), mul(z, math.sin(angle)))
    q = cross(p, axis)
    points = [add(hilt, add(mul(p, a), add(mul(axis, b), mul(q, c)))) for a, b, c in vertices]
    elevation = math.sqrt(1 - pitch * pitch)
    errors = []
    for (c, s), wanted in zip(M['ANGLES'], targets):
        actual = envelope([(c * a - s * d, -elevation * b + pitch * (-s * a - c * d)) for a, b, d in points])
        errors.extend((a - b) ** 2 for a, b in zip(actual, wanted))
    return mean(errors), (p, axis, q)


def rotation_columns(source, target):
    return [tuple(sum(source[i][column] * target[i][row] for i in range(3)) for row in range(3))
            for column in range(3)]


def main():
    saved = M['TOOLS']['read'](REVIEW / 'spectral-five-view-fit.json')
    pitch = saved['pitch_coefficient']
    samples = {(row['slot'], row['frame']): row for row in saved['samples']}
    vertices, bind_basis, blade_length = blade_geometry()
    pixels = median(math.dist(world(row['hilt']), world(row['tip'])) for row in samples.values())
    vertices = [mul(point, pixels / blade_length) for point in vertices]
    rows = [row for row in M['LEDGER']['original_mul_group_candidates'] if row['body'] == 637]
    result = []
    errors_before, errors_after = [], []
    for row in rows:
        slot = row['group']
        views = [M['TOOLS']['read_direction'](M['DATA'], row, direction) for direction in row['directions']]
        assert len({len(view) for view in views}) == 1
        frames = []
        for frame, images in enumerate(zip(*views)):
            fit = samples[slot, frame]
            hilt = world(fit['hilt'])
            axis = unit(sub(world(fit['tip']), hilt))
            targets = [sprite_envelope(image) for image in images]
            candidates = [candidate(hilt, axis, n * math.tau / ROLL_COUNT, vertices, targets, pitch)
                          for n in range(ROLL_COUNT)]
            frames.append(candidates)

        # A short motion should retain a plausible transverse blade axis.
        # The transition cost compares world axes so the reference basis can flip.
        history = []
        costs = [cost for cost, _ in frames[0]]
        for previous, current in zip(frames, frames[1:]):
            paths = [min((value + 2.0 * (1 - dot(old[1][0], basis[0])), index)
                         for index, (value, old) in enumerate(zip(costs, previous))) for _, basis in current]
            history.append([index for _, index in paths])
            costs = [cost + path[0] for (cost, _), path in zip(current, paths)]
        best = min(range(ROLL_COUNT), key=costs.__getitem__)
        route = [best]
        for predecessors in reversed(history):
            route.append(predecessors[route[-1]])
        for frame, roll in enumerate(reversed(route)):
            score, orientation = frames[frame][roll]
            errors_before.append(math.sqrt(frames[frame][0][0]))
            errors_after.append(math.sqrt(score))
            result.append({'slot': slot, 'frame': frame,
                           'hilt': mul(world(samples[slot, frame]['hilt']), blade_length / pixels),
                           'basis': rotation_columns(bind_basis, orientation), 'silhouette_error_px': math.sqrt(score)})
    output = REVIEW / 'spectral-silhouette-fit.json'
    output.write_text(json.dumps({'guard': GUARD, 'blade_length': blade_length, 'poses': result}, indent=2) + '\n', encoding='utf-8')
    for label, errors in [('zero roll', errors_before), ('fitted roll', errors_after)]:
        print(label, 'silhouette support RMS median/p90/max', [round(v, 3) for v in (median(errors), quantiles(errors, n=10)[-1], max(errors))])
    print(len(result), 'poses', output)


if __name__ == '__main__':
    main()
