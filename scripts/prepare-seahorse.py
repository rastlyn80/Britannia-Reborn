# SPDX-License-Identifier: GPL-3.0-or-later
"""Build a local rigged seahorse study using the recovered Third Dawn colour atlas."""

import argparse
from base64 import b64encode
from hashlib import sha256
import json
from math import cos, hypot, radians, sin, tau
from pathlib import Path
from struct import pack

from PIL import Image, ImageEnhance, ImageFilter


ATLAS_SHA256 = "67a3fbf5dcd5e5479a67720c0e8d371fbb4f49688a965e8b47c9ef5e0898c68b"
# Height, fore/aft position, half width, side radius, texture centre and side radius.
BODY = (
    (1.90, .87, .009, .013, 120, 71, 2), (1.93, .77, .070, .063, 113, 68, 5),
    (2.02, .57, .080, .064, 104, 55, 5), (2.15, .38, .125, .093, 94, 42, 7),
    (2.27, .22, .184, .160, 80, 29, 13), (2.25, -.02, .175, .185, 70, 26, 15),
    (2.04, -.15, .160, .205, 67, 40, 17), (1.79, -.23, .200, .261, 69, 58, 20),
    (1.55, -.15, .254, .314, 73, 76, 22), (1.30, -.07, .307, .327, 82, 94, 20),
    (1.07, -.05, .278, .255, 84, 108, 18), (.89, -.08, .185, .191, 85, 117, 14),
    (.78, -.11, .112, .103, 86, 123, 8), (.75, -.13, .012, .015, 86, 125, 3),
)
TAIL = (
    (.86, -.14, .124, .119, 16, 12, 8), (.71, -.23, .115, .104, 11, 25, 8),
    (.53, -.37, .098, .092, 10, 40, 6), (.34, -.50, .084, .079, 13, 52, 6),
    (.16, -.54, .071, .065, 20, 65, 5), (.08, -.40, .060, .055, 26, 77, 5),
    (.07, -.21, .052, .048, 31, 90, 4), (.16, -.06, .044, .041, 33, 101, 4),
    (.28, -.09, .038, .034, 29, 111, 4), (.32, -.21, .026, .025, 20, 115, 4),
    (.25, -.27, .018, .019, 13, 109, 3), (.20, -.22, .008, .011, 16, 102, 2),
)
DORSAL_FIN = (
    (.97, -.21, .006, .015, 44, 80, 2), (1.08, -.29, .013, .096, 46, 73, 5),
    (1.23, -.35, .015, .162, 48, 66, 7), (1.39, -.39, .012, .149, 48, 59, 6),
    (1.54, -.38, .008, .071, 50, 53, 4), (1.64, -.37, .003, .006, 51, 49, 2),
)
CROWN_SPINES = (
    ((2.22, -.05, .068, .068, 66, 29, 6), (2.33, -.10, .041, .044, 64, 23, 4),
     (2.43, -.17, .004, .006, 61, 19, 2)),
    ((2.30, .10, .074, .077, 74, 26, 7), (2.40, .08, .043, .040, 73, 18, 5),
     (2.49, .05, .004, .006, 70, 15, 2)),
    ((2.27, .26, .061, .069, 80, 27, 6), (2.35, .27, .031, .035, 79, 20, 4),
     (2.42, .28, .004, .006, 77, 17, 2)),
)
JOINTS = (
    ("root", -1, (0., 0., 0.)), ("barrel", 0, (0., 1.22, -.12)),
    ("neck", 1, (0., 1.76, -.23)), ("head", 2, (0., 2.15, .18)),
    *((f"tail_{i + 1}", 1 if i == 0 else i + 3, (0., TAIL[index][0], TAIL[index][1]))
      for i, index in enumerate((0, 2, 4, 6, 8, 10))),
    ("saddle_socket", 1, (0., 1.49, -.38)), ("mouth_socket", 3, (0., 1.92, .79)),
    ("dorsal_fin", 1, (0., 1.27, -.27)),
)
SIDES = 20


def curve(points):
    for index in range(len(points) - 1):
        a, b, c, d = (points[max(0, index - 1)], points[index], points[index + 1], points[min(index + 2, len(points) - 1)])
        for step in range(4):
            t = step / 4
            yield tuple(.5 * (2 * p + (-o + q) * t + (2 * o - 5 * p + 4 * q - r) * t**2
                        + (-o + 3 * p - 3 * q + r) * t**3) for o, p, q, r in zip(a, b, c, d))
    yield points[-1]


