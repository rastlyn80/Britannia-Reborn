"""Build the local first-form Harrower from the model table's explicit assignment."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
TOOLS = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA, checked = (TOOLS[key] for key in ('ROOT', 'BASE', 'SHA', 'checked'))
MANIFEST = HERE / 'harrower-inputs.json'
ART = ROOT / 'Viewer/local-art/creatures/harrower'
RES = 'res://local-art/creatures/harrower/'


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'harrower-source' / name, digest)
               for name, digest in manifest['files'].items()}
    for path, digest in manifest['native'].items():
        checked(ROOT / 'Server/ModernUO' / path, digest)

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = TOOLS['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'harrower-preview'
    _, native = pipeline.native_bodies()
    row, = pipeline.prepare('shadowlords', Inputs(), {name: name for name in members},
                            pipeline.table_rows(table.read_bytes()), native)
    if row['status'] != 'prepared':
        raise RuntimeError(f'Harrower source conversion failed: {row.get("blocker")}')
    stats = row['stats']['original']
    if ([body['body'] for body in row['bodies']], stats['bones'], len(row['clip_sources'])) != ([146], 37, 7):
        raise ValueError('Unexpected first-form Harrower model or clip assignment')
    ART.mkdir(parents=True, exist_ok=True)
    row.update(family='harrower', native_constructor_hues={'Harrower': 0},
               assets={}, asset_sha256={}, art_dependency_sha256={})
    renderer = 'Presentation/SourcePreservingCreatureVisual.gd'
    ground = 'Presentation/SourceGroundLookup.gd'
    row.update(presentation_script='res://' + renderer,
               presentation_script_sha256=SHA(ROOT / 'Viewer' / renderer),
               limb_support='plane')
    row['art_dependency_sha256']['res://' + ground] = SHA(ROOT / 'Viewer' / ground)
    for variant in ('original', 'rounded', 'modern'):
        name = f'{row["kind"]}-{variant}.gltf'
        copyfile(pipeline.OUTPUT / name, ART / name)
        row['assets'][variant] = RES + name
        row['asset_sha256'][variant] = SHA(ART / name)
    report = {
        'models': [row],
        'input_manifest_sha256': SHA(MANIFEST),
        'native_forms': [146, 780],
        'scope': 'Private first-form candidate. True form uses the separately validated body 780 route.',
    }
    pending = ART / 'preparation.pending'
    pending.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    pending.replace(ART / 'preparation.json')
    print('Harrower 146: original 37-joint rig, seven source motions, prepared first form')


if __name__ == '__main__':
    main()
