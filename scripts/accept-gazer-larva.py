"""Validate the saved Gazer Larva assets and activate their local body route."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
import runpy
import subprocess
from pathlib import Path

PREPARE = runpy.run_path(str(Path(__file__).with_name('prepare-gazer-larva.py')))
WITH_ALIAS = runpy.run_path(str(Path(__file__).with_name('legacy-action-evidence.py')))['expected_with_legacy_alias']
ROOT = PREPARE['ROOT']
WORK = PREPARE['WORK']
ART = PREPARE['ART']
INDEX = ART / 'accepted-index.json'
PREPARATION = ART / 'gazer_larva/preparation.json'
RECEIPT = PREPARATION.with_name('local-presentation.json')
BODY = 778


def run_test(name, active):
    exe = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir)
    mode = ['--resolution', '96x96'] if name == 'Appearance' else ['--headless']
    command = [str(exe), *mode, '--path', str(ROOT / 'Viewer'), '--script',
               f'res://Presentation/GazerLarva{name}Tests.gd']
    if active:
        command.extend(['--', '--active'])
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                            text=True, encoding='utf-8', errors='replace', timeout=195)
    output = result.stdout + result.stderr
    log = WORK / f'{name}-{"active" if active else "prepared"}.log'
    log.write_text(output, encoding='utf-8')
    markers = {
        'Appearance': ('Vulkan', 'Forward+', 'failures 0'),
        'Death': ('GAZER DECODED DEATH AND HOVER: 27 checks / 0 failures',),
        'Picking': ('477 independent poses, 0 outside',),
        'Skin': ('83 checks / 0 failures / 27 poses',),
    }
    if result.returncode or 'ERROR:' in output or any(mark not in output for mark in markers[name]):
        raise RuntimeError(f'Gazer Larva {name} checks failed. See {log}\n{output[-2000:]}')
    print(output.strip(), flush=True)


def run_tests(names, active=False):
    with ThreadPoolExecutor(max_workers=len(names)) as executor:
        for test in [executor.submit(run_test, name, active) for name in names]:
            test.result()


def replace_index(payload):
    temporary = INDEX.with_suffix('.gazer-larva.pending')
    temporary.write_bytes(payload)
    temporary.replace(INDEX)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--publish', action='store_true')
    modes.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    manifest = PREPARE['SOURCE']['inputs']()
    prepared = PREPARE['candidate'](manifest)
    assert PREPARE['read'](PREPARATION) == prepared
    row, = prepared['models']
    assert [body['body'] for body in row['bodies']] == [BODY]
    row = dict(row, status='validated',
               validation_scope='Original hover and death keys, refined skin, rigid cards, dyes, picking and static corpse.')
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    existing = [item for item in index['entries'] if any(
        int(body['body']) == BODY for body in item['bodies'])]
    assert all(item['family'] == row['family'] and len(item['bodies']) == 1 for item in existing)
    if existing:
        row = WITH_ALIAS(row, existing[0])
    receipt = {'body': BODY, 'preparation_sha256': PREPARE['sha'](PREPARATION)}
    if args.check_active:
        assert existing == [row] and PREPARE['read'](RECEIPT) == receipt
        run_tests(('Skin', 'Picking', 'Death', 'Appearance'), active=True)
    else:
        run_tests(('Skin', 'Picking', 'Death', 'Appearance'))
    if args.publish:
        index['entries'] = [item for item in index['entries'] if item not in existing] + [row]
        published = (json.dumps(index, indent=2) + '\n').encode('utf-8')
        assert INDEX.read_bytes() == previous, 'Creature registry changed during validation'
        replace_index(published)
        try:
            run_tests(('Death', 'Appearance'), active=True)
            assert INDEX.read_bytes() == published, 'Creature registry changed during active validation'
            temporary = RECEIPT.with_suffix('.json.pending')
            temporary.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
            temporary.replace(RECEIPT)
        except BaseException:
            if INDEX.read_bytes() == published:
                replace_index(previous)
            raise
    print('GAZER LARVA 778:', 'active' if args.publish or args.check_active else 'prepared checks passed')


if __name__ == '__main__':
    main()
