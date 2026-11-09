"""Check installed Classic group pins and optionally the isolated two-client packet report."""

import argparse
import hashlib
from itertools import product
from pathlib import Path
import runpy
import subprocess


ROOT = Path(__file__).resolve().parents[1]
COMMON = runpy.run_path(str(ROOT / 'scripts/prepare-post-solen-actions.py'))
read, sha, new_actions = (COMMON[name] for name in ('read', 'sha', 'new_actions'))
ROUTES = ROOT / 'Viewer/Presentation/creature-wire-routes.json'
PINS = ROOT / 'scripts/creature-wire-route-pins.json'
FAMILY = 'classic_wire_aliases'


def checked_source(data, routes, pins, compare_pixels=False):
    assert pins['metadata'] == {name: sha(data / name) for name in pins['metadata']}
    bodies = set(map(int, routes))
    ledger = runpy.run_path(str(ROOT / 'scripts/build-creature-actions.py'))
    rows, _, _ = ledger['original_mul_groups'](data, bodies)
    source = {(row['body'], row['group']): row for row in rows}
    reader = runpy.run_path(str(ROOT / 'scripts/uo-human-sequences.py'))
    sequence = {row['animation_ref']: row for row in reader['inspect'](data / 'AnimationSequence.uop', bodies)}
    assert set(sequence) == bodies
    reference = ROOT / 'work/reference/ClassicUO'
    if (reference / '.git').exists():
        for file, digest in pins['classicuo_files'].items():
            source_bytes = subprocess.check_output(['git', '-C', str(reference), 'show', f'{pins["classicuo_commit"]}:{file}'])
            assert hashlib.sha256(source_bytes).hexdigest() == digest
    registered = runpy.run_path(str(ROOT / 'scripts/inspect-creature-mul-frames.py'))['group_pixels'] if compare_pixels else None
    for body, types in routes.items():
        assert types.keys() == pins['routes'][body].keys()
        metadata = sequence[int(body)]
        assert not metadata.get('parse_blocker')
        for kind, (even, odd, clip) in types.items():
            groups, references = pins['routes'][body][kind]
            assert clip and groups == new_actions(metadata)[kind]
            if kind in {'1', '2'}:
                assert (even, odd) == (16, 15) and set(groups) <= {15, 16}
                assert [row[0] for row in references] == [16, 15]
                if registered is not None:
                    assert registered(data, source[int(body), 16]) == registered(data, source[int(body), 15])
            else:
                assert kind in {'11', '14'} and even == odd == (12 if kind == '11' else 11)
                assert set(groups) == {even} and [row[0] for row in references] == [even]
            for slot, archive, graphic, digest in references:
                row = source[int(body), slot]
                assert row['layout'] == 'large' and not row['mobtype_prefers_uop']
                assert (row['archive'], row['graphic']) == (archive, graphic)
                directions = row['directions']
                assert [item['direction'] for item in directions] == list(range(5))
                assert digest == hashlib.sha256(''.join(item['payload_sha256'] for item in directions).encode('ascii')).hexdigest()
    print(f'Classic wire source: {sum(map(len, routes.values()))} types on {len(routes)} exact bodies')


def checked_native(routes):
    work = ROOT / 'work/creatures' / FAMILY
    path = ROOT / 'outputs/creatures' / FAMILY / 'live.json'
    report = read(path)
    receipt = read(work / 'native-runtime.json')
    assert not report['failures'] and report['prepared_trial'] and report['routes_sha256'] == sha(ROUTES)
    assert receipt['report_sha256'] == sha(path) and receipt['candidate_sha256'] == report['candidate_sha256'] == sha(work / 'candidates.json')
    assert report['test_sha256'] == sha(ROOT / 'Viewer/Network/ClassicWireAliasesLive.gd')
    assert report['dispatcher_sha256'] == sha(ROOT / 'Viewer/Presentation/CreatureWireActions.gd')
    fixture = 'Server/HorseIntegrationFixtures/ClassicWireFixtures.cs'
    assert receipt['build_inputs_sha256'][fixture] == sha(ROOT / fixture)
    assert receipt['runner_sha256'] == sha(ROOT / 'scripts/test-horses.ps1')
    assert receipt['selector_sha256'] == sha(ROOT / 'scripts/prepare-creature-fixtures.py')
    assert len(report['records']) == 2 * len(routes)
    assert {(row['body'], row['female']) for row in report['records']} == set(product(map(int, routes), (False, True)))
    expected = {(int(body), int(kind), mode, female) for body, types in routes.items() for kind in types
                for mode, female in product((0, 1), (False, True))}
    actual = set()
    for witness in report['classic_wire_witnesses']:
        body, kind, mode, female = (witness[name] for name in ('body', 'type', 'mode', 'female'))
        assert witness['clip'] and len(witness['packets']) == 2
        for packet in witness['packets']:
            assert (packet['protocol'], packet['body'], packet['type'], packet['subaction'], packet['variation'], packet['serial']) == (
                'new', body, kind, 0, mode, witness['serial'])
        actual.add((body, kind, mode, female))
    assert actual == expected and len(actual) == len(report['classic_wire_witnesses'])
    print(f'Classic wire live: {report["checks"]} checks and {len(actual)} two-client observations')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path)
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--compare-pixels', action='store_true')
    args = parser.parse_args()
    routes, pins = read(ROUTES), read(PINS)
    assert routes.keys() == pins['routes'].keys() and len(routes) == 66 and sum(map(len, routes.values())) == 110
    config = ROOT / 'Server/runtime/Configuration/modernuo.json'
    if args.data_dir is not None or config.is_file():
        data = args.data_dir or Path(read(config)['dataDirectories'][0])
        checked_source(data, routes, pins, compare_pixels=args.compare_pixels)
    if args.native:
        checked_native(routes)


if __name__ == '__main__':
    main()
