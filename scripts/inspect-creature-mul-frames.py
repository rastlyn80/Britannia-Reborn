"""Decode a direction of installed Classic MUL motion into private review sheets."""

import argparse
import hashlib
import json
from pathlib import Path
import struct

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / 'outputs/creatures/actions.json'
OUTPUT = ROOT / 'work/creatures/mul-motion-review'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def decode(raw, expected_frames):
    palette = struct.unpack_from('<256H', raw)
    count, = struct.unpack_from('<I', raw, 512)
    if count != expected_frames or not 0 < count <= (len(raw) - 516) // 4:
        raise ValueError('Frame table does not match the checked index')
    offsets = struct.unpack_from(f'<{count}I', raw, 516)
    frames = []
    for offset in offsets:
        cursor = 512 + offset
        if cursor < 516 + 4 * count or cursor + 12 > len(raw):
            raise ValueError('Frame header leaves its indexed record')
        cx, cy, width, height = struct.unpack_from('<4h', raw, cursor)
        if not 0 < width < 1024 or not 0 < height < 1024:
            raise ValueError('Invalid frame dimensions')
        cursor += 8
        frame = Image.new('RGBA', (width, height))
        pixels = frame.load()
        while cursor + 4 <= len(raw):
            header, = struct.unpack_from('<I', raw, cursor)
            cursor += 4
            if header == 0x7fff7fff:
                break
            size = header & 0xfff
            x, y = (header >> 22) & 1023, (header >> 12) & 1023
            x = x - 1024 if x & 512 else x
            y = y - 1024 if y & 512 else y
            x += cx
            y += cy + height
            if cursor + size > len(raw):
                raise ValueError('Pixel run leaves its indexed record')
            for delta, index in enumerate(raw[cursor:cursor + size]):
                if 0 <= x + delta < width and 0 <= y < height:
                    value = palette[index]
                    pixels[x + delta, y] = tuple(((value >> shift) & 31) * 255 // 31 for shift in (10, 5, 0)) + (255,)
            cursor += size
        else:
            raise ValueError('Frame has no end marker in its indexed record')
        frames.append((frame, cx, cy))
    return frames


def sheet(frames, label):
    x_min = min(-cx for _, cx, _ in frames)
    x_max = max(frame.width - cx for frame, cx, _ in frames)
    y_min = min(-frame.height - cy for frame, _, cy in frames)
    y_max = max(-cy for _, _, cy in frames)
    width, height = x_max - x_min, y_max - y_min
    scale = min(2.0, 170 / width, 140 / height)
    cell_w, cell_h = round(width * scale) + 12, round(height * scale) + 24
    columns = min(len(frames), 5)
    rows = (len(frames) + columns - 1) // columns
    image = Image.new('RGB', (cell_w * columns, cell_h * rows + 20), '#26323b')
    draw = ImageDraw.Draw(image)
    draw.text((4, 4), label, fill='white')
    for index, (frame, cx, cy) in enumerate(frames):
        x, y = index % columns * cell_w, 20 + index // columns * cell_h
        draw.text((x + 4, y), str(index), fill='white')
        sprite = frame.resize((max(1, round(frame.width * scale)), max(1, round(frame.height * scale))),
                              Image.Resampling.NEAREST)
        image.paste(sprite, (x + 5 + round((-cx - x_min) * scale),
                             y + 20 + round((-frame.height - cy - y_min) * scale)), sprite)
    return image


def read_direction(data, row, direction):
    with (data / row['archive']).open('rb') as source:
        source.seek(direction['offset'])
        raw = source.read(direction['bytes'])
    if hashlib.sha256(raw).hexdigest() != direction['payload_sha256']:
        raise ValueError(f'Body {row["body"]}, group {row["group"]}: rebuild the ledger from the installed archive')
    return decode(raw, direction['frames'])


def registered_pixels(frames):
    result = []
    for frame, cx, cy in frames:
        bounds = frame.getbbox()
        if bounds is None:
            result.append(None)
            continue
        left, top, _, _ = bounds
        visible = frame.crop(bounds)
        result.append((left - cx, top - frame.height - cy, visible.size, visible.tobytes()))
    return result


def group_pixels(data, row):
    return {entry['direction']: registered_pixels(read_direction(data, row, entry))
            for entry in row['directions']}


def compare_groups(data, ledger, body, groups):
    signatures = []
    for group in groups:
        row, = (row for row in ledger['original_mul_group_candidates']
                if (row['body'], row['group']) == (body, group) and 'matching_classic_route' in row)
        signatures.append(group_pixels(data, row))
    if any(signature != signatures[0] for signature in signatures[1:]):
        raise ValueError(f'Body {body} groups {groups} differ in pixels, placement, direction, or frame order')
    print(f'Body {body}: groups {groups} have identical ordered pixels across {len(signatures[0])} directions')


def scan_aliases(data, ledger, bodies):
    by_body = {}
    for row in ledger['original_mul_group_candidates']:
        if 'matching_classic_route' in row:
            by_body.setdefault(row['body'], {})[row['group']] = row
    for gap in ledger['source_frame_gaps']:
        body, slot = gap['body'], gap['classic_slot']
        if bodies and body not in bodies:
            continue
        groups = by_body.get(body, {})
        row = groups.get(slot)
        if not row or row['mobtype_prefers_uop'] or len(row['directions']) != 5:
            continue
        original = group_pixels(data, row)
        counts = {direction: len(frames) for direction, frames in original.items()}
        for donor, candidate in groups.items():
            clip = candidate['matching_classic_route']['resolved']
            if (clip and not candidate['mobtype_prefers_uop']
                    and {d['direction']: d['frames'] for d in candidate['directions']} == counts
                    and group_pixels(data, candidate) == original):
                print(f'Body {body}: group {slot} matches routed group {donor} ({clip}) in all five directions')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bodies', nargs='*', type=int)
    parser.add_argument('--groups', nargs='+', type=int, help='Default: unresolved source-backed slots')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--compare', action='store_true', help='Compare registered frames in all stored directions')
    mode.add_argument('--scan-aliases', action='store_true', help='Find exact matches for unresolved Classic MUL groups')
    parser.add_argument('--direction', type=int, choices=range(5), default=2)
    args = parser.parse_args()
    ledger = read(LEDGER)
    config = read(ROOT / 'Server/runtime/Configuration/modernuo.json')
    data = Path(config['dataDirectories'][0])
    if args.scan_aliases:
        if args.groups:
            parser.error('--scan-aliases accepts optional bodies but no --groups')
        scan_aliases(data, ledger, set(args.bodies))
        return
    if not args.bodies:
        parser.error('provide at least one body or use --scan-aliases')
    if args.compare:
        if len(args.bodies) != 1 or not args.groups or len(set(args.groups)) < 2:
            parser.error('--compare requires one body and at least two distinct --groups')
        compare_groups(data, ledger, args.bodies[0], args.groups)
        return
    wanted = {(row['body'], row['classic_slot']) for row in ledger['source_frame_gaps']}
    if args.groups:
        wanted = {(body, group) for body in args.bodies for group in args.groups}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for body in args.bodies:
        records = []
        for row in ledger['original_mul_group_candidates']:
            group = row['group']
            if row['body'] != body or (body, group) not in wanted or 'matching_classic_route' not in row:
                continue
            direction = next((entry for entry in row['directions'] if entry['direction'] == args.direction), None)
            if direction is None:
                continue
            frames = read_direction(data, row, direction)
            prefix = f'{body}-{group}-{args.direction}-{Path(row["archive"]).stem}'
            sheet(frames, f'{body} / {group} / direction {args.direction} / {row["archive"]}').save(OUTPUT / f'{prefix}.png')
            records.append({'body': body, 'group': group, 'graphic': row['graphic'], 'archive': row['archive'],
                            **direction, 'centres': [[cx, cy] for _, cx, cy in frames], 'sheet': prefix + '.png'})
        if records:
            (OUTPUT / f'{body}-direction-{args.direction}.json').write_text(json.dumps(records, indent=2) + '\n', encoding='utf-8')
        print(f'Body {body}: {len(records)} checked MUL records')


if __name__ == '__main__':
    main()
