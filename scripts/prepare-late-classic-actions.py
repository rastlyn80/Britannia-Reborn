"""Validate the late Classic actions against the exact frames and recovered donors."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {303: ['Devourer'], 172: ['Rikktor'], 311: ['ShadowKnight']}
RECIPES = {
    303: ('devourer_lion_hiryu', 'devourer', 'DevourerMouthCheck',
          'devourer-lion-hiryu-inputs.json', 'devourer-lion-hiryu-source',
          ('anim3.mul', 303, 5, '705a1e562b7833781c73e2326647e2371ab366bc1996ad9152684900963dcee6'),
          'Retimed the torso opening from the recovered Fidget and returned to its opening pose'),
    172: ('champions', 'dragons_dragon_retro_red', 'RikktorTailCheck',
          'champion-creature-inputs.json', 'champions-source',
          ('anim2.mul', 62, 5, '96f6dd12723ae21ee6f36f86851f2b085e963de25af3ba09b8479f3a03b0c1f2'),
          'Retimed the recovered tail sweep and partial wing motion on the held recovered idle'),
    311: ('aos_armed', 'shadow_knight', 'ShadowKnightGlance',
          'aos-armed-inputs.json', 'aos-creature-source',
          ('anim3.mul', 311, 5, '95f3a916f52a3ea5b4ca9c651846997eb505364c9f18584c3f1c60b3f67e4d76'),
          'Retimed the recovered glance and free arm on held idle with the original sword grip'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    bake = read(ROOT / 'work/creatures/mul-motion-review/late-classic-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-late-classic-actions.gd')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body, (family, kind, clip, manifest_file, folder, pin, description) in RECIPES.items():
        base, = (row for row in entries if row['status'] == 'validated' and row['family'] == family
                 and row['kind'] == kind and [identity['body'] for identity in row['bodies']] == [body])
        manifest = read(ROOT / 'scripts' / manifest_file)
        donors = ('Fidget',) if body == 303 else ('Fidget', 'Idle')
        for donor in donors:
            name, = (member for member in manifest['files'] if member.lower() == base['clip_sources'][donor])
            assert sha(ROOT / 'work/creatures/late-client-inputs' / folder / name) == manifest['files'][name]
        witness = reference(ledger, body, 11, pin)
        assets, scenes = {}, {}
        prefix = f'res://local-art/creatures/{family}/{kind}'
        for treatment in ('original', 'rounded', 'modern'):
            original = base['assets'][treatment]
            assert original == f'{prefix}-{treatment}.gltf'
            asset = f'{prefix}-slot11-{treatment}.scn'
            source_sha = sha(ROOT / 'Viewer' / original.removeprefix('res://'))
            scenes[treatment] = sha(ROOT / 'Viewer' / asset.removeprefix('res://'))
            assert source_sha == base['asset_sha256'][treatment]
            assert bake['forms'][kind][treatment] == {'source': source_sha, 'scene': scenes[treatment]}
            assets[treatment] = asset
        rows.append(dict(base, status='prepared', family='late_classic_actions', assets=assets,
                         authored_action_scene_sha256=scenes, authored_action_reference=witness,
                         classic_action_categories=base.get('classic_action_categories', {}) | {'11': clip},
                         authored_replacements=base.get('authored_replacements', {}) | {clip: description}))
    return rows, CLASSES
