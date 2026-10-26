"""Read owned hue palettes without changing client files; output stays local."""
import json, struct, sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
raw = (Path(sys.argv[1])/'hues.mul').read_bytes()
if len(raw) % 708: raise ValueError('Unsupported hue record grouping')
palettes = {}
for group in range(len(raw)//708):
 for i in range(8):
  offset = group*708+4+i*88
  palettes[str(group*8+i)] = struct.unpack_from('<32H',raw,offset)
(root/'Viewer/hues.local.json').write_text(json.dumps(palettes),encoding='utf-8')
print(f'LOCAL ARTWORK ONLY: {len(palettes)} hue palettes')
