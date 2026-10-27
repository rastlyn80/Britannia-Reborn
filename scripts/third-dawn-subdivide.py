"""Conservative Loop refinement for local skinned Granny meshes.

Uses mesh connectivity, keeps UV seams separate, blends up to four bone weights
and caps displacement from the linearly refined source cage. No new anatomy is
invented. Original bones, material islands and animations are retained.
"""
import copy
import math


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def mul(a, k):
    return tuple(x * k for x in a)


def blend(points, coefficients):
    return tuple(sum(p[j] * w for p, w in zip(points, coefficients)) for j in range(3))


def limit(point, reference, maximum):
    d = tuple(a - b for a, b in zip(point, reference))
    distance = math.sqrt(sum(x * x for x in d))
    return add(reference, mul(d, min(1.0, maximum / max(distance, 1e-12))))


def mix_weights(entries):
    weights = {}
    for pairs, coefficient in entries:
        for bone, value in pairs:
            weights[bone] = weights.get(bone, 0.0) + coefficient * value
    ordered = sorted(((b, w) for b, w in weights.items() if w > 0), key=lambda item: (-item[1], item[0]))[:4]
    total = sum(w for _, w in ordered)
    if total <= 0:
        raise ValueError('Refined vertex has no skin weights')
    return [(bone, w / total) for bone, w in ordered]


def refine(source, levels=2, maximum=0.018, strengths=None, weight_smoothing=0.):
    if not 0 <= levels <= 2 or not 0 <= maximum <= (.05 if strengths is not None else .03):
        raise ValueError('Subdivision requires at most two levels; displacement cap is 3 cm globally or 5 cm with a local mask')
    if strengths is not None and (len(strengths) != len(source['points']) or any(not 0 <= w <= 1 for w in strengths)):
        raise ValueError('One finite 0..1 smoothing strength is required per source vertex')
    strengths = list(strengths) if strengths is not None else [1.] * len(source['points'])
    if not 0 <= weight_smoothing <= .5:
        raise ValueError("Joint weight smoothing must be between zero and one half")
    model = copy.deepcopy(source)
    model['weights'] = [[(model['ties'][tie], w) for tie, w in pairs] for pairs in model['weights']]
    model['ties'] = list(range(len(model['bones'])))
    references = list(model['points'])
    start_triangles = len(model['polygons'])
    for _ in range(levels):
        points = model['points']
        edges, neighbors = {}, [set() for _ in points]
        for poly in model['polygons']:
            a, b, c = poly[:3]
            for x, y, opposite in [(a, b, c), (b, c, a), (c, a, b)]:
                edges.setdefault(tuple(sorted((x, y))), []).append(opposite)
                neighbors[x].add(y)
                neighbors[y].add(x)
        boundary = [set() for _ in points]
        for (a, b), others in edges.items():
            if len(others) != 2:
                boundary[a].add(b)
                boundary[b].add(a)
        refined = []
        for i, point in enumerate(points):
            surrounding = sorted(neighbors[i])
            if len(boundary[i]) == 2:
                sides = sorted(boundary[i])
                candidate = blend([point, points[sides[0]], points[sides[1]]], [.75, .125, .125])
            elif boundary[i] or len(surrounding) < 3:
                candidate = point
            else:
                beta = 3 / (8 * len(surrounding)) if len(surrounding) > 3 else 3 / 16
                candidate = blend([point] + [points[n] for n in surrounding], [1 - beta * len(surrounding)] + [beta] * len(surrounding))
            refined.append(limit(blend([references[i], candidate], [1-strengths[i], strengths[i]]), references[i], maximum * strengths[i]))
        edge_ids = {}
        new_weights = []
        for i, pairs in enumerate(model['weights']):
            amount = weight_smoothing * strengths[i]
            sides = sorted(neighbors[i])
            entries = [(pairs, 1-amount)] + [(model['weights'][j], amount/len(sides)) for j in sides] if sides else [(pairs, 1.)]
            new_weights.append(mix_weights(entries))
        new_references = list(references)
        new_strengths = list(strengths)
        for (a, b), opposites in sorted(edges.items()):
            ids = [a, b] + opposites if len(opposites) == 2 else [a, b]
            coefficients = [.375, .375, .125, .125] if len(opposites) == 2 else [.5, .5]
            candidate = blend([points[j] for j in ids], coefficients)
            ref = blend([references[a], references[b]], [.5, .5])
            edge_ids[(a, b)] = len(refined)
            strength = (strengths[a] + strengths[b]) * .5
            refined.append(limit(blend([ref, candidate], [1-strength, strength]), ref, maximum * strength))
            new_strengths.append(strength)
            new_references.append(ref)
            curved = mix_weights([(model['weights'][j], w) for j, w in zip(ids, coefficients)])
            linear = mix_weights([(model['weights'][a], .5), (model['weights'][b], .5)])
            new_weights.append(mix_weights([(linear, 1-strength), (curved, strength)]))
        polygons, tex_polys, uv = [], [], []
        old_uv = model['uv_sets'][-1]
        for pi, poly in enumerate(model['polygons']):
            a, b, c = poly[:3]
            ab, bc, ca = [edge_ids[tuple(sorted(edge))] for edge in [(a, b), (b, c), (c, a)]]
            ua, ub, uc = [old_uv[j] for j in model['texture_polygons'][pi]]
            uab, ubc, uca = [blend([u, v], [.5, .5]) for u, v in [(ua, ub), (ub, uc), (uc, ua)]]
            for vertices, values in [((a, ab, ca), (ua, uab, uca)), ((ab, b, bc), (uab, ub, ubc)),
                                     ((ca, bc, c), (uca, ubc, uc)), ((ab, bc, ca), (uab, ubc, uca))]:
                polygons.append((*vertices, *vertices))
                tex_polys.append((len(uv), len(uv) + 1, len(uv) + 2))
                uv.extend(values)
        normals = [(0., 0., 0.) for _ in refined]
        for poly in polygons:
            a, b, c = [refined[i] for i in poly[:3]]
            u, v = [tuple(x - y for x, y in zip(p, a)) for p in (b, c)]
            normal = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            for i in poly[:3]: normals[i] = add(normals[i], normal)
        normals = [mul(n, 1 / max(1e-12, math.sqrt(sum(v * v for v in n)))) for n in normals]
        # Preserve the source normal convention if triangle winding is reversed.
        score = sum(sum(a * b for a, b in zip(normals[i], model['normals'][model['polygons'][pi][3 + corner]]))
                    for pi, poly in enumerate(model['polygons']) for corner, i in enumerate(poly[:3]))
        if score < 0: normals = [mul(n, -1) for n in normals]
        model.update(points=refined, normals=normals, weights=new_weights, polygons=polygons,
                     uv_sets=[uv], texture_polygons=tex_polys)
        references = new_references
        strengths = new_strengths
    report = dict(levels=levels, triangles_before=start_triangles, triangles_after=len(model['polygons']),
                  vertices_after=len(model['points']), max_source_displacement=maximum,
                  measured_max_displacement=max(math.dist(p, r) for p, r in zip(model['points'], references)))
    report['unchanged_unselected_vertices'] = sum(w == 0 and math.dist(p, r) < 1e-12 for w, p, r in zip(strengths, model['points'], references))
    return model, report
