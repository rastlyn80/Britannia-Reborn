"""Index the owner's UO install audio for the client (local only, never committed).

Writes Viewer/local-audio/index.json: where each sound effect sits inside
soundLegacyMUL.uop (offset and length of its 16-bit PCM, after the 40-byte
entry header), Sound.def aliases for missing ids, and the music tracks from
Music/Digital/Config.txt. The client reads the audio straight from the install
at run time, so nothing proprietary is copied. Format as in ClassicUO's
SoundsLoader/UOFileUop (BSD-2-Clause).
"""
import argparse, json, re, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MASK = 0xffffffff

def rotate(v, n): return ((v << n) | (v >> (32 - n))) & MASK

def name_hash(name):
    data = name.encode('ascii'); a = b = c = (0xdeadbeef + len(data)) & MASK; i = 0
    while len(data) - i > 12:
        aa, bb, cc = struct.unpack_from('<III', data, i); a = (a + aa) & MASK; b = (b + bb) & MASK; c = (c + cc) & MASK
        a = ((a - c) ^ rotate(c, 4)) & MASK; c = (c + b) & MASK
        b = ((b - a) ^ rotate(a, 6)) & MASK; a = (a + c) & MASK
        c = ((c - b) ^ rotate(b, 8)) & MASK; b = (b + a) & MASK
        a = ((a - c) ^ rotate(c, 16)) & MASK; c = (c + b) & MASK
        b = ((b - a) ^ rotate(a, 19)) & MASK; a = (a + c) & MASK
        c = ((c - b) ^ rotate(b, 4)) & MASK; b = (b + a) & MASK; i += 12
    tail = data[i:]
    for n, v in enumerate(tail):
        if n < 4: a = (a + (v << ((n % 4) * 8))) & MASK
        elif n < 8: b = (b + (v << ((n % 4) * 8))) & MASK
        else: c = (c + (v << ((n % 4) * 8))) & MASK
    if tail:
        c = ((c ^ b) - rotate(b, 14)) & MASK; a = ((a ^ c) - rotate(c, 11)) & MASK; b = ((b ^ a) - rotate(a, 25)) & MASK
        c = ((c ^ b) - rotate(b, 16)) & MASK; a = ((a ^ c) - rotate(c, 4)) & MASK; b = ((b ^ a) - rotate(a, 14)) & MASK; c = ((c ^ b) - rotate(b, 24)) & MASK
    return (b << 32) | c

def uop_entries(path):
    entries = {}
    with open(path, 'rb') as f:
        magic, version, stamp, next_block, block_size, count = struct.unpack('<IIIqIi', f.read(28))
        if magic != 0x50594D: raise SystemExit(f'{path} is not a UOP file')
        while next_block:
            f.seek(next_block)
            files, next_block = struct.unpack('<iq', f.read(12))
            for _ in range(files):
                offset, header, compressed, decompressed, h, data_hash, flag = struct.unpack('<qiiiQIh', f.read(34))
                if offset: entries[h] = (offset + header, compressed, flag)
    return entries

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--client', default=None, help='UO install folder (default: ModernUO dataDirectories)')
    args = parser.parse_args()
    client = Path(args.client) if args.client else Path(json.loads((ROOT / 'Server/runtime/Configuration/modernuo.json').read_text(encoding='utf-8-sig'))['dataDirectories'][0])
    uop = client / 'soundLegacyMUL.uop'
    entries = uop_entries(uop)
    sounds = {}
    for sound in range(0x10000):
        hit = entries.get(name_hash(f'build/soundlegacymul/{sound:08d}.dat'))
        if hit and hit[2] == 0 and hit[1] > 40: sounds[sound] = [hit[0] + 40, hit[1] - 40]
    aliases = {}
    definition = client / 'Sound.def'
    if definition.exists():
        for line in definition.read_text(encoding='latin-1').splitlines():
            found = re.match(r'\s*(\d+)\s+\{([\d\s,]+)\}', line)
            if not found: continue
            source = int(found.group(1))
            if source in sounds: continue
            for target in found.group(2).replace(',', ' ').split():
                if int(target) in sounds:
                    aliases[source] = int(target); break
    music = {}
    config = client / 'Music/Digital/Config.txt'
    if config.exists():
        for line in config.read_text(encoding='latin-1').splitlines():
            parts = line.replace(',', ' ').split()
            if len(parts) < 2 or not parts[0].isdigit(): continue
            track = client / 'Music/Digital' / f'{parts[1]}.mp3'
            if track.exists(): music[int(parts[0])] = {'path': str(track), 'loop': 'loop' in parts[2:]}
    out = ROOT / 'Viewer/local-audio'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'index.json').write_text(json.dumps({'uop': str(uop), 'rate': 22050, 'sounds': sounds, 'aliases': aliases, 'music': music}), encoding='utf-8')
    print(f'AUDIO INDEX: {len(sounds)} sounds, {len(aliases)} aliases, {len(music)} music tracks -> {out / "index.json"}')

if __name__ == '__main__':
    main()
