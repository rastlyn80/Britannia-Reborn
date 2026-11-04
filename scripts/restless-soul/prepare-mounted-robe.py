"""Split the retained ghost robe for the private seated motion trial."""

from collections import defaultdict
import json
import math
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parents[1]
PREPARE = runpy.run_path(str(SCRIPTS / 'prepare-khaldun-doom.py'))
BASE = PREPARE['BASE']
DONORS = ('Horse_Walk', 'Horse_Run', 'Horse_Idle', 'Horse_Attack1h_Slashright',
          'Horse_Attackbow', 'Horse_Attackcrossbow')


def mix(a, b, t):
    weights = defaultdict(float)
    for corner, strength in ((a, 1 - t), (b, t)):
        for index, weight in corner[3]:
            weights[index] += weight * strength
    vectors = [tuple(x + t * (y - x) for x, y in zip(va, vb)) for va, vb in zip(a[:3], b[:3])]
    return (*vectors, list(weights.items()))


def clip_polygon(corners, plane):
    result = []
    last = corners[-1]
    previous = plane(last[0])
    for corner in corners:
        distance = plane(corner[0])
        if (distance >= 0) != (previous >= 0):
            result.append(mix(last, corner, previous / (previous - distance)))
        if distance >= 0:
            result.append(corner)
        last, previous = corner, distance
    return result


def split_robe(model):
    cut_height = 0.84
    result = dict(model, points=[], normals=[], uv_sets=[[]], polygons=[], texture_polygons=[], weights=[])
    vertices = {}
    for polygon, texture in zip(model['polygons'], model['texture_polygons'], strict=True):
        corners = [(model['points'][point], model['normals'][normal], model['uv_sets'][0][uv],
                    model['weights'][point]) for point, normal, uv in zip(polygon[:3], polygon[3:], texture)]
        if min(corner[0][2] for corner in corners) >= cut_height:
            parts = [(0, corners)]
        else:
            upper = clip_polygon(corners, lambda point: point[2] - cut_height)
            lower = clip_polygon(corners, lambda point: cut_height - point[2])
            parts = [(0, upper)]
            if lower:
                for side in (-1, 1):
                    halves = clip_polygon(lower, lambda point: side * point[0] - (cut_height - point[2]) * 0.16)
                    parts.append((side, halves))
        for side, part in parts:
            for index in range(1, len(part) - 1):
                points, normals, uvs = [], [], []
                for point, normal, uv, weights in (part[0], part[index], part[index + 1]):
                    if side:
                        opposite = 'bip01 r ' if side > 0 else 'bip01 l '
                        remove = min(1.0, (cut_height - point[2]) / 0.24)
                        weights = [(tie, value * (1 - remove if model['bones'][model['ties'][tie]]['name'].startswith(opposite) else 1.0))
                                   for tie, value in weights]
                    weights = sorted(((tie, w) for tie, w in weights if w > 1e-6), key=lambda pair: -pair[1])[:4]
                    total = sum(weight for _, weight in weights)
                    assert total > 0
                    weights = [(tie, weight / total) for tie, weight in weights]
                    signature = tuple(round(v, 7) for v in point), tuple((tie, round(w, 7)) for tie, w in weights)
                    vertex = vertices.get(signature)
                    if vertex is None:
                        vertex = vertices[signature] = len(result['points'])
                        result['points'].append(point)
                        result['weights'].append(weights)
                    points.append(vertex)
                    normals.append(len(result['normals']))
                    size = math.sqrt(sum(value ** 2 for value in normal))
                    result['normals'].append(tuple(value / size for value in normal))
                    uvs.append(len(result['uv_sets'][0]))
                    result['uv_sets'][0].append(uv)
                if len(set(points)) == 3:
                    result['polygons'].append((*points, *normals))
                    result['texture_polygons'].append(uvs)
    assert 412 <= len(result['polygons']) <= 600
    return result


def main():
    pipeline = PREPARE['TOOLS']['TOOLS']['pipeline']()
    pins = json.loads(PREPARE['MANIFEST'].read_text(encoding='utf-8'))
    members = {name: PREPARE['checked'](BASE / 'khaldun-doom-source' / name, digest)
               for name, digest in pins['files'].items()}
    ghost, _, _ = PREPARE['ghost_model'](pipeline, members, pins['ghost_motions'])
    atlas = pipeline.td.png_from_tga(members[PREPARE['GHOST_ATLAS']].read_bytes())
    library = json.loads((SCRIPTS / 'restless-soul-donor-inputs.json').read_text(encoding='utf-8'))
    motions = {}
    for label in DONORS:
        witness, = (item for item in library['members'] if item['label'] == label)
        path = BASE / 'restless-soul-pinned-donors/Client' / witness['member'].split('/')[-1]
        raw = PREPARE['checked'](path, witness['sha256']).read_bytes()
        assert len(witness['repairs']) <= 1
        animation = pipeline.td.parse(raw, animations_only=True, scene_root_names=True, scale_shear_tracks=True,
                                      auxiliary_scene_leaf=next(iter(witness['repairs']), None))
        animation, _ = pipeline.normalise_bind(raw, animation)
        motions[label], _ = pipeline.helper.match_animation(animation, ghost)
    mesh = split_robe(ghost)
    out = PREPARE['ART'] / 'restless-soul-mounted-robe-review.gltf'
    stats = pipeline.td.export_gltf(mesh, motions, atlas, out, 1.8, preserve_hover_clips=DONORS)
    rounded, _ = pipeline.smooth.refine(mesh, levels=1, maximum=0.012, weight_smoothing=0.08)
    rounded_path = out.with_name('restless-soul-mounted-robe-rounded-review.gltf')
    rounded_stats = pipeline.td.export_gltf(rounded, motions, atlas, rounded_path, 1.8, preserve_hover_clips=DONORS)
    print('MOUNTED GHOST:', len(ghost['points']), 'to', len(mesh['points']), 'vertices;',
          len(ghost['polygons']), 'to', len(mesh['polygons']), 'triangles;', len(stats['clips']), 'seated clips;',
          rounded_stats['triangles'], 'rounded triangles')


if __name__ == '__main__':
    main()
