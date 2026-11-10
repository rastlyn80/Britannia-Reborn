"""Activate the locally proven Quagmire scale without replacing its source motions."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
INDEX = VIEWER / 'local-art/creatures/accepted-index.json'
WORK = ROOT / 'work/creatures/native-form-audit'
SEALED = WORK / 'quagmire-metres-accepted'
EVIDENCE = {
    'client.json': WORK / 'quagmire-metres-client.json',
    'native.json': WORK / 'quagmire-metres-native.json',
    'runtime.json': WORK / 'quagmire-metres-native-runtime.json',
    'gpu.json': WORK / 'isolated-client/quagmire-metres-gpu.json',
}
BODY = 789
TREATMENTS = ('original', 'rounded', 'modern')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def asset_hashes(assets):
    assert set(assets) == set(TREATMENTS)
    return {treatment: sha(VIEWER / path.removeprefix('res://')) for treatment, path in assets.items()}


def scaled(base, evidence):
    assert base['kind'] == 'quagmire' and [row['body'] for row in base['bodies']] == [BODY]
    assert base['classic_gesture_batch'] == 'quagmire_through_exodus_actions'
    original_hashes = asset_hashes(base['assets'])
    assert original_hashes == base['asset_sha256'] == base['authored_action_scene_sha256']
    assets = {treatment: f'res://local-art/creatures/quagmire-metres-{treatment}.scn' for treatment in TREATMENTS}
    hashes = asset_hashes(assets)
    client = read(evidence['client.json'])
    native = read(evidence['native.json'])
    runtime = read(evidence['runtime.json'])
    gpu = read(evidence['gpu.json'])
    assert client['assets_sha256'] == native['assets_sha256'] == gpu['assets_sha256'] == hashes
    assert client['test_sha256'] == sha(ROOT / 'scripts/test-quagmire-metres.gd')
    assert (client['factor'], client['poses'], client['terrain'], client['corpse_hues']) == (0.01, 390, 234, 3)
    assert client['minimum_gap'] > 0.0019
    assert (native['body'], native['initial_hue'], native['hue'], native['checks']) == (BODY, 0, 0x8035, 34)
    assert native['corpse'] > 0 and len(native['actions']) == 2 and all(native['actions'])
    assert runtime['report_sha256'].lower() == sha(evidence['native.json'])
    assert runtime['server_sha256'].lower() == sha(ROOT / 'Server/runtime/Server.dll')
    assert runtime['content_sha256'].lower() == sha(ROOT / 'Server/runtime/Assemblies/UOContent.dll')
    assert gpu['body'] == BODY and gpu['renderer'] == 'Forward+'
    assert set(gpu['views']) == {'neutral', 'full', 'partial', 'corpse'} and min(gpu['views'].values()) > 2000
    return dict(base, assets=assets, asset_sha256=hashes, authored_action_scene_sha256=hashes,
                quagmire_metres={
                    'factor': 0.01,
                    'source_assets': base['assets'],
                    'source_sha256': original_hashes,
                    'evidence_sha256': {name: sha(path) for name, path in evidence.items()},
                })


def without_scale(row):
    """Return the sealed predecessor after checking the new presentation."""
    correction = row['quagmire_metres']
    base = dict(row, assets=correction['source_assets'], asset_sha256=correction['source_sha256'],
                authored_action_scene_sha256=correction['source_sha256'])
    del base['quagmire_metres']
    assert scaled(base, {name: SEALED / name for name in EVIDENCE}) == row
    return base


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true', help='Install the checked local presentation')
    args = parser.parse_args()
    previous = INDEX.read_bytes()
    index = json.loads(previous)
    row, = (row for row in index['entries'] if row['status'] == 'validated' and row['kind'] == 'quagmire')
    if 'quagmire_metres' in row:
        without_scale(row)
        print('QUAGMIRE METRES: active and verified')
        return
    if not args.activate:
        raise SystemExit('Quagmire scale has not been activated')
    replacement = scaled(row, EVIDENCE)
    SEALED.mkdir(parents=True, exist_ok=True)
    for name, path in EVIDENCE.items():
        shutil.copyfile(path, SEALED / name)
    assert without_scale(replacement) == row
    temporary = INDEX.with_suffix('.quagmire.tmp')
    index['entries'][index['entries'].index(row)] = replacement
    temporary.write_text(json.dumps(index, indent=2) + '\n', encoding='utf-8')
    if INDEX.read_bytes() != previous:
        raise SystemExit('The local creature index changed during verification')
    temporary.replace(INDEX)
    print('QUAGMIRE METRES: installed three scale-corrected local scenes')


if __name__ == '__main__':
    main()
