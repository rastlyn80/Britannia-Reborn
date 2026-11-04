"""Check the source-backed Interred Grizzle action overlay."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {259: ['InterredGrizzle', 'Ilhenir']}
KIND = 'monstrousinterredgrizzle'
CLIP = 'GrizzleAntlerCheck'
DONOR = 'Client/Models/Monsters/MonstrousInterredGrizzle_misc.grn'
DONOR_SHA = 'dcecd13f48f146d32e39797936037a097a6a93ee4239113dc9b70526714ad432'
PIXEL_SOURCE = '22fd6d8f127b22282b24066fa8c2404ddfbfdda17f5e0a430e5d4787f67feb47'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == KIND
             and [identity['body'] for identity in row['bodies']] == [259])
    assert base['clip_sources']['Misc'] == DONOR
    inputs = ROOT / 'work/creatures/ml-next/source/Client/MonstrousInterredGrizzle_misc.grn'
    assert sha(inputs) == DONOR_SHA
    bake = read(ROOT / 'work/creatures/mul-motion-review/grizzle-antler-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-grizzle-antler-check.gd')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    witness = reference(ledger, 259, 11, ('anim5.mul', 18, 5, PIXEL_SOURCE))
    assets, scenes = {}, {}
    for treatment in ('original', 'rounded', 'modern'):
        original = base['assets'][treatment]
        expected = f'res://local-art/creatures/{KIND}-{treatment}.scn'
        assert original == expected
        asset = f'res://local-art/creatures/{KIND}-antler-{treatment}.scn'
        original_sha = sha(ROOT / 'Viewer' / original.removeprefix('res://'))
        scenes[treatment] = sha(ROOT / 'Viewer' / asset.removeprefix('res://'))
        assert original_sha == base['asset_sha256'][treatment]
        assert bake['forms'][treatment] == {'source': original_sha, 'scene': scenes[treatment]}
        assets[treatment] = asset
    row = dict(base, status='prepared', family='grizzle_antler', assets=assets,
               authored_action_scene_sha256=scenes, authored_action_reference=witness,
               classic_action_categories=base.get('classic_action_categories', {}) | {'11': CLIP},
               authored_replacements=base.get('authored_replacements', {}) | {
                   CLIP: 'Retimed the first 2.8 seconds of the recovered Misc motion to 0.95 seconds'})
    return [row], CLASSES
