"""Verify the Fire Beetle's retained mount and fitted upright actions."""

import argparse
import json
import os
from pathlib import Path
import runpy
import shutil


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work/creatures/fire_beetle_rest'
SEALED = WORK / 'accepted-native'
REPORT = ROOT / 'outputs/ostard-riding/fire-beetle-rest-live.json'
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
FIXTURE = 'Server/HorseIntegrationFixtures/FireBeetleRestFixtures.cs'
WRAPPER = 'Viewer/Network/FireBeetleRestLive.gd'
BODY = 169
MOUNT_ITEM = 0x3E95
CLIPS = {3: 'Fidget', 4: 'FireBeetleLowerHead', 11: 'LieDown'}
RECIPE = runpy.run_path(str(ROOT / 'scripts/prepare-ridgeback-through-dragons-actions.py'))
read, sha = RECIPE['read'], RECIPE['sha']


def earlier_package():
    publisher = ROOT / 'scripts/accept-fire-beetle.py'
    variant = runpy.run_path(str(publisher))
    preparer = variant['variant']
    source, dependencies = preparer.recipe()
    preparer.check(source, dependencies)
    base, pins = variant['publisher']['checked'](preparer, source, preparer.KIND, BODY, publisher, ('SourceFireBeetleVisual.gd',))
    assert read(INDEX.parent / 'giant_beetle_fire/local-presentation.json') == pins
    return base


def checked(active):
    base = earlier_package()
    candidates, _ = RECIPE['prepared']([base], [BODY])
    candidate, = candidates
    folder = SEALED if active else WORK
    preview = folder / 'preview.json'
    report_file = folder / REPORT.name if active else REPORT
    receipt = read(folder / 'native-runtime.json')
    native = read(report_file)
    assert read(preview) == candidate
    if active:
        assert read(SEALED / 'base-rows.json') == [base]
    assert receipt['report_sha256'] == sha(report_file) and receipt['preview_sha256'] == sha(preview)
    assert receipt['build_inputs_sha256'][FIXTURE] == sha(ROOT / FIXTURE)
    assert native['failures'] == 0 and native['checks'] >= 138
    assert native['preview_sha256'] == sha(preview)
    assert receipt['wrapper_sha256'] == native['wrapper_sha256'] == sha(ROOT / WRAPPER)
    assert len(native['records']) == 2 and {row['female'] for row in native['records']} == {False, True}
    assert all(row['native_class'] == 'FireBeetle' and row['body'] == BODY and row['mount_item'] == MOUNT_ITEM
               and row['ride_permitted'] for row in native['records'])
    witnesses = native['rest_records']
    assert len(witnesses) == 6 and {(row['female'], row['group']) for row in witnesses} == {
        (female, group) for female in (False, True) for group in CLIPS}
    assert len({row['serial'] for row in witnesses}) == 2
    for row in witnesses:
        assert row['clip'] == CLIPS[row['group']] and len(row['packets']) == 2
        assert all(packet['protocol'] == 'classic' and packet['action'] == row['group']
                   and packet['body'] == BODY and packet['serial'] == row['serial'] for packet in row['packets'])
    return base, dict(candidate, family=base['family'], status='validated',
                      asset_sha256=candidate['authored_action_scene_sha256'], fire_beetle_rest_native_sha256=sha(report_file))


def test_active():
    tests = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile)
    tests['run_client_check'](godot, env, 'res://../scripts/test-ridgeback-through-dragons-actions.gd', ['--active', '--fire'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    before = INDEX.read_bytes()
    index = read(INDEX)
    base, fitted = checked(args.check_active)
    current, = (row for row in index['entries'] if any(identity['body'] == BODY for identity in row['bodies']))
    if args.check_active:
        assert current == fitted
        test_active()
    if args.activate:
        assert current == base and INDEX.read_bytes() == before
        SEALED.mkdir(exist_ok=True)
        for source in (WORK / 'preview.json', WORK / 'native-runtime.json', REPORT):
            shutil.copyfile(source, SEALED / source.name)
        (SEALED / 'base-rows.json').write_text(json.dumps([base], indent=2) + '\n', encoding='utf-8')
        assert checked(True) == (base, fitted)
        index['entries'] = [fitted if row == base else row for row in index['entries']]
        pending = INDEX.with_suffix('.beetle-rest.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode()
        pending.write_bytes(updated)
        pending.replace(INDEX)
        try:
            test_active()
        except (Exception, KeyboardInterrupt):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(before)
                pending.replace(INDEX)
            raise
    print('Fire Beetle upright actions active and verified' if args.activate or args.check_active else 'Fire Beetle ready for activation')


if __name__ == '__main__':
    main()

