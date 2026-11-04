"""Triangulate the hood landmarks where the source hands stay below the hood."""

import json
from pathlib import Path
import math
import runpy
from statistics import mean

M = runpy.run_path(str(Path(__file__).with_name('compare-ghost-silhouettes.py')))
REVIEW, T = M['REVIEW'], M['T']


def fit(mask_views, camera):
    measurements = []
    for index, mask in enumerate(mask_views):
        left, top, right, bottom = mask.getbbox()
        crest = [(x + 0.5, y + 0.5) for y in range(top, min(top + 5, bottom)) for x in range(left, right)
                 if mask.getpixel((x, y))]
        offset = camera['offsets'][index]
        width, height = [mean(values) for values in zip(*crest)]
        screen = [(value - centre - shift) / camera['scale']
                  for value, centre, shift in zip((width, height), M['ORIGIN'], offset)]
        angle = camera['yaw'] + index * camera['sense'] * math.pi / 4
        measurements.append((math.cos(angle), math.sin(angle), *screen))
    xx = sum(c * c for c, _, _, _ in measurements)
    zz = sum(s * s for _, s, _, _ in measurements)
    xz = -sum(c * s for c, s, _, _ in measurements)
    xp = sum(c * x for c, _, x, _ in measurements)
    zp = -sum(s * x for _, s, x, _ in measurements)
    determinant = xx * zz - xz * xz
    x = (xp * zz - zp * xz) / determinant
    z = (zp * xx - xp * xz) / determinant
    pitch = camera['pitch']
    rise = math.sqrt(1 - pitch * pitch)
    y = mean((pitch * (s * x + c * z) - height) / rise for c, s, _, height in measurements)
    return [x, y, z]


def main():
    camera = T['read'](REVIEW / 'restless-soul-silhouette-comparison.json')['camera']
    masks = M['source_masks']()
    curves = {str(slot): [fit(frame, camera) for frame in masks[slot]] for slot in (16, 32)}
    for slot, points in curves.items():
        print(slot, [[round(v, 3) for v in point] for point in points])
    (REVIEW / 'ghost-hood-fit.json').write_text(json.dumps(curves, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
