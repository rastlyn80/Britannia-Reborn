"""Verify the two Classic Ettin fidgets and match the saved source scenes."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {18: ['Ettin']}
REFERENCES = {
    '17': '62f8e81c14d79476070a3ae95dfab14a451b683e85563cd7fc91e67e1fe370d1',
    '18': '36de9c9e3f4ab70229828e27fde222ec39f04f869676ad0ef093d49c419862bf',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == 'ettins_ettin'
             and [identity['body'] for identity in row['bodies']] == [2, 18])
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        members = {name.casefold(): name for name in archive.namelist()}
        idle = archive.read(members[base['clip_sources']['Idle'].casefold()])
        assert hashlib.sha256(idle).hexdigest() == '32e0090d7fbaa12f893589c62ae4edae1772e5767e8b60869e4f6168ffdc34ab'
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    evidence = {slot: reference(ledger, 18, int(slot), ('anim.mul', 18, 5, digest))
                for slot, digest in REFERENCES.items()}
    bake = read(ROOT / 'work/creatures/mul-motion-review/ettin-fidgets-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-ettin-fidgets.gd')
    assert bake['aim_solver'] == sha(ROOT / 'scripts/bake-classic-gesture-trials.gd')
    assets, scenes = {}, {}
    for treatment in ('original', 'rounded', 'modern'):
        prefix = 'local-art/creatures/ettins_ettin'
        source = f'{prefix}-{treatment}.gltf'
        output = f'{prefix}-fidgets-{treatment}.scn'
        assert sha(ROOT / 'Viewer' / source) == base['asset_sha256'][treatment]
        scenes[treatment] = sha(ROOT / 'Viewer' / output)
        assert bake['scenes'][treatment] == {'source': base['asset_sha256'][treatment], 'scene': scenes[treatment]}
        assets[treatment] = 'res://' + output
    renderer = 'Presentation/SourcePreservingCreatureVisual.gd'
    row = dict(base, status='prepared', family='ettin_fidgets', bodies=[base['bodies'][1]], assets=assets,
               presentation_script='res://' + renderer, presentation_script_sha256=sha(ROOT / 'Viewer' / renderer),
               authored_action_scene_sha256=scenes, authored_action_reference=evidence['17'],
               classic_motion_references=evidence,
               classic_action_categories=base.get('classic_action_categories', {}) | {
                   '17': 'EttinTempleCheck', '18': 'Fidget2'},
               authored_replacements=base.get('authored_replacements', {}) | {
                   'EttinTempleCheck': 'Left-hand temple check with independently turned source heads',
                   'Fidget2': 'Lower left-hand chest sweep following the separate Classic direction set'})
    return [row], CLASSES