class Geometry:
    def __init__(self):
        self.positions, self.normals, self.uv, self.joints, self.weights, self.indices = [], [], [], [], [], []

    def sweep(self, points, bind, sides=SIDES):
        base = len(self.positions)
        rings = list(curve(points))
        for index, (y, z, wide, deep, u, v, texture_radius) in enumerate(rings):
            before, after = rings[max(0, index - 1)], rings[min(index + 1, len(rings) - 1)]
            dy, dz = after[0] - before[0], after[1] - before[1]
            dv, du = after[5] - before[5], after[4] - before[4]
            length, texture_length = hypot(dy, dz), hypot(dv, du)
            ny, nz = -dz / length, dy / length
            nu, nv = dv / texture_length, -du / texture_length
            first, second, blend = bind(index / (len(rings) - 1))
            for j in range(sides):
                angle = j * tau / sides
                side, edge = cos(angle), sin(angle)
                normal = (side / wide, ny * edge / deep, nz * edge / deep)
                norm = hypot(*normal)
                self.positions.append((wide * side, y + ny * deep * edge, z + nz * deep * edge))
                self.normals.append(tuple(component / norm for component in normal))
                self.uv.append((min(127., max(0., u + nu * texture_radius * edge)) / 127.,
                                min(127., max(0., v + nv * texture_radius * edge)) / 127.))
                self.joints.append((first, second, 0, 0))
                self.weights.append((1 - blend, blend, 0, 0))
        for ring in range(len(rings) - 1):
            for j in range(sides):
                a = base + ring * sides + j
                b = base + ring * sides + (j + 1) % sides
                self.indices.extend((a, a + sides, b, b, a + sides, b + sides))
        for i, reverse in ((base, True), (base + (len(rings) - 1) * sides, False)):
            for j in range(1, sides - 1):
                self.indices.extend((i, i + j + 1, i + j) if reverse else (i, i + j, i + j + 1))


def body_bind(phase):
    if phase < .46:
        return 3, 2, min(1., max(0., (phase - .24) / .22))
    return 2, 1, min(1., max(0., (phase - .46) / .29))


def tail_bind(phase):
    chain = min(5., phase * 5.5)
    index = min(4, int(chain))
    return 4 + index, 5 + index, chain - index


class GltfBuffer:
    def __init__(self):
        self.data = bytearray()
        self.views = []
        self.accessors = []

    def add(self, rows, layout, kind, component=5126, bounds=False):
        self.data.extend(b"\0" * (-len(self.data) % 4))
        start = len(self.data)
        for row in rows:
            self.data.extend(pack("<" + layout, *row))
        view = len(self.views)
        self.views.append({"buffer": 0, "byteOffset": start, "byteLength": len(self.data) - start})
        accessor = {"bufferView": view, "componentType": component, "count": len(rows), "type": kind}
        if bounds:
            accessor["min"] = [min(column) for column in zip(*rows)]
            accessor["max"] = [max(column) for column in zip(*rows)]
        self.accessors.append(accessor)
        return len(self.accessors) - 1


def inverse_translation(x, y, z):
    return (1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1)


def rotation(pitch=0., yaw=0., roll=0.):
    x, y, z = (radians(angle) / 2 for angle in (pitch, yaw, roll))
    cx, cy, cz = (cos(angle) for angle in (x, y, z))
    sx, sy, sz = (sin(angle) for angle in (x, y, z))
    return (sx * cy * cz - cx * sy * sz, cx * sy * cz + sx * cy * sz,
            cx * cy * sz - sx * sy * cz, cx * cy * cz + sx * sy * sz)


def animation(buffer, name, duration, sample):
    frames = max(12, round(duration * 24))
    poses = [sample(index / frames) for index in range(frames + 1)]
    seconds = buffer.add([(index * duration / frames,) for index in range(frames + 1)],
                         "f", "SCALAR", bounds=True)
    samplers, channels = [], []
    for joint, path in poses[0]:
        values = [pose[joint, path] for pose in poses]
        target = buffer.add(values, "4f", "VEC4") if path == "rotation" else buffer.add(values, "3f", "VEC3")
        channels.append({"sampler": len(samplers), "target": {"node": joint + 1, "path": path}})
        samplers.append({"input": seconds, "output": target, "interpolation": "LINEAR"})
    return {"name": name, "samplers": samplers, "channels": channels}


