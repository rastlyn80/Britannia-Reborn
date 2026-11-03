"""Check the exact Hiryu mount evidence and optionally replace the loose-only route."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures'
PACKAGE = ART / 'hiryu_mount/preparation.json'
INDEX = ART / 'accepted-index.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def validate():
    record, = read(PACKAGE)['models']
    if (record['status'] != 'prepared' or record['kind'] != 'hai_riyo'
            or record['mount_item'] != 0x3e94 or [i['body'] for i in record['bodies']] != [243]
            or not {'Fidget', 'Fidget2'} <= record['clip_sources'].keys()):
        raise ValueError('Unexpected Hiryu package')
    renderer = record['presentation_script']
    assets = {record['assets'][name]: digest for name, digest in record['asset_sha256'].items()}
    assets.update(record['art_dependency_sha256'])
    assets[renderer] = record['presentation_script_sha256']
    for resource, digest in assets.items():
        path = (VIEWER / resource.removeprefix('res://')).resolve()
        if not resource.startswith('res://') or not path.is_relative_to(VIEWER) or sha(path) != digest:
            raise ValueError(f'Stale Hiryu resource: {resource}')
    gpu = read(ROOT / 'work/creatures/late-client-inputs/hiryu-wing-clearance-dense/validation.json')
    if (gpu['preparation_sha256'] != sha(PACKAGE) or gpu['failures'] or gpu['renderer'] != 'forward_plus'
            or len(gpu['samples']) != 126 or gpu['wing_centerline_crossings']
            or not all(sample['passed'] for sample in gpu['samples'])):
        raise ValueError('Exact Hiryu GPU fit evidence is missing or stale')
    for name, digest in gpu['runtime_sha256'].items():
        if sha(VIEWER / 'Presentation' / name) != digest:
            raise ValueError(f'Stale Hiryu GPU runtime evidence: {name}')
    native = read(ROOT / 'outputs/ostard-riding/hiryu-live.json')
    expected = {(name, female) for name in ('Hiryu', 'LesserHiryu') for female in (False, True)}
    if (native['preparation_sha256'] != sha(PACKAGE) or native['normal_registry'] or native['failures']
            or not native['checks'] or len(native['records']) != len(expected)
            or {(row['native_class'], row['female']) for row in native['records']} != expected
            or any(row['body'] != 243 or row['mount_item'] != 0x3e94 or not row['ride_permitted']
                   for row in native['records'])):
        raise ValueError('Exact Hiryu native mount evidence is missing or stale')
    print(f'Hiryu evidence: {gpu["checks"]} Vulkan checks, {native["checks"]} native checks')
    return record


def replace(payload):
    pending = INDEX.with_suffix('.hiryu.pending')
    pending.write_bytes(payload)
    pending.replace(INDEX)


def activate(record):
    prior = INDEX.read_bytes()
    index = json.loads(prior.decode('utf-8-sig'))
    matches = [i for i, row in enumerate(index['entries']) if any(body['body'] == 243 for body in row['bodies'])]
    if len(matches) != 1:
        raise ValueError('Expected one existing Hiryu route')
    slot, = matches
    current = index['entries'][slot]
    desired = dict(record, status='validated')
    if current == desired:
        print('Hiryu mount is already active')
        return
    if current['kind'] != 'hai_riyo' or current['family'] != 'devourer_lion_hiryu' or current.get('mount_item'):
        raise ValueError('Unexpected existing Hiryu route')
    index['entries'][slot] = desired
    updated = (json.dumps(index, indent=2) + '\n').encode('utf-8')
    if INDEX.read_bytes() != prior:
        raise ValueError('Registry changed during Hiryu activation')
    replace(updated)
    try:
        godot = next((ROOT / '.tools/godot').glob('*console.exe'))
        user_dir = str(ROOT / '.godot-user')
        for script, args in (('HiryuRidingTests.gd', ['--active']), ('DevourerLionHiryuRouteTests.gd', [])):
            result = subprocess.run([str(godot), '--headless', '--path', str(VIEWER), '--script',
                                     f'res://Presentation/{script}', '--', *args],
                                    cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
                                    capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
            print((result.stdout + result.stderr).strip())
            if result.returncode or 'ERROR:' in result.stdout + result.stderr:
                raise ValueError(f'Normal client check failed: {script}')
        if INDEX.read_bytes() != updated:
            raise ValueError('Registry changed during Hiryu activation checks')
    except BaseException:
        if INDEX.read_bytes() == updated:
            replace(prior)
        raise
    print('Activated native Hiryu mount graphic 0x3E94')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    prepared = validate()
    if args.activate:
        activate(prepared)
