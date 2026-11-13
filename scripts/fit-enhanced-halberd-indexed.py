# SPDX-License-Identifier: GPL-3.0-or-later
from argparse import ArgumentParser
from pathlib import Path
import hashlib
import json
import math
import runpy
from statistics import mean

parser = ArgumentParser(description="Fit the Animated Weapon shaft from the Enhanced five-direction frames.")
parser.add_argument("--frames", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--scripts", type=Path, default=Path(__file__).resolve().parent)
args = parser.parse_args()
pins = json.loads(Path(__file__).with_name("enhanced-indexed-variant-inputs.json").read_bytes())
entries = pins["frame_members"]
legacy = runpy.run_path(str(args.scripts / 'prepare-halberd-uop-fit.py'))
decode = runpy.run_path(str(args.scripts / 'uo-enhanced-frames.py'))['read_amou']
classic_features = legacy['features']
project = legacy['project_fit']
fit_axis = legacy['shaft_fit']


def features(frame):
    x0, y0, _, _ = frame.box
    width, _ = frame.size
    points = []
    for n, (red, green, blue, alpha) in enumerate(zip(*(frame.rgba[offset::4] for offset in range(4)))):
        if alpha >= 128:
            color = ((red >> 3) << 10) | ((green >> 3) << 5) | (blue >> 3)
            points.append((x0 + n % width, -y0 - n // width, color))
    return classic_features(points)


def views(row):
    raw = (args.frames / f'ec-frame-692-{row["group"]}.bin').read_bytes()
    assert hashlib.sha256(raw).hexdigest() == row['sha256']
    body, decoded = decode(raw)
    assert body == 692 and len(decoded) == row['frames'] and {frame.group for frame in decoded} == {row['group']}
    step = len(decoded) // 5
    by_direction = [[features(frame) for frame in decoded[start:start + step]] for start in range(0, len(decoded), step)]
    return list(zip(*by_direction))


rows = [row for row in entries if row['body'] == 692]
assert {row['group'] for row in rows} == {2, 4, 10, 23, 28}
motions = {row['group']: views(row) for row in rows}


def error(elevation):
    return mean(error for frames in motions.values() for frame in frames
                for error in fit_axis(frame, math.radians(elevation))[3])


elevation = min(range(15, 66), key=error)
result = {}
for group, frames in motions.items():
    fits = [fit_axis(views, math.radians(elevation)) for views in frames]
    centers = [project([view[1] for view in views], math.radians(elevation)) for views in frames]
    lengths = [sample[2] for sample in fits]
    axis_rms = math.sqrt(mean(error for fit in fits for error in fit[3]))
    center_rms = math.sqrt(mean(error for _, errors in centers for error in errors))
    print(f'Group {group:2}: {len(frames)} five-view poses; axis {axis_rms:.3f}px, center {center_rms:.3f}px RMS; lengths {min(lengths):.2f} to {max(lengths):.2f}px')
    result[str(group)] = {'axis': [fit[1] for fit in fits], 'centers': [center for center, _ in centers],
                          'pixel_rmse': axis_rms, 'center_rmse': center_rms, 'lengths': lengths}
print(f'Camera elevation {elevation} degrees')
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'elevation_degrees': elevation, 'groups': result, 'source': rows}, indent=2) + '\n')
