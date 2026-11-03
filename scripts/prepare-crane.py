"""Prepare body 254 with its original Crane mesh, atlas, rig and motions."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
TOOLS = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA, checked = (TOOLS[key] for key in ('ROOT', 'BASE', 'SHA', 'checked'))
MANIFEST = HERE / 'crane-inputs.json'
ART = ROOT / 'Viewer/local-art/creatures/crane'
RES = 'res://local-art/creatures/crane/'


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'crane-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = TOOLS['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'crane-preview'
    pipeline.LABELS.update(fidget1='Fidget', fidget2='Fidget2')
    _, native = pipeline.native_bodies()
    row, = pipeline.prepare('crane', Inputs(), {name: name for name in members},
                            pipeline.table_rows(table.read_bytes()), native)
    if row['status'] != 'prepared':
        raise RuntimeError(f'Crane source conversion failed: {row.get("blocker")}')
    identity, = row['bodies']
    if (identity['body'], row['stats']['original']['bones'], len(row['clip_sources'])) != (254, 20, 13):
        raise ValueError('Unexpected original Crane rig or clip assignment')
    for source in identity['native_sources']:
        checked(ROOT / 'Server/ModernUO' / source['path'].replace(chr(92), '/'), source['sha256'])
    row.update(native_constructor_hues={'Crane': 0}, classic_action_categories={'10': 'Fidget2'},
               assets={}, asset_sha256={}, art_dependency_sha256={})
    renderer = 'Presentation/SourceCraneVisual.gd'
    row.update(presentation_script='res://' + renderer,
               presentation_script_sha256=SHA(ROOT / 'Viewer' / renderer))
    ART.mkdir(parents=True, exist_ok=True)
    for variant in ('original', 'rounded', 'modern'):
        name = f'crane-{variant}.gltf'
        copyfile(pipeline.OUTPUT / name, ART / name)
        row['assets'][variant] = RES + name
        row['asset_sha256'][variant] = SHA(ART / name)
    pending = ART / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(ART / 'preparation.json')
    print('Crane 254: original 20-joint rig and 13 recovered motions')


if __name__ == '__main__':
    main()
