"""Pin occurrence-ranked motion overlays and their unmodified model inputs."""

from contextlib import contextmanager
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
LOCAL = VIEWER / 'local-art/creatures'
PUBLIC = VIEWER / 'Art/Creatures'
FAMILY = 'occurrence_gestures'
CLASSES = {124: ['EvilMage'], 240: ['Kappa'], 250: ['TsukiWolf'], 779: ['Bogling']}
MODELS = {124: 'evil-mage', 240: 'kappa', 250: 'tsuki-wolf'}
ROUTES = {
    124: {'2': 'Death', '3': 'Death', '6': 'RaisedCast', '12': 'Cast2', '14': 'Cast2',
          '15': 'WardRecoil', '16': 'WardRecoil', '18': 'StafflessBend'},
    240: {'11': 'Fidget', '15': 'ShellRecoilLeft', '16': 'ShellRecoilRight', '17': 'JawAlert', '18': 'Fidget'},
    250: {'11': 'Fidget', '15': 'PackGuardLeft', '16': 'PackGuardRight', '17': 'ThreeHeadAlert', '18': 'Fidget'},
    779: {'15': 'RootGuard', '16': 'RootGuard', '18': 'Uncurl'},
}
EXTRAS = {124: [2, 3, 15, 16, 18], 240: [15, 16, 18], 250: [15, 16, 18], 779: [15, 16, 18]}
FITTED = {124: (6, 15, 18), 240: (15, 16, 17), 250: (15, 16, 17), 779: (15, 18)}
TREATMENTS = ('original', 'rounded', 'modern')
PUBLIC_INDEX = PUBLIC / 'index.json'
BOGLING_LIBRARY = PUBLIC / 'Bogling/distinct-actions.res'
BOGLING_PROOF = PUBLIC / 'Bogling/distinct-actions-provenance.json'
BOGLING_RECIPE = ROOT / 'scripts/bake-bogling-distinct-actions.gd'
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha, read_bake = (HELPERS[key] for key in ('read', 'sha', 'read_bake'))


def prepared(entries=None):
    if entries is None:
        entries = read(VIEWER / 'local-art/creatures/accepted-index.json')['entries']
        entries = combined_index({'entries': entries})['entries']
        if any(row.get('classic_gesture_batch') == FAMILY for row in entries):
            entries = read(ROOT / 'work/creatures' / FAMILY / 'accepted-native/base-rows.json')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/occurrence-gestures-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base.get('classic_action_categories', {}).items() <= routes.items()
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        if body == 779:
            paths = bogling_candidate(base)
        else:
            paths = local_scenes(base, body)
        added = {routes[str(slot)]: f'Fitted rig motion from Classic group {slot}' for slot in FITTED[body]}
        row = dict(base, **paths)
        row.update(status='prepared', family=FAMILY, classic_action_categories=routes,
                   classic_motion_references=refs, authored_action_reference=refs[str(FITTED[body][0])],
                   native_extra_classic_actions=EXTRAS[body],
                   authored_replacements=base.get('authored_replacements', {}) | added)
        if body != 250:
            row['native_constructor_hues'] = {CLASSES[body][0]: 0}
        rows.append(row)
    return rows, CLASSES


