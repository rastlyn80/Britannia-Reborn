"""Build the authored dust effect for the original invisible Sand Vortex proxy."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'sand-vortex-inputs.json'
ART = ROOT / 'Viewer/local-art/creatures/sand_vortex'
RENDERER = 'Presentation/SandVortexVisual.gd'
SHADER = 'Presentation/SandVortexSurface.gdshader'


def main():
    pins = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if SHA(BASE / 'model-table/Client/Models.txt') != pins['model_table_sha256']:
        raise ValueError('Sand Vortex model table changed')
    for name, digest in pins['files'].items():
        if SHA(BASE / 'horde-kitsune-rune-source' / name) != digest:
            raise ValueError(f'Unexpected Sand Vortex archive member: {name}')
    native = pins['native']
    if SHA(ROOT / 'Server/ModernUO' / native['path']) != native['sha256']:
        raise ValueError('Sand Vortex native declaration changed')
    energy = runpy.run_path(str(HERE / 'prepare-energy-vortex.py'))
    energy['main']()
    ART.mkdir(parents=True, exist_ok=True)
    asset = ART / 'vortex.scn'
    copyfile(energy['ART'] / 'vortex.scn', asset)
    uri = 'res://local-art/creatures/sand_vortex/vortex.scn'
    row = {
        'family': 'sand_vortex', 'kind': 'sand_vortex', 'status': 'prepared',
        'profile': 'monster', 'movement_mode': 'source_hover', 'authored_effect': True,
        'bodies': [{'body': 790, 'scale': [1.0, 1.0, 1.0], 'native_profile': 'monster',
                    'native_sources': [native]}],
        'assets': dict.fromkeys(('original', 'rounded', 'modern'), uri),
        'asset_sha256': dict.fromkeys(('original', 'rounded', 'modern'), SHA(asset)),
        'presentation_script': 'res://' + RENDERER,
        'presentation_script_sha256': SHA(ROOT / 'Viewer' / RENDERER),
        'art_dependency_sha256': {'res://' + SHADER: SHA(ROOT / 'Viewer' / SHADER)},
        'native_constructor_hues': {'SandVortex': 0},
        'stats': {'original': {'height_m': 1.78}},
        'pick_bounds': {'position': [-0.9, 0.0, -0.9], 'size': [1.8, 1.95, 1.8]},
        'surface': 'Authored dust from the shared vortex shell recipe. Original invisible proxy audited separately.',
    }
    pending = ART / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(ART / 'preparation.json')


if __name__ == '__main__':
    main()