def gait(phase, pitch, extension, stroke, lift, guard=0.):
    angle = tau * phase
    pose = {
        (0, "translation"): (0., lift + .038 * sin(angle) * (stroke / 18), 0.),
        (0, "rotation"): rotation(),
        (1, "rotation"): rotation(pitch + .20 * stroke * sin(angle - .30), 0., stroke * .09 * sin(angle)),
        (2, "rotation"): rotation(-pitch * .52 + guard - .10 * stroke * sin(angle - .52)),
        (3, "rotation"): rotation(-guard * .65 + .12 * stroke * sin(angle - .92)),
        (12, "rotation"): rotation(yaw=stroke * .65 * sin(2 * angle - .1)),
    }
    for segment in range(6):
        wave = sin(angle - .56 * segment)
        pose[4 + segment, "rotation"] = rotation(
            extension * (.35 + .13 * segment) + stroke * (.25 + .12 * segment) * wave,
            stroke * .36 * sin(angle - .72 * segment))
    return pose


def authored_keys(keys, phase):
    for (start, first), (end, last) in zip(keys, keys[1:]):
        if phase <= end:
            amount = (phase - start) / (end - start)
            amount = amount * amount * (3 - 2 * amount)
            return tuple(a + (b - a) * amount for a, b in zip(first, last))
    return keys[-1][1]


def turn_root(pose, pitch, yaw, roll, elevation):
    x, y, z, w = root = rotation(pitch, yaw, roll)
    pivot = 1.15
    pose[0, "rotation"] = root
    pose[0, "translation"] = (-pivot * 2 * (x * y - z * w),
                              pivot * 2 * (x * x + z * z) + elevation,
                              -pivot * 2 * (y * z + x * w))


def fall(phase, direction):
    # Both references turn head-down. The combat variant crosses the
    # silhouette earlier and presents the opposite flank at the endpoint.
    keys = (
        (0., (0., 0., 0., 0., 0.)),
        (.22, (-28. * direction, 36. * direction, -14., 17., .18)),
        (.52, (-112. * direction, 53. * direction, 14., 24., -.08)),
        (.78, (-158. * direction, 21. * direction, 9., 11., -.22)),
        (1., (-170. * direction, 8. * direction, 5., 8., -.24)),
    )
    time = min(phase * (1.15 if direction == 1 else 1.0), 1.)
    roll, yaw, pitch, extension, drop = authored_keys(keys, time)
    pose = gait(0., 0., extension, 0., 0.)
    turn_root(pose, pitch, yaw, roll, drop)
    pose[1, "rotation"] = rotation(7. * sin(phase * tau))
    pose[2, "rotation"] = rotation(-16. * sin(phase * tau / 2))
    pose[3, "rotation"] = rotation(13. * sin(phase * tau / 2))
    return pose


