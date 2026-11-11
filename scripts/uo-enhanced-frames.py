# SPDX-License-Identifier: GPL-3.0-or-later
"""Decode locally extracted Enhanced AMOU v1 sprite frames into pose references."""

import argparse
from collections import Counter
from dataclasses import dataclass
from hashlib import sha256
import json
from pathlib import Path
from struct import Struct, pack
import zlib


HEADER = Struct("<4sIIIhhhhIIII")
FRAME = Struct("<HHhhhhI")
FRAME_EXTENT_LIMIT = 2048
FRAME_COUNT_LIMIT = 1500
PIXEL_LIMIT = 16 * 1024 * 1024


@dataclass(frozen=True)
class Frame:
    group: int
    ordinal: int
    box: tuple[int, int, int, int]
    rgba: bytes

    @property
    def size(self):
        left, top, right, bottom = self.box
        return right - left, bottom - top


def decode_pixels(source, area, coverage):
    # Byte opcodes below 128 skip transparent pixels. A drawing opcode
    # carries the opaque count and a second byte carries two edge coverages.
    rgba = bytearray(area * 4)
    pos = 0
    pixel = 0
    while pos < len(source):
        opcode = source[pos]
        pos += 1
        if pixel == area:
            raise ValueError("bytes after final pixel")
        if opcode < 128:
            pixel += opcode
            if pixel > area:
                raise ValueError("transparent run exceeds frame")
            continue
        if pos == len(source):
            raise ValueError("missing edge coverage")
        edges = source[pos]
        pos += 1
        levels = ([edges >> 4] if edges >> 4 else [])
        levels.extend([16] * (opcode & 127))
        if edges & 15:
            levels.append(edges & 15)
        stop = pos + len(levels)
        if stop > len(source) or pixel + len(levels) > area:
            raise ValueError("truncated colour run or run exceeds frame")
        first = pixel * 4
        try:
            rgba[first:first + 4 * len(levels)] = b"".join(
                coverage[level - 1][index] for index, level in zip(source[pos:stop], levels)
            )
        except IndexError as error:
            raise ValueError("colour index outside palette") from error
        pixel += len(levels)
        pos = stop
    if pixel != area:
        raise ValueError("pixel stream ends before declared extent")
    return bytes(rgba)


