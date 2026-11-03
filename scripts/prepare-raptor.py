"""Prepare the licensed Raptor substitute from the pinned Quaternius FBX."""
import json
import os
from pathlib import Path
import runpy
import subprocess

TOOLS = runpy.run_path(str(Path(__file__).with_name('prepare-hydra.py')))
ROOT, SHA, checked = (TOOLS[key] for key in ('ROOT', 'SHA', 'checked'))
MANIFEST = Path(__file__).with_name('raptor-inputs.json')
VIEWER = ROOT / 'Viewer'
FOLDER = 'local-art/creatures/raptor'
BAKER = 'Presentation/BakeRaptor.gd'
RENDERER = 'Presentation/SourcePreservingCreatureVisual.gd'
CLIPS = ('Attack', 'Death', 'Idle', 'Jump', 'Run', 'Walk')


def main():
    pins = json.loads(MANIFEST.read_text(encoding='utf-8'))
    for file, digest in pins['files'].items():
        checked(VIEWER / 'local-art/creatures/raptor-trial' / file, digest)
    checked(ROOT / 'Server/ModernUO' / pins['native_path'], pins['native_sha256'])
    pipeline = TOOLS['TOOLS']['pipeline']()
    if pipeline.body_profiles()[730] != 'monster':
        raise ValueError('Unexpected native Raptor profile')
    directory = VIEWER / FOLDER
    directory.mkdir(parents=True, exist_ok=True)
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    env = dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir)
    for args in (('--editor', '--import'), ('--script', f'res://{BAKER}')):
        result = subprocess.run([str(godot), '--headless', '--path', str(VIEWER), *args],
                                env=env, capture_output=True, text=True, encoding='utf-8',
                                errors='replace', timeout=120, check=True)
        if args[0] == '--script' and ('RAPTOR BAKE:' not in result.stdout or 'ERROR:' in result.stderr):
            raise ValueError(result.stdout + result.stderr)
    asset = f'{FOLDER}/raptor.scn'
    variants = ('original', 'rounded', 'modern')
    row = {
        'kind': 'raptor', 'family': 'raptor', 'status': 'prepared', 'profile': 'monster',
        'bodies': [{'body': 730, 'native': 'Raptor', 'scale': [1., 1., 1.], 'native_profile': 'monster',
                    'native_sources': [{'path': pins['native_path'], 'sha256': pins['native_sha256']}]}],
        'native_constructor_hues': {'Raptor': 0}, 'limb_support': 'plane',
        'presentation_script': f'res://{RENDERER}', 'presentation_script_sha256': SHA(VIEWER / RENDERER),
        'art_dependency_sha256': {
            f'res://{path}': SHA(VIEWER / path) for path in (BAKER, 'Presentation/SourceGroundLookup.gd')
        },
        'assets': dict.fromkeys(variants, f'res://{asset}'),
        'asset_sha256': dict.fromkeys(variants, SHA(VIEWER / asset)),
        'stats': dict.fromkeys(variants, {'triangles': 1248, 'bones': 37}),
        'clip_sources': {name: f'Velociraptor.fbx / Armature|Velociraptor_{name}' for name in CLIPS},
        'authored_clips': {'Hit': 'Torso and head recoil keyed against the first Idle pose.',
                           'Fidget': 'Idle motion reused as a stationary fallback.'},
        'classic_action_categories': {'5': 'Jump', '6': 'Attack', '3': 'Death'},
        'inputs': [{'member': name, 'sha256': digest} for name, digest in pins['files'].items()],
        'archive_sha256': pins['archive_sha256'], 'source_url': pins['source'], 'license': pins['license'],
        'source_interpretation': 'Quaternius CC0 Velociraptor substitute with fitted proportions and ochre materials.',
    }
    pending = directory / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': SHA(MANIFEST)}, indent=2) + '\n',
                       encoding='utf-8')
    pending.replace(directory / 'preparation.json')


if __name__ == '__main__':
    main()
