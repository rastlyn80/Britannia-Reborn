"""Check and distribute the independently authored Wisp reaction library."""

import argparse
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'Art/Creatures'
INDEX = ART / 'index.json'
PUBLIC = ART / 'Wisp'
SOURCE = PUBLIC / 'wisp.scn'
LIBRARY = PUBLIC / 'distinct-actions.res'
PROOF = PUBLIC / 'distinct-actions-provenance.json'
LOCAL = VIEWER / 'local-art/creatures'
FAMILY = 'wisp_distinct_actions'
CLASSES = {58: ['Wisp', 'CrystalWisp']}
ROUTES = {'10': 'Hit', '15': 'TallFlare', '16': 'SplitFlicker', '17': 'Fidget', '18': 'RayDrift'}
ADDED = {'TallFlare': 'Authored vertical energy flare with compressed side rays',
         'SplitFlicker': 'Authored alternating pulses across opposing rays',
         'RayDrift': 'Authored slow asymmetric sweep through the rays'}
VISUAL = 'Presentation/WispActionsVisual.gd'
PICK_BOUNDS = {'position': [-0.44, -0.02, -0.43], 'size': [0.87, 1.73, 0.86]}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha = (HELPERS[name] for name in ('read', 'sha'))
RECIPE = ROOT / 'scripts/bake-wisp-distinct-actions.gd'


def prepared(entries=None):
    entries = read(INDEX)['entries'] if entries is None else entries
    base, = (row for row in entries if row['kind'] == 'wisp' and row['status'] == 'validated')
    assert base['assets'] == {'modern': 'res://Art/Creatures/Wisp/wisp.scn'}
    assert sha(SOURCE) == read(PUBLIC / 'provenance.json')['asset_sha256'] == base['asset_sha256']
    scene = LOCAL / 'wisp-distinct-candidate.scn'
    library = LOCAL / 'wisp-distinct-actions.res'
    bake = read(LOCAL / 'wisp-distinct-bake.json')
    assert bake == {'source': sha(SOURCE), 'scene': sha(scene), 'library': sha(library), 'recipe': sha(RECIPE)}
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/wisp-distinct-frame-pins.json')['58']
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    refs = {slot: reference(ledger, 58, int(slot), pin) for slot, pin in pins.items()}
    assert set(refs) == set(ROUTES)
    treatments = ('original', 'rounded', 'modern')
    row = dict(base, status='prepared', family=FAMILY,
               assets=dict.fromkeys(treatments, 'res://local-art/creatures/' + scene.name),
               presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
               authored_action_scene_sha256=dict.fromkeys(treatments, sha(scene)),
               authored_action_reference=refs['15'], classic_motion_references=refs,
               native_extra_classic_actions=[10, 15, 16, 18], native_constructor_hues={'Wisp': 0, 'CrystalWisp': 0x482},
               classic_action_categories=ROUTES, pick_bounds=PICK_BOUNDS,
               authored_replacements=base['authored_replacements'] | ADDED)
    return [row], CLASSES


def check_public():
    row, = (row for row in read(INDEX)['entries'] if row['kind'] == 'wisp')
    proof = read(PROOF)
    assert sha(SOURCE) == proof['source_sha256'] and sha(LIBRARY) == proof['animation_library_sha256']
    assert sha(RECIPE) == proof['recipe_sha256']
    assert row['additional_animation_library'] == 'res://Art/Creatures/Wisp/' + LIBRARY.name
    assert row['presentation_script'] == 'res://' + VISUAL and row['presentation_script_sha256'] == sha(VIEWER / VISUAL)
    assert row['classic_action_categories'] == ROUTES and row['pick_bounds'] == PICK_BOUNDS


def install():
    previous = INDEX.read_bytes()
    index = read(INDEX)
    checked = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))['checked']
    (base,), (candidate,) = checked(index, False, FAMILY)
    assert not LIBRARY.exists() and not PROOF.exists()
    library = LOCAL / 'wisp-distinct-actions.res'
    row = dict(base, additional_animation_library='res://Art/Creatures/Wisp/' + LIBRARY.name)
    for key in ('authored_replacements', 'classic_action_categories', 'classic_motion_references', 'pick_bounds',
                'presentation_script', 'presentation_script_sha256'):
        row[key] = candidate[key]
    row['stats'] = {name: stats | {'clips': stats['clips'] | {clip: {'authored': True} for clip in ADDED}}
                    for name, stats in base['stats'].items()}
    index['entries'][index['entries'].index(base)] = row
    newline = '\r\n' if b'\r\n' in previous else '\n'
    updated = (json.dumps(index, indent=2, ensure_ascii=False) + '\n').replace('\n', newline).encode()
    pending = INDEX.with_suffix('.wisp-actions.pending')
    assert INDEX.read_bytes() == previous
    try:
        shutil.copyfile(library, LIBRARY)
        assert sha(LIBRARY) == sha(library)
        PROOF.write_text(json.dumps({
            'license': 'GPL-3.0-or-later, independently authored motions on the original project Wisp rig',
            'source': SOURCE.name, 'source_sha256': sha(SOURCE), 'animation_library_sha256': sha(LIBRARY),
            'recipe_sha256': sha(RECIPE), 'native_report_sha256': candidate['classic_gesture_native_sha256'],
            'scope': 'Three authored ray and energy-root animations. The original project mesh, rig and shader remain intact.',
        }, indent=2) + '\n', encoding='utf-8')
        pending.write_bytes(updated)
        pending.replace(INDEX)
        check_public()
        subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/test-wisp-distribution.py')], check=True)
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
