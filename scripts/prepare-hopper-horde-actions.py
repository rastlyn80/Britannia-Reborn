"""Validate distinct Classic 11 motions for the recovered Hopper and Horde rigs."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {302: ['SkitteringHopper'], 776: ['HordeMinion', 'HordeMinionFamiliar']}
RECIPES = {
    302: ('occurrence_next', 'skittering_hopper', 'HopperCheck',
          'occurrence-creature-inputs.json', 'occurrence-next-source', ('Fidget',),
          ('anim3.mul', 302, 5, '4379faba0a1e85d733c2a1b8620c548fdbb368159897c4a2771bbc9f00f6dc99'),
          'Retimed the recovered crouched Fidget, preserving its source head and limb poses'),
    776: ('horde_rune', 'horde_demon', 'HordeJawCheck',
          'horde-rune-inputs.json', 'horde-kitsune-rune-source', ('Idle', 'Fidget'),
          ('anim2.mul', 44, 5, 'ff32cacf385f41d375b78c1d38b8a2c8a8d4e64b3986689c4c3cf5be93cd5f34'),
          'Held the source idle stance with a shortened recovered jaw opening and authored neck accent'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    bake = read(ROOT / 'work/creatures/mul-motion-review/hopper-horde-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-hopper-horde-actions.gd')
    assert bake['solver'] == sha(ROOT / 'scripts/bake-skeleton-axe-trial.gd')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body, (family, kind, clip, manifest_file, folder, donors, pin, description) in RECIPES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and row['kind'] == kind and row['family'] == family
                 and [identity['body'] for identity in row['bodies']] == [body])
        manifest = read(ROOT / 'scripts' / manifest_file)
        members = {name.lower(): name for name in manifest['files']}
        for donor in donors:
            name = members[base['clip_sources'][donor]]
            source = ROOT / 'work/creatures/late-client-inputs' / folder / name
            assert sha(source) == manifest['files'][name]
        witness = reference(ledger, body, 11, pin)
        assets, scenes = {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            original = base['assets'][treatment]
            prefix = f'res://local-art/creatures/{family}/{kind}'
            assert original == f'{prefix}-{treatment}.gltf'
            asset = f'{prefix}-slot11-{treatment}.scn'
            original_sha = sha(ROOT / 'Viewer' / original.removeprefix('res://'))
            scenes[treatment] = sha(ROOT / 'Viewer' / asset.removeprefix('res://'))
            assert original_sha == base['asset_sha256'][treatment]
            assert bake['forms'][kind][treatment] == {'source': original_sha, 'scene': scenes[treatment]}
            assets[treatment] = asset
        rows.append(dict(base, status='prepared', family='hopper_horde_actions', assets=assets,
                         authored_action_scene_sha256=scenes, authored_action_reference=witness,
                         classic_action_categories=base.get('classic_action_categories', {}) | {'11': clip},
                         authored_replacements=base.get('authored_replacements', {}) | {clip: description}))
    return rows, CLASSES