def read_amou(data, *, directions=5):
    if len(data) < HEADER.size:
        raise ValueError("truncated AMOU header")
    magic, version, length, body, *tail = HEADER.unpack_from(data)
    left, top, right, bottom, colours, palette_at, count, table_at = tail
    if (magic, version, length) != (b"AMOU", 1, len(data)):
        raise ValueError("expected length-checked AMOU v1")
    if not (0 < colours <= 256 and HEADER.size <= palette_at
            and palette_at + 4 * colours <= table_at
            and 0 < count <= FRAME_COUNT_LIMIT and directions in (1, 5) and count % directions == 0):
        raise ValueError("invalid palette or five-direction frame table")
    table_end = table_at + FRAME.size * count
    if not table_end < len(data):
        raise ValueError("truncated frame table")
    palette = [tuple(data[start:start + 3])
               for start in range(palette_at, palette_at + 4 * colours, 4)]
    coverage = [tuple(bytes((*colour, level * 255 // 16)) for colour in palette)
                for level in range(1, 17)]
    rows = []
    pixels = 0
    for index in range(count):
        table_pos = table_at + FRAME.size * index
        group, ordinal, x0, y0, x1, y1, offset = FRAME.unpack_from(data, table_pos)
        if not (ordinal > (rows[-1][1] if rows else 0) and group == (rows[0][0] if rows else group)
                and left <= x0 < x1 <= right and top <= y0 < y1 <= bottom
                and max(x1 - x0, y1 - y0) <= FRAME_EXTENT_LIMIT):
            raise ValueError(f"invalid registration at frame {index + 1}")
        rows.append((group, ordinal, (x0, y0, x1, y1), table_pos + offset))
        pixels += (x1 - x0) * (y1 - y0)
        if pixels > PIXEL_LIMIT:
            raise ValueError("decoded group exceeds pixel limit")
    per_direction = count // directions
    stride = rows[per_direction][1] - rows[0][1] if directions > 1 else rows[-1][1]
    ordinals = [row[1] for row in rows[:per_direction]]
    if not (ordinals[-1] <= stride and all(
            rows[index][1] == stride * (index // per_direction) + ordinals[index % per_direction]
            for index in range(count))):
        raise ValueError("source ordinals do not repeat across five directions")
    offsets = [row[3] for row in rows] + [len(data)]
    if offsets[0] != table_end or not all(a < b for a, b in zip(offsets, offsets[1:])):
        raise ValueError("invalid or unordered pixel ranges")
    frames = []
    for (group, ordinal, box, offset), end in zip(rows, offsets[1:]):
        x0, y0, x1, y1 = box
        rgba = decode_pixels(memoryview(data)[offset:end], (x1 - x0) * (y1 - y0), coverage)
        frames.append(Frame(group, ordinal, box, rgba))
    return body, frames


def png(path, width, height, rgba):
    def chunk(kind, data):
        return pack(">I", len(data)) + kind + data + pack(">I", zlib.crc32(kind + data))

    stride = width * 4
    lines = b"".join(b"\0" + rgba[start:start + stride] for start in range(0, len(rgba), stride))
    header = pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
                     + chunk(b"IDAT", zlib.compress(lines)) + chunk(b"IEND", b""))


def sheet(frames, path, directions, max_columns):
    per_direction = len(frames) // 5
    count = min(per_direction, max_columns)
    indices = [0] if count == 1 else [round(i * (per_direction - 1) / (count - 1)) for i in range(count)]
    left = min(frame.box[0] for frame in frames) - 6
    top = min(frame.box[1] for frame in frames) - 6
    right = max(frame.box[2] for frame in frames) + 6
    bottom = max(frame.box[3] for frame in frames) + 6
    cell_width, cell_height = right - left, bottom - top
    width, height = cell_width * count, cell_height * len(directions)
    if width * height > PIXEL_LIMIT:
        raise ValueError("contact sheet exceeds pixel limit")
    rgba = bytearray(width * height * 4)
    for row, direction in enumerate(directions):
        for column, i in enumerate(indices):
            frame = frames[direction * per_direction + i]
            x0, y0, _, _ = frame.box
            fw, fh = frame.size
            for y in range(cell_height):
                background = (45, 53, 63, 255) if y != -top else (82, 87, 91, 255)
                start = ((row * cell_height + y) * width + column * cell_width) * 4
                rgba[start:start + 4 * cell_width] = bytes(background) * cell_width
            for y in range(fh):
                start = ((row * cell_height + y0 - top + y) * width + column * cell_width + x0 - left) * 4
                src = frame.rgba[y * fw * 4:(y + 1) * fw * 4]
                for x in range(0, len(src), 4):
                    alpha = src[x + 3]
                    if alpha:
                        rgba[start + x:start + x + 3] = bytes(
                            (src[x + channel] * alpha + rgba[start + x + channel] * (255 - alpha)) // 255
                            for channel in range(3)
                        )
    png(path, width, height, rgba)
    return indices


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sheets", type=int, nargs="*", default=[])
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for path in sorted(args.input.glob("ec-frame-*.bin")):
        data = path.read_bytes()
        body, frames = read_amou(data)
        group = frames[0].group
        if path.name != f"ec-frame-{body}-{group}.bin":
            raise ValueError(f"{path.name} does not match its body and group")
        count = Counter()
        decoded_hash = sha256()
        for frame in frames:
            count.update(frame.rgba[3::4])
            decoded_hash.update(frame.rgba)
        row = {
            "body": body, "group": group, "input_sha256": sha256(data).hexdigest(),
            "rgba_sha256": decoded_hash.hexdigest(), "frames": len(frames),
            "frames_per_direction": len(frames) // 5,
            "pixel_counts": dict(sorted(count.items())),
        }
        if body in args.sheets:
            row["sheet_indices"] = sheet(frames, args.output / f"{body}-{group}.png", range(5), 12)
        results.append(row)
    if not results:
        raise ValueError("no AMOU input payloads")
    (args.output / "decoded-frames.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"AMOU: {len(results)} files, {sum(row['frames'] for row in results)} complete frames, "
          f"{len({row['body'] for row in results})} bodies")


if __name__ == "__main__":
    main()
