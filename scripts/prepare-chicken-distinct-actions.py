"""Check and distribute the Chicken distinct action library."""

import argparse
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'Art/Creatures'
INDEX = ART / 'index.json'
PUBLIC = ART / 'Chicken'
SOURCE = PUBLIC / 'chicken.glb'
LIBRARY = PUBLIC / 'distinct-actions.res'
PROOF = PUBLIC / 'distinct-actions-provenance.json'
LOCAL = VIEWER / 'local-art/creatures'
FAMILY = 'chicken_distinct_actions'
CLASSES = {208: ['Chicken']}
ROUTES = {'4': 'SourcePecking2', '5': 'Attack', '6': 'RearStrike', '8': 'Death',
          '9': 'Fidget', '10': 'SourceIdle2', '12': 'Death2'}
ADDED = {'RearStrike': 'Authored rear and forward strike with a raised foot',
         'Death2': 'Authored seated collapse with separately folded legs'}
VISUAL = 'Presentation/ChickenActionsVisual.gd'
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha = (HELPERS[name] for name in ('read', 'sha'))
RECIPE = ROOT / 'scripts/bake-chicken-distinct-actions.gd'


def prepared(entries=None):
    entries = read(INDEX)['entries'] if entries is None else entries
    base, = (row for row in entries if row['kind'] == 'chicken' and row['status'] == 'validated')
    assert base['assets'] == {'modern': 'res://Art/Creatures/Chicken/chicken.glb'}
    assert sha(SOURCE) == read(PUBLIC / 'provenance.json')['asset_sha256']
    scene = LOCAL / 'chicken-distinct-candidate.scn'
    library = LOCAL / 'chicken-distinct-actions.res'
    bake = read(LOCAL / 'chicken-distinct-bake.json')
    assert bake == {'source': sha(SOURCE), 'scene': sha(scene), 'library': sha(library), 'recipe': sha(RECIPE)}
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/chicken-distinct-frame-pins.json')['208']
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    refs = {slot: reference(ledger, 208, int(slot), pin) for slot, pin in pins.items()}
    assert set(refs) == set(ROUTES)
    treatments = ('original', 'rounded', 'modern')
    row = dict(base, status='prepared', family=FAMILY,
               assets=dict.fromkeys(treatments, 'res://local-art/creatures/' + scene.name),
               presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
               authored_action_scene_sha256=dict.fromkeys(treatments, sha(scene)),
               authored_action_reference=refs['6'], classic_motion_references=refs,
               native_extra_classic_actions=[4, 6, 8, 10, 12], native_constructor_hues={'Chicken': 0},
               classic_action_categories=ROUTES,
               authored_replacements=base['authored_replacements'] | ADDED)
    return [row], CLASSES


def check_public():
    row, = (row for row in read(INDEX)['entries'] if row['kind'] == 'chicken')
    proof = read(PROOF)
    assert sha(SOURCE) == proof['source_sha256'] and sha(LIBRARY) == proof['animation_library_sha256']
    assert sha(RECIPE) == proof['recipe_sha256']
    assert row['additional_animation_library'] == 'res://Art/Creatures/Chicken/' + LIBRARY.name
    assert row['presentation_script'] == 'res://' + VISUAL and row['presentation_script_sha256'] == sha(VIEWER / VISUAL)
    assert row['classic_action_categories'] == ROUTES
    gate = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    gate['run_client_check'](godot, dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile),
                             'res://../scripts/test-chicken-distinct-landings.gd', [])


def install():
    previous = INDEX.read_bytes()
    index = read(INDEX)
    checked = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))['checked']
    (base,), (candidate,) = checked(index, False, FAMILY)
    assert not LIBRARY.exists() and not PROOF.exists()
    library = LOCAL / 'chicken-distinct-actions.res'
    row = dict(base, additional_animation_library='res://Art/Creatures/Chicken/' + LIBRARY.name)
    for key in ('authored_replacements', 'classic_action_categories', 'classic_motion_references',
                'presentation_script', 'presentation_script_sha256'):
        row[key] = candidate[key]
    row['stats'] = {name: stats | {'clips': stats['clips'] | {clip: {'authored': True} for clip in ADDED}}
                    for name, stats in base['stats'].items()}
    index['entries'][index['entries'].index(base)] = row
    newline = '\r\n' if b'\r\n' in previous else '\n'
    updated = (json.dumps(index, indent=2, ensure_ascii=False) + '\n').replace('\n', newline).encode()
    pending = INDEX.with_suffix('.chicken-actions.pending')
    assert INDEX.read_bytes() == previous
    try:
        shutil.copyfile(library, LIBRARY)
        assert sha(LIBRARY) == sha(library)
        PROOF.write_text(json.dumps({
            'license': 'GPL-3.0-or-later, independently authored motions on the CC0 CDmir hen rig',
            'source': SOURCE.name, 'source_sha256': sha(SOURCE), 'animation_library_sha256': sha(LIBRARY),
            'recipe_sha256': sha(RECIPE), 'native_report_sha256': candidate['classic_gesture_native_sha256'],
            'scope': 'Two independently fitted animations. The existing mesh, rig, textures and source clips remain intact.',
        }, indent=2) + '\n', encoding='utf-8')
        pending.write_bytes(updated)
        pending.replace(INDEX)
        check_public()
        subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/test-chicken-distribution.py')], check=True)
    except (Exception, KeyboardInterrupt):
        if INDEX.read_bytes() == updated:
            pending.write_bytes(previous)
            pending.replace(INDEX)
        LIBRARY.unlink(missing_ok=True)
        PROOF.unlink(missing_ok=True)
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--install', action='store_true')
    mode.add_argument('--check-public', action='store_true')
    args = parser.parse_args()
    install() if args.install else check_public()
