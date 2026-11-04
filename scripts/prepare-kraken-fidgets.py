"""Verify the original Kraken action pair and bind it to the local scene recipe."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
CLASSES = {77: ['Kraken', 'Leviathan']}
SHALLOW = 'de6bf8379e600beb4d2e692d9520c1360da5d5fb95a5df7cf17d6880de279863'
SWEEP = '10e6a13f7be6b5f5348ad302f49ba50be340e3b26d80dc368a037fd1b5048e2c'
DONORS = {
    'Idle': '6a2c503db590ef3e60c7fc3ac0b7405a2cd2eed5580fba27c8c25e3060fd1dd5',
    'Fidget': 'fefab4169d877ecbd7a7cc69d9b9dd54cf33c28d4d83d94ef17da1dde7ecdc6e',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == 'krakens_kraken'
             and [identity['body'] for identity in row['bodies']] == [77])
    assert base['movement_mode'] == 'native_waterline'
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        members = {name.casefold(): name for name in archive.namelist()}
        for clip, digest in DONORS.items():
            raw = archive.read(members[base['clip_sources'][clip].casefold()])
            assert hashlib.sha256(raw).hexdigest() == digest

    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    evidence = {str(slot): reference(ledger, 77, slot, ('anim2.mul', 19, 5, digest))
                for slot, digest in ((11, SHALLOW), (17, SHALLOW), (18, SWEEP))}
    bake = read(ROOT / 'work/creatures/mul-motion-review/kraken-fidgets-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-kraken-fidgets.gd')
    assets, scenes = {}, {}
    for treatment in ('original', 'rounded', 'modern'):
        prefix = 'local-art/creatures/krakens_kraken'
        source = f'{prefix}-{treatment}.gltf'
        output = f'{prefix}-fidgets-{treatment}.scn'
        assert sha(ROOT / 'Viewer' / source) == base['asset_sha256'][treatment]
        scenes[treatment] = sha(ROOT / 'Viewer' / output)
        assert bake['scenes'][treatment] == {'source': base['asset_sha256'][treatment], 'scene': scenes[treatment]}
        assets[treatment] = 'res://' + output
    sources = dict(base['clip_sources'])
    sources['Fidget2'] = sources.pop('Fidget')
    row = dict(base, family='kraken_fidgets', status='prepared', assets=assets, clip_sources=sources,
               native_constructor_hues={'Kraken': 0, 'Leviathan': 0x481},
               authored_action_scene_sha256=scenes, authored_action_reference=evidence['17'],
               classic_motion_references=evidence,
               classic_action_categories=base['classic_action_categories'] | {
                   '11': 'Fidget', '17': 'Fidget', '18': 'Fidget2'},
               authored_replacements=base['authored_replacements'] | {
                   'Fidget': 'Shallow mantle and tentacle pulse on the recovered idle pose for the identical Classic 11 and 17 frames'})
    return [row], CLASSES
