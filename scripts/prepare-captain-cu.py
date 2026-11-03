"""Rebuild the original Minotaur Captain and Cu Sidhe from statically extracted archive members."""
import argparse
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'captain-cu-inputs.json'
FAMILY = 'captain_cu'
FORMS = {
    280: ('minotaurarmored', ('MinotaurCaptain',), 35, 13),
    277: ('cushidhe', ('CuSidhe',), 37, 9),
}
CU_HUES = (0, 0x489, 0x657, 0x515, 0x4b1, 0x481, 0x482, 0x455,
           0x97a, 0x978, 0x901, 0x8ac, 0x5a7, 0x527)


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mounted-cu', action='store_true')
    args = parser.parse_args()
    family = 'cu_sidhe_mount' if args.mounted_cu else FAMILY
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'elemental-minotaur-meer-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'minotaur-captain-cu-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    destination = ROOT / 'Viewer/local-art/creatures' / family
    destination.mkdir(parents=True, exist_ok=True)
    models = []
    for body, (kind, native_classes, joints, motions) in FORMS.items():
        if args.mounted_cu and body != 277:
            continue
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        row, = pipeline.prepare(kind.split('_')[0], Inputs(), names, selected, native,
                                selected_kinds={kind})
        if row['status'] != 'prepared':
            raise ValueError(f'{kind} conversion failed: {row.get("blocker")}')
        identity, = row['bodies']
        if (identity['body'] != body or row['stats']['original']['bones'] != joints
                or len(row['clip_sources']) != motions):
            raise ValueError(f'Unexpected rig or recovered motions for {kind}')
        for source in identity['native_sources']:
            checked(ROOT / 'Server/ModernUO' / source['path'].replace(chr(92), '/'), source['sha256'])
        row.update(family=family, native_constructor_hues=dict.fromkeys(native_classes, 0),
                   assets={}, asset_sha256={}, art_dependency_sha256={})
        renderer = 'Presentation/OccurrenceCreatureVisual.gd'
        if args.mounted_cu:
            renderer = 'Presentation/SourceCuSidheMountVisual.gd'
            row.update(mount_item=0x3e91, limb_support='quadruped')
            dependency = 'Presentation/SourceRigMountVisual.gd'
            row['art_dependency_sha256'][f'res://{dependency}'] = SHA(ROOT / 'Viewer' / dependency)
        row['presentation_script'] = f'res://{renderer}'
        row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        if body == 277:
            row['native_mount_graphic'] = 0x3e91
            row['native_constructor_hue_ranges'] = {'CuSidhe': [[hue, hue] for hue in CU_HUES]}
        for treatment in ('original', 'rounded', 'modern'):
            filename = f'{kind}-{treatment}.gltf'
            copyfile(pipeline.OUTPUT / filename, destination / filename)
            row['assets'][treatment] = f'res://local-art/creatures/{family}/{filename}'
            row['asset_sha256'][treatment] = SHA(destination / filename)
        models.append(row)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
