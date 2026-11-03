"""Rebuild archived late-client creature presentations from exact inputs."""
import argparse
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
TOE_ENDS = frozenset(('bip01 l toe0nub', 'bip01 r toe0nub'))


def checked(path, expected):
    if SHA(path) != expected:
        raise ValueError(f'Changed archive or native input: {path}')
    return path


def match_tormented(animation, body, match):
    indices = {i for i, bone in enumerate(body['bones']) if bone['name'] in TOE_ENDS}
    weighted = any(body['ties'][joint] in indices and weight > 0
                   for point in body['weights'] for joint, weight in point)
    if len(indices) != len(TOE_ENDS) or weighted or any(bone['parent'] in indices for bone in body['bones']):
        raise ValueError('Tormented Minotaur toe ends must remain unweighted leaves')
    retained = [bone for i, bone in enumerate(body['bones']) if i not in indices]
    return match(animation, dict(body, bones=retained))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tormented', action='store_true')
    args = parser.parse_args()
    family = 'tormented_minotaur' if args.tormented else FAMILY
    forms = {262: ('tormentedminotaur', {'TormentedMinotaur': 0}, 40, 12)} if args.tormented else FORMS
    manifest_path = HERE / 'tormented-minotaur-inputs.json' if args.tormented else MANIFEST
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'final-late-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = TOOLS['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / f'{family.replace("_", "-")}-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    destination = ROOT / 'Viewer/local-art/creatures' / family
    destination.mkdir(parents=True, exist_ok=True)
    models = []
    match = pipeline.helper.match_animation
    for body, (stem, hues, joints, motions) in forms.items():
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
        elif body == 262:
            names['client/models/monsters/tormentedminotaur_gethit.grn'] = 'client/models/monsters/tormentedminotaur_takedamage.grn'
            pipeline.helper.match_animation = partial(match_tormented, match=match)
        try:
            row, = pipeline.prepare(stem, Inputs(), names, selected, native, selected_kinds={stem})
        finally:
            pipeline.td.parse, pipeline.td.export_gltf, pipeline.smooth.refine = parser, exporter, refine
            pipeline.helper.match_animation = match
        if row['status'] != 'prepared':
            raise ValueError(f'{stem}: {row.get("blocker")}')
        identity, = row['bodies']
        if (identity['body'], row['stats']['original']['bones'], len(row['clip_sources'])) != (body, joints, motions):
            raise ValueError(f'Unexpected original rig or recovered clip count for {stem}')
        for entry in identity['native_sources']:
            checked(ROOT / 'Server/ModernUO' / entry['path'].replace(chr(92), '/'), entry['sha256'])
        row.update(family=family, native_constructor_hues=hues, assets={}, asset_sha256={}, art_dependency_sha256={})
        renderer = 'Presentation/OccurrenceCreatureVisual.gd'
        if body in (768, 249, 276):
            renderer = 'Presentation/SourcePreservingCreatureVisual.gd'
            row['limb_support'] = 'plane'
            ground = 'Presentation/SourceGroundLookup.gd'
            row['art_dependency_sha256'][f'res://{ground}'] = SHA(ROOT / 'Viewer' / ground)
        if body == 276:
            row['skin_policy'] = 'Original 546 triangles and up to six source influences; eight-slot glTF, no subdivision.'
            row['native_mount_graphic'] = 0x3e90
        if body == 262:
            row['motion_matching_omitted_unweighted_leaves'] = sorted(TOE_ENDS)
        row['presentation_script'] = f'res://{renderer}'
        row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        for variant in ('original', 'rounded', 'modern'):
            name = f'{stem}-{variant}.gltf'
            copyfile(pipeline.OUTPUT / name, destination / name)
            row['assets'][variant] = f'res://local-art/creatures/{family}/{name}'
            row['asset_sha256'][variant] = SHA(destination / name)
        models.append(row)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(manifest_path)}, indent=2) + '\n')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
