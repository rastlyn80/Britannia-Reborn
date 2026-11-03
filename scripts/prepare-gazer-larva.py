"""Build the private Gazer Larva candidate without changing the active registry."""
import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

SCRIPTS = Path(__file__).resolve().parent
SOURCE = runpy.run_path(str(SCRIPTS / 'prepare-gazer-larva-source.py'))
ROOT = SCRIPTS.parent
WORK = SOURCE['WORK'] / 'owned-source'
ART = ROOT / 'Viewer/local-art/creatures'
FOLDER = 'res://local-art/creatures/gazer_larva/'
ALPHA = 'swarm-larva-original-alpha.png'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return SOURCE['sha'](path)


def bake():
    exe = next((ROOT / '.tools/godot').glob('*console.exe'))
    env = dict(os.environ, APPDATA=str(ROOT / '.godot-user'), LOCALAPPDATA=str(ROOT / '.godot-user'))
    for name in ('BakeGazerLarvaSource', 'BakeGazerLarvaRefined'):
        result = subprocess.run([str(exe), '--headless', '--path', str(ROOT / 'Viewer'),
                                 '--script', f'res://Presentation/{name}.gd'],
                                cwd=ROOT, env=env, text=True, encoding='utf-8', errors='replace',
                                capture_output=True, timeout=300)
        output = result.stdout + result.stderr
        (WORK / f'{name}.log').write_text(output, encoding='utf-8')
        if result.returncode or 'ERROR:' in output:
            raise RuntimeError(output[-3500:])
        print(output.strip())


def candidate(manifest, write_assets=False):
    exported = read(WORK / 'full-affine-export.json')
    saved = read(WORK / 'saved-clock-library.json')
    refined = read(WORK / 'body-refine.json')
    assert exported['manifest_sha256'] == sha(SOURCE['MANIFEST'])
    assert exported['exporter_sha256'] == sha(SCRIPTS / 'export-gazer-larva-affine.py')
    assert exported['factor_recipe_sha256'] == sha(SCRIPTS / 'gazer-affine-factors.py')
    assert saved['failures'] == 0 and saved['keys'] == 1286964 and len(saved['clips']) == 9
    assert exported['gltf_sha256'] == saved['gltf_sha256'] == sha(WORK / 'prepared/swarm-full-affine.gltf')
    clips = [motion['name'] for motion in saved['clips']]
    clip_sources = {motion['clip']: f"Models/Monsters/{motion['source_file']}"
                    for motion in exported['animations']}
    assert set(clips) == set(clip_sources)
    assert saved['installer_sha256'] == sha(ROOT / 'Viewer/Presentation/SourceGazerExactClocks.gd')
    assert saved['library_sha256'] == sha(ART / 'gazer_larva/swarm-exact-clocks.res')
    assert refined['source'] == saved['scene_sha256'] == sha(ART / 'gazer_larva/swarm-exact-source.scn')
    assert refined['asset'] == sha(ART / 'gazer_larva/swarm-body-refined.scn')
    assert (refined['rig_joints'], refined['cards'], refined['untouched_card_triangles'],
            refined['refined_body_triangles']) == (126, 21, 42, 3128)
    atlas = SOURCE['pipeline']().td.png_from_tga((SOURCE['SOURCE'] / 'Models/Maps/swarm_256.tga').read_bytes())
    atlas_path = ART / ALPHA
    if write_assets and not atlas_path.exists():
        atlas_path.write_bytes(atlas)
    assert atlas_path.read_bytes() == atlas
    renderer = 'res://Presentation/SourceGazerLarvaVisual.gd'
    # Both complete meshes were measured in 225 poses. The padded box also
    # enclosed all 477 independent off-grid poses on the same source motion.
    pick_bounds = {'position': [-1.166, .260, -1.744], 'size': [2.302, 2.700, 4.184]}
    row = {
        'kind': 'gazer_larva', 'family': 'gazer_larva', 'status': 'prepared',
        'profile': 'monster', 'movement_mode': 'source_hover',
        'presentation_script': renderer,
        'presentation_script_sha256': sha(ROOT / 'Viewer' / renderer.removeprefix('res://')),
        'bodies': [{'body': 778, 'scale': [1.3] * 3, 'native_profile': 'monster',
                    'native_sources': [manifest['native_class_source']]}],
        'native_constructor_hues': {'GazerLarva': 0},
        'assets': {'original': FOLDER + 'swarm-exact-source.scn', 'modern': FOLDER + 'swarm-body-refined.scn'},
        'asset_sha256': {'original': refined['source'], 'modern': refined['asset']},
        'stats': {treatment: {'clips': clips} for treatment in ('original', 'modern')},
        'clip_sources': clip_sources,
        'source_alpha_texture': ALPHA, 'art_dependency_sha256': {ALPHA: sha(atlas_path)},
        'loop_categories': ['Idle', 'Walk', 'Run'], 'pick_bounds': pick_bounds,
    }
    return {'models': [row], 'manifest_sha256': sha(SOURCE['MANIFEST']),
            'source_proof_sha256': {name: sha(WORK / name) for name in (
                'full-affine-export.json', 'saved-clock-library.json', 'body-refine.json')},
            'scope': 'Prepared local candidate. Client and native acceptance are separate.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--bake-only', action='store_true')
    modes.add_argument('--check-prepared', action='store_true')
    args = parser.parse_args()
    manifest = SOURCE['inputs']()
    if not args.check_prepared:
        subprocess.run([sys.executable, str(SCRIPTS / 'prepare-gazer-larva-source.py')], check=True)
        if not args.bake_only:
            subprocess.run([sys.executable, str(SCRIPTS / 'export-gazer-larva-affine.py')], check=True)
        bake()
    report = candidate(manifest, write_assets=not args.check_prepared)
    path = ART / 'gazer_larva/preparation.json'
    if args.check_prepared:
        assert read(path) == report
    else:
        path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('GAZER LARVA PREPARATION: 126 render joints, nine clips, refined body and 21 source cards')


if __name__ == '__main__':
    main()
