"""Rebuild Horde Minion and Rune Beetle from statically extracted archive members."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'horde-rune-inputs.json'
FAMILY = 'horde_rune'
FORMS = {
    776: ('horde_demon', ('HordeMinion', 'HordeMinionFamiliar'), 52, 9),
    244: ('rune_beetle', ('RuneBeetle',), 24, 13),
}


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'horde-kitsune-rune-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'horde-kitsune-rune-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    destination = ROOT / 'Viewer/local-art/creatures' / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    strict_parse = pipeline.td.parse
    models = []
    for body, (kind, native_classes, joints, motions) in FORMS.items():
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        mesh = next(path.read_bytes() for name, path in members.items()
                    if name.endswith(f'/{kind}_lod2.grn'))
        repairs = {}
        retained = ([bone['name'] for bone in strict_parse(mesh, scene_root_names=True)['bones']]
                    if body == 776 else None)

        def parse(raw, **options):
            if retained is not None and options.get('animations_only'):
                options['retained_bone_names'] = retained
            if body == 244 and raw == mesh and not options.get('animations_only'):
                model, repair = pipeline.repairs.repair_one_unweighted_vertex(raw, pipeline.td)
                if repair['vertex'] != 12 or repair['neighbours'] != [11, 13]:
                    raise ValueError('Unexpected Rune Beetle repair topology')
                repairs.update(repair)
                return model
            return strict_parse(raw, **options)

        pipeline.td.parse = parse
        try:
            row, = pipeline.prepare(kind.split('_')[0], Inputs(), names, selected, native,
                                    selected_kinds={kind})
        finally:
            pipeline.td.parse = strict_parse
        if row['status'] != 'prepared':
            raise ValueError(f'{kind} conversion failed: {row.get("blocker")}')
        identity, = row['bodies']
        if (identity['body'] != body or row['stats']['original']['bones'] != joints
                or len(row['clip_sources']) != motions):
            raise ValueError(f'Unexpected rig or recovered motions for {kind}')
        for source in identity['native_sources']:
            checked(ROOT / 'Server/ModernUO' / source['path'].replace(chr(92), '/'), source['sha256'])
        row.update(family=FAMILY, native_constructor_hues=dict.fromkeys(native_classes, 0),
                   assets={}, asset_sha256={}, art_dependency_sha256={})
        common_renderer = 'Presentation/OccurrenceCreatureVisual.gd'
        renderer = 'Presentation/RuneBeetleVisual.gd' if body == 244 else common_renderer
        row['presentation_script'] = f'res://{renderer}'
        row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        if body == 244:
            row['art_dependency_sha256'][f'res://{common_renderer}'] = SHA(ROOT / 'Viewer' / common_renderer)
        if repairs:
            row['skin_weight_repair'] = repairs
        for treatment in ('original', 'rounded', 'modern'):
            filename = f'{kind}-{treatment}.gltf'
            copyfile(pipeline.OUTPUT / filename, destination / filename)
            row['assets'][treatment] = f'res://local-art/creatures/{FAMILY}/{filename}'
            row['asset_sha256'][treatment] = SHA(destination / filename)
        models.append(row)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
