"""Prepare a source-only Fetid Essence replacement using the project's Wisp."""
import json
import os
from pathlib import Path
import runpy
import subprocess

TOOLS = runpy.run_path(str(Path(__file__).with_name('prepare-hydra.py')))
ROOT, SHA, checked = (TOOLS[key] for key in ('ROOT', 'SHA', 'checked'))
MANIFEST = Path(__file__).with_name('fetid-essence-inputs.json')
VIEWER = ROOT / 'Viewer'
FOLDER = 'local-art/creatures/fetid_essence'
BAKER = 'Presentation/BakeFetidEssence.gd'
RENDERER = 'Presentation/FetidEssenceVisual.gd'


def main():
    pins = json.loads(MANIFEST.read_text(encoding='utf-8'))
    checked(VIEWER / pins['donor'], pins['donor_sha256'])
    for path, digest in pins['native'].items():
        checked(ROOT / 'Server/ModernUO' / path, digest)
    directory = VIEWER / FOLDER
    directory.mkdir(parents=True, exist_ok=True)
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    result = subprocess.run(
        [str(godot), '--headless', '--path', str(VIEWER), '--script', f'res://{BAKER}'],
        env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir), capture_output=True,
        text=True, encoding='utf-8', errors='replace', timeout=45, check=True,
    )
    if 'FETID ESSENCE BAKE:' not in result.stdout or 'ERROR:' in result.stderr:
        raise ValueError(result.stdout + result.stderr)
    asset = f'{FOLDER}/fetid-essence.scn'
    variants = ('original', 'rounded', 'modern')
    dependencies = (BAKER, pins['donor'], 'Presentation/FetidEssenceSurface.gdshader',
                    'Presentation/WispVisual.gd', 'Presentation/WispMaterial.gd')
    row = {
        'kind': 'fetid_essence', 'family': 'fetid_essence', 'status': 'prepared', 'profile': 'monster',
        'bodies': [{'body': 273, 'native': 'Fetid Essence / Mantra Effervescence',
                    'scale': [1., 1., 1.], 'native_profile': 'monster',
                    'native_sources': [{'path': path, 'sha256': digest} for path, digest in pins['native'].items()]}],
        'native_constructor_hues': {'FetidEssence': 0, 'MantraEffervescence': 0},
        'movement_mode': 'source_hover',
        'presentation_script': f'res://{RENDERER}', 'presentation_script_sha256': SHA(VIEWER / RENDERER),
        'art_dependency_sha256': {f'res://{path}': SHA(VIEWER / path) for path in dependencies},
        'assets': dict.fromkeys(variants, f'res://{asset}'),
        'asset_sha256': dict.fromkeys(variants, SHA(VIEWER / asset)),
        'stats': dict.fromkeys(variants, {'triangles': 4480, 'bones': 7}),
        'clip_sources': {},
        'authored_clips': {clip: 'Project Wisp animation adapted with broader cloud proportions.'
                           for clip in ('Idle', 'Walk', 'Run', 'Attack', 'Attack2', 'Attack3', 'Hit', 'Cast',
                                        'Fidget', 'Fidget2', 'Death', 'Death2', 'Alert', 'Eat', 'Pillage', 'LieDown')},
        'source_interpretation': 'The archived two-triangle unskinned card has a fully transparent atlas. '
                                 'Project-authored Wisp geometry and actions support a new green cloud surface.',
    }
    pending = directory / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': SHA(MANIFEST)}, indent=2) + '\n',
                       encoding='utf-8')
    pending.replace(directory / 'preparation.json')
    print(result.stdout.strip())


if __name__ == '__main__':
    main()
