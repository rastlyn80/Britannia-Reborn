"""Prepare the original five-headed Hydra for private client validation."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

LATE = runpy.run_path(str(Path(__file__).with_name('prepare-late-creatures.py')))
ROOT, BASE, TOOLS = (LATE[key] for key in ('ROOT', 'BASE', 'TOOLS'))
SHA = TOOLS['sha']
MANIFEST = Path(__file__).with_name('hydra-inputs.json')
ART = ROOT / 'Viewer/local-art/creatures/hydra'
RES = 'res://local-art/creatures/hydra/'


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected Hydra source input: {path}')
    return path


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'hydra-source' / name, digest)
               for name, digest in manifest['files'].items()}
    native_sources = []
    for path, digest in manifest['native'].items():
        checked(ROOT / 'Server/ModernUO' / path, digest)
        native_sources.append({'path': path, 'sha256': digest})

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = TOOLS['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'hydra-preview'
    pipeline.LABELS.update(takedamage='Hit', fidget2='Fidget2')
    _, native = pipeline.native_bodies()
    row, = pipeline.prepare('hydra', Inputs(), {name: name for name in members},
                            pipeline.table_rows(table.read_bytes()), native)
    identity, = row['bodies']
    stats = row['stats']['original']
    if (row['status'], identity['body'], stats['bones'], stats['triangles'], len(row['clip_sources'])) != (
            'prepared', 265, 43, 590, 13):
        raise ValueError('Unexpected Hydra source mesh, rig or clip set')
    identity['native_sources'] = native_sources
    row.update(
        movement_mode='ground_plane',
        native_constructor_hues={'Hydra': 0, 'Abscess': 0x8fd},
        classic_action_categories={'12': 'Attack2', '18': 'Fidget2'},
        action_interpretation='FireBreath classic 12 uses the recovered open-jaw Attack2 as an authored mapping.',
        assets={}, asset_sha256={}, art_dependency_sha256={})
    ART.mkdir(parents=True, exist_ok=True)
    for variant in ('original', 'rounded', 'modern'):
        name = f'hydra-{variant}.gltf'
        copyfile(pipeline.OUTPUT / name, ART / name)
        row['assets'][variant] = RES + name
        row['asset_sha256'][variant] = SHA(ART / name)
    (ART / 'preparation.json').write_text(json.dumps(
        {'models': [row], 'input_manifest_sha256': SHA(MANIFEST)}, indent=2) + '\n', encoding='utf-8')
    print('Hydra 265: 13 recovered motions, Hydra and Abscess candidate only')


if __name__ == '__main__':
    main()
