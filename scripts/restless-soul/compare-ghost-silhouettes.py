"""Compare local 3D donor skin poses with the registered Classic ghost sprites."""

from itertools import product
import json
import math
from pathlib import Path
import runpy
from statistics import mean
import sys

from PIL import Image, ImageChops, ImageDraw

M = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'fit-spectral-landmarks.py'))
T = M['TOOLS']
REVIEW = T['OUTPUT']
LIBRARY = '--library' in sys.argv
SKIN = T['read'](REVIEW / 'ghost-library-poses.json')
FACES = list(zip(*[iter(SKIN['indices'])] * 3))
SIZE = (170, 164)
ORIGIN = (85, 124)


def source_masks():
    result = {}
    for row in M['LEDGER']['original_mul_group_candidates']:
        if row['body'] != 970:
            continue
        sequences = []
        for direction in row['directions']:
            samples = []
            for frame, cx, cy in T['read_direction'](M['DATA'], row, direction):
                mask = Image.new('L', SIZE)
                mask.paste(frame.getchannel('A'), (ORIGIN[0] - cx, ORIGIN[1] - frame.height - cy))
                samples.append(mask)
            sequences.append(samples)
        result[row['group']] = list(zip(*sequences, strict=True))
    return result


def midpoint(bounds):
    left, top, right, bottom = bounds
    return (left + right) / 2, (top + bottom) / 2


def compare(a, b):
    union = (a | b).bit_count()
    return (a & b).bit_count() / union if union else 0.0


def bits(mask):
    return int.from_bytes(mask.convert('1').tobytes(), 'little')


def silhouette(pose, direction, scale, pitch, yaw, sense, offset=(0, 0)):
    angle = yaw + direction * sense * math.pi / 4
    c, s = math.cos(angle), math.sin(angle)
    rise = math.sqrt(1 - pitch * pitch)
    ox, oy = ORIGIN[0] + offset[0], ORIGIN[1] + offset[1]
    projected = [(ox + scale * (x * c - z * s), oy + scale * (-y * rise + (x * s + z * c) * pitch))
                 for x, y, z in pose]
    image = Image.new('L', SIZE)
    draw = ImageDraw.Draw(image)
    for a, b, c in FACES:
        draw.polygon([projected[a], projected[b], projected[c]], fill=255)
    return image


def calibrate(poses, source):
    targets = [midpoint(mask.getbbox()) for mask in source]
    best = (-1.0, None)
    for frame, scale, pitch, yaw, sense in product(
            range(0, 25, 8), range(33, 42, 2), (0.35, 0.446, 0.54),
            (index * math.pi / 8 for index in range(16)), (-1, 1)):
        values, offsets = [], []
        for direction in range(5):
            predicted = silhouette(poses[frame], direction, scale, pitch, yaw, sense)
            centre = midpoint(predicted.getbbox())
            offset = tuple(round(a - b) for a, b in zip(targets[direction], centre))
            offsets.append(offset)
            values.append(compare(bits(source[direction]), bits(ImageChops.offset(predicted, *offset))))
        # Avoid independent camera shifts that absorb a pose or handedness error.
        score = mean(values) - 0.002 * mean(abs(a) + abs(b) for a, b in offsets)
        if score > best[0]:
            best = score, dict(frame=frame, scale=scale, pitch=pitch, yaw=yaw, sense=sense, offsets=offsets,
                               iou=mean(values))
    return best[1]


def motion_path(source, predicted):
    """Match the ordered original frames while limiting skipped donor poses."""
    scores = [[mean(compare(a, b) for a, b in zip(frame, phase)) for phase in predicted]
              for frame in source]
    count = len(scores[0])
    values = scores[0][:]
    histories = [[phase] for phase in range(count)]
    max_step = max(4, math.ceil(count * 1.7 / len(scores)))
    for index, frame in enumerate(scores[1:], 1):
        source_change = [a ^ b for a, b in zip(source[index - 1], source[index])]
        updated, paths = [], []
        for phase, overlap in enumerate(frame):
            best = (-1.0, -1)
            for prior in range(max(0, phase - max_step), phase + 1):
                change = [a ^ b for a, b in zip(predicted[prior], predicted[phase])]
                motion = mean(compare(a, b) for a, b in zip(source_change, change))
                score = values[prior] + 0.72 * overlap + 0.28 * motion
                if score > best[0]:
                    best = score, prior
            score, start = best
            updated.append(score)
            paths.append(histories[start] + [phase])
        values, histories = updated, paths
    end = max(range(count), key=values.__getitem__)
    indices = histories[end]
    return values[end] / len(source), mean(scores[frame][phase] for frame, phase in enumerate(indices)), indices


def main():
    source = source_masks()
    baseline = REVIEW / 'restless-soul-silhouette-comparison.json'
    settings = T['read'](baseline)['camera'] if LIBRARY else calibrate(SKIN['poses']['Idle'], source[4][0])
    print('Ghost camera', settings, flush=True)
    source = {slot: [[bits(view) for view in frame] for frame in frames] for slot, frames in source.items()}
    matches = {}
    for clip, poses in SKIN['poses'].items():
        predicted = [
            [bits(silhouette(pose, view, settings['scale'], settings['pitch'], settings['yaw'],
                             settings['sense'], settings['offsets'][view])) for view in range(5)]
            for pose in poses]
        for slot, frames in source.items():
            score, overlap, path = motion_path(frames, predicted)
            reversed_score, reversed_overlap, reversed_path = motion_path(frames, list(reversed(predicted)))
            if reversed_score > score:
                score, overlap, path = reversed_score, reversed_overlap, [len(poses) - phase - 1 for phase in reversed_path]
            matches.setdefault(slot, []).append(dict(clip=clip, score=score, iou=overlap, phase=path))
    for slot in matches:
        matches[slot].sort(key=lambda row: row['score'], reverse=True)
        print(slot, [(row['clip'], round(row['iou'], 3), row['phase']) for row in matches[slot][:3]], flush=True)
    report = REVIEW / 'restless-soul-donor-motion-comparison.json' if LIBRARY else baseline
    report.write_text(json.dumps(dict(camera=settings, matches=matches), indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
