"""Verify exact Classic UOP redirects and preview body-specific clip reuse."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
LEDGER = ROOT / 'outputs/creatures/actions.json'
RECIPE = ROOT / 'scripts/creature-uop-redirects.json'
PREVIEW = ROOT / 'work/creatures/uop_redirects/preview.json'
SEALED = PREVIEW.parent / 'accepted-native'
REPORT = ROOT / 'outputs/creatures/uop_redirects/live.json'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_rows(entries, ledger):
    recipe = read(RECIPE)
    archives = {row['name']: row['sha256'] for row in ledger['archives']}
    if any(archives.get(name) != digest for name, digest in recipe['inputs'].items()):
        raise ValueError('Rebuild the action ledger from the pinned client archive version')
    redirects = {(row['body'], row['old_group']): row for row in ledger['original_group_links']
                 if row['frame_count'] == 0}
    routes = {(row['body'], row['group_or_type']): row for row in ledger['routes'] if row['protocol'] == 'classic'}
    frames = {(row['body'], row['group']): row for row in ledger['original_uop_frame_groups']}
    owners = {int(identity['body']): row for row in entries if row['status'] == 'validated'
              for identity in row['bodies']}
    prepared = []
    for key, proof in recipe['bodies'].items():
        body = int(key)
        base = owners[body]
        if base['kind'] != proof['kind'] or [item['body'] for item in base['bodies']] != [body]:
            raise ValueError(f'Redirect scope no longer matches the accepted body {body}')
        overrides = {}
        for target_key, target in proof['targets'].items():
            group = int(target_key)
            frame = frames[body, group]
            if any(frame[field] != target[field] for field in ('archive', 'frame_headers', 'payload_sha256')):
                raise ValueError(f'UOP destination frames changed for body {body}, group {group}')
            for slot in target['slots']:
                actual = redirects.get((body, slot))
                old, destination = routes[body, slot], routes[body, group]
                if (actual is None or actual['new_group'] != group or destination['resolved'] != target['clip']
                        or old['kind'] != proof['kind'] or old['native_profile'] != 'monster'
                        or old['resolved'] not in (None, target['clip']) or str(slot) in overrides):
                    raise ValueError(f'UOP redirect no longer matches body {body}, slot {slot}')
                overrides[str(slot)] = target['clip']
        presentation = dict(base, classic_action_categories=base.get('classic_action_categories', {}) | overrides)
        prepared.append({'body': body, 'kind': base['kind'], 'targets': proof['targets'],
                         'presentation': presentation})
    return prepared


def merge_active(row, proof, receipt_hash):
    overrides = {str(slot): target['clip'] for target in proof.values() for slot in target['slots']}
    return dict(row, classic_action_categories=row.get('classic_action_categories', {}) | overrides,
                uop_redirect_targets=proof, uop_redirect_native_sha256=receipt_hash)


def redirect_layer(row):
    if 'mesh_binding_native_sha256' in row:
        bindings = runpy.run_path(str(ROOT / 'scripts/accept-creature-mesh-bindings.py'))
        return bindings['retained'](row)
    if 'preferred_uop_native_sha256' in row:
        preferred = runpy.run_path(str(ROOT / 'scripts/accept-preferred-uop-actions.py'))
        return preferred['retained'](row)
    if 'uop_motion_native_sha256' in row:
        halberd = runpy.run_path(str(ROOT / 'scripts/accept-halberd-uop-actions.py'))
        return halberd['retained'](row)
    if row.get('classic_gesture_batch') == 'frost_through_gargoyle_actions' and [
            body['body'] for body in row['bodies']] == [130]:
        gate = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))
        bases, rows = gate['checked']({'entries': []}, True, row['classic_gesture_batch'],
                                      compare_registry=False)
        if row not in rows:
            raise ValueError('Active Fire Gargoyle does not match its sealed action package')
        row, = (base for base in bases if base['bodies'][0]['body'] == 130)
    return row


def without_active_redirect(row):
    row = redirect_layer(row)
    if 'classic_gesture_native_sha256' in row and any(body['body'] in (730, 734) for body in row['bodies']):
        ready = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))['without_ready_stance']
        row = ready(row)
    if 'uop_redirect_native_sha256' not in row:
        return row
    body, = (int(item['body']) for item in row['bodies'])
    baseline = read(SEALED / 'base-rows.json')
    base, = (item for item in baseline if [entry['body'] for entry in item['bodies']] == [body])
    proof = read(RECIPE)['bodies'][str(body)]
    if row['kind'] != proof['kind'] or merge_active(base, proof['targets'], sha(SEALED / 'live.json')) != row:
        raise ValueError(f'Active UOP redirect overlay changed for body {body}')
    return base


def check_native(index, active=False):
    folder = SEALED if active else PREVIEW.parent
    report_path = folder / 'live.json' if active else REPORT
    candidates_path = folder / 'candidates.json'
    report = read(report_path)
    receipt = read(folder / 'native-runtime.json')
    candidates = read(candidates_path)
    if (report['failures'] or not report['prepared_trial']
            or (not active and report['accepted_index_sha256'] != sha(INDEX))
            or receipt['report_sha256'] != sha(report_path)
            or receipt['candidate_sha256'] != sha(candidates_path)
            or report['candidate_sha256'] != receipt['candidate_sha256']
            or report['test_sha256'] != sha(ROOT / 'Viewer/Network/CreatureLive.gd')
            or report['prepared_wrapper_sha256'] != sha(ROOT / 'Viewer/Network/UopRedirectsLive.gd')
            or report['fixture_sha256'] != sha(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs')):
        raise ValueError('Native redirect receipt no longer matches the current inputs')
    prepare = runpy.run_path(str(ROOT / 'scripts/prepare-creature-fixtures.py'))['prepared_entries']
    entries = [without_active_redirect(row) for row in index['entries']] if active else index['entries']
    rows, classes = prepare('uop_redirects', entries)
    by_body = {row['bodies'][0]['body']: row for row in rows}
    expected = {(body, name) for body, names in classes.items() for name in names}
    if (len(candidates) != len(expected) or {(row['body'], row['native_class']) for row in candidates} != expected
            or any(row['presentation'] != by_body[row['body']] for row in candidates)):
        raise ValueError('Native constructor selection or redirect package changed')
    witnesses = set()
    action_count = 0
    for record in report['records']:
        body = record['body']
        row = by_body[body]
        expected_routes = {slot: target['clip'] for target in row['uop_redirect_targets'].values()
                           for slot in target['slots']}
        expected_actions = {(slot, clip, clip) for slot, clip in expected_routes.items()}
        actions = record['uop_redirects']
        if (record['kind'] != row['kind'] or record['native_death_refused']
                or record['corpse_suppressed'] != (body == 692) or len(actions) != len(expected_actions)
                or {(a['slot'], a['owner_clip'], a['observer_clip']) for a in actions} != expected_actions):
            raise ValueError(f'Native body {body} has an incomplete redirect or corpse witness')
        witnesses.add((body, record['native_class'], record['female']))
        action_count += len(actions)
    if len(report['records']) != 2 * len(expected) or witnesses != {
            (body, name, female) for body, name in expected for female in (False, True)}:
        raise ValueError('Both clients must witness all constructors')
    print(f'UOP REDIRECTS: {action_count} two-client redirect witnesses, {int(report["checks"])} native checks')
    return entries, rows, sha(report_path)


def run_client(script, arguments=()):
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    profile = str(ROOT / '.godot-user')
    result = subprocess.run([str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
                             script, '--', *arguments], cwd=ROOT,
                            env=dict(os.environ, APPDATA=profile, LOCALAPPDATA=profile),
                            capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=65)
    output = result.stdout + result.stderr
    print(output.strip())
    if result.returncode or 'SCRIPT ERROR:' in output or 'Parse Error:' in output:
        raise RuntimeError(f'Decoded creature redirect check failed: {script}')


def test_client(rows, active):
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    PREVIEW.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    run_client('res://../scripts/test-creature-uop-redirects.gd', ['--active'] if active else [])

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check-native', action='store_true')
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    original = INDEX.read_bytes()
    index = json.loads(original)
    entries = index['entries']
    active = args.check_active
    installed = any('uop_redirect_native_sha256' in row for row in entries)
    if installed and not active:
        parser.error('The redirect batch is already active. Use --check-active.')
    if args.check_native or args.activate or active:
        entries, _, receipt = check_native(index, active)
    if args.check_native:
        return
    preview = build_rows(entries, read(LEDGER))
    if not (active or args.activate):
        test_client(preview, False)
        if INDEX.read_bytes() != original:
            raise RuntimeError('Accepted registry changed during the isolated preview')
        return
    by_body = {row['body']: row for row in preview}
    baseline = [row for row in entries if row['status'] == 'validated' and len(row['bodies']) == 1
                and row['bodies'][0]['body'] in by_body]
    if len(baseline) != len(by_body):
        raise ValueError('Each redirect body must have one validated registry row')
    final = {row['bodies'][0]['body']: merge_active(row, by_body[row['bodies'][0]['body']]['targets'], receipt)
             for row in baseline}
    for row in preview:
        row['presentation'] = final[row['body']]
        row['baseline'] = next(base for base in baseline if base['bodies'][0]['body'] == row['body'])
    if active:
        actual = {row['bodies'][0]['body']: row for row in index['entries'] if 'uop_redirect_native_sha256' in row}
        strip_ready = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))['without_ready_stance']
        if {body: strip_ready(redirect_layer(row)) for body, row in actual.items()} != final:
            raise ValueError('The active redirect batch is incomplete')
        for row in preview:
            row['presentation'] = actual[row['body']]
        test_client(preview, True)
        return
    if INDEX.read_bytes() != original:
        raise RuntimeError('Accepted registry changed before redirect activation')
    SEALED.mkdir(exist_ok=True)
    for source in (REPORT, PREVIEW.with_name('native-runtime.json'), PREVIEW.with_name('candidates.json')):
        shutil.copyfile(source, SEALED / source.name)
    (SEALED / 'base-rows.json').write_text(json.dumps(baseline, indent=2) + '\n', encoding='utf-8')
    index['entries'] = [final[row['bodies'][0]['body']] if row in baseline else row for row in entries]
    pending = INDEX.with_suffix('.uop-redirects.pending')
    updated = (json.dumps(index, indent=2) + '\n').encode()
    pending.write_bytes(updated)
    pending.replace(INDEX)
    try:
        test_client(preview, True)
        for family in ('animated_weapon', 'raptor', 'slith'):
            run_client('res://Presentation/LateCreatureRouteTests.gd', [f'--family={family}'])
        for script, arguments in [
            ('accept-classic-gestures.py', ['--batch', 'blistering_pillage', '--check-active']),
            ('accept-source-family-batch.py', ['--check-active']),
        ]:
            subprocess.run([sys.executable, '-B', str(ROOT / 'scripts' / script), *arguments],
                           cwd=ROOT, check=True, timeout=180)
        if INDEX.read_bytes() != updated:
            raise RuntimeError('Accepted registry changed while verifying redirect activation')
        print('UOP redirects active and verified')
    except BaseException:
        if INDEX.read_bytes() == updated:
            pending.write_bytes(original)
            pending.replace(INDEX)
        raise


if __name__ == '__main__':
    main()
