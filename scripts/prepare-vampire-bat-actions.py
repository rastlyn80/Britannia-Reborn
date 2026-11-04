"""Validate the two body-317 wing actions against Classic frames and recovered 3D motions."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {317: ['VampireBat', 'VampireBatFamiliar']}
PINS = {
    '11': ('anim3.mul', 317, 5, '24157205a5d651975a0d19e2bf6628373523099faf15c0bf7ef3674d9074d74d'),
    '20': ('anim3.mul', 317, 3, '38b23e685003315b01ff7dda089cf05f96aafddf4152bea79530c566e8fbf037'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == 'vampire_bat'
             and [identity['body'] for identity in row['bodies']] == [317])
    manifest = read(ROOT / 'scripts/vampire-bat-inputs.json')
    source = ROOT / 'work/creatures/late-client-inputs/vampire-bat-source'
    members = {p.relative_to(source).as_posix().lower(): p for p in source.rglob('*') if p.is_file()}
    for clip in ('Idle', 'Fidget'):
        name = base['clip_sources'][clip]
        assert sha(members[name]) == manifest['files'][name]
    bake = read(ROOT / 'work/creatures/mul-motion-review/vampire-bat-actions-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-vampire-bat-actions.gd')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    references = {group: reference(ledger, 317, int(group), pin) for group, pin in PINS.items()}
    assets, scenes = {}, {}
    folder = 'res://local-art/creatures/vampire_bat/'
    for treatment in ('original', 'rounded', 'modern'):
        original = base['assets'][treatment]
        assert original == folder + f'vampire_bat-{treatment}.gltf'
        asset = folder + f'vampire-bat-wings-{treatment}.scn'
        source_sha = sha(ROOT / 'Viewer' / original.removeprefix('res://'))
        scenes[treatment] = sha(ROOT / 'Viewer' / asset.removeprefix('res://'))
        assert source_sha == base['asset_sha256'][treatment]
        assert bake['forms'][treatment] == {'source': source_sha, 'scene': scenes[treatment]}
        assets[treatment] = asset
    row = dict(base, status='prepared', family='vampire_bat_actions', assets=assets,
               authored_action_scene_sha256=scenes, authored_action_reference=references['11'],
               classic_motion_references=references,
               classic_action_categories=base.get('classic_action_categories', {}) | {
                   '11': 'BatWingCheck', '20': 'BatSettle'},
               authored_replacements=base.get('authored_replacements', {}) | {
                   'BatWingCheck': 'Two wing beats with recovered wing poses and aligned body lift',
                   'BatSettle': 'Three airborne wing poses on the held recovered idle'})
    return [row], CLASSES
