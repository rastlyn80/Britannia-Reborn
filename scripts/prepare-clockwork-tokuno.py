"""Rebuild the original Tokuno and late-client creature batch from statically extracted archive members."""
import copy
import json
from pathlib import Path
import runpy
import struct
from shutil import copyfile

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'clockwork-tokuno-inputs.json'
FAMILY = 'clockwork_tokuno'
FORMS = {
    304: ('flesh_golem', ('FleshGolem',), 50, 8),
    757: ('clockwork_minion', ('ExodusMinion',), 26, 9),
    756: ('clockwork_overseer', ('ExodusOverseer',), 23, 9),
    252: ('lady_of_the_snow', ('LadyOfTheSnow',), 25, 11),
    199: ('gouzen_ha', ('RaiJu',), 31, 11),
    271: ('satyr', ('Satyr',), 34, 11),
    310: ('wailingbanshee', ('WailingBanshee',), 67, 10),
    278: ('squirrel', ('Squirrel',), 40, 11),
}


def skeletal_chunks(chunks):
    transforms = other = 0
    for tag, payload, parents in chunks:
        if tag == 0xca5e1204:
            if len(payload) < 52:
                raise ValueError('Truncated Rai-Ju record header')
            translation, rotation, scale = struct.unpack_from('<13I', payload)[6:9]
            if 52 + translation * 16 + rotation * 20 + scale * 40 != len(payload):
                other += 1
                continue
            transforms += 1
        yield tag, payload, parents
    if transforms != 33 or other != 33:
        raise ValueError(f'Unexpected Rai-Ju record layout: {transforms}/{other}')


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'clockwork-tokuno-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'clockwork-tokuno-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    destination = ROOT / 'Viewer/local-art/creatures' / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    chunks = pipeline.td.chunks
    repair_normals = pipeline.helper.audit.repair_invalid_normals
    rai_motion = {path.read_bytes() for name, path in members.items()
                  if '/gouzen_ha_' in name and name.endswith('.grn') and '_lod2' not in name}
    actions = pipeline.humanoid_actions
    install_actions = actions.install

    def install(body, clips, authored, aliases, kind):
        if kind == 'lady_of_the_snow' and 'Cast' not in clips:
            clips['Cast'] = copy.deepcopy(clips['Attack2'])
            aliases['Cast'] = 'Attack2: authored reuse of an original motion for spell packets.'
        return install_actions(body, clips, authored, aliases, kind)

    actions.install = install
    models = []
    for body, (kind, native_classes, joints, motions) in FORMS.items():
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        inputs = names.copy()
        if body == 199:
            pipeline.td.chunks = lambda raw: skeletal_chunks(chunks(raw)) if raw in rai_motion else chunks(raw)
        if body == 757:
            mesh = members['client/models/monsters/clockwork_minion_lod2.grn'].read_bytes()

            def repair_minion(raw, **options):
                if raw == mesh:
                    options['allow_coincident_seams'] = True
                return repair_normals(raw, **options)

            pipeline.helper.audit.repair_invalid_normals = repair_minion
        if body == 278:
            prefix = 'client/models/animals/squirrel_'
            for logical, original in {'walk': 'run', 'attack1': 'attack2', 'gethit': 'takedamage'}.items():
                inputs[f'{prefix}{logical}.grn'] = names[f'{prefix}{original}.grn']
            pipeline.LABELS['fidget2'] = 'Fidget2'
        try:
            row, = pipeline.prepare(kind.split('_')[0], Inputs(), inputs, selected, native,
                                    selected_kinds={kind})
        finally:
            pipeline.td.chunks = chunks
            pipeline.helper.audit.repair_invalid_normals = repair_normals
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
        plane_support = body in (756, 252)
        visual = 'SourcePreservingCreatureVisual' if plane_support else 'OccurrenceCreatureVisual'
        renderer = f'Presentation/{visual}.gd'
        row['presentation_script'] = f'res://{renderer}'
        row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        if plane_support:
            row['limb_support'] = 'plane'
            dependency = 'Presentation/SourceGroundLookup.gd'
            row['art_dependency_sha256'][f'res://{dependency}'] = SHA(ROOT / 'Viewer' / dependency)
        if body == 199:
            row['source_animation_record_scope'] = '33 skeletal records per input; 33 unconverted records of unknown format.'
        if body == 757:
            repair = row['normal_repair']
            expected = [20, 21, 83, 135, 136, 154, 264, 265, 267, 269, 272, 307]
            if (repair['normal_indices'] != expected or repair['coincident_seam_approximations'] != expected
                    or repair['dropped_repeated_vertex_faces']):
                raise ValueError('Unexpected Clockwork Minion normal repair')
        if body == 278:
            row['classic_action_categories'] = {'10': 'Fidget2'}
            row['category_aliases'].update(Walk='Run: original Walk is trackless',
                                           Attack='Attack2: original Attack1 is trackless')
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
