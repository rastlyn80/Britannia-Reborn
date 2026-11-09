"""Verify the Classic decoder's newer gesture compatibility against local MUL frames."""

import argparse
import hashlib
from itertools import product
from pathlib import Path
import runpy
import subprocess


ROOT = Path(__file__).resolve().parents[1]
COMMON = runpy.run_path(str(ROOT / 'scripts/prepare-post-solen-actions.py'))
read, sha = COMMON['read'], COMMON['sha']
ROUTES = ROOT / 'Viewer/Presentation/creature-classic-gesture-bridge.json'
PINS = ROOT / 'scripts/classic-gesture-bridge-pins.json'
NATIVE_WORK = ROOT / 'work/creatures/classic-gesture-bridge/native'
GROUPS = {'5': (17, 18), '8': (11, 11)}


def check_shape(routes, pins):
    assert routes.keys() == pins['routes'].keys() == pins['native_classes'].keys()
    assert len(routes) == 155 and sum(map(len, routes.values())) == 288
    existing = read(ROOT / 'Viewer/Presentation/creature-wire-routes.json')
    for body, types in routes.items():
        assert set(types) <= GROUPS.keys() and types.keys() == pins['routes'][body].keys()
        assert not types.keys() & existing.get(body, {}).keys()
        for kind, rule in types.items():
            assert tuple(rule[:2]) == GROUPS[kind]
            clips = rule[2:]
            assert len(clips) in (1, 2) and len(set(clips)) == len(clips)
            assert all(isinstance(clip, str) and clip for clip in clips)
            if kind == '8':
                assert len(clips) == 1
            assert [row[0] for row in pins['routes'][body][kind]] == list(dict.fromkeys(GROUPS[kind]))


def check_source(data, routes, pins):
    assert pins['metadata'] == {name: sha(data / name) for name in pins['metadata']}
    reference = ROOT / 'work/reference/ClassicUO'
    if (reference / '.git').exists():
        for path, digest in pins['reference_files'].items():
            content = subprocess.check_output(['git', '-C', str(reference), 'show',
                                               f'{pins["reference_commit"]}:{path}'])
            assert hashlib.sha256(content).hexdigest() == digest
    reader = runpy.run_path(str(ROOT / 'scripts/build-creature-actions.py'))
    groups, _, flags = reader['original_mul_groups'](data, set(map(int, routes)))
    lookup = {(row['body'], row['group']): row for row in groups}
    for body, types in pins['routes'].items():
        assert flags[int(body)][0] == 'MONSTER'
        for refs in types.values():
            for group, archive, graphic, digest in refs:
                row = lookup[int(body), group]
                assert row['layout'] == 'large' and not row['mobtype_prefers_uop']
                assert (row['archive'], row['graphic']) == (archive, graphic)
                directions = row['directions']
                assert [direction['direction'] for direction in directions] == list(range(5))
                encoded = ''.join(direction['payload_sha256'] for direction in directions).encode('ascii')
                assert hashlib.sha256(encoded).hexdigest() == digest
    print(f'Classic gesture compatibility source: {sum(map(len, routes.values()))} types on {len(routes)} bodies')


def check_native(routes, trial):
    families = read(trial / 'shards.json')
    covered = set()
    checks, observations = 0, 0
    for family, body_keys in families.items():
        assert family.startswith('classic_gesture_bridge_') and family.isidentifier()
        assert len(body_keys) == len(set(body_keys)) and not covered & set(body_keys)
        folder = trial / family
        table = read(folder / 'routes.json')
        constructors = read(folder / 'constructors.json')
        assert table == {body: routes[body] for body in body_keys}
        assert constructors.keys() == table.keys()
        result = ROOT / 'outputs/creatures' / family / 'live.json'
        report = read(result)
        work = ROOT / 'work/creatures' / family
        receipt = read(work / 'native-runtime.json')
        assert report['failures'] == 0 and report['prepared_trial']
        assert report['routes_sha256'] == sha(folder / 'routes.json')
        assert report['test_sha256'] == sha(trial / 'ClassicGestureBridgeLive.gd')
        assert report['dispatcher_sha256'] == sha(ROOT / 'Viewer/Presentation/CreatureWireActions.gd')
        assert receipt['report_sha256'] == sha(result)
        assert report['candidate_sha256'] == receipt['candidate_sha256'] == sha(work / 'candidates.json')
        assert receipt['runner_sha256'] == sha(trial / 'test-native-bridge.ps1')
        assert receipt['selector_sha256'] == sha(trial / 'prepare-bridge-fixtures.py')
        fixture = trial / 'fixture/ClassicWireFixtures.cs'
        assert receipt['build_inputs_sha256'][fixture.relative_to(ROOT).as_posix()] == sha(fixture)
        expected_actors = {(int(body), name, female) for body, name in constructors.items() for female in (False, True)}
        actual_actors = {(row['body'], row['native_class'], row['female']) for row in report['records']}
        assert actual_actors == expected_actors and len(actual_actors) == len(report['records'])
        expected = {(int(body), int(kind), mode, female) for body, types in table.items() for kind in types
                    for mode, female in product((0, 1), (False, True))}
        actual = set()
        for witness in report['classic_wire_witnesses']:
            body, kind, mode, female = (witness[key] for key in ('body', 'type', 'mode', 'female'))
            rule = table[str(body)][str(kind)]
            assert witness['clip'] == rule[2 + mode if len(rule) == 4 else 2]
            assert len(witness['packets']) == 2
            for packet in witness['packets']:
                assert (packet['protocol'], packet['body'], packet['type'], packet['subaction'], packet['variation'],
                        packet['serial']) == ('new', body, kind, 0, mode, witness['serial'])
            actual.add((body, kind, mode, female))
        assert actual == expected and len(actual) == len(report['classic_wire_witnesses'])
        covered.update(body_keys)
        checks += report['checks']
        observations += len(actual)
    assert covered == routes.keys()
    print(f'Classic gesture compatibility live: {checks} checks, {observations} two-client observations')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path)
    parser.add_argument('--routes', type=Path, default=ROUTES)
    parser.add_argument('--pins', type=Path, default=PINS)
    parser.add_argument('--native', type=Path, nargs='?', const=NATIVE_WORK)
    args = parser.parse_args()
    routes, pins = read(args.routes), read(args.pins)
    check_shape(routes, pins)
    config = ROOT / 'Server/runtime/Configuration/modernuo.json'
    if args.data_dir is not None or config.is_file():
        data = args.data_dir or Path(read(config)['dataDirectories'][0])
        check_source(data, routes, pins)
    if args.native:
        check_native(routes, args.native.resolve())


if __name__ == '__main__':
    main()
