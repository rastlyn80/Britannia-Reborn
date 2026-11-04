"""Apply reviewed exact-frame aliases to locally accepted generic creatures."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'
LEDGER = ROOT / 'outputs/creatures/actions.json'
TRIAL = ROOT / 'work/creatures/legacy-aliases/candidates.json'
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
    return {'body': body, 'kind': REVIEWED[body], 'original_slot': 11, 'identical_slot': 17,
            'clip': 'Fidget', 'archive': source['archive'], 'graphic': source['graphic'],
            'directions': source['directions']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    previous = INDEX.read_bytes()
    index = json.loads(previous.decode('utf-8-sig'))
    actions = read(LEDGER)['original_mul_group_candidates']
    proofs = []
    for body, kind in REVIEWED.items():
        matches = [row for row in index['entries'] if row['status'] == 'validated'
                   and any(int(identity['body']) == body for identity in row['bodies'])]
        if not matches or matches[-1]['kind'] != kind:
            raise ValueError(f'Active registry does not select {kind} for {body}')
        row = matches[-1]
        identity, = row['bodies']
        if int(identity['body']) != body or identity['native_profile'] != 'monster':
            raise ValueError(f'Unexpected active identity for {kind}')
        proof = alias_proof(body, actions)
        categories = row.setdefault('classic_action_categories', {})
        if categories.get('11', 'Fidget') != 'Fidget':
            raise ValueError(f'{kind} already has a different dedicated slot 11')
        if args.check_active and categories.get('11') != 'Fidget':
            raise ValueError(f'{kind} has no active slot 11 alias')
        categories['11'] = 'Fidget'
        proofs.append({'proof': proof, 'presentation': row})

    TRIAL.parent.mkdir(parents=True, exist_ok=True)
    TRIAL.write_text(json.dumps(proofs, indent=2) + '\n', encoding='utf-8')
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    command = [str(godot), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
               'res://Presentation/LegacyCreatureAliasTests.gd']
    env = dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir)
    subprocess.run(command + (['--', '--active'] if args.check_active else []),
                   env=env, check=True, timeout=90)
    if args.activate:
        if INDEX.read_bytes() != previous:
            raise RuntimeError('Local registry changed during alias trial')
        pending = INDEX.with_suffix('.legacy-aliases.pending')
        updated = (json.dumps(index, indent=2) + '\n').encode('utf-8')
        pending.write_bytes(updated)
        pending.replace(INDEX)
        try:
            subprocess.run(command + ['--', '--active'], env=env, check=True, timeout=90)
        except (subprocess.SubprocessError, OSError):
            if INDEX.read_bytes() == updated:
                pending.write_bytes(previous)
                pending.replace(INDEX)
            raise
        print(f'Activated {len(proofs)} exact legacy action aliases')


if __name__ == '__main__':
    main()
