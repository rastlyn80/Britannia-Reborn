"""Reconstruct the floating halberd's axis and centre from five installed UOP views."""

import argparse
import hashlib
from itertools import product
import json
import math
from pathlib import Path
import runpy
from statistics import mean
import struct


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
OUT = ROOT / 'work/creatures/halberd-uop/fit.json'
PINS = SCRIPTS / 'halberd-uop-pins.json'
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha = COMMON['read'], COMMON['sha']
ANGLE = tuple(math.pi * direction / 4 for direction in range(5))
AXES = tuple((math.cos(angle), math.sin(angle)) for angle in ANGLE)
SHAFT_PIXELS = 71.6


def sprite_points(raw, start, end):
    assert start + 520 <= end
    palette = struct.unpack_from('<256H', raw, start)
    cx, cy, width, height = struct.unpack_from('<4h', raw, start + 512)
    assert 0 < width < 1024 and 0 < height < 1024
    cursor = start + 520
    pixels = {}
    while cursor + 4 <= end:
        header, = struct.unpack_from('<I', raw, cursor)
        cursor += 4
        if header == 0x7fff7fff:
            return [(index % width - cx, height + cy - index // width, color)
                    for index, color in sorted(pixels.items())]
        size = header & 0xfff
        x, y = (header >> 22) & 1023, (header >> 12) & 1023
        x -= 1024 if x & 512 else 0
        y -= 1024 if y & 512 else 0
        offset = (y + cy + height) * width + x + cx
        assert cursor + size <= end and 0 <= offset <= width * height - size
        for index, pixel in enumerate(raw[cursor:cursor + size], offset):
            color = palette[pixel]
            if color:
                pixels[index] = color
            else:
                pixels.pop(index, None)
        cursor += size
    raise ValueError('A UOP halberd frame has no bounded terminator')


def features(points):
    assert points
    mx, my = mean(x for x, _, _ in points), mean(y for _, y, _ in points)
    xx = sum((x - mx)**2 for x, _, _ in points)
    yy = sum((y - my)**2 for _, y, _ in points)
    xy = sum((x - mx) * (y - my) for x, y, _ in points)
    theta = math.atan2(2 * xy, xx - yy) / 2
    dx, dy = math.cos(theta), math.sin(theta)
    projection = [(x - mx) * dx + (y - my) * dy for x, y, _ in points]
    lo, hi = min(projection), max(projection)
    midpoint = (lo + hi) / 2
    warm = []
    for value, (_, _, color) in zip(projection, points):
        red, green, blue = [(color >> shift & 31) * 255 // 31 for shift in (10, 5, 0)]
        if red >= 57 and red > green * 1.45 and red > blue * 1.45:
            warm.append(value)
    assert warm, 'The source halberd blade colour marker must be visible'
    sign = 1 if mean(warm) > midpoint else -1
    return (sign * (hi - lo) * dx, sign * (hi - lo) * dy), (mx + midpoint * dx, my + midpoint * dy), len(warm)


def read_group(raw, group, pins):
    count, start = struct.unpack_from('<II', raw, 32)
    assert count == pins['frame_headers'] and count % 5 == 0 and 40 <= start <= len(raw) - count * 16
    offsets = []
    for frame, pos in enumerate(range(start, start + count * 16, 16), 1):
        stored_group, frame_id, _, pixel = struct.unpack_from('<HHQI', raw, pos)
        assert frame_id == frame and stored_group == group
        offsets.append(pos + pixel)
    ordered = sorted(set(offsets))
    assert start + count * 16 <= ordered[0] < ordered[-1] < len(raw)
    ends = dict(zip(ordered, ordered[1:] + [len(raw)]))
    decoded = [features(sprite_points(raw, offset, ends[offset])) for offset in offsets]
    stride = count // 5
    assert pins['decoded_visible_by_direction'] == [stride] * 5
    return list(zip(*(decoded[index:index + stride] for index in range(0, count, stride))))


def project_fit(values, elevation):
    x = sum(value[0] * co for value, (co, _) in zip(values, AXES)) / 3
    z = sum(value[0] * si for value, (_, si) in zip(values, AXES)) / 2
    depth = [-x * si + z * co for co, si in AXES]
    tilt = math.sin(elevation)
    vertical = mean(value[1] - tilt * dep for value, dep in zip(values, depth))
    squared_errors = [(value[0] - x * co - z * si)**2 + (value[1] - vertical - tilt * dep)**2
                      for value, (co, si), dep in zip(values, AXES, depth)]
    return [x, vertical / math.cos(elevation), z], squared_errors


def shaft_fit(samples, elevation):
    # Blade colours disambiguate the two ends. Small projected views can give
    # a weak marker, so compare signs across all five views of the rigid shaft.
    best = None
    for signs in product((1, -1), repeat=5):
        vectors = [(vec[0] * sign, vec[1] * sign) for (vec, _, _), sign in zip(samples, signs)]
        axis, errors = project_fit(vectors, elevation)
        length = math.sqrt(sum(value**2 for value in axis))
        appearance_penalty = sum(0.035 * confidence for (_, _, confidence), sign in zip(samples, signs) if sign < 0)
        score = mean(errors) + 0.25 * (length - 71.5)**2 + appearance_penalty
        if best is None or score < best[0]:
            best = score, [value / length for value in axis], length, errors
    return best


def checked_frames(data, pins):
    body = pins['body']
    assert body == 692 and pins['inputs'] == {name: sha(data / name) for name in pins['inputs']}
    reader = runpy.run_path(str(SCRIPTS / 'uo-human-sequences.py'))
    hashes = runpy.run_path(str(SCRIPTS / 'audit-classic-parity.py'))['name_hash']
    ledger = runpy.run_path(str(SCRIPTS / 'build-creature-actions.py'))
    _, _, flags = ledger['original_mul_groups'](data, {body})
    assert list(flags[body]) == pins['mobtypes'] == ['MONSTER', 0x10000]
    sequence, = reader['inspect'](data / 'AnimationSequence.uop', {body})
    fields = ('mode', 'fallback_mode', 'default_group', 'transitions')
    selected_types = {2, 5, 8, 11, 14, 15}
    modes = [{key: mode[key] for key in fields} | {'packet_groups': {
        str(row['type']): row['groups'] for row in mode['new_protocol_actions']
        if row['type'] in selected_types and row['subaction'] == -1}} for mode in sequence['modes']]
    assert modes == pins['modes']
    groups = {hashes(f'build/animationlegacyframe/{body:06d}/{int(group):02d}.bin'): int(group)
              for group in pins['frames']}
    observed = {}
    for archive in {item['archive'] for item in pins['frames'].values()}:
        for digest, raw in reader['payloads'](data / archive, groups):
            group = groups[digest]
            proof = pins['frames'][str(group)]
            assert proof['archive'] == archive and hashlib.sha256(raw).hexdigest() == proof['payload_sha256']
            observed[group] = read_group(raw, group, proof)
    assert set(observed) == set(groups.values())
    return observed


def reconstruct(observed):
    def error(degrees):
        return mean(squared for samples in observed.values() for views in samples
                    for squared in shaft_fit(views, math.radians(degrees))[3])

    degrees = min(range(18, 42), key=error)
    elevation = math.radians(degrees)
    groups = {}
    for group, frames in sorted(observed.items()):
        fits = [shaft_fit(views, elevation) for views in frames]
        lengths = [fit[2] for fit in fits]
        axis = [fit[1] for fit in fits]
        centers = [project_fit([view[1] for view in views], elevation)[0] for views in frames]
        rmse = math.sqrt(mean(squared for fit in fits for squared in fit[3]))
        assert min(lengths) > 70.0 and max(lengths) < 74.0 and rmse < 2.0
        groups[str(group)] = dict(lengths=lengths, axis=axis, centers=centers, pixel_rmse=rmse)
    return {'elevation_degrees': degrees, 'shaft_pixels': SHAFT_PIXELS, 'groups': groups}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = args.data_dir or Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    report = reconstruct(checked_frames(data, read(PINS)))
    if args.check:
        assert report == read(OUT)
    else:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        pending = OUT.with_suffix('.pending')
        pending.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        pending.replace(OUT)
    print(f'ANIMATED WEAPON: five UOP groups and five views with a {report["elevation_degrees"]} degree fit')


if __name__ == '__main__':
    main()
