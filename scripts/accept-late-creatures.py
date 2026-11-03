"""Activate the exact recovered local assets exercised by the native trial."""
import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess

HERE = Path(__file__).resolve().parent
FIXTURES = runpy.run_path(str(HERE / 'prepare-creature-fixtures.py'))
ROOT, SHA = FIXTURES['ROOT'], FIXTURES['sha']
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'


def replace_index(payload):
    pending = INDEX.with_suffix('.late-source.pending')
    pending.write_bytes(payload)
    pending.replace(INDEX)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-evidence', action='store_true')
    parser.add_argument('--family', choices=('late_source', 'hydra', 'energy_vortex', 'champions', 'fey_champions', 'crane', 'deathwatch', 'tsuki_wolf'), default='late_source')
    args = parser.parse_args()
    rows, classes = FIXTURES['prepared_entries'](args.family)
    evidence = ROOT / 'work/creatures' / args.family
    candidates_path = evidence / 'candidates.json'
    report_path = ROOT / 'outputs/creatures' / args.family / 'live.json'
    runtime = json.loads((evidence / 'native-runtime.json').read_text(encoding='utf-8-sig'))
    candidates = json.loads(candidates_path.read_text(encoding='utf-8'))
    report = json.loads(report_path.read_text(encoding='utf-8'))
    if (not report['prepared_trial'] or report['failures'] or not report['checks']
            or SHA(report_path) != runtime['report_sha256']
            or SHA(candidates_path) != runtime['candidate_sha256']
            or report['candidate_sha256'] != runtime['candidate_sha256']):
        raise ValueError('Prepared native evidence is missing or stale')
    expected = {(body, name) for body, names in classes.items() for name in names}
    actual = {(record['body'], record['native_class'], record['female']) for record in report['records']}
    if len(report['records']) != 2 * len(expected) or actual != {
            (body, name, female) for body, name in expected for female in (False, True)}:
        raise ValueError('Native evidence must include both clients for every constructor')
    if args.family == 'energy_vortex' and any(
            record['native_state'] != 'summoned' or not record['corpse_suppressed']
            for record in report['records']):
        raise ValueError('Energy Vortex evidence must cover native summoning and corpse suppression')
    by_body = {row['bodies'][0]['body']: row for row in rows}
    if (len(candidates) != len(expected)
            or {(row['body'], row['native_class']) for row in candidates} != expected
            or any(candidate['presentation'] != by_body[candidate['body']] for candidate in candidates)):
        raise ValueError('Current package differs from the native trial')
    if args.check_evidence:
        print(f'Exact recovered package matches {len(expected)} constructors and {report["checks"]} native checks')
        return
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    entries = index['entries']
    for entry in entries:
        bodies = {int(identity['body']) for identity in entry['bodies']}
        if bodies & by_body.keys():
            raise ValueError(f'Existing registry route overlaps recovered package: {entry["kind"]}')
    index['entries'] = entries + [dict(row, status='validated') for row in rows]
    published = (json.dumps(index, indent=2) + '\n').encode('utf-8')
    if INDEX.read_bytes() != previous:
        raise RuntimeError('Registry changed while preparing activation')
    replace_index(published)
    try:
        godot = next((ROOT / '.tools/godot').glob('*console.exe'))
        user_dir = str(ROOT / '.godot-user')
        test_script = {'energy_vortex': 'EnergyVortexRouteTests.gd',
                       'champions': 'ChampionCreatureRouteTests.gd',
                       'fey_champions': 'FeyChampionRouteTests.gd',
                       'crane': 'CraneRouteTests.gd',
                       'deathwatch': 'DeathwatchRouteTests.gd',
                       'tsuki_wolf': 'TsukiWolfRouteTests.gd'}.get(args.family, 'LateCreatureRouteTests.gd')
        result = subprocess.run(
            [str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
             f'res://Presentation/{test_script}', '--', f'--family={args.family}'],
            cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
            capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
        output = result.stdout + result.stderr
        print(output.strip())
        if (result.returncode or 'ERROR:' in output
                or any(f'{row["kind"]} passed' not in output for row in rows)):
            raise RuntimeError('Normal recovered creature routes failed')
        if INDEX.read_bytes() != published:
            raise RuntimeError('Registry changed during activation')
    except BaseException:
        if INDEX.read_bytes() == published:
            replace_index(previous)
        raise
    print('Activated recovered local routes: ' + ', '.join(row['kind'] for row in rows))


if __name__ == '__main__':
    main()
