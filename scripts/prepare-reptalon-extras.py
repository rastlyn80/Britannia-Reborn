"""Recover the three additional Reptalon motions from pinned Third Dawn members."""

from functools import partial
import json
from pathlib import Path
import runpy


SCRIPTS = Path(__file__).resolve().parent
RECIPE = runpy.run_path(str(SCRIPTS / 'prepare-recovered-late.py'))
ROOT, BASE, SHA = (RECIPE[key] for key in ('ROOT', 'BASE', 'SHA'))
OUTPUT = ROOT / 'work/creatures/reptalon-source-clips'
EXTRAS = {'lying': 'FittedRest', 'grazing': 'ReptalonGrazing', 'idle2': 'ReptalonSourceFidget2'}


def main():
    base = json.loads(RECIPE['MANIFEST'].read_text(encoding='utf-8'))
    extra = json.loads((SCRIPTS / 'reptalon-extra-inputs.json').read_text(encoding='utf-8'))
    assert base['installer_sha256'] == extra['installer_sha256']
    source = BASE / 'final-late-source'
    names = {name: digest for name, digest in base['files'].items() if '/Raptalon_' in name or name.endswith('/Reptalon.tga')}
    files = {name.lower(): RECIPE['checked'](source / name, digest) for name, digest in (names | extra['files']).items()}
    table = RECIPE['checked'](BASE / 'model-table/Client/Models.txt', base['model_table_sha256'])

    class Inputs:
        def read(self, name):
            return files[name].read_bytes()

    pipeline = RECIPE['TOOLS']['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = base['installer_sha256']
    pipeline.OUTPUT = OUTPUT
    pipeline.LABELS.update(EXTRAS)
    pipeline.td.parse = partial(pipeline.td.parse, max_influences=8)
    pipeline.td.export_gltf = partial(pipeline.td.export_gltf, max_influences=8)
    original_refine = pipeline.smooth.refine

    def preserve_weights(mesh, **options):
        return original_refine(mesh, **(options | {'levels': 0, 'weight_smoothing': 0.0, 'max_influences': 8}))

    pipeline.smooth.refine = preserve_weights
    rows = [row for row in pipeline.table_rows(table.read_bytes()) if row['stem'] != 'raptalon' or row['body'] == 276]
    _, native = pipeline.native_bodies()
    bindings = {name: name for name in files}
    bindings['client/models/animals/raptalon_gethit.grn'] = 'client/models/animals/raptalon_takedamage.grn'
    row, = pipeline.prepare('raptalon', Inputs(), bindings, rows, native, selected_kinds={'raptalon'})
    assert row['status'] == 'prepared' and row['stats']['original']['bones'] == 45
    assert {row['clip_sources'][clip] for clip in EXTRAS.values()} == {name.lower() for name in extra['files']}
    for clip in EXTRAS.values():
        witness = row['stats']['original']['clips'][clip]
        assert witness['matched_tracks'] == 45 and not witness['missing']
    scenes = {treatment: SHA(OUTPUT / f'raptalon-{treatment}.gltf') for treatment in ('original', 'rounded', 'modern')}
    receipt = dict(clips={clip: row['clip_sources'][clip] for clip in EXTRAS.values()}, scenes_sha256=scenes,
                   source_sha256=extra['files'], rig_joint_count=45)
    (OUTPUT / 'extra-motion-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('Reptalon source: three extra archived clips, all 45 matching tracks on the retained rig')


if __name__ == '__main__':
    main()