# Phase, pitch of the full body, yaw, roll, neck pitch, head pitch,
# tail extension, and vertical excursion. Pose timing follows the AMOU rows.
NEUTRAL = (0., 0., 0., 0., 0., 0., 0.)
ACTIONS = (
    (4, "RearingStrike", .92, (
        (0., NEUTRAL), (.23, (-43., 14., -8., -13., 8., 20., .13)),
        (.5, (-29., 10., -6., -22., 17., 27., .18)),
        (.75, (32., 1., 5., 12., 11., 12., -.03)), (1., NEUTRAL),
    )),
    (5, "DivingStrike", .88, (
        (0., NEUTRAL), (.22, (-16., -4., 0., -10., 0., 9., .04)),
        (.50, (53., -8., 9., 25., 12., -15., -.15)),
        (.76, (13., -3., -6., 9., -8., -7., .02)), (1., NEUTRAL),
    )),
    (10, "Recoil", .64, (
        (0., (5., 0., 0., 4., 0., 5., 0.)), (.30, (-57., 18., -6., -13., -12., 18., .13)),
        (.58, (-43., 10., -4., -10., 6., 10., .09)), (1., NEUTRAL),
    )),
    (11, "ForwardRush", .78, (
        (0., (27., 0., 0., 8., 3., 10., .06)), (.24, (67., 0., 0., 13., 3., 32., .09)),
        (.5, (74., 0., 0., 2., 5., 36., .11)), (.76, (43., 0., 0., -3., 0., 23., .08)),
        (1., NEUTRAL),
    )),
    (12, "Cast", .97, (
        (0., NEUTRAL), (.22, (-31., 12., -6., -17., -12., 3., .05)),
        (.50, (-40., 15., -9., -23., 7., 25., .23)),
        (.76, (42., 4., 6., 17., 5., 5., .07)), (1., NEUTRAL),
    )),
    (15, "TailCurl", .69, (
        (0., (8., 2., 0., 10., 4., -5., 0.)), (.28, (31., 21., 24., 23., 9., -19., -.22)),
        (.54, (26., 19., 14., 17., 11., -13., -.16)), (.78, (13., 9., 6., 8., 8., -5., -.06)),
        (1., NEUTRAL),
    )),
    (23, "Uncoil", 1.10, (
        (0., (76., -14., 50., 26., 16., -22., -.60)), (.24, (64., -8., 33., 17., 11., -15., -.49)),
        (.5, (42., -5., 15., 13., 6., 8., -.17)), (.76, (-10., -1., 4., -12., -4., 17., .10)),
        (1., NEUTRAL),
    )),
    (26, "Look", .94, (
        (0., NEUTRAL), (.28, (3., 17., 2., -5., -7., 5., .02)),
        (.60, (-4., -13., -2., -8., 7., -3., .02)), (1., NEUTRAL),
    )),
    (27, "LongReach", 1.15, (
        (0., NEUTRAL), (.22, (9., -5., 0., 10., -3., 4., .01)),
        (.5, (39., -3., 5., 28., 8., -7., .02)), (.76, (12., 0., 0., 8., 1., -2., .02)),
        (1., NEUTRAL),
    )),
    (28, "Alert", .59, (
        (0., NEUTRAL), (.26, (-9., 6., -3., -18., -5., 9., .06)),
        (.57, (-2., -3., 2., -8., -9., 5., .04)), (1., NEUTRAL),
    )),
)


def action(phase, keys):
    pitch, yaw, roll, neck, head, tail, lift = authored_keys(keys, phase)
    pose = gait(0., .22 * pitch, tail, 0., 0.)
    turn_root(pose, pitch, yaw, roll, lift)
    pose[2, "rotation"] = rotation(neck, .34 * yaw)
    pose[3, "rotation"] = rotation(head, .25 * yaw)
    pose[12, "rotation"] = rotation(yaw=6 * sin(phase * tau))
    return pose


def padded_atlas(atlas, destination):
    with Image.open(atlas) as source_image:
        image = source_image.convert("RGBA")
    if image.size != (128, 128):
        raise ValueError("The original Sea Horse colour atlas must be 128 by 128 pixels.")
    width, height = image.size
    source = image.load()
    opaque = [(x, y) for y in range(height) for x in range(width) if source[x, y][3] >= 128]
    colour = Image.new("RGB", image.size)
    pixels = colour.load()
    for y in range(height):
        for x in range(width):
            if source[x, y][3] < 128:
                p = min(opaque, key=lambda point: (point[0] - x)**2 + (point[1] - y)**2)
                pixels[x, y] = source[p][:3]
            else:
                pixels[x, y] = source[x, y][:3]
    ImageEnhance.Brightness(ImageEnhance.Color(colour).enhance(.83)).enhance(.90).save(destination)
    return colour


