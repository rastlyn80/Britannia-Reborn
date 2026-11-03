"""Rebuild the next archive-backed creature batch from statically extracted archive members."""
import copy
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'elemental-minotaur-inputs.json'
FAMILY = 'elemental_minotaur'
FORMS = {
    300: ('crystal_elemental', ('CrystalElemental',), 117, 8),
    263: ('minotaur', ('Minotaur',), 35, 13),
    305: ('gore_fiend', ('GoreFiend',), 63, 10),
    281: ('leatherminotaur', ('MinotaurScout',), 37, 13),
    241: ('oni', ('Oni',), 26, 11),
    789: ('quagmire', ('Quagmire',), 64, 9),
    772: ('npc_adranath', ('MeerEternal',), 52, 7),
}
MATCH_NUBS = runpy.run_path(str(HERE / 'prepare-devourer-lion-hiryu.py'))['match_devourer']


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'elemental-minotaur-meer-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'elemental-minotaur-meer-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    destination = ROOT / 'Viewer/local-art/creatures' / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    strict_parse = pipeline.td.parse
    match = pipeline.helper.match_animation
    actions = pipeline.humanoid_actions
    install_actions = actions.install

    def install(body, clips, authored, aliases, kind):
        if kind in ('crystal_elemental', 'oni', 'npc_adranath') and 'Cast' not in clips:
            clips['Cast'] = copy.deepcopy(clips['Attack2'])
            aliases['Cast'] = 'Attack2: authored routing of the original motion for casting packets.'
        return install_actions(body, clips, authored, aliases, kind)

    actions.install = install
    models = []
    for body, (kind, native_classes, joints, motions) in FORMS.items():
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        if body == 300:
            pipeline.helper.match_animation = lambda anim, model: MATCH_NUBS(match, anim, model)
        if body == 789:
            mesh = next(path.read_bytes() for name, path in members.items()
                        if name.endswith('/quagmire_lod2.grn'))
            retained = [bone['name'] for bone in strict_parse(mesh, scene_root_names=True)['bones']]

            def parse_quagmire(raw, **options):
                if options.get('animations_only'):
                    options['retained_bone_names'] = retained
                return strict_parse(raw, **options)

            pipeline.td.parse = parse_quagmire
        try:
            row, = pipeline.prepare(kind.split('_')[0], Inputs(), names, selected, native,
                                    selected_kinds={kind})
        finally:
            pipeline.td.parse = strict_parse
            pipeline.helper.match_animation = match
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
        if body in (241, 772, 789):
            name = 'SourcePreservingCreatureVisual' if body == 789 else 'OccurrenceCreatureVisual'
            renderer = f'Presentation/{name}.gd'
            row['presentation_script'] = f'res://{renderer}'
            row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        if body == 789:
            row['limb_support'] = 'plane'
            dependency = 'Presentation/SourceGroundLookup.gd'
            row['art_dependency_sha256'][f'res://{dependency}'] = SHA(ROOT / 'Viewer' / dependency)
        if body == 241:
            repair = row['normal_repair']
            if (repair['normal_indices'] != [28, 42, 52, 142, 152, 162]
                    or repair['dropped_repeated_vertex_faces'] != [42, 76, 237, 271]):
                raise ValueError('Unexpected Oni normal repair')
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
