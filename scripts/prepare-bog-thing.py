"""Build the private Bog Thing scene and weighted footprint from pinned source."""
import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

SCRIPTS = Path(__file__).resolve().parent
SOURCE = runpy.run_path(str(SCRIPTS / 'prepare-bog-thing-source.py'))
WITH_ALIAS = runpy.run_path(str(SCRIPTS / 'legacy-action-evidence.py'))['expected_with_legacy_alias']
ROOT = SOURCE['ROOT']
WORK = SOURCE['WORK'] / 'owned-source'
ART = ROOT / 'Viewer/local-art/creatures/bog_thing'
BASE = 'res://local-art/creatures/bog_thing/'
SHA = SOURCE['MIXED']['sha']


def check_active():
    preparation = json.loads((ART / 'preparation.json').read_text(encoding='utf-8'))
    row, = preparation['models']
    assert preparation['manifest_sha256'] == SHA(SOURCE['MANIFEST'])
    index = json.loads((ART.parent / 'accepted-index.json').read_text(encoding='utf-8'))
    active, = [item for item in index['entries']
               if any(int(body['body']) == 780 for body in item['bodies'])]
    if active.get('classic_gesture_batch') == 'orc_bog_actions':
        gate = runpy.run_path(str(SCRIPTS / 'accept-classic-gestures.py'))
        retained, _ = gate['checked'](index, True, 'orc_bog_actions')
        active, = (item for item in retained if item['kind'] == 'bog_thing')
    expected = WITH_ALIAS(dict(row, status='validated'), active)
    assert {key: active[key] for key in expected} == expected
    pins = {**row['art_dependency_sha256'],
            **{path: row['asset_sha256'][name] for name, path in row['assets'].items()},
            row['presentation_script']: row['presentation_script_sha256']}
    for path, digest in pins.items():
        assert path.startswith('res://')
        assert SHA(ROOT / 'Viewer' / path.removeprefix('res://')) == digest, path
    for name, mode, arguments, marker in (
        ('Terrain', ['--headless'], [], '168 supported; 168 rejected'),
        ('MixedTerrain', ['--headless'], [], '315 supported; 315 rejected'),
        ('MixedTerrain', ['--headless'], ['--', '--step'], '630 supported; 0 rejected'),
        ('Corpse', ['--headless'], [], '48 checks / 0 failures'),
        ('Appearance', ['--resolution', '96x96'], [], 'failures 0'),
    ):
        output = run_godot(name, mode, arguments)
        assert marker in output, output
        if name == 'Appearance':
            assert 'Vulkan' in output and 'Forward+' in output, output
        print(output.strip(), flush=True)
    print('BOG THING 780: active source scene and footprint match the verified preparation')


def run_godot(name, mode, arguments):
    exe = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    result = subprocess.run([str(exe), *mode, '--path', str(ROOT / 'Viewer'), '--script',
                             f'res://Presentation/BogThing{name}Tests.gd', *arguments],
                            cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
                            capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=95)
    output = result.stdout + result.stderr
    if result.returncode or 'ERROR:' in output:
        raise RuntimeError(output)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--bake-only', action='store_true', help='Reuse an export from this exact source and exporter.')
    modes.add_argument('--check-active', action='store_true', help='Check the active local scene without rebuilding.')
    args = parser.parse_args()
    manifest = SOURCE['inputs']()
    if args.check_active:
        check_active()
        return
    if not args.bake_only:
        subprocess.run([sys.executable, '-B', str(SCRIPTS / 'export-bog-thing-affine.py')], check=True)
    export = json.loads((WORK / 'full-affine-export.json').read_text())
    assert export['manifest_sha256'] == SHA(SOURCE['MANIFEST'])
    assert export['exporter_sha256'] == SHA(SCRIPTS / 'export-gazer-larva-affine.py')
    assert export['factor_recipe_sha256'] == SHA(SCRIPTS / 'gazer-affine-factors.py')
    assert export['gltf_sha256'] == SHA(WORK / 'prepared/bog-thing-full-affine-dense.gltf')
    exe = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    result = subprocess.run(
        [str(exe), '--headless', '--path', str(ROOT / 'Viewer'), '--script',
         'res://Presentation/BakeGazerLarvaSource.gd', '--', '--bog-thing'],
        cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=250)
    log = result.stdout + result.stderr
    (WORK / 'bake.log').write_text(log, encoding='utf-8')
    if result.returncode or 'ERROR:' in log:
        raise RuntimeError(log)
    bake = json.loads((WORK / 'saved-clock-library.json').read_text())
    assert (bake['tracks'], bake['keys'], bake['failures']) == (2088, 1118472, 0)
    assert bake['gltf_sha256'] == export['gltf_sha256'] == SHA(WORK / 'prepared/bog-thing-full-affine-dense.gltf')
    assert bake['scene_sha256'] == SHA(ART / 'bog-thing-exact-source.scn')
    assert bake['library_sha256'] == SHA(ART / 'bog-thing-exact-clocks.res')
    model, _ = SOURCE['decode'](manifest, SOURCE['MIXED']['pipeline']())
    footprint = ART / 'weighted-footprint.json'
    footprint.write_text(json.dumps(SOURCE['footprint'](model)), encoding='utf-8')
    scene = BASE + 'bog-thing-exact-source.scn'
    clips = [motion['name'] for motion in bake['clips']]
    clip_sources = {motion['clip']: 'Models/Monsters/' + motion['source_file'] for motion in export['animations']}
    assert set(clips) == set(clip_sources)
    constructor = manifest['native_class_source']
    renderer = 'res://Presentation/SourceBogThingVisual.gd'
    treatments = ('original', 'modern')
    row = {
        'kind': 'bog_thing', 'family': 'bog_thing', 'status': 'prepared',
        'profile': 'monster', 'movement_mode': 'source_grounded_base',
        'bodies': [{'body': 780, 'scale': [1.3] * 3, 'native_profile': 'monster',
                    'native_sources': [{key: constructor[key] for key in ('path', 'sha256')}]}],
        'native_constructor_hues': {'BogThing': 0},
        'assets': {name: scene for name in treatments},
        'asset_sha256': {name: bake['scene_sha256'] for name in treatments},
        'stats': {name: {'clips': clips} for name in treatments},
        'clip_sources': clip_sources, 'loop_categories': ['Idle', 'Walk', 'Run'],
        'presentation_script': renderer,
        'presentation_script_sha256': SHA(ROOT / 'Viewer' / renderer.removeprefix('res://')),
        'footprint': BASE + footprint.name,
        'art_dependency_sha256': {BASE + footprint.name: SHA(footprint),
                                  BASE + 'bog-thing-exact-clocks.res': bake['library_sha256']},
    }
    preparation = {'models': [row], 'manifest_sha256': SHA(SOURCE['MANIFEST']),
                   'scope': 'Private candidate. Unit conversion 1:1000 precedes the model-table scale.'}
    (ART / 'preparation.json').write_text(json.dumps(preparation, indent=2) + '\n', encoding='utf-8')
    print('BOG THING PREPARATION: 116 render joints, nine clips and 103 footprint points')


if __name__ == '__main__':
    main()
