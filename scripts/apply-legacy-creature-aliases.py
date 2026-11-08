"""Apply reviewed exact-frame aliases to locally accepted generic creatures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
LEDGER = ROOT / 'outputs/creatures/actions.json'
TRIAL = ROOT / 'work/creatures/legacy-aliases/candidates.json'
DREAD_RENDERER = 'Presentation/LegacyDreadSpiderVisual.gd'
LATE_ALIASES = ROOT / 'Viewer/Presentation/legacy-late-action-aliases.json'
PACKAGE_TESTS = {
    'fey_champions': 'FeyChampionRouteTests.gd',
    'deathwatch': 'DeathwatchRouteTests.gd',
    'tsuki_wolf': 'TsukiWolfRouteTests.gd',
    'kappa': 'KappaRouteTests.gd',
    'yomotsu': 'YomotsuRouteTests.gd',
    'horde_rune': 'OccurrenceCreatureRouteTests.gd',
    'occurrence_next': 'OccurrenceCreatureRouteTests.gd',
    'devourer_lion_hiryu': 'DevourerLionHiryuRouteTests.gd',
    'elemental_minotaur': 'ElementalMinotaurRouteTests.gd',
    'meer_donors': 'MeerDonorRouteTests.gd',
    'clockwork_tokuno': 'ClockworkTokunoRouteTests.gd',
}
PUBLICATION_TESTS = {
    'gazer_larva': 'accept-gazer-larva.py',
    'bog_thing': 'prepare-bog-thing.py',
    'mummies': 'accept-reviewed-creatures.py',
    'solen_warriors': 'accept-reviewed-creatures.py',
    'ant_lion_chain': 'accept-ant-lion.py',
    'crystal_lattice': 'accept-crystal-lattice.py',
    'solen_queens': 'accept-solen-queens.py',
    'source_preserving': 'accept-source-preserving.py',
}
# Each record below has exactly one body and uses the generic classic action map.
REVIEWED = {
    77: 'krakens_kraken',
    20: 'arachnids_spider_frost',
    101: 'centaurs_centaur',
    38: 'daemons_daemon_black_gate',
    40: 'daemons_daemon_elder',
    43: 'daemons_daemon_ice_fiend',
    46: 'dragons_wyrm_ancient',
    62: 'dragons_wyvern',
    76: 'titans_titan',
    103: 'dragons_dragon_asian',
    104: 'dragons_dragon_skeletal',
    128: 'fey_race_pixie',
    152: 'terathan_terathan_avenger',
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def alias_proof(body, rows, sibling_slots=(17,)):
    sources = [row for row in rows if row['body'] == body and row['group'] == 11
               and row['layout'] == 'large' and 'matching_classic_route' in row]
    source, = sources
    target = next((
        row for row in rows if row['body'] == body and row['group'] in sibling_slots
        and row['group'] in source.get('same_payload_groups', [])
        and row.get('matching_classic_route', {}).get('resolved') == 'Fidget'
        and all(row[name] == source[name] for name in ('archive', 'layout', 'graphic'))
    ), None)
    if (target is None or len(source['directions']) != 5
            or [item['payload_sha256'] for item in source['directions']] !=
            [item['payload_sha256'] for item in target['directions']]
            or target['matching_classic_route']['resolved'] != 'Fidget'
            or source['matching_classic_route']['resolved'] not in (None, 'Fidget')):
        raise ValueError(f'Classic group 11 has no exact reviewed match for {body}')
    return {'body': body, 'original_slot': 11, 'identical_slot': target['group'],
            'clip': 'Fidget', 'archive': source['archive'], 'graphic': source['graphic'],
            'directions': source['directions']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    parser.add_argument('--dread-spider', action='store_true',
                        help='Test or activate the body-specific Dread Spider alias only.')
    parser.add_argument('--preview-packages', action='store_true',
                        help='Preview eligible exact-package aliases without editing their accepted records.')
    parser.add_argument('--late-packages', action='store_true',
                        help='Use the release-reviewed recovered packages.')
    args = parser.parse_args()
    if sum((args.preview_packages, args.dread_spider, args.late_packages)) > 1:
        parser.error('Select only one alias batch')
    if args.preview_packages and (args.activate or args.check_active or args.dread_spider):
        parser.error('--preview-packages only runs the isolated client preview')
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    actions = read(LEDGER)['original_mul_group_candidates']
    proofs = []
    selected = {11: 'arachnids_spider_dread'} if args.dread_spider else REVIEWED
    # Pixel-only matches use the native evidence gate in accept-classic-gestures.py.
    late_aliases = {body: proof for body, proof in read(LATE_ALIASES).items()
                    if 'matched_payload_signature' not in proof} if args.late_packages else {}
    if late_aliases:
        selected = {int(body): proof['kind'] for body, proof in late_aliases.items()}
    if args.preview_packages:
        active = {int(identity['body']): row for row in index['entries'] if row['status'] == 'validated'
                  for identity in row['bodies']}
        selected = {}
        for action in actions:
            body = action['body']
            if (action['group'] != 11 or body in REVIEWED or body == 11
                    or action.get('matching_classic_route', {}).get('resolved', '') is not None
                    or not set(action.get('same_payload_groups', [])) & {17, 18}
                    or body not in active or len(active[body]['bodies']) != 1):
                continue
            selected[body] = active[body]['kind']
        if not selected:
            raise ValueError('No exact-package aliases to preview')
    for body, kind in selected.items():
        matches = [row for row in index['entries'] if row['status'] == 'validated'
                   and any(int(identity['body']) == body for identity in row['bodies'])]
        if (args.dread_spider and args.check_active and matches
                and matches[-1].get('classic_gesture_batch') == 'tokuno_spider_dragon_actions'):
            gate = runpy.run_path(str(ROOT / 'scripts/accept-classic-gestures.py'))
            baseline, _ = gate['checked'](index, True, 'tokuno_spider_dragon_actions')
            original, = (row for row in baseline if row['kind'] == kind)
            sibling, = (row for row in index['entries'] if row['kind'] == kind)
            if (original.get('classic_action_categories_by_body') != {'11': {'11': 'Fidget'}}
                    or sibling != dict(original, bodies=[identity for identity in original['bodies'] if identity['body'] == 19])):
                raise ValueError('Fitted Dread Spider must retain the reviewed body 19 sibling')
            proof = alias_proof(body, actions, (17,))
            proof.update(kind=matches[-1]['kind'], unchanged_body=19)
            proofs.append({'proof': proof, 'presentation': matches[-1], 'unchanged_presentation': sibling})
            continue
        if not matches or matches[-1]['kind'] != kind:
            raise ValueError(f'Active registry does not select {kind} for {body}')
        row = matches[-1]
        proof = alias_proof(body, actions, (17, 18) if args.preview_packages or late_aliases else (17,))
        proof['kind'] = kind
        if args.dread_spider:
            scoped_categories = {'11': {'11': 'Fidget'}}
            if ({int(identity['body']) for identity in row['bodies']} != {11, 19}
                    or row.get('classic_action_categories', {}).get('11') is not None
                    or row.get('classic_action_categories_by_body') not in (None, scoped_categories)
                    or row.get('presentation_script') not in (None, f'res://{DREAD_RENDERER}')):
                raise ValueError('Unexpected shared Dread Spider route')
            if args.check_active and row.get('presentation_script') != f'res://{DREAD_RENDERER}':
                raise ValueError('Dread Spider alias is not active')
            row['presentation_script'] = f'res://{DREAD_RENDERER}'
            row['presentation_script_sha256'] = hashlib.sha256((ROOT / 'Viewer' / DREAD_RENDERER).read_bytes()).hexdigest()
            row['classic_action_categories_by_body'] = scoped_categories
            proof['unchanged_body'] = 19
            proofs.append({'proof': proof, 'presentation': row})
            continue
        identity, = row['bodies']
        if int(identity['body']) != body or identity['native_profile'] != 'monster':
            raise ValueError(f'Unexpected active identity for {kind}')
        categories = row.setdefault('classic_action_categories', {})
        if categories.get('11', 'Fidget') != 'Fidget':
            raise ValueError(f'{kind} already has a different dedicated slot 11')
        if args.check_active and categories.get('11') != 'Fidget':
            raise ValueError(f'{kind} has no active slot 11 alias')
        categories['11'] = 'Fidget'
        if late_aliases:
            sealed = late_aliases[str(body)]
            signature = hashlib.sha256(''.join(
                direction['payload_sha256'] for direction in proof['directions']).encode('ascii')).hexdigest()
            if (sealed['family'] != row['family'] or sealed['sibling'] != proof['identical_slot']
                    or sealed['payload_signature'] != signature
                    or args.check_active and row.get('legacy_slot11_evidence') != sealed):
                raise ValueError(f'Legacy package alias evidence changed for {kind}')
            row['legacy_slot11_evidence'] = sealed
        proofs.append({'proof': proof, 'presentation': row})

    batch = ('late-packages' if late_aliases else 'preview-packages' if args.preview_packages
             else 'dread-spider' if args.dread_spider else 'candidates')
    trial = TRIAL.with_name(f'{batch}.json' if batch != 'preview-packages' else 'packages.json')
    trial.parent.mkdir(parents=True, exist_ok=True)
    trial.write_text(json.dumps(proofs, indent=2) + '\n', encoding='utf-8')
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    command = [str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
               'res://Presentation/LegacyCreatureAliasTests.gd']
    flags = [] if batch == 'candidates' else [f'--{batch}']
    env = dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir)
    subprocess.run(command + ['--', *flags, *(['--active'] if args.check_active else [])],
                   env=env, check=True, timeout=90)
    if args.activate:
        if INDEX.read_bytes() != previous:
            raise RuntimeError('Local registry changed during alias trial')
        pending = INDEX.with_suffix('.legacy-aliases.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode('utf-8')
        pending.write_bytes(updated)
        pending.replace(INDEX)
        try:
            subprocess.run(command + ['--', *flags, '--active'], env=env, check=True, timeout=90)
            checked_publishers = set()
            for family in sorted({proof['family'] for proof in late_aliases.values()}):
                if family in PUBLICATION_TESTS:
                    publisher = PUBLICATION_TESTS[family]
                    if publisher not in checked_publishers:
                        subprocess.run([sys.executable, '-B', str(ROOT / 'scripts' / publisher), '--check-active'],
                                       env=env, check=True, timeout=180)
                        checked_publishers.add(publisher)
                    continue
                script = PACKAGE_TESTS.get(family, 'LateCreatureRouteTests.gd')
                subprocess.run(command[:-1] + [f'res://Presentation/{script}',
                                              '--', f'--family={family}'],
                               env=env, check=True, timeout=45)
        except (subprocess.SubprocessError, OSError):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(previous)
                pending.replace(INDEX)
            raise
        print(f'Activated {len(proofs)} exact legacy action aliases')


if __name__ == '__main__':
    main()
