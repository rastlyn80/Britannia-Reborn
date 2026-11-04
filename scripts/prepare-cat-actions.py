"""Pin the additional actions on the independently licensed cat."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
FAMILY = 'cat_actions'
CLASSES = {201: ['Cat']}
SOURCE = 'Art/Creatures/Cat/cat.glb'
LOCAL = 'local-art/creatures/cat-actions.scn'
PUBLIC = 'Art/Creatures/Cat/cat-actions.scn'
VISUAL = 'Presentation/SourceQuadrupedCollapseVisual.gd'
REFERENCES = {
    8: ('Death2', 6, 'fdf1bb11b0128db996cd63c30e6dd8d24bbefd6674817ab22630a5e1f218c562'),
    9: ('CatStretch', 5, 'a13c3cb14d082b7ab576cd17c0d428d3dd3f779b4607e770910f75a42b1ef43a'),
    10: ('Fidget2', 3, '2319edd14522e26f8905ea2a7ac9a8ed0d4bad4da3c4bca94b1379b1eb6a5091'),
    12: ('Death', 6, '31d1a35e814bef49bf204c9c04f84d5d6f7d4471079c80bd24dc7ddc071331a7'),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def prepared(entries=None):
    if entries is None:
        entries = read(VIEWER / 'Art/Creatures/index.json')['entries']
    base, = (row for row in entries if row['kind'] == 'cat_domestic' and row['status'] == 'validated')
    assert base['assets'] == {'modern': 'res://' + SOURCE}
    source = sha(VIEWER / SOURCE)
    assert source == read(VIEWER / 'Art/Creatures/Cat/provenance.json')['asset_sha256']
    scene = sha(VIEWER / LOCAL)
    bake = read(VIEWER / 'local-art/creatures/cat-actions-bake.json')
    assert bake == {
        'source': source, 'scene': scene, 'recipe': sha(ROOT / 'scripts/bake-cat-actions.gd'),
        'skin_solver': sha(VIEWER / 'Presentation/SourceGroundLookup.gd'),
    }
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    groups = {str(slot): reference(ledger, 201, slot, ('anim.mul', 201, frames, digest))
              for slot, (_, frames, digest) in REFERENCES.items()}
    treatments = ('original', 'rounded', 'modern')
    row = dict(base, family=FAMILY, status='prepared', assets=dict.fromkeys(treatments, 'res://' + LOCAL),
               presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
               authored_action_scene_sha256=dict.fromkeys(treatments, scene), authored_action_reference=groups['8'],
               classic_motion_references=groups, native_extra_classic_actions=[8, 12],
               native_constructor_hue_ranges={'Cat': [[2301, 2318]]},
               classic_action_categories={str(slot): clip for slot, (clip, _, _) in REFERENCES.items()},
               authored_replacements=base['authored_replacements'] | {
                   'Death2': 'Authored rear-up and side roll on the licensed cat',
                   'CatStretch': 'Authored low forward stretch with raised tail',
                   'Fidget2': 'Authored short head lift and tail flick',
               })
    return [row], CLASSES


def install():
    index = VIEWER / 'Art/Creatures/index.json'
    previous = index.read_bytes()
    data = json.loads(previous)
    gate = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))
    (base,), (checked,) = gate['checked'](data, False, FAMILY)
    asset = VIEWER / PUBLIC
    provenance = asset.with_name('actions-provenance.json')
    assert not asset.exists() and not provenance.exists()
    scene = checked['authored_action_scene_sha256']['modern']
    row = dict(base, assets={'modern': 'res://' + PUBLIC},
               authored_replacements=checked['authored_replacements'],
               classic_action_categories=checked['classic_action_categories'],
               classic_motion_references=checked['classic_motion_references'],
               presentation_script=checked['presentation_script'],
               presentation_script_sha256=checked['presentation_script_sha256'])
    data['entries'][data['entries'].index(base)] = row
    newline = '\r\n' if b'\r\n' in previous else '\n'
    updated = (json.dumps(data, indent=2) + '\n').replace('\n', newline).encode()
    pending = index.with_suffix('.cat-actions.pending')
    try:
        shutil.copyfile(VIEWER / LOCAL, asset)
        assert sha(asset) == scene
        provenance.write_text(json.dumps({
            'license': 'GPL-3.0-or-later; Quaternius source cat CC0-1.0',
            'predecessor': 'provenance.json',
            'scene_sha256': scene,
            'source_sha256': sha(VIEWER / SOURCE),
            'recipe_sha256': sha(ROOT / 'scripts/bake-cat-actions.gd'),
            'renderer_sha256': row['presentation_script_sha256'],
            'native_receipt_sha256': checked['classic_gesture_native_sha256'],
            'classic_references': row['classic_motion_references'],
            'interpretation': 'Independent hand-authored motions on the licensed cat using visual reference only.',
        }, indent=2) + '\n', encoding='utf-8')
        assert index.read_bytes() == previous
        pending.write_bytes(updated)
        pending.replace(index)
        subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/test-cat-distribution.py')], check=True)
    except (Exception, KeyboardInterrupt):
        if index.read_bytes() == updated:
            pending.write_bytes(previous)
            pending.replace(index)
        asset.unlink(missing_ok=True)
        provenance.unlink(missing_ok=True)
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true', required=True)
    parser.parse_args()
    install()
