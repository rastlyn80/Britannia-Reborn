"""Fit bounded common 3D displacement and yaw to the five stored views."""

from functools import lru_cache
import json
from pathlib import Path
import math
import runpy
from statistics import mean

from PIL import ImageChops

R = runpy.run_path(str(Path(__file__).with_name('review-ghost-on-foot.py')))
M, T, REVIEW = (R[key] for key in ('M', 'T', 'REVIEW'))


def fit_frame(points, reference, camera, previous, lift_limit=3):
    yaw, sense, scale, pitch = (camera[key] for key in ('yaw', 'sense', 'scale', 'pitch'))
    angles = [yaw + i * sense * math.pi / 4 for i in range(5)]
    matrix = [(math.cos(angle), math.sin(angle)) for angle in angles]
    rise = math.sqrt(1 - pitch * pitch)
    targets = [M['bits'](view) for view in reference]

    @lru_cache(maxsize=None)
    def pose_at(turn):
        radians = math.radians(5 * turn)
        c, s = math.cos(radians), math.sin(radians)
        shape = [(c * x + s * z, y, -s * x + c * z) for x, y, z in points]
        return tuple(M['silhouette'](shape, i, scale, pitch, yaw, sense, camera['offsets'][i])
                     for i in range(5))

    @lru_cache(maxsize=None)
    def projected(turn, view, dx, dy):
        return M['bits'](ImageChops.offset(pose_at(turn)[view], dx, dy))

    @lru_cache(maxsize=None)
    def overlap(x, z, lift, turn):
        return mean(M['compare'](target, projected(turn, i, round(c * x - s * z),
                    round(pitch * (s * x + c * z) - rise * lift)))
                    for i, ((c, s), target) in enumerate(zip(matrix, targets)))

    def objective(params):
        x, z, lift, turn = params
        return overlap(*params) - 0.0015 * (abs(x) + abs(z) + 2 * lift + abs(turn)) - 0.0018 * sum(
            abs(a - b) for a, b in zip(params, previous))

    limits = ((-14, 14), (-14, 14), (0, lift_limit), (-6, 6))
    zero = (0, 0, 0, 0)
    params = max((previous, zero), key=objective)
    for step in (4, 2, 1):
        for _ in range(3):
            candidates = [params]
            for axis, (low, high) in enumerate(limits):
                for sign in (-1, 1):
                    changed = params[axis] + sign * step
                    if low <= changed <= high:
                        candidates.append(params[:axis] + (changed,) + params[axis + 1:])
            best = max(candidates, key=objective)
            if best == params:
                break
            params = best
    return params, overlap(*zero), overlap(*params)


def main():
    camera = T['read'](REVIEW / 'restless-soul-silhouette-comparison.json')['camera']
    poses = T['read'](REVIEW / 'ghost-on-foot-poses.json')['poses']
    source = M['source_masks']()
    result = {}
    for slot, (label, _) in R['CLIPS'].items():
        previous = (0, 0, 0, 0)
        fitted, before, after = [], [], []
        frames = source[slot]
        for i, frame in enumerate(frames):
            points = poses[label][round(24 * i / max(1, len(frames) - 1))]
            previous, initial, final = fit_frame(points, frame, camera, previous)
            x, z, y, turn = previous
            scale = camera['scale']
            fitted.append([x / scale, y / scale, z / scale, math.radians(5 * turn)])
            before.append(initial)
            after.append(final)
        result[str(slot)] = dict(clip=label, transforms=fitted, original_overlap=mean(before),
                                 fitted_overlap=mean(after))
        print(slot, label, round(mean(before), 3), round(mean(after), 3), flush=True)
    path = REVIEW / 'ghost-registration-fit.json'
    path.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
