"""Check exact prepared creature packets observed by two disposable clients."""

import hashlib
from itertools import product
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / 'Viewer/local-art/creatures/accepted-index.json'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def checked(native, family, rows, classes, routes, checks, sealed=None):
    work = sealed or ROOT / 'work/creatures' / family
    result = work / 'live.json' if sealed else ROOT / 'outputs/creatures' / family / 'live.json'
    candidates = work / 'candidates.json'
    receipt = read(work / 'native-runtime.json')
    report = read(result)
    digest = sha(result)
    assert report['prepared_trial'] and report['failures'] == 0 and report['checks'] == checks
    assert report['candidate_sha256'] == receipt['candidate_sha256'] == sha(candidates)
    assert receipt['report_sha256'] == digest
    assert report['routes_sha256'] == sha(native / family / 'routes.json')
    assert report['test_sha256'] == sha(native / 'ClassicGestureBridgeLive.gd')
    assert report['dispatcher_sha256'] == sha(ROOT / 'Viewer/Presentation/CreatureWireActions.gd')
    assert receipt['selector_sha256'] == sha(native / 'prepare-bridge-fixtures.py')
    assert receipt['runner_sha256'] == sha(native / 'test-native-bridge.ps1')
    fixture = native / 'fixture/ClassicWireFixtures.cs'
    assert receipt['build_inputs_sha256'][fixture.relative_to(ROOT).as_posix()] == sha(fixture)
    actual = read(candidates)
    expected = {int(row['bodies'][0]['body']): row for row in rows}
    assert len(actual) == len(expected) and {row['body']: row['presentation'] for row in actual} == expected
    assert {row['body']: row['native_class'] for row in actual} == classes
    records = report['records']
    assert len(records) == len(classes) * 2
    assert {(row['body'], row['native_class'], row['female']) for row in records} == {
        (body, name, female) for body, name in classes.items() for female in (False, True)}
    observed = set()
    for witness in report['classic_wire_witnesses']:
        body, kind, mode = witness['body'], witness['type'], witness['mode']
        assert witness['clip'] == routes[body][str(kind)] and len(witness['packets']) == 2
        for packet in witness['packets']:
            assert (packet['protocol'], packet['body'], packet['type'], packet['subaction'], packet['variation'],
                    packet['serial']) == ('new', body, kind, 0, mode, witness['serial'])
        observed.add((body, witness['female'], str(kind), mode))
    assert len(report['classic_wire_witnesses']) == len(observed)
    assert observed == {(body, female, kind, mode) for body, row in routes.items()
                        for female, kind, mode in product((False, True), row, (0, 1))}
    if sealed is None:
        assert report['accepted_index_sha256'] == sha(INDEX)
    return digest
