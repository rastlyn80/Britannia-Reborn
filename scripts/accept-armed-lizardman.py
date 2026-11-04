#!/usr/bin/env python3
"""Activate the two locally baked, native-tested armed Lizardman routes."""

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
EVIDENCE = ROOT / 'work/creatures/lizard_armed'
LIVE = ROOT / 'outputs/creatures/lizard_armed/live.json'
SEALED = EVIDENCE / 'accepted-native'
BODY_KINDS = {35: 'lizardman_spear', 36: 'lizardman_mace'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def active_row(row, native_digest):
    result = dict(row, status='validated', armed_native_receipt_sha256=native_digest)
    # These receipts cover the donor body before adding the armed skin.
    for key in ('validation_sha256', 'gpu_sha256', 'gpu_runtime_sha256'):
        result.pop(key, None)
    source = runpy.run_path(str(ROOT / 'scripts/prepare-lizardman-weapons.py'))
    form = row['kind'].removeprefix('lizardman_').title()
    checksum, vertices, triangles = source['WEAPONS'][form]
    result['weapon_source'] = {
        'mesh_member': f'Client/Models/Others/Weapon_Lizard_Man_{form}_Lod2.grn',
        'mesh_sha256': checksum, 'source_vertices': vertices, 'triangles': triangles,
        'atlas_member': 'Client/Models/Maps/Weapons_512b.tga', 'atlas_sha256': source['ATLAS_SHA256'],
    }
    return result


def checked_rows(index, active):
    folder = SEALED if active else EVIDENCE
    report_file = SEALED / 'live.json' if active else LIVE
    runtime = read(folder / 'native-runtime.json')
    report = read(report_file)
    candidate_file = folder / 'candidates.json'
    native_digest = digest(report_file)
    if (runtime['report_sha256'] != native_digest
            or runtime['candidate_sha256'] != digest(candidate_file)
            or report['candidate_sha256'] != digest(candidate_file)
            or report['prepared_wrapper_sha256'] != digest(ROOT / 'Viewer/Network/SourceArmedLizardmanLive.gd')
            or report['test_sha256'] != digest(ROOT / 'Viewer/Network/CreatureLive.gd')
            or report['fixture_sha256'] != digest(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs')
            or report['failures'] or not report['prepared_trial']):
        raise ValueError('The isolated native evidence does not match this package')
    if not active and report['accepted_index_sha256'] != digest(INDEX):
        raise ValueError('The registry changed since the isolated native trial')

    candidates = read(candidate_file)
    rows, _ = runpy.run_path(str(ROOT / 'scripts/prepare-creature-fixtures.py'))['prepared_entries']('lizard_armed')
    if [candidate['presentation'] for candidate in candidates] != rows:
        raise ValueError('Current assets or identities differ from the native-tested package')

    witnessed = set()
    for record in report['records']:
        body = record['body']
        pillage = [action for action in record['actions'] if action['requested'] == 11]
        if (record['kind'] != BODY_KINDS[body] or record['native_class'] != 'Lizardman'
                or record['corpse_suppressed'] or record['native_death_refused']
                or len(pillage) != 1 or pillage[0]['owner_clip'] != 'Pillage'
                or pillage[0]['observer_clip'] != 'Pillage'):
            raise ValueError('Missing exact native witness for an armed variant')
        witnessed.add((body, record['female']))
    if len(report['records']) != 4 or witnessed != {(body, female) for body in BODY_KINDS for female in (False, True)}:
        raise ValueError('Both clients must witness both body variants')

    owners = {}
    for row in index['entries']:
        if row['status'] == 'validated':
            for identity in row['bodies']:
                body = identity['body']
                if body in (33, *BODY_KINDS):
                    if body in owners:
                        raise ValueError(f'Duplicate active Lizardman route {body}')
                    owners[body] = row
    if owners[33]['kind'] != 'lizard_race_lizardman':
        raise ValueError('Historical Lizardman route changed')
    for row in rows:
        body = row['bodies'][0]['body']
        if active and owners[body] != active_row(row, native_digest):
            raise ValueError(f'Active weapon package changed for body {body}')
        if not active and owners[body] != owners[33]:
            raise ValueError(f'Unexpected existing Lizardman route for body {body}')
    return rows, native_digest


def test_active():
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile)
    subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
                    'res://../scripts/test-lizardman-weapon-corpses.gd', '--', '--active'],
                   cwd=ROOT, env=env, check=True, timeout=65)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    previous = INDEX.read_bytes()
    index = read(INDEX)
    rows, native_digest = checked_rows(index, args.check_active)
    if args.activate:
        base = next(row for row in index['entries'] if row['kind'] == 'lizard_race_lizardman'
                    and row['status'] == 'validated')
        base['bodies'] = [identity for identity in base['bodies'] if identity['body'] not in BODY_KINDS]
        index['entries'].extend(active_row(row, native_digest) for row in rows)
        if INDEX.read_bytes() != previous:
            raise RuntimeError('The local registry changed during activation checks')
        SEALED.mkdir(exist_ok=True)
        for source in (LIVE, EVIDENCE / 'native-runtime.json', EVIDENCE / 'candidates.json'):
            shutil.copyfile(source, SEALED / source.name)
        pending = INDEX.with_suffix('.armed-lizardman.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode()
        pending.write_bytes(updated)
        pending.replace(INDEX)
        try:
            checked_rows(read(INDEX), True)
            test_active()
        except (Exception, KeyboardInterrupt):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(previous)
                pending.replace(INDEX)
            raise
    elif args.check_active:
        test_active()
    print('Armed Lizardman:', 'active and verified' if args.activate or args.check_active else 'verified for activation')


if __name__ == '__main__':
    main()
