"""Seal the shorter Classic Kraken recoil on the recovered rig."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
FAMILY = 'kraken_reactions'
CLASSES = {77: ['Kraken', 'Leviathan']}
LONG = '6e05ed6f18587254da441d5e92c57fcfd5c264590d2a008f38749878e32159bd'
SHORT = 'a43bfaee18144a8d5740024b9ac42fc5f790967a2a6628a14fda9f98bc5c6332'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == 'krakens_kraken'
             and not row.get('classic_gesture_batch') and [item['body'] for item in row['bodies']] == [77])
    assert base['movement_mode'] == 'native_waterline' and base['classic_gesture_native_sha256']
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    bake = read(ROOT / 'Viewer/local-art/creatures/kraken-brief-hit.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-kraken-reactions.gd')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    evidence = {str(slot): reference(ledger, 77, slot, ('anim2.mul', 19, frames, digest))
                for slot, frames, digest in ((10, 4, LONG), (15, 3, SHORT), (16, 3, SHORT))}
    assets, scenes = {}, {}
    for treatment, source in base['assets'].items():
        output = f'res://local-art/creatures/kraken-brief-hit-{treatment}.scn'
        source_hash = sha(ROOT / 'Viewer' / source.removeprefix('res://'))
        assert source_hash == base['asset_sha256'][treatment]
        scenes[treatment] = sha(ROOT / 'Viewer' / output.removeprefix('res://'))
        assert bake['scenes'][treatment] == {'source': source_hash, 'scene': scenes[treatment]}
        assets[treatment] = output
    row = dict(base, status='prepared', family=FAMILY, assets=assets,
               authored_action_scene_sha256=scenes, authored_action_reference=evidence['15'],
               classic_motion_references=evidence, native_extra_classic_actions=[10, 15, 16],
               classic_action_categories=base['classic_action_categories'] | {'10': 'Hit', '15': 'BriefHit', '16': 'BriefHit'},
               authored_replacements=base['authored_replacements'] | {
                   'BriefHit': 'Short recoil and direct recovery fitted from the recovered Hit motion for identical Classic groups 15 and 16'})
    return [row], CLASSES
