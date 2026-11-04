"""Check the Classic sea turn and strike against the recovered 3D baseline."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
STEM = 'sea_serpents_sea_serpent'
CLASSES = {150: ['DeepSeaSerpent', 'SeaSerpent']}
REFERENCES = {
    '3': ('Fidget', 15, 'a416825b25700eeb8608609a68f9ae52f1ee245597970bf5e308be599700201c'),
    '4': ('Fidget2', 20, '8b218f24de00f60a7b3b0dde8955a5cd0a3ca5574a967a86b4974d2ff85a875b'),
    '5': ('Attack', 15, 'ca643e11e0638633815abdcbad1227433db3ace4ecab24e30ae89c6bfc587089'),
    '6': ('Attack2', 20, '8b9fd0710663140ae14c1c71bc6ac419fecc07aa397c87fe8dc77a4fdeef4826'),
}
DONORS = {
    'Idle': '00f0e88a2e1df1004b8b8c08098db4a009645e3a671458595e065010f710923c',
    'Fidget': '1e8c05ac3a226b3ccb016c1082f50a3b61250559adb23f82b657c6fdc56ea0d7',
    'Attack': 'de5901df9350edda3b96ddd69cd2d64f03b2c4c0d30c6f423d14969490aed938',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    base, = (row for row in entries if row['status'] == 'validated' and row['kind'] == STEM
             and [identity['body'] for identity in row['bodies']] == [150, 145])
    assert base['movement_mode'] == 'native_waterline'
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        for label, digest in DONORS.items():
            assert hashlib.sha256(archive.read(base['clip_sources'][label])).hexdigest() == digest

    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    evidence = {slot: reference(ledger, 150, int(slot), ('anim.mul', 150, frames, digest))
                for slot, (_, frames, digest) in REFERENCES.items()}
    art = ROOT / 'Viewer/local-art/creatures'
    bake = read(art / f'{STEM}-classic-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-sea-serpent-actions.gd')
    assets, scenes = {}, {}
    for treatment in ('original', 'rounded', 'modern'):
        source = f'{STEM}-{treatment}.gltf'
        output = f'{STEM}-classic-{treatment}.scn'
        assert sha(art / source) == base['asset_sha256'][treatment]
        scenes[treatment] = sha(art / output)
        assert bake['scenes'][treatment] == {'source': base['asset_sha256'][treatment], 'scene': scenes[treatment]}
        assets[treatment] = 'res://local-art/creatures/' + output
    row = dict(base, status='prepared', family='sea_serpent_actions', bodies=[base['bodies'][0]], assets=assets,
               native_constructor_hue_ranges={'DeepSeaSerpent': [[0x8A0, 0x8A4]], 'SeaSerpent': [[0x530, 0x538]]},
               authored_action_scene_sha256=scenes, authored_action_reference=evidence['4'],
               classic_motion_references=evidence,
               classic_action_categories=base.get('classic_action_categories', {}) | {
                   slot: clip for slot, (clip, _, _) in REFERENCES.items()},
               authored_replacements=base['authored_replacements'] | {
                   'Fidget2': 'Curling surface turn following the 20-frame Classic group 4',
                   'Attack2': 'Dive and rising open-jaw strike following the 20-frame Classic group 6'})
    return [row], CLASSES
