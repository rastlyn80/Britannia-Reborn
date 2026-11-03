"""Register the validated Ethereal Beetle as mounted-item art."""
import argparse
import json
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
variant = runpy.run_path(str(SCRIPTS / 'prepare-ethereal-beetle.py'))
ROOT, WORK, OUTPUT = (variant[key] for key in ('ROOT', 'WORK', 'OUTPUT'))
BODY, ITEM = 195, 0x3E97
RUNTIME = ROOT / 'Viewer/Presentation'
RECEIPT = OUTPUT.with_name('local-presentation.json')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def riding_script():
    text = (RUNTIME / 'GiantBeetleRidingTests.gd').read_text(encoding='utf-8')
    changes = {
        'res://local-art/creatures/giant_beetle/preparation.json':
            'res://local-art/creatures/giant_beetle_ethereal/preparation.json',
        'giant-beetle/final/riding': 'giant-beetle/ethereal-final/riding',
        '791': str(BODY),
        '"layer":25,"hue":0': '"layer":25,"hue":0x4001',
        '"SourceBeetleVisual.gd",':
            '"SourceBeetleVisual.gd","SourceEtherealBeetleVisual.gd","SourceEtherealBeetleSurface.gdshader",',
        '\t\t\t\tcheck(actor.human_visual.missing_art.is_empty()':
            '\t\t\t\tcheck(actor.horse_visual.native_hue==0x4001 and actor.horse_visual.get_meta("equine_profile").ethereal,'
            '"Spectral mount retains the native hue flag")\n\t\t\t\tcheck(actor.human_visual.missing_art.is_empty()',
    }
    for before, after in changes.items():
        assert before in text
        text = text.replace(before, after)
    return text


def verified(base, active):
    sha = base.sha
    riding = read(WORK / 'riding/validation.json')
    route = read(WORK / ('item-route-active.json' if active else 'item-route.json'))
    for proof in (riding, route):
        assert proof['failures'] == 0 and proof['preparation_sha256'] == sha(OUTPUT)
        for name, digest in proof['runtime_sha256'].items():
            assert Path(name).name == name and sha(RUNTIME / name) == digest
    assert route['candidate'] is not active and route['checks'] == 25
    assert route['body_art_key'] == BODY and route['mounted_item'] == ITEM
    assert riding['renderer'] == 'forward_plus' and riding['checks'] == 134
    assert len(riding['samples']) == 36
    assert all(int(sample['body']) == BODY and sample['passed'] for sample in riding['samples'])
    assert {sample['female'] for sample in riding['samples']} == {False, True}
    assert {sample['clip'] for sample in riding['samples']} == {'Rider_Idle', 'Rider_Walk', 'Rider_Run'}
    log = (WORK / 'riding.log').read_text(encoding='utf-8-sig')
    assert 'Vulkan' in log and 'Forward+' in log and 'ERROR:' not in log
    assert (WORK / 'EtherealBeetleRidingTests.gd').read_text(encoding='utf-8') == riding_script()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--write-riding-test', action='store_true')
    group.add_argument('--publish', action='store_true')
    group.add_argument('--check-active', action='store_true')
    args = parser.parse_args()
    if args.write_riding_test:
        WORK.mkdir(parents=True, exist_ok=True)
        (WORK / 'EtherealBeetleRidingTests.gd').write_text(riding_script(), encoding='utf-8')
        return
    base, source = variant['recipe']()
    variant['check'](base, source)
    verified(base, args.check_active)
    row, = read(OUTPUT)['models']
    row.update(status='validated', validation_scope='Original spectral art for mounted item 0x3E97 only.')
    path = OUTPUT.parents[1] / 'accepted-index.json'
    index = read(path)
    existing = [record for record in index['entries'] if any(
        int(identity['body']) == BODY for identity in record['bodies'])]
    assert all(record['kind'] == row['kind'] and record['mount_only'] for record in existing)
    receipt = {'publisher_sha256': base.sha(Path(__file__)), 'preparation_sha256': base.sha(OUTPUT)}
    if args.check_active:
        assert existing == [row] and read(RECEIPT) == receipt
    if args.publish:
        backup = WORK / 'accepted-index-before-ethereal-beetle.json'
        if not backup.exists():
            backup.write_bytes(path.read_bytes())
        index['entries'] = [record for record in index['entries'] if record not in existing] + [row]
        pending = path.with_suffix('.json.pending')
        pending.write_text(json.dumps(index, indent=2) + '\n', encoding='utf-8')
        pending.replace(path)
        RECEIPT.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('ETHEREAL BEETLE ITEM 0x3E97:', 'active' if args.check_active else 'registered' if args.publish else 'dry run')


if __name__ == '__main__':
    main()
