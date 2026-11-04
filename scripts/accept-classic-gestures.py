#!/usr/bin/env python3
"""Activate the exact native-tested classic gesture batch by body ID."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
WORK = ROOT / 'work/creatures/classic_gestures'
SEALED = WORK / 'accepted-native'
LIVE = ROOT / 'outputs/creatures/classic_gestures/live.json'
MANIFEST = ROOT / 'scripts/classic-gesture-inputs.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def compose(base, prepared, native_sha):
    assets = base.get('assets', {
        name: f"res://local-art/creatures/{base['kind']}-{name}.gltf"
        for name in prepared['assets']
    })
    row = dict(prepared, status='validated', family=base['family'],
               classic_gesture_base_assets=assets, classic_gesture_native_sha256=native_sha,
               asset_sha256=prepared['authored_action_scene_sha256'], import_sha256={})
    if len(base['bodies']) > 1:
        row['kind'] = f"{base['kind']}_slot11_{prepared['bodies'][0]['body']}"
    for key in ('validation_sha256', 'gpu_sha256', 'gpu_runtime_sha256'):
        row.pop(key, None)
    return row


def checked(index, active):
    recipes = read(MANIFEST)
    bodies = {int(body) for body in recipes}
    if active:
        baseline = read(SEALED / 'base-rows.json')
    else:
        baseline = [row for row in index['entries'] if row['status'] == 'validated'
                    and any(identity['body'] in bodies for identity in row['bodies'])]
    owners = {int(identity['body']): row for row in baseline for identity in row['bodies']}
    prepare = runpy.run_path(str(ROOT / 'scripts/prepare-creature-fixtures.py'))['prepared_entries']
    prepared, classes = prepare('classic_gestures', baseline)

    report_path = SEALED / 'live.json' if active else LIVE
    folder = SEALED if active else WORK
    report = read(report_path)
    receipt = read(folder / 'native-runtime.json')
    candidates = folder / 'candidates.json'
    native_sha = sha(report_path)
    if (receipt['report_sha256'] != native_sha or receipt['candidate_sha256'] != sha(candidates)
            or report['candidate_sha256'] != sha(candidates)
            or report['test_sha256'] != sha(ROOT / 'Viewer/Network/CreatureLive.gd')
            or report['prepared_wrapper_sha256'] != sha(ROOT / 'Viewer/Network/ClassicGestureLive.gd')
            or report['fixture_sha256'] != sha(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs')
            or report['failures'] or not report['prepared_trial']):
        raise ValueError('Classic gesture native evidence does not match this batch')

    by_body = {row['bodies'][0]['body']: row for row in prepared}
    candidate_keys = set()
    for candidate in read(candidates):
        body = candidate['body']
        if candidate['presentation'] != by_body[body]:
            raise ValueError(f'Tested package changed for body {body}')
        candidate_keys.add((body, candidate['native_class']))
    expected = {(body, name) for body, names in classes.items() for name in names}
    if candidate_keys != expected:
        raise ValueError('The native constructor allow-list changed')
    witnesses = set()
    for witness in report['records']:
        body = int(witness['body'])
        clip = recipes[str(body)]['clip']
        actions = [row for row in witness['actions'] if row['requested'] == 11]
        if (witness['kind'] != by_body[body]['kind'] or witness['corpse_suppressed']
                or witness['native_death_refused'] or len(actions) != 1
                or any(actions[0][key] != clip for key in ('owner_clip', 'observer_clip'))):
            raise ValueError(f'Missing original body, gesture, or corpse evidence for {body}')
        witnesses.add(((body, witness['native_class']), witness['female']))
    if len(report['records']) != len(expected) * 2 or witnesses != {
            (pair, female) for pair in expected for female in (False, True)}:
        raise ValueError('Both clients must witness every native constructor')

    rows = [compose(owners[row['bodies'][0]['body']], row, native_sha) for row in prepared]
    if active:
        targets = {row['bodies'][0]['body']: row for row in rows}
        siblings = {body: row for body, row in owners.items() if body not in bodies}
        for body, expected_row in (targets | siblings).items():
            matches = [row for row in index['entries'] if row['status'] == 'validated'
                       and any(identity['body'] == body for identity in row['bodies'])]
            if body in siblings:
                expected_row = dict(expected_row, bodies=[identity for identity in expected_row['bodies']
                                                         if identity['body'] not in bodies])
            if matches != [expected_row]:
                raise ValueError(f'Active body {body} differs from its checked package')
    return baseline, rows


def test_active():
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile)
    subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
                    'res://../scripts/test-classic-gesture-trials.gd', '--', '--active'],
                   cwd=ROOT, env=env, check=True, timeout=65)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    previous = INDEX.read_bytes()
    index = read(INDEX)
    baseline, rows = checked(index, args.check_active)
    if args.activate:
        if any(row.get('classic_gesture_native_sha256') for row in index['entries']):
            raise ValueError('The classic gesture batch is already active')
        bodies = {row['bodies'][0]['body'] for row in rows}
        retained = []
        for row in index['entries']:
            if row in baseline:
                siblings = [identity for identity in row['bodies'] if identity['body'] not in bodies]
                if siblings:
                    retained.append(dict(row, bodies=siblings))
            else:
                retained.append(row)
        index['entries'] = retained + rows
        if INDEX.read_bytes() != previous:
            raise RuntimeError('Registry changed during classic gesture activation')
        SEALED.mkdir(exist_ok=True)
        for source in (LIVE, WORK / 'native-runtime.json', WORK / 'candidates.json'):
            shutil.copyfile(source, SEALED / source.name)
        (SEALED / 'base-rows.json').write_text(json.dumps(baseline, indent=2) + '\n', encoding='utf-8')
        pending = INDEX.with_suffix('.classic-gestures.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode()
        pending.write_bytes(updated)
        pending.replace(INDEX)
        try:
            checked(read(INDEX), True)
            test_active()
        except (Exception, KeyboardInterrupt):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(previous)
                pending.replace(INDEX)
            raise
    elif args.check_active:
        test_active()
    print('Classic gestures:', 'active and verified' if args.activate or args.check_active else 'verified for activation')


if __name__ == '__main__':
    main()
