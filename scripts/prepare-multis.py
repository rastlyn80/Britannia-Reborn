"""Index the owner's UO install multis for the client (local only, never committed).

Writes Viewer/local-multis/index.json:
  multis   multi id -> visible components [graphic, x, y, z] (MultiCollection.uop)
  tiles    tiledata for every graphic used there or by the house designer:
           {name, height, flags} (tiledata.mul)
  designer the house designer catalogues (walls, doors, floors, stairs, roof,
           misc, teleprts .txt): one row per style with its named columns
Formats as in ClassicUO's MultiLoader, TileDataLoader and
HouseCustomizationManager (BSD-2-Clause). Nothing proprietary is copied into
the repository: the output stays in the git-ignored local-* folder.
"""
import argparse, json, struct, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
import importlib.util
_audio = importlib.util.spec_from_file_location('prepare_audio', Path(__file__).with_name('prepare-audio.py'))
audio = importlib.util.module_from_spec(_audio); _audio.loader.exec_module(audio)

def uop_records(path):
    """hash -> (data offset, compressed length, decompressed length, flag)."""
    entries = {}
    with open(path, 'rb') as f:
        magic, version, stamp, next_block, block_size, count = struct.unpack('<IIIqIi', f.read(28))
        if magic != 0x50594D: raise SystemExit(f'{path} is not a UOP file')
        while next_block:
            f.seek(next_block)
            files, next_block = struct.unpack('<iq', f.read(12))
            for _ in range(files):
                offset, header, compressed, decompressed, h, data_hash, flag = struct.unpack('<qiiiQIh', f.read(34))
                if offset: entries[h] = (offset + header, compressed, decompressed, flag)
    return entries

def read_multis(client):
    path = client / 'MultiCollection.uop'
    entries = uop_records(path)
    multis = {}
    with open(path, 'rb') as f:
        for multi in range(0x10000):
            hit = entries.get(audio.name_hash(f'build/multicollection/{multi:06d}.bin'))
            if not hit: continue
            f.seek(hit[0]); data = f.read(hit[1])
            if hit[3] >= 1: data = zlib.decompress(data)
            count = struct.unpack_from('<i', data, 4)[0]
            at = 8; parts = []
            for _ in range(count):
                graphic, x, y, z, flags, extra = struct.unpack_from('<HhhhHI', data, at)
                at += 14 + extra * 4
                if flags in (0, 0x100) and graphic: parts.append([graphic, x, y, z])
            if parts: multis[multi] = parts
    return multis

def read_tiledata(client):
    data = (client / 'tiledata.mul').read_bytes()
    at = 512 * (4 + 32 * 30)
    tiles = {}
    graphic = 0
    while at + 4 + 41 <= len(data):
        at += 4
        for _ in range(32):
            if at + 41 > len(data): break
            flags = struct.unpack_from('<Q', data, at)[0]
            height = data[at + 20]
            name = data[at + 21:at + 41].split(b'\0')[0].decode('latin-1')
            tiles[graphic] = {'name': name, 'height': height, 'flags': flags}
            graphic += 1; at += 41
    return tiles

def read_designer(client):
    catalogues = {}
    for name in ['walls', 'doors', 'floors', 'stairs', 'roof', 'misc', 'teleprts']:
        path = client / f'{name}.txt'
        if not path.exists(): continue
        lines = [line.rstrip('\r\n').split('\t') for line in path.read_text(encoding='latin-1').splitlines()]
        header = next((row for row in lines if row and row[0] == 'Category'), None)
        if not header: continue
        rows = []
        for row in lines:
            if not row or not row[0].strip().lstrip('-').isdigit(): continue
            entry = {}
            for column, value in zip(header, row):
                value = value.strip()
                entry[column] = int(value) if value.lstrip('-').isdigit() else value
            rows.append(entry)
        catalogues[name] = rows
    return catalogues

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--client', default=None, help='UO install folder (default: ModernUO dataDirectories)')
    args = parser.parse_args()
    client = Path(args.client) if args.client else Path(json.loads((ROOT / 'Server/runtime/Configuration/modernuo.json').read_text(encoding='utf-8-sig'))['dataDirectories'][0])
    multis = read_multis(client)
    tiledata = read_tiledata(client)
    designer = read_designer(client)
    used = {part[0] for parts in multis.values() for part in parts}
    for rows in designer.values():
        for row in rows:
            for column, value in row.items():
                if isinstance(value, int) and value > 0 and column not in ('Category', 'Style', 'TID', 'FeatureMask'): used.add(value)
    tiles = {g: tiledata[g] for g in sorted(used) if g in tiledata}
    out = ROOT / 'Viewer/local-multis'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'index.json').write_text(json.dumps({'multis': multis, 'tiles': tiles, 'designer': designer}, separators=(',', ':')), encoding='utf-8')
    print(f'MULTI INDEX: {len(multis)} multis, {sum(len(p) for p in multis.values())} components, {len(tiles)} tiles, '
          f'{sum(len(r) for r in designer.values())} designer styles -> {out / "index.json"}')

if __name__ == '__main__':
    main()