def scale_normals(source, destination):
    luminance = source.convert("L").resize((256, 256), Image.Resampling.BICUBIC)
    local = luminance.filter(ImageFilter.GaussianBlur(2))
    height = [sharp - soft for sharp, soft in zip(luminance.tobytes(), local.tobytes())]
    width, rows = luminance.size
    normals = []
    for y in range(rows):
        previous, following = max(0, y - 1) * width, min(rows - 1, y + 1) * width
        for x in range(width):
            row = y * width
            dx = (height[row + min(width - 1, x + 1)] - height[row + max(0, x - 1)]) * -.014
            dy = (height[following + x] - height[previous + x]) * .014
            length = hypot(dx, dy, 1.)
            normals.append(tuple(round(127.5 * (1 + value / length)) for value in (dx, dy, 1.)))
    image = Image.new("RGB", luminance.size)
    image.putdata(normals)
    image.save(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--atlas", type=Path, required=True,
                        help="Private, statically extracted sea_horse_sea_horse.tga")
    parser.add_argument("--output-dir", type=Path, required=True,
                        help="Private working directory for the generated scene and textures")
    args = parser.parse_args()
    atlas_hash = sha256(args.atlas.read_bytes()).hexdigest()
    if atlas_hash != ATLAS_SHA256:
        parser.error("The atlas does not match the verified Third Dawn member.")
    model = Geometry()
    model.sweep(BODY, body_bind)
    model.sweep(TAIL, tail_bind)
    model.sweep(DORSAL_FIN, lambda _phase: (12, 1, .24), sides=12)
    for spine in CROWN_SPINES:
        model.sweep(spine, lambda _phase: (3, 3, 0.), sides=10)
    buffer = GltfBuffer()
    attributes = {
        "POSITION": buffer.add(model.positions, "3f", "VEC3", bounds=True),
        "NORMAL": buffer.add(model.normals, "3f", "VEC3"),
        "TEXCOORD_0": buffer.add(model.uv, "2f", "VEC2"),
        "JOINTS_0": buffer.add(model.joints, "4H", "VEC4", 5123),
        "WEIGHTS_0": buffer.add(model.weights, "4f", "VEC4"),
    }
    indices = buffer.add([(value,) for value in model.indices], "H", "SCALAR", 5123)
    bind = buffer.add([inverse_translation(*position) for _, _, position in JOINTS], "16f", "MAT4")
    nodes = [{"name": "Seahorse", "mesh": 0, "skin": 0}]
    for name, parent, position in JOINTS:
        anchor = JOINTS[parent][2] if parent >= 0 else (0., 0., 0.)
        node = {"name": name, "translation": [v - p for v, p in zip(position, anchor)]}
        if parent >= 0:
            nodes[parent + 1].setdefault("children", []).append(len(nodes))
        nodes.append(node)
    target = args.output_dir
    target.mkdir(parents=True, exist_ok=True)
    colour = padded_atlas(args.atlas, target / "atlas.png")
    scale_normals(colour, target / "scales-normal.png")
    animations = []
    source_groups = {}
    for group, name, duration, style in (
        (25, "Idle", 2.8, (0., 0., 3., 0.)),
        (22, "Glide", 1.14, (7., 12., 11., .05)),
        (24, "Rush", .84, (16., 20., 19., .13)),
        (1, "CombatIdle", 2.2, (2., 4., 5., .03, -8.)),
        (0, "CombatGlide", 1.12, (12., 19., 13., .07, -9.)),
    ):
        animations.append(animation(buffer, name, duration, lambda phase: gait(phase, *style)))
        source_groups[name] = group
    animations.extend((
        animation(buffer, "DeathTurn", 1.10, lambda phase: fall(phase, 1)),
        animation(buffer, "DeathRoll", 1.0, lambda phase: fall(phase, -1)),
    ))
    source_groups.update(DeathTurn=2, DeathRoll=3)
    for group, name, duration, keys in ACTIONS:
        animations.append(animation(buffer, name, duration, lambda phase: action(phase, keys)))
        source_groups[name] = group
    asset = {"asset": {"version": "2.0", "generator": "Britannia Reborn seahorse study"}, "scene": 0,
             "scenes": [{"nodes": [0, 1]}], "nodes": nodes,
             "meshes": [{"primitives": [{"attributes": attributes, "indices": indices, "material": 0}]}],
             "skins": [{"joints": list(range(1, len(nodes))), "skeleton": 1, "inverseBindMatrices": bind}],
             "images": [{"uri": "atlas.png"}, {"uri": "scales-normal.png"}], "textures": [{"source": 0}, {"source": 1}],
             "materials": [{"name": "Private Third Dawn seahorse atlas", "normalTexture": {"index": 1, "scale": .42},
                            "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": .0,
                                                    "roughnessFactor": .68}}],
             "animations": animations, "bufferViews": buffer.views, "accessors": buffer.accessors,
             "buffers": [{"uri": "data:application/octet-stream;base64," + b64encode(buffer.data).decode(),
                          "byteLength": len(buffer.data)}]}
    path = target / "sea-horse.gltf"
    path.write_text(json.dumps(asset, separators=(",", ":")) + "\n", encoding="utf-8")
    receipt = {"mesh": sha256(path.read_bytes()).hexdigest(), "local_atlas": atlas_hash,
               "vertices": len(model.positions), "triangles": len(model.indices) // 3, "joints": len(JOINTS),
               "clips": [clip["name"] for clip in animations],
               "source_groups": source_groups,
               "scope": "Authored model and hand-fitted motions for the 17 official AMOU groups. Private recovered atlas. No published asset or native route."}
    (target / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(receipt)


if __name__ == "__main__":
    main()
