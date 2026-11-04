"""Validate the Orc's two distinct Classic fidgets and saved source scenes."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {17: ['Orc']}
SOURCES = {
    17: ('anim.mul', 17, 5, '5266a5f366363271bedb623c44013db94008e251ca8e3a2a0d53cf0676f0de7a'),
    18: ('anim.mul', 17, 5, '5e46d2ccd9bdd4bc599b4dde6f12712c78216ce992e985b1f68c986548e66c27'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == 'orcs_orc'
             and [identity['body'] for identity in row['bodies']] == [17, 41])
    identity = base['bodies'][0]
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        members = {name.casefold(): name for name in archive.namelist()}
        idle = archive.read(members[base['clip_sources']['Idle'].casefold()])
        assert hashlib.sha256(idle).hexdigest() == '66edd30295c4ddecb810d0ace05ea229575b4cfc7b59260c9ce410f4be7b5fc6'
    donor = base['authored_action_recipe']
    assert donor['path'] == 'scripts/creature-humanoid-actions.py'
    assert donor['sha256'] == sha(ROOT / donor['path']) == '42b78ca0d934eb6e679988e8d208920eec23cac1ed6246c1e1ad2e187946095b'

    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    evidence = {slot: reference(ledger, 17, slot, pin) for slot, pin in SOURCES.items()}
    bake = read(ROOT / 'work/creatures/mul-motion-review/orc-fidgets-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-orc-fidgets.gd')
    assert bake['aim_solver'] == sha(ROOT / 'scripts/bake-classic-gesture-trials.gd')
    assets, scenes = {}, {}
    for treatment in ('original', 'rounded', 'modern'):
        prefix = 'local-art/creatures/orcs_orc'
        source = f'{prefix}-{treatment}.gltf'
        path = f'{prefix}-fidgets-{treatment}.scn'
        assert sha(ROOT / 'Viewer' / source) == base['asset_sha256'][treatment]
        scenes[treatment] = sha(ROOT / 'Viewer' / path)
        assert bake['scenes'][treatment] == {'source': base['asset_sha256'][treatment], 'scene': scenes[treatment]}
        assets[treatment] = 'res://' + path
    renderer = 'Presentation/SourcePreservingCreatureVisual.gd'
    row = dict(base, status='prepared', family='orc_fidgets', bodies=[identity], assets=assets,
               presentation_script='res://' + renderer, presentation_script_sha256=sha(ROOT / 'Viewer' / renderer),
               authored_action_scene_sha256=scenes, authored_action_reference=evidence[17],
               authored_action_secondary_reference=evidence[18],
               classic_action_categories=base.get('classic_action_categories', {}) | {
                   '17': 'OrcHighGesture', '18': 'Fidget2'},
               authored_replacements=base.get('authored_replacements', {}) | {
                   'OrcHighGesture': 'Retimed right-arm wind-up on the recovered Orc idle stance',
                   'Fidget2': 'Planted right-arm gesture across the waist following five Classic directions'})
    return [row], CLASSES
