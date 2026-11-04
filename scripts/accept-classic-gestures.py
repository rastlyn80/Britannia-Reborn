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
BATCHES = {
    'classic_gestures': ((1, 3, 50), 'ClassicGestureLive.gd', ('test-classic-gesture-trials.gd',)),
    'troll_gestures': ((53, 54, 55), 'TrollGestureLive.gd',
                      ('test-troll-overhead-trial.gd', 'test-troll-weapon-trial.gd')),
    'blistering_pillage': ((130,), 'BlisteringPillageLive.gd', ('test-gargoyle-pillage-trial.gd',)),
    'parrot_flight': ((831,), 'PreparedCreatureActionLive.gd', ('test-parrot-flight-trial.gd',)),
    'troglodyte_reach': ((267,), 'PreparedCreatureActionLive.gd', ('test-troglodyte-reach-trial.gd',)),
    'ready_stances': ((730, 734), 'PreparedCreatureActionLive.gd', ('test-creature-ready-stance.gd',)),
    'giant_serpent_pillage': ((21,), 'PreparedCreatureActionLive.gd', ('test-giant-serpent-pillage.gd',)),
    'skeleton_axe': ((56,), 'PreparedCreatureActionLive.gd', ('test-skeleton-axe-trial.gd',)),
    'ratman_hunch': ((42,), 'PreparedCreatureActionLive.gd', ('test-classic-gesture-trials.gd',)),
    'spider_mongbat': ((28, 39), 'PreparedCreatureActionLive.gd', ('test-spider-mongbat-gestures.gd',)),
    'reaper_harpy': ((30, 47), 'PreparedCreatureActionLive.gd', ('test-reaper-harpy-gestures.gd',)),
    'earth_elemental_aos': ((14,), 'PreparedCreatureActionLive.gd', ('test-earth-elemental-aos.gd',)),
    'wraith_sway': ((26,), 'PreparedCreatureActionLive.gd', ('test-wraith-gesture.gd',)),
    'gargoyle_classic': ((4,), 'PreparedCreatureActionLive.gd', ('test-gargoyle-classic.gd',)),
    'scorpion_imp': ((48, 74), 'PreparedCreatureActionLive.gd', ('test-scorpion-imp-gestures.gd',)),
    'ophidian_bardiche': ((86,), 'PreparedCreatureActionLive.gd', ('test-ophidian-bardiche.gd',)),
    'dragon_daemon': ((9, 10, 12, 38, 40, 43, 59, 60, 61), 'PreparedCreatureActionLive.gd',
                      ('test-dragon-daemon-gestures.gd',)),
    'terathan_classic': ((70, 71, 72), 'PreparedCreatureActionLive.gd', ('test-terathan-gestures.gd',)),
    'ophidian_staff': ((85, 87), 'PreparedCreatureActionLive.gd', ('test-ophidian-staff-gestures.gd',)),
    'fidget_aliases_toad': ((67, 80, 149), 'PreparedCreatureActionLive.gd', ('test-fidget-aliases-toad.gd',)),
    'exact_creature_fidgets': ((146, 157, 173, 777), 'ExactCreatureFidgetLive.gd', ()),
    'skeletal_mage_staff': ((148,), 'PreparedCreatureActionLive.gd', ('test-skeletal-mage-staff.gd',)),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def compose(base, prepared, native_sha):
    if prepared['family'] == 'exact_creature_fidgets':
        return dict(base, classic_action_categories=prepared['classic_action_categories'],
                    legacy_slot11_evidence=prepared['legacy_slot11_evidence'])
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
    if prepared['family'] == 'ready_stances' and 'uop_redirect_targets' in base:
        row['classic_action_categories'] = base['classic_action_categories'] | prepared['classic_action_categories']
        for key in ('uop_redirect_targets', 'uop_redirect_native_sha256'):
            row[key] = base[key]
    return row


def without_ready_stance(row):
    if 'classic_gesture_native_sha256' not in row or len(row['bodies']) != 1:
        return row
    body = int(row['bodies'][0]['body'])
    if body not in BATCHES['ready_stances'][0]:
        return row
    sealed = ROOT / 'work/creatures/ready_stances/accepted-native'
    base, = (item for item in read(sealed / 'base-rows.json') if item['bodies'][0]['body'] == body)
    candidates = sealed / 'candidates.json'
    receipt = read(sealed / 'native-runtime.json')
    digest = sha(sealed / 'live.json')
    sources = [candidate['presentation'] for candidate in read(candidates) if candidate['body'] == body]
    if (receipt['candidate_sha256'] != sha(candidates) or receipt['report_sha256'] != digest
            or not sources or any(source != sources[0] for source in sources)
            or compose(base, sources[0], digest) != row):
        raise ValueError(f'Active ready stance overlay changed for body {body}')
    return base


def checked(index, active, batch):
    body_ids, wrapper, _ = BATCHES[batch]
    bodies = set(body_ids)
    work = ROOT / 'work/creatures' / batch
    sealed = work / 'accepted-native'
    live = ROOT / 'outputs/creatures' / batch / 'live.json'
    if active:
        baseline = read(sealed / 'base-rows.json')
    else:
        baseline = [row for row in index['entries'] if row['status'] == 'validated'
                    and any(identity['body'] in bodies for identity in row['bodies'])]
    owners = {int(identity['body']): row for row in baseline for identity in row['bodies']}
    prepare = runpy.run_path(str(ROOT / 'scripts/prepare-creature-fixtures.py'))['prepared_entries']
    prepared, classes = prepare(batch, baseline)

    report_path = sealed / 'live.json' if active else live
    folder = sealed if active else work
    report = read(report_path)
    receipt = read(folder / 'native-runtime.json')
    candidates = folder / 'candidates.json'
    native_sha = sha(report_path)
    if (receipt['report_sha256'] != native_sha or receipt['candidate_sha256'] != sha(candidates)
            or report['candidate_sha256'] != sha(candidates)
            or report['test_sha256'] != sha(ROOT / 'Viewer/Network/CreatureLive.gd')
            or report['prepared_wrapper_sha256'] != sha(ROOT / 'Viewer/Network' / wrapper)
            or report['fixture_sha256'] != sha(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs')
            or report['failures'] or not report['prepared_trial']):
        raise ValueError('Classic gesture native evidence does not match this batch')

    by_body = {row['bodies'][0]['body']: row for row in prepared}
    if batch == 'dragon_daemon':
        recipe = runpy.run_path(str(ROOT / 'scripts/prepare-dragon-daemon-actions.py'))
        recipe['check_breath'](read((sealed if active else live.parent) / 'breath.json'), candidates, by_body)
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
        package = by_body[body]
        source = package['authored_action_reference']
        slots = [int(slot) for slot in package.get('classic_motion_references', {})]
        if not slots:
            slots = [source['group'] if isinstance(source, dict) else 11]
        refuses_death = batch == 'dragon_daemon' and body == 38 and witness['native_class'] == 'ServantOfSemidar'
        if (witness['kind'] != package['kind'] or witness['corpse_suppressed']
                or witness['native_death_refused'] != refuses_death):
            raise ValueError(f'Missing original body or expected native death behaviour for {body}')
        if batch == 'exact_creature_fidgets' and body == 146 and (
                witness.get('transformed_body') != 780 or not witness.get('true_form_corpse')):
            raise ValueError('Harrower evidence must include the transformation and true-form corpse')
        for slot in slots:
            clip = ('Fidget' if batch == 'exact_creature_fidgets' and slot == 17
                    else package['classic_action_categories'][str(slot)])
            actions = [row for row in witness['actions'] if row['requested'] == slot]
            if len(actions) != 1 or any(actions[0][key] != clip for key in ('owner_clip', 'observer_clip')):
                raise ValueError(f'Missing Classic gesture evidence for body {body}, slot {slot}')
        if isinstance(source, dict) and 'new_type' in source:
            matches = [row for row in witness['actions'] if row['requested'] == -5]
            if (len(matches) != 1 or any(matches[0][key] != clip for key in ('owner_clip', 'observer_clip'))
                    or any(matches[0][side]['type'] != source['new_type']
                           for side in ('owner_packet', 'observer_packet'))):
                raise ValueError(f'Missing new-protocol ready stance evidence for {body}')
        witnesses.add(((body, witness['native_class']), witness['female']))
    if len(report['records']) != len(expected) * 2 or witnesses != {
            (pair, female) for pair in expected for female in (False, True)}:
        raise ValueError('Both clients must witness every native constructor')

    rows = [compose(owners[row['bodies'][0]['body']], row, native_sha) for row in prepared]
    if active:
        redirect = runpy.run_path(str(ROOT / 'scripts/prepare-creature-uop-redirects.py'))['without_active_redirect']
        targets = {row['bodies'][0]['body']: row for row in rows}
        siblings = {body: row for body, row in owners.items() if body not in bodies}
        for body, expected_row in (targets | siblings).items():
            matches = [row for row in index['entries'] if row['status'] == 'validated'
                       and any(identity['body'] == body for identity in row['bodies'])]
            if body in siblings:
                expected_row = dict(expected_row, bodies=[identity for identity in expected_row['bodies']
                                                         if identity['body'] not in bodies])
            compared = matches if batch == 'ready_stances' else [redirect(row) for row in matches]
            if compared != [expected_row]:
                raise ValueError(f'Active body {body} differs from its checked package')
    return baseline, rows


def test_active(batch):
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile)
    trial_args = {'blistering_pillage': ['--blistering'], 'ratman_hunch': ['--ratman']}.get(batch, [])
    for script in BATCHES[batch][2]:
        run_client_check(godot, env, f'res://../scripts/{script}', ['--active', *trial_args])
    package = {'parrot_flight': 'late_donors', 'troglodyte_reach': 'late_source'}.get(batch)
    if package:
        run_client_check(godot, env, 'res://Presentation/LateCreatureRouteTests.gd', [f'--family={package}'])
    if batch == 'ready_stances':
        for family in ('raptor', 'slith'):
            run_client_check(godot, env, 'res://Presentation/LateCreatureRouteTests.gd', [f'--family={family}'])
    if batch == 'exact_creature_fidgets':
        run_client_check(godot, env, 'res://Presentation/LegacyCreatureAliasTests.gd', ['--exact-fidgets', '--active'])
        for test in ('ChampionCreatureRouteTests', 'HarrowerMorphTests'):
            run_client_check(godot, env, f'res://Presentation/{test}.gd', [])


def run_client_check(godot, env, script, args):
    result = subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
                             script, '--', *args], cwd=ROOT, env=env, timeout=65,
                            capture_output=True, text=True, encoding='utf-8', errors='replace')
    output = result.stdout + result.stderr
    print(output.strip())
    if result.returncode or 'SCRIPT ERROR:' in output or 'Parse Error:' in output:
        raise RuntimeError(f'Creature action check failed: {script}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    parser.add_argument('--batch', choices=BATCHES, default='classic_gestures')
    args = parser.parse_args()
    batch = args.batch
    work = ROOT / 'work/creatures' / batch
    sealed = work / 'accepted-native'
    live = ROOT / 'outputs/creatures' / batch / 'live.json'
    previous = INDEX.read_bytes()
    index = read(INDEX)
    baseline, rows = checked(index, args.check_active, batch)
    if args.activate:
        if batch == 'ready_stances' and any('uop_redirect_native_sha256' not in row for row in baseline):
            raise ValueError('Activate the already verified UOP redirect layer before the ready stances')
        if any((row.get('classic_gesture_native_sha256') or
                batch == 'exact_creature_fidgets' and row.get('legacy_slot11_evidence')) and
               any(identity['body'] in BATCHES[batch][0] for identity in row['bodies'])
               for row in index['entries']):
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
        sealed.mkdir(exist_ok=True)
        for source in (live, work / 'native-runtime.json', work / 'candidates.json'):
            shutil.copyfile(source, sealed / source.name)
        if batch == 'dragon_daemon':
            shutil.copyfile(live.parent / 'breath.json', sealed / 'breath.json')
        (sealed / 'base-rows.json').write_text(json.dumps(baseline, indent=2) + '\n', encoding='utf-8')
        pending = INDEX.with_suffix('.classic-gestures.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode()
        pending.write_bytes(updated)
        pending.replace(INDEX)
        try:
            checked(read(INDEX), True, batch)
            test_active(batch)
        except (Exception, KeyboardInterrupt):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(previous)
                pending.replace(INDEX)
            raise
    elif args.check_active:
        test_active(batch)
    print(batch + ':', 'active and verified' if args.activate or args.check_active else 'verified for activation')


if __name__ == '__main__':
    main()
