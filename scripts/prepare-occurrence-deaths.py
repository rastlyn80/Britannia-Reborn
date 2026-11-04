"""Fit Classic deaths over the existing Orc and Ettin reaction packages."""

import hashlib
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
FAMILY = 'occurrence_deaths'
CLASSES = {17: ['Orc'], 18: ['Ettin']}
REFERENCES = {
    17: {2: '937752c59a4d1746b10da4614c9c79ff5b0d99cd09ccee57202f2aa756b0deb6',
         3: '5177aee7649ac44517157b6a72ae7e004e1f6b08b49894d964c60cb33cee8624'},
    18: {2: 'a9eadae8559ecc59b46c5ca476e40c15dd25f36ee7589e9954ced760076bd6c1',
         3: 'a2ba6005e6fbdf5af80626bfb3708d82f8950827ef9d4f7a77daf871b13efed7'},
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    bake = read(ROOT / 'Viewer/local-art/creatures/occurrence-death-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-occurrence-deaths.gd')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    rows = []
    for body in CLASSES:
        base, = (row for row in entries if row['status'] == 'validated'
                 and row.get('classic_gesture_batch') == 'orc_ettin_reactions'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assets, scenes = {}, {}
        for treatment, source in base['assets'].items():
            output = f'res://local-art/creatures/occurrence-death-{body}-{treatment}.scn'
            source_hash = sha(ROOT / 'Viewer' / source.removeprefix('res://'))
            assert source_hash == base['asset_sha256'][treatment]
            scenes[treatment] = sha(ROOT / 'Viewer' / output.removeprefix('res://'))
            assert bake['scenes'][str(body)][treatment] == {'source': source_hash, 'scene': scenes[treatment]}
            assets[treatment] = output
        evidence = {str(slot): reference(ledger, body, slot, ('anim.mul', body, 4, digest))
                    for slot, digest in REFERENCES[body].items()}
        rows.append(dict(base, status='prepared', family=FAMILY, assets=assets,
                         presentation_script='res://Presentation/SourceClassicCollapseVisual.gd',
                         authored_action_scene_sha256=scenes, authored_action_reference=evidence['2'],
                         classic_motion_references=evidence, native_extra_classic_actions=[2, 3],
                         classic_action_categories=base['classic_action_categories'] | {'2': 'Death2', '3': 'Death'},
                         authored_replacements=base['authored_replacements'] | {
                             'Death2': 'Rear collapse fitted to the five stored views of Classic group 2'}))
    return rows, CLASSES
