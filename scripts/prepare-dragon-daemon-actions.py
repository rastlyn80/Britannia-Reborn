"""Check the source frames and saved scenes for the Dragon and Daemon actions."""

import hashlib
import json
from pathlib import Path, PureWindowsPath
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Viewer/local-art/creatures'
TREATMENTS = ('original', 'rounded', 'modern')
DRAGONS = {12, 59, 60, 61}
CLASSES = {
    9: ['Daemon'], 10: ['SummonedDaemon'], 12: ['Dragon', 'GreaterDragon'],
    38: ['ServantOfSemidar'], 40: ['Balron'], 43: ['IceFiend'],
    59: ['Dragon', 'GreaterDragon'], 60: ['Drake'], 61: ['Drake'],
}
IDLE_HASHES = {
    'dragons_wyrm_ancient_idle.grn': '1a58ebf07d4284fc189deb865cef24f71b241a12ee2cd1621ffd5ab2f595f753',
    'daemons_daemon_idle.grn': '0506af8e97406e213adb6aacdfb2bfdc8de33c9f08d4f416d949d30c9e695e1f',
}
JAW_HASH = '6f11b172ab252d5c59f6f76b7dbd79570f90e9cc795bca6d794c6cab03b4dec3'
DESCRIPTIONS = {
    'DragonDip': 'Authored head dip and wing brace on the recovered Ancient Wyrm rig',
    'DragonBreath': 'Authored wind-up and forward breath pose timed for the native projectile',
    'DaemonWingCheck': 'Authored shoulder and wing check on the recovered Daemon rig',
    'DaemonCast': 'Authored wing brace and reaching cast with the native facing preserved',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def prepared(entries):
    pins = read(ROOT / 'scripts/dragon-daemon-frame-pins.json')
    ledger = read(ROOT / 'outputs/creatures/actions.json')
    bake = read(ROOT / 'work/creatures/mul-motion-review/dragon-daemon-bake.json')
    assert bake['recipe'] == sha(ROOT / 'scripts/bake-dragon-daemon-gestures.gd')
    assert bake['joint_solver'] == sha(ROOT / 'scripts/bake-skeleton-axe-trial.gd')
    visual = 'Presentation/SourceDragonBreathVisual.gd'
    rows = []
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        for body, classes in CLASSES.items():
            base, = (row for row in entries if row['status'] == 'validated'
                     and any(identity['body'] == body for identity in row['bodies']))
            identity, = (entry for entry in base['bodies'] if entry['body'] == body)
            paths = {PureWindowsPath(item['path']).stem for item in identity['native_sources']}
            assert set(classes) <= paths
            donor = base['clip_sources']['Idle']
            assert hashlib.sha256(archive.read(donor)).hexdigest() == IDLE_HASHES[Path(donor).name]
            if body in DRAGONS:
                jaw = base['clip_sources']['Attack2']
                assert hashlib.sha256(archive.read(jaw)).hexdigest() == JAW_HASH
            categories = ({'11': 'DragonDip', '12': 'DragonBreath'} if body in DRAGONS else
                          {'11': 'DaemonWingCheck', '12': 'DaemonCast'} if body in (9, 10) else
                          {'12': 'DaemonCast'})
            assert categories.keys() == pins[str(body)].keys()
            references = {
                slot: reference(ledger, body, int(slot), pin) for slot, pin in pins[str(body)].items()
            }
            assets, scenes = {}, {}
            for treatment in TREATMENTS:
                kind = base['kind']
                file = f'{kind}-classic-{treatment}.scn'
                scenes[treatment] = sha(ART / file)
                source = sha(ART / f'{kind}-{treatment}.gltf')
                assert source == base['asset_sha256'][treatment]
                assert bake['forms'][kind][treatment] == {'source': source, 'scene': scenes[treatment]}
                assets[treatment] = f'res://local-art/creatures/{file}'
            row = dict(base, bodies=[identity], status='prepared', family='dragon_daemon',
                       assets=assets, authored_action_scene_sha256=scenes,
                       authored_action_reference=next(iter(references.values())), classic_motion_references=references,
                       classic_action_categories=base.get('classic_action_categories', {}) | categories,
                       authored_replacements=base.get('authored_replacements', {}) | {
                           clip: DESCRIPTIONS[clip] for clip in categories.values()})
            if body in DRAGONS:
                ratios = [value / source for value, source in zip(identity['scale'], base['bodies'][0]['scale'])]
                assert len(ratios) == 3 and ratios.count(ratios[0]) == 3
                row.update(presentation_script=f'res://{visual}', presentation_script_sha256=sha(ROOT / 'Viewer' / visual),
                           dragon_asset_scale=ratios[0])
            rows.append(row)
    return rows, CLASSES


def reference(ledger, body, slot, pin):
    archive, graphic, frames, digest = pin
    group, = (item for item in ledger['original_mul_group_candidates']
              if (item['body'], item['group']) == (body, slot) and 'matching_classic_route' in item)
    assert (group['archive'], group['graphic']) == (archive, graphic) and not group['mobtype_prefers_uop']
    directions = group['directions']
    assert [direction['direction'] for direction in directions] == list(range(5))
    assert all(direction['frames'] == frames for direction in directions)
    hashes = ''.join(direction['payload_sha256'] for direction in directions).encode('ascii')
    assert hashlib.sha256(hashes).hexdigest() == digest
    return dict(body=body, group=slot, archive=archive, graphic=graphic, frames=frames,
                directional_payload_sha256=digest)


def check_breath(report, candidates, rows):
    files = {
        'native_sha256': 'Server/ModernUO/Projects/UOContent/Mobiles/Abilities/Fire Breath/FireBreath.cs',
        'fixture_sha256': 'Server/HorseIntegrationFixtures/DragonBreathFixtures.cs',
        'test_sha256': 'Viewer/Network/DragonBreathLive.gd',
        'presenter_sha256': 'Viewer/Presentation/EffectPresenter.gd',
    }
    assert report['failures'] == 0 and report['candidate_sha256'] == sha(candidates)
    assert all(report[key] == sha(ROOT / path) for key, path in files.items())
    expected = {(body, name) for body in DRAGONS for name in CLASSES[body]}
    observed = set()
    for record in report['records']:
        body = record['body']
        assert set(record['launch_ms']) == {'0', '1'}
        assert all(1050 <= delay <= 1800 for delay in record['launch_ms'].values())
        assert record['damage'] > 0 and record['scene_sha256'] == rows[body]['authored_action_scene_sha256']['modern']
        observed.add((body, record['native_class']))
    assert observed == expected and len(report['records']) == len(expected)
