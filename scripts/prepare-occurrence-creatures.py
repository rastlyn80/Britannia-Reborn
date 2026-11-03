"""Rebuild four original creature forms from statically extracted archive members."""
import json
from pathlib import Path
import runpy
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'occurrence-creature-inputs.json'
FAMILY = 'occurrence_next'
FORMS = {
    309: ('patchskeleton', 'PatchworkSkeleton', 42, 9),
    196: ('denkou_yajuu', 'KazeKemono', 33, 12),
    302: ('skittering_hopper', 'SkitteringHopper', 48, 8),
    247: ('fan_dancer', 'FanDancer', 30, 11),
}


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def patchwork_match(match, animation, body):
    # The mesh's left grasp socket is an unused leaf attached to the scene
    # root. Motion files attach it to a hand absent from the mesh bind.
    index, = [i for i, bone in enumerate(body['bones']) if bone['name'] == 'cp_grasp_lhand']
    if (any(bone['parent'] == index for bone in body['bones'])
            or any(j == index and weight > 0 for point in body['weights'] for j, weight in point)):
        raise ValueError('Patchwork left grasp socket is no longer an unweighted leaf')
    retained = [dict(bone, parent=bone['parent'] - (bone['parent'] > index))
                for i, bone in enumerate(body['bones']) if i != index]
    return match(animation, dict(body, bones=retained))


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'occurrence-next-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'occurrence-next-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    destination = ROOT / 'Viewer/local-art/creatures' / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    parse, refine, export = pipeline.td.parse, pipeline.smooth.refine, pipeline.td.export_gltf
    match = pipeline.helper.match_animation
    actions = pipeline.humanoid_actions
    install_actions = actions.install

    def install(body, clips, authored, aliases, kind):
        if kind == 'denkou_yajuu' and 'Cast' not in clips:
            clips['Cast'] = actions.gesture(body, clips['Idle'], 'Cast')
            authored['Cast'] = 'Authored cast on the original Kaze Kemono rig.'
        return install_actions(body, clips, authored, aliases, kind)

    actions.install = install
    models = []

    for body, (kind, native_class, joints, motions) in FORMS.items():
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        if body == 309:
            pipeline.helper.match_animation = lambda anim, model: patchwork_match(match, anim, model)
        if body == 247:
            mesh = next(path.read_bytes() for name, path in members.items()
                        if name.endswith('/fan_dancer_lod2.grn'))

            def parse_fan(raw, **options):
                if raw == mesh:
                    options['max_influences'] = 8
                return parse(raw, **options)

            pipeline.td.parse = parse_fan
            pipeline.smooth.refine = lambda model, **opts: refine(model, max_influences=8, **opts)
            pipeline.td.export_gltf = lambda *args, **opts: export(*args, max_influences=8, **opts)
        try:
            row, = pipeline.prepare(kind.split('_')[0], Inputs(), names, selected, native,
                                    selected_kinds={kind})
        finally:
            pipeline.helper.match_animation = match
            pipeline.td.parse, pipeline.smooth.refine, pipeline.td.export_gltf = parse, refine, export
        if row['status'] != 'prepared':
            raise ValueError(f'{kind} conversion failed: {row.get("blocker")}')
        identity, = row['bodies']
        if (identity['body'] != body or row['stats']['original']['bones'] != joints
                or len(row['clip_sources']) != motions):
            raise ValueError(f'Unexpected rig or recovered motions for {kind}')
        for source in identity['native_sources']:
            checked(ROOT / 'Server/ModernUO' / source['path'].replace(chr(92), '/'), source['sha256'])
        row.update(family=FAMILY, native_constructor_hues={native_class: 0},
                   assets={}, asset_sha256={}, art_dependency_sha256={})
        if body != 309:
            common = 'Presentation/OccurrenceCreatureVisual.gd'
            renderer = 'Presentation/FanDancerVisual.gd' if body == 247 else common
            row['presentation_script'] = f'res://{renderer}'
            row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
            if body == 247:
                for dependency in (common, 'Presentation/FanDancerSupport.gd'):
                    row['art_dependency_sha256'][f'res://{dependency}'] = SHA(ROOT / 'Viewer' / dependency)
        if body == 196:
            row['authored_cast_recipe_sha256'] = SHA(HERE / 'creature-humanoid-actions.py')
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
