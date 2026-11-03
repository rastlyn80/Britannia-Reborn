"""Exact disposable native mounted Rider witnesses, separate from art acceptance."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    folder = ROOT/'work/creatures/savage-riders'
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
    assert report['failures'] == 0 and report['checks'] > 250
    assert len(report['records']) == 4
    assert {(r['owner'], r['body']) for r in report['records']} == {
        (owner, body) for owner in [0, 1] for body in [185, 186]}
    for row in report['records']:
        assert row['native_class'] == 'SavageRider'
        assert row['native_mount_body'] == 188 and row['native_mount_item'] == 0x3EB8
        assert row['dismount_remount']
        assert row['walk_run'] and row['independent_full_partial_hues']
        assert 151 <= row['native_stats']['str'] <= 170
        assert 92 <= row['native_stats']['dex'] <= 130
        assert 51 <= row['native_stats']['int'] <= 65
        assert {a['action'] for a in row['actions']} == set(range(23, 30))
        assert len(row['actions']) == 7
        assert all(a['protocol'] == 'classic' and a['body'] == row['body'] for a in row['actions'])
        assert any(item['layer'] == 25 and item['id'] == 0x3EB8 for item in row['native_items'])
        assert {(0xF62,2),(0x144E,19),(0x1452,4)} <= {(item['id'],item['layer']) for item in row['native_items']}
        death = row['death']
        assert death['body'] == row['body'] and death['hue'] == 0x8035
        assert death['corpse'] > 0 and death['mount_deleted'] and death['mount_serial'] > 0
        assert len(death['witnesses']) == 2
        for witness in death['witnesses']:
            assert witness['corpse'] == death['corpse'] and witness['body'] == row['body']
            assert witness['hue'] == death['hue'] and witness['clip'] == 'Death' and witness['grounded']
            assert not any(item['layer'] == 25 for item in witness['equipment'])
    print(f"SAVAGE RIDER NATIVE: {report['checks']} checks, four two-client mounted identity/action/gait/hue/dismount/remount/death cases; exact runtime receipt. No autonomous AI or GPU claim.")


if __name__ == '__main__':
    main()
