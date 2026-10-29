"""Render the owner's UO install radar maps, every facet, for the client (local only, never committed).

Writes Viewer/local-worldmap/<facet>/ (0 Felucca ... 5 Ter Mur): 512x512-tile PNGs (one pixel per map tile) and
index.json {width, height, tile, tiles}, and a root index.json of facets. Colours come from radarcol.mul (land
ids, then statics at 0x4000+id, ARGB1555); each cell shows its highest static,
or its land tile. Land from mapNLegacyMUL.uop (entries concatenated in order
give map1.mul's 196-byte blocks, column-major), statics from staidxN.mul /
staticsN.mul. Formats as in ClassicUO's MapLoader and radar map (BSD-2-Clause).
Used by the world map and treasure/cartography map windows; nothing derived
is committed.
"""
import argparse, json, struct, zlib, importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_audio = importlib.util.spec_from_file_location('prepare_audio', Path(__file__).with_name('prepare-audio.py'))
audio = importlib.util.module_from_spec(_audio); _audio.loader.exec_module(audio)

TILE = 512
# Facet id (ModernUO map id) -> size in tiles.
FACETS = {0: (7168, 4096), 1: (7168, 4096), 2: (2304, 1600), 3: (2560, 2048), 4: (1448, 1448), 5: (1280, 4096)}
NAMES = {0: 'Felucca', 1: 'Trammel', 2: 'Ilshenar', 3: 'Malas', 4: 'Tokuno', 5: 'Ter Mur'}

def uop_concat(path, prefix):
    entries = {}
    with open(path, 'rb') as f:
        magic, version, stamp, next_block, block_size, count = struct.unpack('<IIIqIi', f.read(28))
        while next_block:
            f.seek(next_block)
            files, next_block = struct.unpack('<iq', f.read(12))
            for _ in range(files):
                offset, header, compressed, decompressed, h, data_hash, flag = struct.unpack('<qiiiQIh', f.read(34))
                if offset: entries[h] = (offset + header, compressed)
        parts = []
        i = 0
        while True:
            hit = entries.get(audio.name_hash(f'{prefix}{i:08d}.dat'))
            if not hit: break
            f.seek(hit[0]); parts.append(f.read(hit[1])); i += 1
    return b''.join(parts)

def png(path, width, height, rgb_rows):
    """Minimal RGB PNG writer (no image library needed)."""
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    raw = b''.join(b'\x00' + row for row in rgb_rows)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--client', default=None, help='UO install folder (default: ModernUO dataDirectories)')
    args = parser.parse_args()
    client = Path(args.client) if args.client else Path(json.loads((ROOT / 'Server/runtime/Configuration/modernuo.json').read_text(encoding='utf-8-sig'))['dataDirectories'][0])
    radar = struct.unpack(f'<{(client / "radarcol.mul").stat().st_size // 2}H', (client / 'radarcol.mul').read_bytes())
    rgb = []
    for c in radar:
        r, g, b = (c >> 10) & 31, (c >> 5) & 31, c & 31
        rgb.append(bytes(((r * 255) // 31, (g * 255) // 31, (b * 255) // 31)))
    root = ROOT / 'Viewer/local-worldmap'
    root.mkdir(parents=True, exist_ok=True)
    # Older single-facet layout at the root: replaced by one folder per facet.
    for old in list(root.glob('*.png')) + list(root.glob('*.png.import')): old.unlink()
    # Read straight from disk by the client; Godot must not import them.
    (root / '.gdignore').write_text('', encoding='utf-8')
    done = []
    for facet, (width, height) in FACETS.items():
        if not (client / f'map{facet}LegacyMUL.uop').exists(): continue
        render(client, rgb, facet, width, height, root / str(facet))
        done.append(facet)
    (root / 'index.json').write_text(json.dumps({'facets': done, 'names': {str(f): NAMES[f] for f in done}}), encoding='utf-8')

def render(client, rgb, facet, width, height, out):
    land = uop_concat(client / f'map{facet}LegacyMUL.uop', f'build/map{facet}legacymul/')
    blocks_y = height // 8
    pixels = bytearray(width * height * 3)
    for bx in range(width // 8):
        for by in range(blocks_y):
            base = (bx * blocks_y + by) * 196 + 4
            if base + 192 > len(land): continue
            for cy in range(8):
                row = ((by * 8 + cy) * width + bx * 8) * 3
                for cx in range(8):
                    at = base + (cy * 8 + cx) * 3
                    graphic = land[at] | (land[at + 1] << 8)
                    pixels[row + cx * 3:row + cx * 3 + 3] = rgb[graphic & 0x3fff]
    index = (client / f'staidx{facet}.mul').read_bytes()
    statics = (client / f'statics{facet}.mul').read_bytes()
    top = {}
    for block in range(min((width // 8) * blocks_y, len(index) // 12)):
        lookup, length, _ = struct.unpack_from('<iii', index, block * 12)
        if lookup < 0 or length <= 0 or lookup + length > len(statics): continue
        bx, by = divmod(block, blocks_y)
        for at in range(lookup, lookup + length - 6, 7):
            graphic, x, y, z = struct.unpack_from('<HBBb', statics, at)
            cell = (by * 8 + y) * width + bx * 8 + x
            if cell not in top or z >= top[cell][1]: top[cell] = (graphic, z)
    for cell, (graphic, z) in top.items():
        colour = 0x4000 + graphic
        if colour < len(rgb): pixels[cell * 3:cell * 3 + 3] = rgb[colour]
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob('*.png'): old.unlink()
    tiles = []
    for y in range(0, height, TILE):
        for x in range(0, width, TILE):
            w, h = min(TILE, width - x), min(TILE, height - y)
            rows = [bytes(pixels[((y + r) * width + x) * 3:((y + r) * width + x + w) * 3]) for r in range(h)]
            png(out / f'{x}_{y}.png', w, h, rows)
            tiles.append([x, y])
    # Overview: one pixel per 8x8 tiles (the cell's top-left sample).
    step = 8
    rows = []
    for y in range(0, height - height % step, step):
        row = bytearray()
        for x in range(0, width - width % step, step):
            at = (y * width + x) * 3
            row += pixels[at:at + 3]
        rows.append(bytes(row))
    png(out / 'overview.png', width // step, height // step, rows)
    (out / 'index.json').write_text(json.dumps({'facet': facet, 'name': NAMES[facet], 'width': width, 'height': height, 'tile': TILE, 'tiles': tiles, 'overview': step}), encoding='utf-8')
    print(f'WORLD MAP {NAMES[facet]}: {width}x{height}, {len(tiles)} tiles, {len(top)} static-topped cells -> {out}')

if __name__ == '__main__':
    main()
