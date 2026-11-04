"""Pin and install authored motions on the independently licensed rabbit."""

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
LOCAL = VIEWER / 'local-art/creatures'
ASSET = ART / 'Rabbit/distinct-actions.res'
PROOF = ART / 'Rabbit/distinct-actions-provenance.json'
SOURCE = ART / 'Rabbit/rabbit.glb'
FAMILY = 'rabbit_distinct_actions'
CLASSES = {205: ['Rabbit', 'JackRabbit']}
ROUTES = {5: 'Attack', 6: 'RabbitLunge', 8: 'Death', 9: 'Fidget', 10: 'RabbitEarCheck', 12: 'Death2'}
VISUAL = 'Presentation/RabbitActionsVisual.gd'
EXTRA = {'RabbitLunge': 'Authored short lunge on the licensed source rig',
         'RabbitEarCheck': 'Authored head turn and asymmetric ear movement',
         'Death2': 'Authored side collapse on the licensed body and fur skins'}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha = (HELPERS[name] for name in ('read', 'sha'))


def prepared(entries=None):
    entries = read(INDEX)['entries'] if entries is None else entries
    base, = (row for row in entries if row['kind'] == 'rabbit' and row['status'] == 'validated')
    assert base['assets'] == {'modern': 'res://Art/Creatures/Rabbit/rabbit.glb'}
    assert sha(SOURCE) == read(SOURCE.with_name('provenance.json'))['asset_sha256']
    scene = LOCAL / 'rabbit-actions-candidate.scn'
    library = LOCAL / 'rabbit-distinct-actions.res'
    bake = read(LOCAL / 'rabbit-distinct-actions-bake.json')
    inputs = [ROOT / 'scripts/bake-rabbit-distinct-actions.gd', ROOT / 'scripts/bake-cat-actions.gd',
              VIEWER / 'Presentation/SourceGroundLookup.gd']
    assert bake == {'source': sha(SOURCE), 'scene': sha(scene), 'library': sha(library),
                    'inputs': {path.name: sha(path) for path in inputs}}
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/rabbit-distinct-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))['reference']
    refs = {slot: reference(ledger, 205, int(slot), ('anim.mul', 205, frames, digest))
            for slot, (frames, digest) in pins.items()}
    assert set(refs) == {str(slot) for slot in ROUTES}
    treatments = ('original', 'rounded', 'modern')
    candidate = dict(base, status='prepared', family=FAMILY,
                     assets=dict.fromkeys(treatments, 'res://local-art/creatures/' + scene.name),
                     presentation_script='res://' + VISUAL, presentation_script_sha256=sha(VIEWER / VISUAL),
                     authored_action_scene_sha256=dict.fromkeys(treatments, sha(scene)),
                     authored_action_reference=refs['8'], classic_motion_references=refs,
                     native_constructor_hue_ranges={'Rabbit': [[0, 0], [2301, 2318]], 'JackRabbit': [[443, 443]]},
                     native_extra_classic_actions=[6, 8, 10, 12],
                     classic_action_categories={str(slot): clip for slot, clip in ROUTES.items()},
                     authored_replacements=base['authored_replacements'] | EXTRA)
    return [candidate], CLASSES


def install():
    previous = INDEX.read_bytes()
    index = read(INDEX)
    check = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))['checked']
    (base,), (candidate,) = check(index, False, FAMILY)
    assert not ASSET.exists() and not PROOF.exists()
    library = LOCAL / 'rabbit-distinct-actions.res'
    row = dict(base, additional_animation_library='res://Art/Creatures/Rabbit/' + ASSET.name)
    for key in ('authored_replacements', 'classic_action_categories', 'classic_motion_references',
                'presentation_script', 'presentation_script_sha256'):
        row[key] = candidate[key]
    stats = base['stats']['modern']
    clips = stats['clips'] | {clip: {'authored': True} for clip in EXTRA}
    row['stats'] = base['stats'] | {'modern': stats | {'clips': clips}}
    index['entries'][index['entries'].index(base)] = row
    assert INDEX.read_bytes() == previous
    newline = '\r\n' if b'\r\n' in previous else '\n'
    updated = (json.dumps(index, indent=2, ensure_ascii=False) + '\n').replace('\n', newline).encode()
    pending = INDEX.with_suffix('.rabbit-actions.pending')
    try:
        shutil.copyfile(library, ASSET)
        assert sha(ASSET) == sha(library)
        PROOF.write_text(json.dumps({
            'license': 'GPL-3.0-or-later authored animations on the retained CC0-1.0 rabbit rig',
            'source': SOURCE.name, 'source_sha256': sha(SOURCE), 'animation_library_sha256': sha(ASSET),
            'native_report_sha256': candidate['classic_gesture_native_sha256'],
            'recipe_sha256': sha(ROOT / 'scripts/bake-rabbit-distinct-actions.gd'),
            'scope': 'Three authored animation clips. No proprietary sprites, meshes or motion keys are included.',
        }, indent=2) + '\n', encoding='utf-8')
        pending.write_bytes(updated)
        pending.replace(INDEX)
        subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/test-rabbit-distribution.py')], check=True)
        check_public()
    except (Exception, KeyboardInterrupt):
        if INDEX.read_bytes() == updated:
            pending.write_bytes(previous)
            pending.replace(INDEX)
        ASSET.unlink(missing_ok=True)
        PROOF.unlink(missing_ok=True)
        raise
    print('RABBIT DISTINCT ACTIONS: active and independently distributable')


def check_public():
    row, = (row for row in read(INDEX)['entries'] if row['kind'] == 'rabbit')
    proof = read(PROOF)
    assert sha(SOURCE) == proof['source_sha256'] and sha(ASSET) == proof['animation_library_sha256']
    assert proof['recipe_sha256'] == sha(ROOT / 'scripts/bake-rabbit-distinct-actions.gd')
    assert row['additional_animation_library'] == 'res://Art/Creatures/Rabbit/' + ASSET.name
    assert row['presentation_script'] == 'res://' + VISUAL and row['presentation_script_sha256'] == sha(VIEWER / VISUAL)
    assert row['classic_action_categories'] == {str(slot): clip for slot, clip in ROUTES.items()}
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    result = subprocess.run([str(godot), '--headless', '--path', str(VIEWER), '--script',
                             'res://../scripts/test-rabbit-distinct-deaths.gd'],
                            env=dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile), timeout=45,
                            capture_output=True, text=True, encoding='utf-8', errors='replace')
    output = result.stdout + result.stderr
    print(output.strip())
    assert result.returncode == 0 and 'ERROR:' not in output, output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--install', action='store_true')
    action.add_argument('--check-public', action='store_true')
    args = parser.parse_args()
    if args.install:
        install()
    else:
        check_public()
