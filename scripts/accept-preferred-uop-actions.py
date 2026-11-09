"""Activate the verified preferred UOP Gargoyle and Parrot packages together."""

import argparse
import json
from pathlib import Path
import runpy
import shutil


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
RECIPE = runpy.run_path(str(SCRIPTS / 'prepare-preferred-uop-actions.py'))
EVIDENCE = runpy.run_path(str(SCRIPTS / 'creature-packet-evidence.py'))
read, FAMILY, CLASSES, WORK = (RECIPE[key] for key in ('read', 'FAMILY', 'CLASSES', 'WORK'))
INDEX = EVIDENCE['INDEX']
SEALED = WORK / 'accepted-native'
RESULT = ROOT / 'outputs/creatures' / FAMILY / 'live.json'


def body_key(row):
    return tuple(int(identity['body']) for identity in row['bodies'])


def checked(base, active):
    prepared = RECIPE['prepared'](base)
    routes = {int(row['bodies'][0]['body']): {kind: row['new_action_categories'][kind]
               for kind in row['uop_motion_packet_groups']} for row in prepared}
    digest = EVIDENCE['checked'](WORK / 'native', FAMILY, prepared, CLASSES, routes, 151,
                                  sealed=SEALED if active else None)
    families = {body_key(row): row['family'] for row in base}
    return [dict(row, status='validated', family=families[body_key(row)], preferred_uop_native_sha256=digest)
            for row in prepared]


def retained(row):
    if 'preferred_uop_native_sha256' not in row:
        return row
    base = read(SEALED / 'base.json')
    assert row in checked(base, True)
    original, = (item for item in base if body_key(item) == body_key(row))
    return original


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    original = INDEX.read_bytes()
    index = json.loads(original)
    current = [row for row in index['entries'] if row['status'] == 'validated' and body_key(row) in {(753,), (831,)}]
    assert len(current) == len(CLASSES)
    gate = runpy.run_path(str(SCRIPTS / 'prepare-creature-uop-redirects.py'))
    if args.check_active:
        assert current == checked(read(SEALED / 'base.json'), True)
        gate['run_client']('res://../scripts/test-preferred-uop-actions.gd', ['--active'])
        print('PREFERRED UOP ACTIONS: active and verified')
        return
    rows = checked(current, False)
    SEALED.mkdir(parents=True, exist_ok=True)
    trial = ROOT / 'work/creatures' / FAMILY
    for path in (RESULT, trial / 'candidates.json', trial / 'native-runtime.json'):
        shutil.copyfile(path, SEALED / path.name)
    (SEALED / 'base.json').write_text(json.dumps(current, indent=2) + '\n', encoding='utf-8')
    index['entries'] = [row for row in index['entries'] if row not in current] + rows
    assert INDEX.read_bytes() == original
    pending = INDEX.with_suffix('.preferred-uop.pending')
    updated = (json.dumps(index, indent=2) + '\n').encode()
    pending.write_bytes(updated)
    pending.replace(INDEX)
    try:
        assert rows == checked(current, True)
        gate['run_client']('res://../scripts/test-preferred-uop-actions.gd', ['--active'])
        gate['run_client']('res://../scripts/test-parrot-flight-trial.gd', ['--active'])
        assert INDEX.read_bytes() == updated
    except BaseException:
        if INDEX.read_bytes() == updated:
            pending.write_bytes(original)
            pending.replace(INDEX)
        raise
    print('PREFERRED UOP ACTIONS: activated and verified')


if __name__ == '__main__':
    main()
