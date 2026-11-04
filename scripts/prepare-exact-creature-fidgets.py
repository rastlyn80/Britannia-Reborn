"""Pin exact Classic group 11/17 pixel matches without changing source scenes."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {146: ['Harrower'], 157: ['GiantBlackWidow'], 173: ['Mephitis'], 777: ['Doppleganger']}


def prepared(entries):
    manifest = json.loads((ROOT / 'Viewer/Presentation/legacy-late-action-aliases.json').read_text())
    ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        proof = manifest[str(body)]
        assert proof['kind'] == base['kind'] and proof['family'] == base['family']
        assert base.get('classic_action_categories', {}).get('11') is None
        assert base.get('classic_action_categories', {}).get('17', 'Fidget') == 'Fidget'
        assert proof['sibling'] == 17 and 'Fidget' in base['clip_sources']
        references = {
            str(slot): reference(ledger, body, slot, ('anim2.mul', proof['graphic'], 5, proof[signature]))
            for slot, signature in ((11, 'payload_signature'), (17, 'matched_payload_signature'))
        }
        for treatment, digest in base['asset_sha256'].items():
            default = f"res://local-art/creatures/{base['kind']}-{treatment}.gltf"
            scene = base.get('assets', {}).get(treatment, default)
            assert hashlib.sha256((ROOT / 'Viewer' / scene.removeprefix('res://')).read_bytes()).hexdigest() == digest
        rows.append(dict(base, status='prepared', family='exact_creature_fidgets',
                         legacy_slot11_evidence=proof, authored_action_reference=references['11'],
                         classic_motion_references=references,
                         classic_action_categories=base.get('classic_action_categories', {}) | {'11': 'Fidget'}))
    return rows, CLASSES
