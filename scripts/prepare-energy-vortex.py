"""Build the authored Energy Vortex candidate and pin its native inputs."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / 'Viewer'
ART = VIEWER / 'local-art/creatures/energy_vortex'
ASSET = 'res://local-art/creatures/energy_vortex/vortex.scn'
RENDERER = 'Presentation/EnergyVortexVisual.gd'
SHADER = 'Presentation/EnergyVortexSurface.gdshader'
NATIVE = 'Projects/UOContent/Mobiles/Monsters/Misc/Melee/EnergyVortex.cs'
SPELL = 'Projects/UOContent/Spells/Eighth/EnergyVortex.cs'
NATIVE_PINS = {
    NATIVE: '4eaaa2d2a31577514adac10c5865734519fc3fc6fe99392d36eb59eeb47c7c22',
    SPELL: '1c953f96e4fc600ee527c6cf3cf5c68600b305f113a34732840e4833627683e6',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    for path, digest in NATIVE_PINS.items():
        if sha(ROOT / 'Server/ModernUO' / path) != digest:
            raise ValueError(f'Native Energy Vortex declaration changed: {path}')
    index = ART.parent / 'accepted-index.json'
    if index.exists():
        entries = json.loads(index.read_text(encoding='utf-8-sig'))['entries']
        for row in entries:
            if not any(body['body'] == 164 for body in row['bodies']):
                continue
            if (row['kind'] != 'energy_vortex' or row['assets']['modern'] != ASSET
                    or row['asset_sha256']['modern'] != sha(ART / 'vortex.scn')
                    or row['presentation_script_sha256'] != sha(VIEWER / RENDERER)
                    or row['art_dependency_sha256']['res://' + SHADER] != sha(VIEWER / SHADER)):
                raise ValueError('Energy Vortex active route differs from the prepared package')
            print('Energy Vortex active package verified')
            return
    godot = next((ROOT / '.tools/godot').glob('*console.exe'))
    user_dir = str(ROOT / '.godot-user')
    result = subprocess.run(
        [str(godot), '--headless', '--path', str(VIEWER), '--script',
         'res://Presentation/BakeEnergyVortex.gd'],
        cwd=ROOT, env=dict(os.environ, APPDATA=user_dir, LOCALAPPDATA=user_dir),
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30)
    output = result.stdout + result.stderr
    if result.returncode or 'ERROR:' in output or 'ENERGY VORTEX BAKE:' not in output:
        raise RuntimeError(output)
    digest = sha(ART / 'vortex.scn')
    row = {
        'family': 'energy_vortex', 'kind': 'energy_vortex', 'status': 'prepared',
        'profile': 'monster', 'movement_mode': 'source_hover',
        'bodies': [{'body': 164, 'scale': [1, 1, 1], 'native_profile': 'monster',
                    'native_sources': [{'path': NATIVE, 'sha256': NATIVE_PINS[NATIVE]}]}],
        'assets': {'original': ASSET, 'modern': ASSET},
        'asset_sha256': {'original': digest, 'modern': digest},
        'presentation_script': 'res://' + RENDERER,
        'presentation_script_sha256': sha(VIEWER / RENDERER),
        'art_dependency_sha256': {'res://' + SHADER: sha(VIEWER / SHADER)},
        'native_constructor_hues': {'EnergyVortex': 0},
        'pick_bounds': {'position': [-0.95, 0.0, -0.95], 'size': [1.9, 2.2, 1.9]},
        'surface': 'Independently authored ribbons. No proprietary inputs in the bake.',
    }
    pending = ART / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'native_pins': NATIVE_PINS},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(ART / 'preparation.json')
    print(output.strip())


if __name__ == '__main__':
    main()