def local_scenes(base, body):
    stem = MODELS[body] + '-distinct-actions'
    recipe = read_bake(stem, ('bake-occurrence-gestures.gd', 'bake-zombie-actions.gd',
                              'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))[str(body)]
    assets, scenes, originals = {}, {}, {}
    for treatment in TREATMENTS:
        original = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
        source = sha(VIEWER / original.removeprefix('res://'))
        scene = f'{stem}-{treatment}.scn'
        digest = sha(LOCAL / scene)
        assert source == base['asset_sha256'][treatment] and recipe[treatment] == {'source': source, 'scene': digest}
        assets[treatment] = 'res://local-art/creatures/' + scene
        scenes[treatment] = digest
        originals[treatment] = original
    return dict(assets=assets, authored_action_scene_sha256=scenes, classic_gesture_base_assets=originals)


def bogling_candidate(base):
    source = PUBLIC / 'Bogling/bogling.glb'
    assert sha(source) == base['asset_sha256'] == read(source.with_name('provenance.json'))['asset_sha256']
    scene = LOCAL / 'bogling-distinct-candidate.scn'
    library = LOCAL / 'bogling-distinct-actions.res'
    visual = 'Presentation/BoglingActionsVisual.gd'
    return dict(assets=dict.fromkeys(TREATMENTS, 'res://local-art/creatures/' + scene.name),
                authored_action_scene_sha256=dict.fromkeys(TREATMENTS, sha(scene)),
                classic_gesture_base_assets=dict.fromkeys(TREATMENTS, base['assets']['modern']),
                additional_animation_library='res://local-art/creatures/' + library.name,
                additional_animation_sha256=sha(library),
                presentation_script='res://' + visual, presentation_script_sha256=sha(VIEWER / visual))


def combined_index(index):
    assert not any(row['kind'] == 'bogling' for row in index['entries'])
    bogling, = (row for row in read(PUBLIC_INDEX)['entries'] if row['kind'] == 'bogling')
    return dict(index, entries=index['entries'] + [bogling])


def public_bogling(base, candidate, native_sha):
    fields = ('authored_replacements', 'classic_action_categories', 'classic_motion_references',
              'presentation_script', 'presentation_script_sha256', 'additional_animation_sha256')
    row = dict(base, **{field: candidate[field] for field in fields})
    row.update(additional_animation_library='res://Art/Creatures/Bogling/' + BOGLING_LIBRARY.name,
               classic_gesture_batch=FAMILY, classic_gesture_native_sha256=native_sha,
               classic_gesture_base_assets=base['assets'])
    added = {ROUTES[779][str(slot)]: {'authored': True} for slot in FITTED[779]}
    row['stats'] = {name: stats | {'clips': stats['clips'] | added}
                    for name, stats in base['stats'].items()}
    return row


def check_public_bogling():
    row, = (row for row in read(PUBLIC_INDEX)['entries'] if row['kind'] == 'bogling')
    proof = read(BOGLING_PROOF)
    assert row['classic_gesture_batch'] == FAMILY and row['classic_action_categories'] == ROUTES[779]
    assert row['additional_animation_library'] == 'res://Art/Creatures/Bogling/' + BOGLING_LIBRARY.name
    assert sha(BOGLING_LIBRARY) == proof['animation_library_sha256'] == row['additional_animation_sha256']
    assert sha(BOGLING_RECIPE) == proof['recipe_sha256']
    assert sha(BOGLING_LIBRARY.with_name('bogling.glb')) == proof['source_sha256'] == row['asset_sha256']
    assert row['classic_gesture_native_sha256'] == proof['native_report_sha256']


@contextmanager
def install_bogling(base, row):
    previous = PUBLIC_INDEX.read_bytes()
    index = read(PUBLIC_INDEX)
    assert index['entries'].count(base) == 1
    index['entries'][index['entries'].index(base)] = row
    newline = '\r\n' if b'\r\n' in previous else '\n'
    updated = (json.dumps(index, indent=2, ensure_ascii=False) + '\n').replace('\n', newline).encode()
    pending = PUBLIC_INDEX.with_suffix('.bogling-actions.pending')
    assert not BOGLING_LIBRARY.exists() and not BOGLING_PROOF.exists()
    assert PUBLIC_INDEX.read_bytes() == previous
    try:
        shutil.copyfile(LOCAL / 'bogling-distinct-actions.res', BOGLING_LIBRARY)
        assert sha(BOGLING_LIBRARY) == row['additional_animation_sha256']
        BOGLING_PROOF.write_text(json.dumps({
            'license': 'GPL-3.0-or-later, independently authored motions on the CC0 Tennessippi rig',
            'source': 'bogling.glb',
            'source_sha256': row['asset_sha256'],
            'animation_library_sha256': row['additional_animation_sha256'],
            'recipe_sha256': sha(BOGLING_RECIPE),
            'native_report_sha256': row['classic_gesture_native_sha256'],
        }, indent=2) + '\n', encoding='utf-8')
        pending.write_bytes(updated)
        pending.replace(PUBLIC_INDEX)
        check_public_bogling()
        subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/test-bogling-distribution.py')], check=True)
        yield
    except (Exception, KeyboardInterrupt):
        if PUBLIC_INDEX.read_bytes() == updated:
            pending.write_bytes(previous)
            pending.replace(PUBLIC_INDEX)
        BOGLING_LIBRARY.unlink(missing_ok=True)
        BOGLING_PROOF.unlink(missing_ok=True)
        raise


if __name__ == '__main__':
    rows, classes = prepared()
    print(json.dumps({'rows': len(rows), 'bodies': list(classes)}))

