"""Check and distribute the Fire Elemental reaction library."""

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
PUBLIC = ART / 'Fire'
SOURCE = PUBLIC / 'fire-elemental.scn'
LIBRARY = PUBLIC / 'distinct-actions.res'
PROOF = PUBLIC / 'distinct-actions-provenance.json'
LOCAL = VIEWER / 'local-art/creatures'
FAMILY = 'fire_distinct_actions'
CLASSES = {15: ['FireElemental', 'SummonedFireElemental']}
ROUTES = {'10': 'Hit', '15': 'EmberFlinch', '16': 'FlameGuard', '17': 'Fidget', '18': 'FlareSpread'}
ADDED = {'EmberFlinch': 'Authored side bend and sweeping lower arms',
         'FlameGuard': 'Authored hunched brace with a raised forearm',
         'FlareSpread': 'Authored opening of the arms during a flame fidget'}
VISUAL = 'Presentation/FireActionsVisual.gd'
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha = (HELPERS[name] for name in ('read', 'sha'))
RECIPE = ROOT / 'scripts/bake-fire-distinct-actions.gd'


def prepared(entries=None):
    entries = read(INDEX)['entries'] if entries is None else entries
    base, = (row for row in entries if row['kind'] == 'fire_elemental' and row['status'] == 'validated')
    assert base['assets'] == {'modern': 'res://Art/Creatures/Fire/fire-elemental.scn'}
    assert sha(SOURCE) == read(PUBLIC / 'provenance.json')['preparation']['asset_sha256'] == base['asset_sha256']
    scene = LOCAL / 'fire-distinct-candidate.scn'
    library = LOCAL / 'fire-distinct-actions.res'
    bake = read(LOCAL / 'fire-distinct-bake.json')
    assert bake == {'source': sha(SOURCE), 'scene': sha(scene), 'library': sha(library), 'recipe': sha(RECIPE)}
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/fire-distinct-frame-pins.json')['15']
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    refs = {slot: reference(ledger, 15, int(slot), pin) for slot, pin in pins.items()}
    assert set(refs) == set(ROUTES)
    treatments = ('original', 'rounded', 'modern')
    row = dict(base, status='prepared', family=FAMILY,
               assets=dict.fromkeys(treatments, 'res://local-art/creatures/' + scene.name),
               presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
               authored_action_scene_sha256=dict.fromkeys(treatments, sha(scene)),
               authored_action_reference=refs['15'], classic_motion_references=refs,
               native_extra_classic_actions=[10, 15, 16, 18], native_constructor_hues={'FireElemental': 0, 'SummonedFireElemental': 0},
               classic_action_categories=base["classic_action_categories"] | ROUTES,
               authored_replacements=base['authored_replacements'] | ADDED)
    return [row], CLASSES


def check_public():
    row, = (row for row in read(INDEX)['entries'] if row['kind'] == 'fire_elemental')
    proof = read(PROOF)
    assert sha(SOURCE) == proof['source_sha256'] and sha(LIBRARY) == proof['animation_library_sha256']
    assert sha(RECIPE) == proof['recipe_sha256']
    assert row['additional_animation_library'] == 'res://Art/Creatures/Fire/' + LIBRARY.name
    assert row['presentation_script'] == 'res://' + VISUAL and row['presentation_script_sha256'] == sha(VIEWER / VISUAL)
    assert row['classic_action_categories'] == ({'7': 'ElementalOverhead', '8': 'ElementalHeldReach'} | ROUTES)


def install():
    previous = INDEX.read_bytes()
    index = read(INDEX)
    checked = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))['checked']
    (base,), (candidate,) = checked(index, False, FAMILY)
    assert not LIBRARY.exists() and not PROOF.exists()
    library = LOCAL / 'fire-distinct-actions.res'
    row = dict(base, additional_animation_library='res://Art/Creatures/Fire/' + LIBRARY.name)
    for key in ('authored_replacements', 'classic_action_categories', 'classic_motion_references',
                'presentation_script', 'presentation_script_sha256'):
        row[key] = candidate[key]
    row['stats'] = {name: stats | {'clips': stats['clips'] | {clip: {'authored': True} for clip in ADDED}}
                    for name, stats in base['stats'].items()}
    index['entries'][index['entries'].index(base)] = row
    newline = '\r\n' if b'\r\n' in previous else '\n'
    updated = (json.dumps(index, indent=2, ensure_ascii=False) + '\n').replace('\n', newline).encode()
    pending = INDEX.with_suffix('.fire-actions.pending')
    assert INDEX.read_bytes() == previous
    try:
        shutil.copyfile(library, LIBRARY)
        assert sha(LIBRARY) == sha(library)
        PROOF.write_text(json.dumps({
            'license': 'GPL-3.0-or-later, independently authored motions on the CC0 Quaternius carrier retained by the project Fire Elemental',
            'source': SOURCE.name, 'source_sha256': sha(SOURCE), 'animation_library_sha256': sha(LIBRARY),
            'recipe_sha256': sha(RECIPE), 'native_report_sha256': candidate['classic_gesture_native_sha256'],
            'scope': 'Three fitted body and arm animations. The original project mesh, rig and shader remain intact.',
        }, indent=2) + '\n', encoding='utf-8')
        pending.write_bytes(updated)
        pending.replace(INDEX)
        check_public()
        subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/test-fire-distribution.py')], check=True)
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
