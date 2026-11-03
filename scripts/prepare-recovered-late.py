"""Rebuild the archived Juggernaut, Yamandon and Reptalon presentations."""
from functools import partial
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
TOOLS = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (TOOLS[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'recovered-late-inputs.json'
FAMILY = 'recovered_late'
FORMS = {
    768: ('juggernaut', {'Juggernaut': 0}, 24, 8),
    249: ('yamandon', {'Yamandon': 0, 'Serado': 0x96c}, 24, 11),
    276: ('raptalon', {'Reptalon': 0}, 45, 10),
}


def checked(path, expected):
    if SHA(path) != expected:
        raise ValueError(f'Changed archive or native input: {path}')
    return path


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'final-late-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = TOOLS['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'recovered-late-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    destination = ROOT / 'Viewer/local-art/creatures' / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    models = []
    for body, (stem, hues, joints, motions) in FORMS.items():
        names = {name: name for name in members}
        selected = [row for row in rows if row['stem'] != stem or row['body'] == body]
        parser, exporter, refine = pipeline.td.parse, pipeline.td.export_gltf, pipeline.smooth.refine
        if body == 276:
            names['client/models/animals/raptalon_gethit.grn'] = 'client/models/animals/raptalon_takedamage.grn'
            pipeline.td.parse = partial(parser, max_influences=8)
            pipeline.td.export_gltf = partial(exporter, max_influences=8)

            def preserve_weights(mesh, **options):
                return refine(mesh, **(options | {'levels': 0, 'weight_smoothing': 0.0, 'max_influences': 8}))

            pipeline.smooth.refine = preserve_weights
        try:
            row, = pipeline.prepare(stem, Inputs(), names, selected, native, selected_kinds={stem})
        finally:
            pipeline.td.parse, pipeline.td.export_gltf, pipeline.smooth.refine = parser, exporter, refine
        if row['status'] != 'prepared':
            raise ValueError(f'{stem}: {row.get("blocker")}')
        identity, = row['bodies']
        if (identity['body'], row['stats']['original']['bones'], len(row['clip_sources'])) != (body, joints, motions):
            raise ValueError(f'Unexpected original rig or recovered clip count for {stem}')
        for entry in identity['native_sources']:
            checked(ROOT / 'Server/ModernUO' / entry['path'].replace(chr(92), '/'), entry['sha256'])
        row.update(family=FAMILY, native_constructor_hues=hues, assets={}, asset_sha256={}, art_dependency_sha256={})
        renderer = 'Presentation/OccurrenceCreatureVisual.gd'
        if body in (768, 249, 276):
            renderer = 'Presentation/SourcePreservingCreatureVisual.gd'
            row['limb_support'] = 'plane'
            ground = 'Presentation/SourceGroundLookup.gd'
            row['art_dependency_sha256'][f'res://{ground}'] = SHA(ROOT / 'Viewer' / ground)
        if body == 276:
            row['skin_policy'] = 'Original 546 triangles and up to six source influences; eight-slot glTF, no subdivision.'
            row['native_mount_graphic'] = 0x3e90
        row['presentation_script'] = f'res://{renderer}'
        row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        for variant in ('original', 'rounded', 'modern'):
            name = f'{stem}-{variant}.gltf'
            copyfile(pipeline.OUTPUT / name, destination / name)
            row['assets'][variant] = f'res://local-art/creatures/{FAMILY}/{name}'
            row['asset_sha256'][variant] = SHA(destination / name)
        models.append(row)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(MANIFEST)}, indent=2) + '\n')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
