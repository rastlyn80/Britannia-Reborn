"""Check Slime, Mummy and Giant Toad motion overlays and source floor samples."""

import argparse
from hashlib import sha256
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
LOCAL = VIEWER / 'local-art/creatures'
FAMILY = 'lowland_creature_gestures'
CLASSES = {51: ['Slime', 'CorrosiveSlime', 'Jwilson'], 154: ['Mummy', 'PestilentBandage'], 80: ['GiantToad']}
SLIME_HUES = {'Slime': [[2201, 2224]], 'CorrosiveSlime': [[2201, 2224]],
              'Jwilson': [[value, value] for value in (0x89C, 0x8A2, 0x8A8, 0x8AE)]}
STEMS = {51: 'slime', 154: 'mummy', 80: 'giant-toad'}
ROUTES = {
    51: {'17': 'Fidget', '18': 'CrestRise'},
    154: {'11': 'Fidget', '15': 'MummyRecoil', '16': 'MummyRecoil', '17': 'Fidget', '18': 'MummyCurl'},
    80: {'4': 'Attack', '6': 'SpringLunge', '10': 'Hit', '11': 'ToadGulp',
         '15': 'HindBrace', '16': 'BellyDuck', '17': 'Fidget', '18': 'ThroatPulse'},
}
FITTED = {51: (18,), 154: (15, 18), 80: (6, 15, 16, 18)}
EXTRAS = {51: [18], 154: [15, 16, 18], 80: [10, 15, 16, 18]}
HELPERS = runpy.run_path(str(ROOT / 'scripts/prepare-field-fauna.py'))
read, sha, read_bake = (HELPERS[key] for key in ('read', 'sha', 'read_bake'))


def prepared(entries):
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    pins = read(ROOT / 'scripts/lowland-creature-gesture-frame-pins.json')
    reference = runpy.run_path(str(ROOT / 'scripts/prepare-earth-gazer-imp-actions.py'))['reference']
    rows = []
    for body, routes in ROUTES.items():
        base, = (row for row in entries if row['status'] == 'validated'
                 and [identity['body'] for identity in row['bodies']] == [body])
        assert base.get('classic_action_categories', {}).items() <= routes.items()
        refs = {slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()}
        assert refs.keys() == routes.keys()
        for slot, previous in base.get('classic_motion_references', {}).items():
            assert previous.items() <= refs[slot].items()
            refs[slot] = previous
        stem = STEMS[body] + '-distinct-actions'
        bake = read_bake(stem, ('bake-lowland-creature-gestures.gd', 'bake-zombie-actions.gd',
                               'bake-troll-actions.gd', 'bake-skeleton-actions.gd'))[str(body)]
        originals, assets, hashes = {}, {}, {}
        for treatment in ('original', 'rounded', 'modern'):
            original = base.get('assets', {}).get(treatment, f"res://local-art/creatures/{base['kind']}-{treatment}.gltf")
            source = sha(VIEWER / original.removeprefix('res://'))
            name = f'{stem}-{treatment}.scn'
            digest = sha(LOCAL / name)
            assert source == base['asset_sha256'][treatment] and bake[treatment] == {'source': source, 'scene': digest}
            originals[treatment] = original
            assets[treatment] = 'res://local-art/creatures/' + name
            hashes[treatment] = digest
        added = {routes[str(slot)]: f'Fitted motion from Classic group {slot}' for slot in FITTED[body]}
        row = dict(base, status='prepared', family=FAMILY, assets=assets, authored_action_scene_sha256=hashes,
                   classic_gesture_base_assets=originals, classic_action_categories=routes, classic_motion_references=refs,
                   authored_action_reference=refs[str(FITTED[body][0])], native_extra_classic_actions=EXTRAS[body],
                   authored_replacements=base.get('authored_replacements', {}) | added)
        if body == 51:
            row['native_constructor_hue_ranges'] = SLIME_HUES
        elif body == 154:
            row.update(native_constructor_hues={'Mummy': 0, 'PestilentBandage': 0x515},
                       **mummy_ground_overlay(base, hashes))
        else:
            row['native_constructor_hues'] = {'GiantToad': 0}
        rows.append(row)
    return rows, CLASSES


def combined_mummy_curves(original, original_digest):
    measured = read(LOCAL / 'mummy-distinct-actions-ground-measured.json')
    assert original['sample_rate'] == measured['sample_rate'] == 960
    assert measured['predecessor_sha256'] == original_digest
    assert measured['overlay_recipe_sha256'] == sha(ROOT / 'scripts/bake-mummy-distinct-ground.gd')
    treatments = {}
    for name, prior in original['treatments'].items():
        added = measured['treatments'][name]
        assert not (prior['clips'].keys() & added['clips'].keys())
        treatments[name] = prior | added | {'clips': prior['clips'] | added['clips']}
    return original | measured | {'treatments': treatments}


def mummy_ground_overlay(base, scene_hashes):
    prior_path = VIEWER / base['ground_lookup'].removeprefix('res://')
    overlay = LOCAL / 'mummy-distinct-actions-ground.json'
    old, new = read(prior_path), read(overlay)
    predecessor_bytes = prior_path.read_bytes()
    if old['preparation_sha256'] != new['preparation_sha256']:
        # A new presentation test can reseal an otherwise identical ground bake.
        # Verify the exact original bytes and every curve before reusing this overlay.
        current_pin = old['preparation_sha256'].encode('ascii')
        sealed_pin = new['preparation_sha256'].encode('ascii')
        assert predecessor_bytes.count(current_pin) == 1
        predecessor_bytes = predecessor_bytes.replace(current_pin, sealed_pin)
        old['preparation_sha256'] = new['preparation_sha256']
    predecessor_digest = sha256(predecessor_bytes).hexdigest()
    assert new == combined_mummy_curves(old, predecessor_digest)
    fitted = {'MummyRecoil', 'MummyCurl'}
    for treatment, previous in old['treatments'].items():
        updated = new['treatments'][treatment]
        assert updated['overlay_asset_sha256'] == scene_hashes[treatment]
        assert previous['clips'].items() <= updated['clips'].items()
        assert updated['clips'].keys() - previous['clips'].keys() == fitted
        for clip in fitted:
            samples = updated['clips'][clip]
            assert samples[0][0] == 0 and len(samples) >= 460
            assert all(abs(offset) < 0.01 for _, offset in samples)
            assert all(0 < b[0] - a[0] <= 1 / 959 for a, b in zip(samples, samples[1:]))
    return dict(ground_lookup='res://local-art/creatures/' + overlay.name,
                ground_lookup_sha256=sha(overlay), predecessor_ground_lookup_sha256=predecessor_digest)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compose-mummy-ground', action='store_true', required=True)
    parser.parse_args()
    overlay = LOCAL / 'mummy-distinct-actions-ground.json'
    prior = LOCAL / 'walking_dead_mummy-ground.json'
    combined = combined_mummy_curves(read(prior), sha(prior))
    overlay.write_text(json.dumps(combined, separators=(',', ':')), encoding='utf-8')
