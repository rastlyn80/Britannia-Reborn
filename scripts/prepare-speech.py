"""Index the owner's UO install speech keywords for the client (local only, never committed).

Writes Viewer/local-speech/keywords.json: [[keyword id, text], ...] from
speech.mul (big-endian id and length, UTF-8 text; '*' marks open ends), as in
ClassicUO's SpeechesLoader (BSD-2-Clause). The client sends the ids of the
keywords a line matches with its speech (0xAD encoded), which is how ModernUO
recognises "bank", "vendor buy", boat orders and other spoken commands.
"""
import argparse, json, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--client', default=None, help='UO install folder (default: ModernUO dataDirectories)')
    args = parser.parse_args()
    client = Path(args.client) if args.client else Path(json.loads((ROOT / 'Server/runtime/Configuration/modernuo.json').read_text(encoding='utf-8-sig'))['dataDirectories'][0])
    data = (client / 'speech.mul').read_bytes()
    entries, at = [], 0
    while at + 4 <= len(data):
        keyword, length = struct.unpack_from('>HH', data, at)
        at += 4
        if length:
            entries.append([keyword, data[at:at + length].decode('utf-8', 'replace')])
            at += length
    out = ROOT / 'Viewer/local-speech'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'keywords.json').write_text(json.dumps(entries, ensure_ascii=False), encoding='utf-8')
    print(f'SPEECH KEYWORDS: {len(entries)} entries -> {out / "keywords.json"}')

if __name__ == '__main__':
    main()
