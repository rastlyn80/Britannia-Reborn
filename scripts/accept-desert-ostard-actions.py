"""Verify the Desert Ostard’s Classic reference, local library and native trial."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/ostards'
MARKER = ART / 'desert-actions-active.json'
BAKE = ART / 'desert-actions-bake.json'
PINS = ROOT / 'scripts/desert-ostard-frame-pins.json'
REPORTS = ROOT / 'outputs/creatures/desert_ostard_actions'
EVIDENCE = ROOT / 'work/creatures/desert-ostard-actions'
TREATMENTS = ('original', 'rounded', 'modern')
ROUTES = ('Walk', 'Run', 'Idle', 'Eat', 'Alert', 'Attack', 'Peck', 'Hit', 'Death',
          'CrestDip', 'CrestTwitch', 'LieDown', 'Death2')
FITTED = {4, 6, 9, 10, 11, 12}
INPUTS = ('Presentation/DesertOstardActions.gd', 'Presentation/OstardMount.gd',
          'Presentation/CreatureFallPlayback.gd', 'Presentation/CreatureDeathsWithOstard.gd',
          'Network/DesertOstardLive.gd', 'Network/DesertOstardLiveTransition.gd',
          '../Server/HorseIntegrationFixtures/DesertOstardActionFixtures.cs',
          '../Server/HorseIntegrationFixtures/EquineFixtures.cs')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_reference():
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    ledger = runpy.run_path(str(ROOT / 'scripts/build-creature-actions.py'))
    groups, _, _ = ledger['original_mul_groups'](data, {210})
    actual = {}
    for row in groups:
        directions = row['directions']
        assert (row['archive'], row['graphic'], row['layout']) == ('anim.mul', 210, 'small')
        assert [item['direction'] for item in directions] == list(range(5))
        digests = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
        actual[str(row['group'])] = [[item['frames'] for item in directions], hashlib.sha256(digests).hexdigest()]
    assert actual == read(PINS) and len(actual) == 13
    return actual


def verify_bake():
    bake = read(BAKE)
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-desert-ostard-actions.gd')
    expected = {variant: {'source': sha(ART / f'desert-{variant}.gltf'),
                          'actions': sha(ART / f'desert-actions-{variant}.res')} for variant in TREATMENTS}
    assert bake['assets'] == expected


def verify_native(candidate):
    report = read(REPORTS / ('candidate-live.json' if candidate else 'live.json'))
    assert report['candidate'] == candidate and report['checks'] >= 107 and report['failures'] == 0
    assert report['bake_sha256'] == sha(BAKE)
    assert report['inputs'] == {path: sha(VIEWER / path) for path in INPUTS}
    records = report['records']
    assert len(records) == 2 and [row['female'] for row in records] == [False, True]
    for row in records:
        assert (row['body'], row['mount_item'], row['native_class']) == (210, 0x3ea3, 'DesertOstard')
        assert row['groups'] == ([4, 6, 9, 10, 11, 12] if row['female'] else [4, 6, 9, 10, 11])
        assert row['death'] and row['corpse_clip'] == ('Death2' if row['female'] else 'Death')


def check_client(candidate):
    godot, = (ROOT / '.tools/godot').glob('*console.exe')
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    profile = str(ROOT / '.godot-user')
    for name, summary in [('actions', '2214 terrain poses, 210 ridden phases'),
                          ('corpses', '12 decoded handoffs across 492 terrain poses')]:
        script = f'test-desert-ostard-{name}'
        result = subprocess.run([str(godot), '--headless', '--path', str(VIEWER), '--script',
                                 f'res://../scripts/{script}.gd', '--', *(['--candidate'] if candidate else [])],
                                capture_output=True, text=True, timeout=100,
                                env=os.environ | {'APPDATA': profile, 'LOCALAPPDATA': profile})
        log = result.stdout + result.stderr
        (EVIDENCE / f'{script}.log').write_text(log, encoding='utf-8')
        if result.returncode or 'SCRIPT ERROR:' in log or summary not in log:
            raise RuntimeError(log)
        print(summary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    source = verify_reference()
    verify_bake()
    verify_native(candidate=True)
    receipt = {'body': 210, 'source_frame_pins_sha256': sha(PINS), 'bake_sha256': sha(BAKE),
               'native_sha256': sha(REPORTS / 'candidate-live.json')}
    if args.activate:
        check_client(candidate=True)
        previous = MARKER.read_bytes() if MARKER.exists() else None
        staged = MARKER.with_suffix('.tmp')
        staged.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
        staged.replace(MARKER)
        try:
            check_client(candidate=False)
        except BaseException:
            if previous is None:
                MARKER.unlink()
            else:
                staged.write_bytes(previous)
                staged.replace(MARKER)
            raise
    elif args.check_active:
        assert read(MARKER) == receipt
        verify_native(candidate=False)
        check_client(candidate=False)
    else:
        check_client(candidate=True)
    if args.activate or args.check_active:
        catalogue = {'body': 210, 'layout': 'small', 'archive': 'anim.mul', 'slots': [
            {'group': group, 'clip': clip, 'frames_by_direction': source[str(group)][0],
             'payloads_sha256': source[str(group)][1],
             'evidence': ('fitted from Classic frames' if group in FITTED else
                          'authored feeding' if group == 3 else 'recovered Third Dawn clip')}
            for group, clip in enumerate(ROUTES)], 'receipt': receipt}
        (REPORTS / 'actions.json').write_text(json.dumps(catalogue, indent=2) + '\n', encoding='utf-8')
    print('DESERT OSTARD ACTIONS:', 'active and verified' if args.activate or args.check_active else 'candidate verified')


if __name__ == '__main__':
    main()
