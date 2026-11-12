"""Check installed Classic frame references and activate the local cattle scenes."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/animals'
MARKER = ART / 'bovine-actions-active.json'
BAKE = ART / 'bovine-actions-bake.json'
REPORT = ROOT / 'outputs/ostard-riding/bovine-live.json'
OUTPUT = ROOT / 'outputs/bovines/actions.json'
EVIDENCE = ROOT / 'work/creatures/bovine-actions'
FORMS = {216: 'bovine_cow_spotted', 231: 'bovine_cow_brown', 232: 'bovine_bull_brown', 233: 'bovine_bull_spotted'}
ROUTES = {0: 'Walk', 1: 'Run', 2: 'Idle', 3: 'Eat', 5: 'Attack', 6: 'Attack2', 7: 'Hit',
          8: 'Death', 9: 'Fidget', 10: 'Fidget2', 12: 'Death2'}
TREATMENTS = ('original', 'rounded', 'modern')
BAKE_INPUTS = ('scripts/bake-bovine-actions.gd', 'scripts/bake-troll-actions.gd',
               'scripts/bake-skeleton-actions.gd', 'Viewer/Presentation/WaterElementalFidgets.gd',
               'Viewer/Presentation/SourceGroundLookup.gd')
NATIVE_INPUTS = ('Network/OstardLive.gd', 'Network/BovineLiveTransition.gd', 'Presentation/BovineActionsVisual.gd',
                 'Presentation/CreatureDeathsWithBovines.gd', 'Presentation/CreatureDeaths.gd',
                 'Presentation/AnimalVisual.gd', 'Presentation/BovineVisual.gd',
                 'Presentation/CorpseModels.gd', 'Presentation/WorldItems.gd',
                 '../Server/HorseIntegrationFixtures/EquineFixtures.cs', 'local-art/animals/bovine-actions-bake.json')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    staged = path.with_suffix('.tmp')
    staged.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    staged.replace(path)


def verify_original_groups():
    data = Path(read(ROOT / 'Server/runtime/Configuration/modernuo.json')['dataDirectories'][0])
    ledger = runpy.run_path(str(ROOT / 'scripts/build-creature-actions.py'))
    groups, _, _ = ledger['original_mul_groups'](data, set(FORMS))
    pins = read(ROOT / 'scripts/bovine-frame-pins.json')
    result = {str(body): {} for body in FORMS}
    for row in groups:
        body, group = row['body'], row['group']
        directions = row['directions']
        assert row['archive'] == 'anim.mul' and row['graphic'] == body and row['layout'] == 'small'
        assert not row['mobtype_prefers_uop'] and [item['direction'] for item in directions] == list(range(5))
        frames, digest = pins[str(body)][str(group)]
        assert all(item['frames'] == frames for item in directions)
        payloads = ''.join(item['payload_sha256'] for item in directions).encode('ascii')
        assert hashlib.sha256(payloads).hexdigest() == digest
        result[str(body)][str(group)] = {'clip': ROUTES[group], 'archive': row['archive'],
                                        'frames_per_direction': frames, 'directional_payload_sha256': digest}
    assert all(set(groups) == {str(group) for group in ROUTES} for groups in result.values())
    return result


def verify_bake():
    bake = read(BAKE)
    assert bake['inputs'] == {Path(path).name: sha(ROOT / path) for path in BAKE_INPUTS}
    scenes = {}
    for kind in FORMS.values():
        for treatment in TREATMENTS:
            stem = f'{kind}-{treatment}'
            scene = f'{stem}-actions.scn'
            scenes[scene] = {'source': sha(ART / f'{stem}.gltf'), 'scene': sha(ART / scene)}
    assert bake['scenes'] == scenes


def verify_native(path):
    report = read(path)
    assert report['checks'] >= 518 and report['failures'] == 0
    assert report['bovine_inputs'] == {file: sha(VIEWER / file) for file in NATIVE_INPUTS}
    witnesses = {(row['body'], row['female']): row for row in report['bovine_actions']}
    assert set(witnesses) == {(body, female) for body in FORMS for female in (False, True)}
    assert len(report['bovine_actions']) == len(witnesses)
    for (body, female), row in witnesses.items():
        owner, observer = row['transitions']
        assert owner['corpse'] == observer['corpse'] and owner['corpse'] > 0
        for event in (owner, observer):
            assert event['body'] == body and event['hue'] == 0x8035
            assert event['clip'] == ('Death2' if female else 'Death')
            assert (event['position'] > 0) if female else (event['position'] == 0)
    return report


def check_client(candidate):
    godot, = sorted((ROOT / '.tools/godot').glob('*console.exe'))
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    for name in ('test-bovine-actions', 'test-bovine-deaths'):
        args = [str(godot), '--headless', '--log-file', str(EVIDENCE / f'{name}.log'),
                '--path', str(VIEWER), '--script', f'res://../scripts/{name}.gd']
        if candidate and name == 'test-bovine-deaths':
            args.extend(('--', '--candidate'))
        # The full 72-handoff corpse replay can exceed 50 wall-clock seconds.
        timeout = 180 if name == 'test-bovine-deaths' else 50
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        print(result.stdout, end='')
        assert result.returncode == 0 and 'SCRIPT ERROR:' not in result.stderr
        assert 'ERROR:' not in result.stdout + result.stderr, result.stderr


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--activate', action='store_true')
    mode.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    groups = verify_original_groups()
    verify_bake()
    previous = read(MARKER) if args.check_active else {}
    if args.check_active:
        digest = previous['native_sha256']
        assert len(digest) == 64 and all(character in '0123456789abcdef' for character in digest)
        native_path = EVIDENCE / f'{digest}.json'
    else:
        native_path = REPORT
    report = verify_native(native_path)
    receipt = {'bake_sha256': sha(BAKE), 'native_sha256': sha(native_path),
               'frame_pins_sha256': sha(ROOT / 'scripts/bovine-frame-pins.json')}
    if args.activate:
        check_client(candidate=True)
        sealed = EVIDENCE / f"{receipt['native_sha256']}.json"
        staged = sealed.with_suffix('.tmp')
        staged.write_bytes(native_path.read_bytes())
        assert sha(staged) == receipt['native_sha256']
        staged.replace(sealed)
        write(MARKER, receipt)
    if args.check_active:
        assert previous == receipt
        check_client(candidate=False)
    write(OUTPUT, {'routed_classic_groups': sum(map(len, groups.values())), 'bodies': groups,
                   'shared_classic_action_pairs': 0,
                   'native_checks': report['checks'], 'active': args.activate or args.check_active,
                   'scope': 'Cattle-only Classic ledger. Three fitted replacements per body. Cow.Tip is a distinct living packet signature.'})
    print('BOVINE ACTIONS: 44 stored groups across four bodies, 12 separated pairs, exact source and native evidence')


if __name__ == '__main__':
    main()
