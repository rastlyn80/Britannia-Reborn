"""Compose the native-tested Gargoyle action with its sealed base package."""

import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
KIND = 'gargoyles_gargoyle_slave'
WORK = ROOT / 'work/creatures/gargoyle_pillage'
LIVE = ROOT / 'outputs/creatures/gargoyle_pillage/live.json'
SEALED = WORK / 'accepted-native'
SOURCE = {
    'body': 753, 'group': 11, 'archive': 'AnimationFrame4.uop', 'frame_headers': 65,
    'payload_sha256': '7645864d894aee1d394f8c38fb235392553b3ccf8b29b0cb34913ae3cd6bfaef',
}
DESCRIPTION = 'Authored crouch and alternating reach from preferred UOP reference'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def compose(base, sealed):
    folder = SEALED if sealed else WORK
    report_path = SEALED / 'live.json' if sealed else LIVE
    candidate_path = folder / 'candidates.json'
    receipt = read(folder / 'native-runtime.json')
    report = read(report_path)
    if (receipt['report_sha256'] != sha(report_path)
            or receipt['candidate_sha256'] != sha(candidate_path)
            or report['candidate_sha256'] != sha(candidate_path)
            or report['prepared_wrapper_sha256'] != sha(ROOT / 'Viewer/Network/GargoylePillageLive.gd')
            or report['test_sha256'] != sha(ROOT / 'Viewer/Network/CreatureLive.gd')
            or report['fixture_sha256'] != sha(ROOT / 'Server/HorseIntegrationFixtures/CreatureFixtures.cs')
            or report['failures'] or not report['prepared_trial']):
        raise ValueError('Gargoyle native evidence no longer matches its inputs')
    candidate, = read(candidate_path)
    if candidate['native_class'] != 'EnslavedGargoyle' or candidate['body'] != 753:
        raise ValueError('Wrong native constructor in Gargoyle evidence')
    assets = {treatment: 'res://local-art/creatures/gargoyle-753-pillage-trial'
              + ('' if treatment == 'modern' else '-' + treatment) + '.scn'
              for treatment in base['assets']}
    pins = {name: sha(ROOT / 'Viewer' / path.removeprefix('res://')) for name, path in assets.items()}
    row = dict(base, assets=assets, authored_action_reference=SOURCE,
               authored_action_scene_sha256=pins,
               classic_action_categories=base['classic_action_categories'] | {'11': 'Pillage'},
               authored_replacements=base['authored_replacements'] | {'Pillage': DESCRIPTION})
    if candidate['presentation'] != dict(row, status='prepared', family='gargoyle_pillage'):
        raise ValueError('The Gargoyle trial differs from the original package plus the verified action')
    witnessed = set()
    for record in report['records']:
        routes = [action for action in record['actions'] if action['requested'] == 11]
        if (record['body'] != 753 or record['native_class'] != 'EnslavedGargoyle'
                or record['kind'] != KIND or record['corpse_suppressed'] or record['native_death_refused']
                or len(routes) != 1 or any(routes[0][side] != 'Pillage' for side in ('owner_clip', 'observer_clip'))):
            raise ValueError('Missing two-client native witness for Gargoyle Pillage')
        witnessed.add(record['female'])
    if len(report['records']) != 2 or witnessed != {False, True}:
        raise ValueError('Expected one native witness from each client')
    return dict(row, authored_action_base_assets=base['assets'], authored_action_native_sha256=sha(report_path))


def seal():
    SEALED.mkdir(exist_ok=True)
    for source in (LIVE, WORK / 'native-runtime.json', WORK / 'candidates.json'):
        shutil.copyfile(source, SEALED / source.name)
