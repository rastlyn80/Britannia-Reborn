"""Activate the exact Cu Sidhe package checked with human and elf riders."""
import argparse
import json
from pathlib import Path
import runpy
import subprocess
import os

SHARED = runpy.run_path(str(Path(__file__).with_name('accept-hiryu-mount.py')))
ROOT, VIEWER, ART, INDEX = (SHARED[key] for key in ('ROOT', 'VIEWER', 'ART', 'INDEX'))
read, sha = SHARED['read'], SHARED['sha']
PACKAGE = ART / 'cu_sidhe_mount/preparation.json'


def validate():
    record, = read(PACKAGE)['models']
    if (record['status'] != 'prepared' or record['kind'] != 'cushidhe'
            or record['mount_item'] != 0x3e91 or [body['body'] for body in record['bodies']] != [277]):
        raise ValueError('Unexpected Cu Sidhe package')
    assets = {record['assets'][name]: digest for name, digest in record['asset_sha256'].items()}
    assets.update(record['art_dependency_sha256'])
    assets[record['presentation_script']] = record['presentation_script_sha256']
    for resource, digest in assets.items():
        path = (VIEWER / resource.removeprefix('res://')).resolve()
        if not resource.startswith('res://') or not path.is_relative_to(VIEWER) or sha(path) != digest:
            raise ValueError(f'Stale Cu Sidhe resource: {resource}')
    gpu = read(ROOT / 'work/creatures/late-client-inputs/cu-riding/validation.json')
    samples = gpu['samples']
    if (gpu['preparation_sha256'] != sha(PACKAGE) or gpu['failures'] or gpu['renderer'] != 'forward_plus'
            or len(samples) != 72 or not all(sample['passed'] for sample in samples)
            or any(sum(row['rider_body'] == body for row in samples) != 18 for body in (400, 401, 605, 606))):
        raise ValueError('Exact human and elf Cu Sidhe Vulkan evidence is missing or stale')
    for name, digest in gpu['runtime_sha256'].items():
        if sha(VIEWER / 'Presentation' / name) != digest:
            raise ValueError(f'Stale Cu Sidhe Vulkan evidence: {name}')
    native = read(ROOT / 'outputs/ostard-riding/cu-sidhe-live.json')
    scenarios = {(variant, female, variant != 52) for variant in (52, 53, 54) for female in (False, True)}
    if (native['preparation_sha256'] != sha(PACKAGE) or native['failures'] or not native['checks']
            or len(native['records']) != len(scenarios)
            or {(row['fixture_variant'], row['female'], row['ride_permitted']) for row in native['records']} != scenarios
            or any((row['native_class'], row['body'], row['mount_item']) != ('CuSidhe', 277, 0x3e91)
                   for row in native['records'])):
        raise ValueError('Exact Cu Sidhe permissions and riding evidence is missing or stale')
    print(f'Cu Sidhe evidence: {gpu["checks"]} Vulkan checks and {native["checks"]} native checks')
    return record


def replace_index(payload):
    pending = INDEX.with_suffix('.cu-sidhe.pending')
    pending.write_bytes(payload)
    pending.replace(INDEX)


def activate(record):
    prior = INDEX.read_bytes()
    index = json.loads(prior.decode('utf-8-sig'))
    slot, = [i for i, row in enumerate(index['entries']) if any(body['body'] == 277 for body in row['bodies'])]
    current = index['entries'][slot]
    desired = dict(record, status='validated')
    if current == desired:
        print('Cu Sidhe mount is already active')
        return
    if current['kind'] != 'cushidhe' or current['family'] != 'captain_cu' or current.get('mount_item'):
        raise ValueError('Unexpected existing Cu Sidhe route')
    index['entries'][slot] = desired
    updated = (json.dumps(index, indent=2) + '\n').encode('utf-8')
    if INDEX.read_bytes() != prior:
        raise ValueError('Registry changed during Cu Sidhe activation')
    replace_index(updated)
    try:
        godot = next((ROOT / '.tools/godot').glob('*console.exe'))
        user_dir = str(ROOT / '.godot-user')
        for script in ('CuSidheRidingTests.gd', 'CaptainCuRouteTests.gd'):
            result = subprocess.run([str(godot), '--headless', '--path', str(VIEWER), '--script',
                                     f'res://Presentation/{script}', '--', '--active'],
                                    cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
                                    capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
            output = result.stdout + result.stderr
            print(output.strip())
            if result.returncode or 'ERROR:' in output:
                raise ValueError(f'Normal Cu Sidhe client check failed: {script}')
        if INDEX.read_bytes() != updated:
            raise ValueError('Registry changed during Cu Sidhe activation checks')
    except BaseException:
        if INDEX.read_bytes() == updated:
            replace_index(prior)
        raise
    print('Activated native Cu Sidhe mount graphic 0x3E91')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate', action='store_true')
    args = parser.parse_args()
    record = validate()
    if args.activate:
        activate(record)
