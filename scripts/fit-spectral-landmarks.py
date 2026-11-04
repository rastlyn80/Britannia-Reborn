"""Fit landmarks from the local registered Classic scimitar projections."""

from collections import Counter
from itertools import zip_longest
import json
import math
from pathlib import Path
import runpy
from statistics import mean, median, quantiles

TOOLS = runpy.run_path(str(Path(__file__).with_name('inspect-creature-mul-frames.py')))
ROOT = TOOLS['ROOT']
LEDGER = TOOLS['read'](TOOLS['LEDGER'])
DATA = Path(TOOLS['read'](ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
ANGLES = [(math.cos(n * math.pi / 4), math.sin(n * math.pi / 4)) for n in range(5)]


def image_points(frame):
    picture, cx, cy = frame
    guard = []
    blade = []
    for y in range(picture.height):
        for x in range(picture.width):
            r, g, b, a = picture.getpixel((x, y))
            if not a:
                continue
            point = (x - cx + 0.5, y - picture.height - cy + 0.5)
            if r > 63 and r > g + 12 and g > b + 14:
                guard.append(point)
            elif abs(r - g) < 29 and abs(r - b) < 32 and max(r, g, b) > 35:
                blade.append(point)
    if not guard or not blade:
        return None
    centre = mean(p[0] for p in guard), mean(p[1] for p in guard)
    blade.sort(key=lambda p: math.dist(p, centre))
    tip = blade[-max(1, min(4, len(blade) // 15)):]
    tip = mean(p[0] for p in tip), mean(p[1] for p in tip)
    return centre, tip, len(guard)


def fit_horizontal(points):
    m = [(ANGLES[i], p[0]) for i, p in points]
    aa = sum(c * c for (c, _), _ in m)
    bb = sum(c * s for (c, s), _ in m)
    cc = sum(s * s for (_, s), _ in m)
    ap = sum(c * x for (c, _), x in m)
    bp = sum(s * x for (_, s), x in m)
    divisor = aa * cc - bb * bb
    if divisor < 0.1:
        raise ValueError('Degenerate cameras')
    x, z = (ap * cc - bp * bb) / divisor, (bp * aa - ap * bb) / divisor
    error = math.sqrt(mean((px - c * x - s * z) ** 2 for (c, s), px in m))
    depths = [(-ANGLES[i][1] * x + ANGLES[i][0] * z, p[1]) for i, p in points]
    return x, z, error, depths


def main():
    rows = [r for r in LEDGER['original_mul_group_candidates'] if r['body'] == 637]
    samples = {}
    observations = {}
    for row in rows:
        views = [TOOLS['read_direction'](DATA, row, direction) for direction in row['directions']]
        for frame, group in enumerate(zip_longest(*views)):
            points = [(index, image_points(value)) for index, value in enumerate(group) if value is not None]
            points = [(index, found) for index, found in points if found is not None]
            if len(points) >= 3:
                samples[row['group'], frame] = [fit_horizontal([(index, p[endpoint]) for index, p in points]) for endpoint in (0, 1)]
                observations[row['group'], frame] = points
    guards = [point[0] for point in samples.values()]
    centered = [(d - mean(x[0] for x in values), v - mean(x[1] for x in values))
                for _, _, error, values in guards if error < 2.5 for d, v in values]
    pitch = sum(d * v for d, v in centered) / sum(d * d for d, _ in centered)
    elevation_scale = math.sqrt(max(0.01, 1 - pitch * pitch))
    diagnostics = []
    for (slot, frame), endpoints in samples.items():
        pose = []
        for x, z, horizontal_error, values in endpoints:
            elevated = mean(v - pitch * d for d, v in values)
            error = math.sqrt(mean((v - pitch * d - elevated) ** 2 for d, v in values))
            pose.append({'point': [x, -elevated / elevation_scale, z], 'fit_px': [horizontal_error, error]})
        diagnostics.append({'slot': slot, 'frame': frame, 'hilt': pose[0], 'tip': pose[1]})
    expected = sum(r['directions'][0]['frames'] for r in rows)
    print(len(rows), 'groups;', len(samples), '/', expected, 'frames with at least three views;', 'pitch coefficient', round(pitch, 3))
    for point in ('hilt', 'tip'):
        errors = [math.hypot(*sample[point]['fit_px']) for sample in diagnostics]
        print(point, 'combined RMS residual median / p90 / worst', [round(v, 2) for v in [median(errors), quantiles(errors, n=10)[-1], max(errors)]])
    holdout = [[], []]
    for points in observations.values():
        if len(points) < 4:
            continue
        for index, observed in points:
            cosine, sine = ANGLES[index]
            for endpoint in (0, 1):
                training = [(view, point[endpoint]) for view, point in points if view != index]
                x, z, _, values = fit_horizontal(training)
                intercept = mean(v - pitch * d for d, v in values)
                projected = (cosine * x + sine * z, intercept + pitch * (-sine * x + cosine * z))
                holdout[endpoint].append(math.dist(projected, observed[endpoint]))
    for label, errors in zip(('hilt', 'tip'), holdout):
        print(label, 'holdout view errors', len(errors), 'median / p90 / worst',
              [round(v, 2) for v in [median(errors), quantiles(errors, n=10)[-1], max(errors)]])
    print('frame coverage by group', sorted(Counter(slot for slot, _ in samples).items()))
    output = TOOLS['OUTPUT'] / 'spectral-five-view-fit.json'
    output.write_text(json.dumps({'pitch_coefficient': pitch, 'samples': diagnostics}, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
