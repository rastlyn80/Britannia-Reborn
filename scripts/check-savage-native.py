"""Prepared Savage witnesses and the actual disposable runtime, not acceptance."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def main():
    folder = ROOT/'work/creatures/savages'
    report = read(folder/'native-tests.json')
    receipt = read(folder/'native-runtime.json')
    assert sha(folder/'native-tests.json') == receipt['report_sha256']
    runtime = Path(receipt['runtime']).resolve()
    assert runtime.is_relative_to((ROOT/'work/creature-session').resolve())
    assert runtime.name == 'server'
    for name, digest in receipt['build_inputs_sha256'].items():
        assert sha(ROOT/name) == digest, name
    assert len(receipt['assemblies_sha256']) == 4
    for name, digest in receipt['assemblies_sha256'].items():
        assert sha(runtime/name) == digest, name
    assert receipt['assemblies_sha256']['Assemblies/UOContent.dll'] == receipt['reviewed_content_sha256']
    for name, digest in report['inputs_sha256'].items():
        assert sha(ROOT/name) == digest, name
    assert report['failures'] == 0 and report['checks'] > 2000
    assert report['preparation_sha256'] == sha(ROOT/'Viewer/local-art/human-npcs/savages/dance/preparation.json')
    assert report['death_preparation_sha256'] == sha(ROOT/'Viewer/local-art/human-npcs/shared/death-preparation.json')
    identity = [r for r in report['records'] if 'kind' in r]
    groups = [r for r in report['records'] if 'quorum' in r]
    assert len(identity) == len(groups) == 8
    assert {(r['owner'], r['kind'], r['body']) for r in identity} == {
        (owner, kind, body) for owner in [0, 1] for kind in ['savage', 'shaman'] for body in [183, 184]}
    actions = set(range(35)) - set(range(23, 30))
    for row in identity:
        assert {a['action'] for a in row['actions']} == actions
        assert len(row['actions']) == 28
        assert row['native_class'] == ('Savage' if row['kind'] == 'savage' else 'SavageShaman')
        assert all(a['protocol'] == 'classic' and a['body'] == row['body'] for a in row['actions'])
        death = row['death']
        assert death['body'] == row['body'] and death['corpse'] > 0 and death['hue'] == 0x8035
        assert len(death['witnesses']) == 2
        for witness in death['witnesses']:
            assert witness['corpse'] == death['corpse'] and witness['body'] == row['body']
            assert witness['hue'] == death['hue'] and witness['clip'] == 'Death' and witness['grounded']
            assert witness['equipment'] == row['native_items']
    assert {(r['owner'], r['body'], r['quorum']) for r in groups} == {
        (owner, body, quorum) for owner in [0, 1] for body in [183, 184] for quorum in [1, 4]}
    for row in groups:
        assert len(row['dancers']) == row['quorum']
        assert 1 <= len(row['attempts']) <= 24
        if row['quorum'] == 4:
            assert row['native_group_effects'] == {'heal': True, 'lightning': True, 'poison': True}
            assert any(a['healed'] for a in row['attempts'])
            assert any(a['damaged'] for a in row['attempts'])
            assert any(a['poisoned'] for a in row['attempts'])
        else:
            assert not row['native_group_effects']
            assert not any(a['healed'] or a['damaged'] or a['poisoned'] for a in row['attempts'])
        for attempt in row['attempts']:
            early, late = attempt['early'], attempt['late']
            assert int(early[2]) < 1000 <= int(late[2])
            assert int(early[4])-int(early[3]) < 25 and early[5] == early[6] and int(early[7]) < 0
            assert late[8] == '1'
    print(f"SAVAGE NATIVE: {report['checks']} checks, eight two-client identity/action/death cases and eight native group/timer cases; exact source/build/runtime receipt. Prepared only.")

if __name__ == '__main__':
    main()
