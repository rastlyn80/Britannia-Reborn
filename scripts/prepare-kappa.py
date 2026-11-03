"""Prepare body 240 with its original Kappa mesh, atlas, rig and motions."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
TOOLS = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA, checked = (TOOLS[key] for key in ('ROOT', 'BASE', 'SHA', 'checked'))
MANIFEST = HERE / 'kappa-inputs.json'
ART = ROOT / 'Viewer/local-art/creatures/kappa'
RES = 'res://local-art/creatures/kappa/'


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'tokuno-creature-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = TOOLS['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'kappa-preview'
    _, native = pipeline.native_bodies()
    row, = pipeline.prepare('kappa', Inputs(), {name: name for name in members},
                            pipeline.table_rows(table.read_bytes()), native)
    if row['status'] != 'prepared':
        raise RuntimeError(f'Kappa source conversion failed: {row.get("blocker")}')
    identity, = row['bodies']
    if (identity['body'], row['stats']['original']['bones'], len(row['clip_sources'])) != (240, 28, 11):
        raise ValueError('Unexpected original Kappa rig or clip assignment')
    for source in identity['native_sources']:
        checked(ROOT / 'Server/ModernUO' / source['path'].replace(chr(92), '/'), source['sha256'])
    row.update(family='kappa', native_constructor_hues={'Kappa': 0},
               assets={}, asset_sha256={}, art_dependency_sha256={})
    renderer = 'Presentation/SourceKappaVisual.gd'
    row.update(presentation_script='res://' + renderer,
               presentation_script_sha256=SHA(ROOT / 'Viewer' / renderer))
    ART.mkdir(parents=True, exist_ok=True)
    for variant in ('original', 'rounded', 'modern'):
        name = f'kappa-{variant}.gltf'
        copyfile(pipeline.OUTPUT / name, ART / name)
        row['assets'][variant] = RES + name
        row['asset_sha256'][variant] = SHA(ART / name)
    pending = ART / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(ART / 'preparation.json')
    print('Kappa 240: original 28-joint rig and 11 recovered motions')


if __name__ == '__main__':
    main()
