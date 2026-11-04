"""Seal separate Classic recoil poses over the already validated fidget scenes."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
STEMS = {17: 'orcs_orc', 18: 'ettins_ettin'}
CLASSES = {17: ['Orc'], 18: ['Ettin']}
REFERENCES = {
    17: {15: '54923095d846b156309b837d8e0515ec0c30dc9def704612c788d611e137b4ed',
         16: '21915ece7a44498e49205f7aa4ae168d518b3d661b683e0ee534a22dd145da44'},
    18: {15: '583bf53fa4bd9c37c11c7615d9cb59e77b32784e18888d4a2fb2f0e766e95c33',
         16: '993746e6b456644fb275776020d165967e1f080bd7c5c64c7a3d3d4e12568a25'},
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    bake = read(ART / 'orc-ettin-reactions-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-orc-ettin-reactions.gd')
    assert bake['solver'] == sha(ROOT / 'scripts/bake-classic-gesture-trials.gd')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body, stem in STEMS.items():
        base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == stem + '_fidgets'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base['classic_gesture_native_sha256'] and not base.get('classic_gesture_batch')
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            source = f'{stem}-fidgets-{treatment}.scn'
            output = f'{stem}-reactions-{treatment}.scn'
            assert base['assets'][treatment] == 'res://local-art/creatures/' + source
            assert sha(ART / source) == base['asset_sha256'][treatment]
            scenes[treatment] = sha(ART / output)
            assert bake['scenes'][str(body)][treatment] == {'source': base['asset_sha256'][treatment], 'scene': scenes[treatment]}
            assets[treatment] = 'res://local-art/creatures/' + output
        evidence = {str(slot): reference(ledger, body, slot, ('anim.mul', body, 3, digest))
                    for slot, digest in REFERENCES[body].items()}
        rows.append(dict(base, status='prepared', family='orc_ettin_reactions', assets=assets,
                         authored_action_scene_sha256=scenes, authored_action_reference=evidence['15'],
                         classic_motion_references=evidence, native_extra_classic_actions=[15, 16],
                         classic_action_categories=base['classic_action_categories'] | {'15': 'RightRecoil', '16': 'LeftRecoil'},
                         authored_replacements=base['authored_replacements'] | {
                             'RightRecoil': 'High right-side recoil following Classic group 15',
                             'LeftRecoil': 'Inward left-side recoil following Classic group 16'}))
    return rows, CLASSES
