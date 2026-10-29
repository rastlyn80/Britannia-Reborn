"""Wearable item layers from your own UO install (tiledata.mul).

Writes the git-ignored Viewer/local-items/wearables.json: {graphic: layer} for
every graphic tiledata marks Wearable (flag 0x00400000), so the paperdoll can
show which slot an item you drag will go to before the server equips it.
Nothing is committed; the server still decides what can be worn.

usage: python scripts/prepare-wearables.py [--client UO_FOLDER]
"""
import argparse
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEARABLE = 0x00400000


def read_layers(client):
    data = (client / 'tiledata.mul').read_bytes()
    # 64-bit flags format: 512 land groups (4-byte header + 32 * 30 bytes),
    # then static groups of 32 records of 41 bytes: flags 8, weight 1,
    # layer 1, count 4, animation 2, hue 2, light 2, height 1, name 20.
    at = 512 * (4 + 32 * 30)
    layers = {}
    graphic = 0
    while at + 4 + 41 <= len(data):
        at += 4
        for _ in range(32):
            if at + 41 > len(data):
                break
            flags = struct.unpack_from('<Q', data, at)[0]
            if flags & WEARABLE and data[at + 9]:
                layers[graphic] = data[at + 9]
            graphic += 1
            at += 41
    return layers


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--client', default=None, help='UO install folder (default: ModernUO dataDirectories)')
    args = parser.parse_args()
    client = Path(args.client) if args.client else Path(json.loads((ROOT / 'Server/runtime/Configuration/modernuo.json').read_text(encoding='utf-8-sig'))['dataDirectories'][0])
    layers = read_layers(client)
    out = ROOT / 'Viewer/local-items'
    out.mkdir(parents=True, exist_ok=True)
    (out / '.gdignore').write_text('')
    (out / 'wearables.json').write_text(json.dumps({str(g): l for g, l in layers.items()}, separators=(',', ':')), encoding='utf-8')
    print(f'WEARABLES: {len(layers)} graphics -> {out / "wearables.json"}')


if __name__ == '__main__':
    main()
