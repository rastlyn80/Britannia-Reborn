"""Keep the exact parsed source curve values when adding newly measured clips."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
BASE = ART / 'elementals_ice_elemental-ground.json'
TARGET = ART / 'ice-elemental-ground.json'
raw = BASE.read_bytes()
original = json.loads(raw)
measured = json.loads(TARGET.read_bytes())
assert measured['overlay']['base_sha256'] == hashlib.sha256(raw).hexdigest()
assert original['sample_rate'] == measured['sample_rate'] == 960
assert original['treatments'].keys() == measured['treatments'].keys()
count = 0
for treatment, row in original['treatments'].items():
    kept = row['clips']
    fresh = measured['treatments'][treatment]['clips']
    additions = {key: curve for key, curve in fresh.items() if key not in kept}
    assert additions.keys() == {'IceArmDraw', 'IceForearmGuard', 'IceWeightShift'}
    count += sum(map(len, additions.values()))
    row['clips'] = kept | additions
assert count == measured['overlay']['samples']
original['overlay'] = measured['overlay']
TARGET.write_text(json.dumps(original, separators=(',', ':')) + '\n', encoding='utf-8')
print(f'Ice ground curves: {count} new samples, all 39 earlier clip curves preserved exactly')
