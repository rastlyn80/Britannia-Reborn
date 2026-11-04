"""Apply reviewed exact-frame aliases to locally accepted generic creatures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
LEDGER = ROOT / 'outputs/creatures/actions.json'
TRIAL = ROOT / 'work/creatures/legacy-aliases/candidates.json'
DREAD_RENDERER = 'Presentation/LegacyDreadSpiderVisual.gd'
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


def alias_proof(body, rows):
    sources = [row for row in rows if row['body'] == body and row['group'] == 11
               and row['layout'] == 'large' and 'matching_classic_route' in row]
    source, = sources
    target = next(
        row for row in rows if row['body'] == body and row['group'] == 17
        and all(row[name] == source[name] for name in ('archive', 'layout', 'graphic'))
    )
    if (17 not in source.get('same_payload_groups', []) or len(source['directions']) != 5
            or [item['payload_sha256'] for item in source['directions']] !=
            [item['payload_sha256'] for item in target['directions']]
            or target['matching_classic_route']['resolved'] != 'Fidget'
            or source['matching_classic_route']['resolved'] not in (None, 'Fidget')):
        raise ValueError(f'Classic group 11 has no exact reviewed match for {body}')
    return {'body': body, 'original_slot': 11, 'identical_slot': 17,
            'clip': 'Fidget', 'archive': source['archive'], 'graphic': source['graphic'],
            'directions': source['directions']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    parser.add_argument('--dread-spider', action='store_true',
                        help='Test or activate the body-specific Dread Spider alias only.')
    args = parser.parse_args()
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    actions = read(LEDGER)['original_mul_group_candidates']
    proofs = []
    selected = {11: 'arachnids_spider_dread'} if args.dread_spider else REVIEWED
    for body, kind in selected.items():
        matches = [row for row in index['entries'] if row['status'] == 'validated'
                   and any(int(identity['body']) == body for identity in row['bodies'])]
        if not matches or matches[-1]['kind'] != kind:
            raise ValueError(f'Active registry does not select {kind} for {body}')
        row = matches[-1]
        proof = alias_proof(body, actions)
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
        proofs.append({'proof': proof, 'presentation': row})

    trial = TRIAL.with_name('dread-spider.json') if args.dread_spider else TRIAL
    trial.parent.mkdir(parents=True, exist_ok=True)
    trial.write_text(json.dumps(proofs, indent=2) + '\n', encoding='utf-8')
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    command = [str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
               'res://Presentation/LegacyCreatureAliasTests.gd']
    flags = ['--dread-spider'] if args.dread_spider else []
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
        except (subprocess.SubprocessError, OSError):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(previous)
                pending.replace(INDEX)
            raise
        print(f'Activated {len(proofs)} exact legacy action aliases')


if __name__ == '__main__':
    main()
