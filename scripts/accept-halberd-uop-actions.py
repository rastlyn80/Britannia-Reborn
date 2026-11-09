"""Activate the fitted Animated Weapon motions after exact two-client playback."""

import argparse
import json
from pathlib import Path
import runpy
import shutil


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'scripts'
VIEWER = ROOT / 'Viewer'
WORK = ROOT / 'work/creatures/halberd-uop'
NATIVE = WORK / 'native-verified'
SEALED = WORK / 'accepted-native'
FAMILY = 'halberd_uop_verified_01'
BODY = 692
RESULT = ROOT / 'outputs/creatures' / FAMILY / 'live.json'
INDEX = VIEWER / 'local-art/creatures/accepted-index.json'
ASSET = 'res://local-art/creatures/animated_weapon/animated-weapon-uop.scn'
CLIPS = {'1': 'UopHalberdHover', '10': 'UopHalberdRecoil', '23': 'UopHalberdRise',
         '25': 'UopHalberdReadyHover', '28': 'UopHalberdSpin'}
GROUPS = {'2': '10', '8': '28', '11': '1', '14': '1', '15': '23'}
ROUTES = {kind: CLIPS[group] for kind, group in GROUPS.items()}
COMMON = runpy.run_path(str(SCRIPTS / 'prepare-post-solen-actions.py'))
read, sha = COMMON['read'], COMMON['sha']


def body_row(index):
    base, = (row for row in index['entries'] if row['status'] == 'validated'
             and [int(identity['body']) for identity in row['bodies']] == [BODY])
    assert base['kind'] == 'animated_weapon'
    return base


def prepared(base):
    assert base['family'] == 'animated_weapon' and base['uop_redirect_targets']
    assert not base.get('uop_motion_native_sha256')
    before, digest = base['assets']['modern'], base['asset_sha256']['modern']
    assert set(base['assets'].values()) == {before} and sha(VIEWER / before[6:]) == digest
    scene = sha(VIEWER / ASSET[6:])
    fit = sha(WORK / 'fit.json')
    bake = read(WORK / 'bake.json')
    assert {key: bake[key] for key in ('source_asset', 'source_sha256', 'scene_sha256', 'fit_sha256', 'baker_sha256')} == {
        'source_asset': before, 'source_sha256': digest, 'scene_sha256': scene,
        'fit_sha256': fit, 'baker_sha256': sha(SCRIPTS / 'bake-halberd-uop-actions.gd')}
    assert 0.0 < bake['maximum_lift'] < 0.50
    pins = read(SCRIPTS / 'halberd-uop-pins.json')
    modes = {mode['mode']: mode for mode in pins['modes']}
    for kind, group in GROUPS.items():
        assert set(modes[0]['packet_groups'][kind]) == {int(group)}
        assert modes[1]['fallback_mode'] == 0 and kind not in modes[1]['packet_groups']
    assert modes[0]['packet_groups']['5'] != modes[1]['packet_groups']['5'] and '5' not in ROUTES
    replacements = {clip: f'Rigid shaft axis and centre fitted to five UOP directions for group {group}'
                    for group, clip in CLIPS.items()}
    return dict(base, status='prepared', family=FAMILY, assets=dict.fromkeys(base['assets'], ASSET),
                asset_sha256=dict.fromkeys(base['asset_sha256'], scene),
                uop_motion_base_asset=before, uop_motion_base_sha256=digest,
                uop_motion_fit_sha256=fit, uop_motion_packet_groups=GROUPS,
                authored_replacements=base.get('authored_replacements', {}) | replacements,
                new_action_categories=base.get('new_action_categories', {}) | ROUTES)


def native(ready, active):
    evidence = runpy.run_path(str(SCRIPTS / 'creature-packet-evidence.py'))
    return evidence['checked'](NATIVE, FAMILY, [ready], {BODY: 'AnimatedWeapon'}, {BODY: ROUTES}, 85,
                               sealed=SEALED if active else None)


def retained(row):
    if 'uop_motion_native_sha256' not in row:
        return row
    base = read(SEALED / 'base.json')
    ready = prepared(base)
    assert row == dict(ready, status='validated', family=base['family'], uop_motion_native_sha256=native(ready, True))
    return base


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    helper = runpy.run_path(str(SCRIPTS / 'prepare-halberd-uop-fit.py'))
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    assert helper['reconstruct'](helper['checked_frames'](data, read(helper['PINS']))) == read(WORK / 'fit.json')
    original = INDEX.read_bytes()
    index = json.loads(original)
    row = body_row(index)
    run_client = runpy.run_path(str(SCRIPTS / 'prepare-creature-uop-redirects.py'))['run_client']
    if args.check_active:
        assert retained(row) != row
        run_client('res://../scripts/test-halberd-uop-actions.gd', ['--active'])
        print('ANIMATED WEAPON UOP ACTIONS: active and verified')
        return
    ready = prepared(row)
    accepted = dict(ready, status='validated', family=row['family'], uop_motion_native_sha256=native(ready, False))
    SEALED.mkdir(parents=True, exist_ok=True)
    trial = ROOT / 'work/creatures' / FAMILY
    for source in (RESULT, trial / 'candidates.json', trial / 'native-runtime.json'):
        shutil.copyfile(source, SEALED / source.name)
    (SEALED / 'base.json').write_text(json.dumps(row, indent=2) + '\n', encoding='utf-8')
    index['entries'] = [accepted if item == row else item for item in index['entries']]
    assert INDEX.read_bytes() == original
    pending = INDEX.with_suffix('.halberd.pending')
    updated = (json.dumps(index, indent=2) + '\n').encode()
    pending.write_bytes(updated)
    pending.replace(INDEX)
    try:
        assert retained(body_row(read(INDEX))) == row
        run_client('res://../scripts/test-halberd-uop-actions.gd', ['--active'])
        run_client('res://Presentation/LateCreatureRouteTests.gd', ['--family=animated_weapon'])
        assert INDEX.read_bytes() == updated
    except BaseException:
        if INDEX.read_bytes() == updated:
            pending.write_bytes(original)
            pending.replace(INDEX)
        raise
    print('ANIMATED WEAPON UOP ACTIONS: activated and verified')


if __name__ == '__main__':
    main()
