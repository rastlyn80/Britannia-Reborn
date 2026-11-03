"""Rebuild original Age of Shadows creatures from statically extracted archive members."""
import argparse
from copy import deepcopy
import json
from pathlib import Path
import runpy
from shutil import copyfile
from struct import pack, unpack
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'aos-creature-inputs.json'
FAMILY = 'aos_creatures'
FORMS = {
    306: ('impaler', ('Impaler',), 37, 7),
    307: ('gibberling', ('Gibberling',), 43, 8),
    308: ('bonedemon', ('BoneDemon',), 56, 10),
    313: ('darknight_creeper', ('DarknightCreeper',), 81, 8),
    318: ('demon_knight', ('DemonKnight',), 78, 8),
}
ALIAS_FORMS = {
    315: ('flesh_renderer', ('FleshRenderer',), 78, 8),
    316: ('wander', ('WandererOfTheVoid',), 97, 8),
}
ALIASES = {
    315: ('bip01 bip01bone rb2', 'bip01 bone rb2', 'bip01 bone rb1'),
    316: ('head', 'bip01 head', 'neck2'),
}
MOUND_FORMS = {319: ('mound_of_maggots', ('MoundOfMaggots',), 75, 8)}
MOUND_HELPERS = frozenset(('dummy87', 'dummy93', 'dummy105'))
ARMED_FORMS = {
    311: ('shadow_knight', ('ShadowKnight',), 51, 8),
    314: ('ravager', ('Ravager',), 78, 8),
}
ARMED_PARTS = {
    311: (1, 1, 'shadow knight sword', 593, 1106, 50, 86),
    314: (0, 2, 'club', 604, 1303, 41, 78),
}
ABYSMAL_FORMS = {312: ('abysmal_horror', ('AbysmalHorror',), 43, 7)}
ABYSMAL_ALIASES = {'bip01 head': ('head', 0.0001), 'abysmal horror root': ('bip01', 0.02)}


def checked(path, digest):
    if SHA(path) != digest:
        raise ValueError(f'Unexpected archive input: {path}')
    return path


def match_alias(animation, body, match, alias):
    old, new, parent = alias
    candidates = [bone for bone in animation['bones'] if bone['name'] == old]
    if not candidates:
        return match(animation, body)
    source, = candidates
    target, = [bone for bone in body['bones'] if bone['name'] == new]
    if (any(bone['name'] == new for bone in animation['bones'])
            or animation['bones'][source['parent']]['name'] != parent
            or body['bones'][target['parent']]['name'] != parent
            or any(abs(a - b) > 0.0001 for a, b in zip(source['translation'], target['translation']))):
        raise ValueError(f'Unrecognised animation joint alias: {old}')
    animation = deepcopy(animation)
    for channel in animation['bones'] + animation['tracks']:
        if channel['name'] == old:
            channel['name'] = new
    return match(animation, body)


def match_mound(animation, body, match):
    indices = {i for i, bone in enumerate(body['bones']) if bone['name'] in MOUND_HELPERS}
    weighted = any(body['ties'][joint] in indices and weight > 0
                   for point in body['weights'] for joint, weight in point)
    if len(indices) != len(MOUND_HELPERS) or weighted or any(bone['parent'] in indices for bone in body['bones']):
        raise ValueError('Mound motion helpers must remain unweighted leaf joints')
    retained = [bone for i, bone in enumerate(body['bones']) if i not in indices]
    return match(animation, dict(body, bones=retained))


def match_abysmal(animation, body, match):
    animation = deepcopy(animation)
    rig = {bone['name']: bone for bone in body['bones']}
    names = {bone['name'] for bone in animation['bones']}
    for bone in animation['bones']:
        old = bone['name']
        if old not in ABYSMAL_ALIASES:
            continue
        target, translation_limit = ABYSMAL_ALIASES[old]
        bind = rig[target]
        if (target in names
                or animation['bones'][bone['parent']]['name'] != body['bones'][bind['parent']]['name']
                or any(abs(a - b) > translation_limit for a, b in zip(bone['translation'], bind['translation']))):
            raise ValueError(f'Unexpected Abysmal Horror joint alias: {old}')
        bone['name'] = target
    for track in animation['tracks']:
        if track['name'] in ABYSMAL_ALIASES:
            track['name'] = ABYSMAL_ALIASES[track['name']][0]
    return match(animation, body)


def decode_armed(pipeline, raw, layout):
    mesh_index, material_count, joint, body_points, body_faces, part_points, part_faces = layout
    reader = pipeline.td
    chunks = list(reader.chunks(raw))
    rig = reader.parse(raw, animations_only=True, scene_root_names=True)
    tie, = [i for i, bone in enumerate(rig['ties']) if rig['bones'][bone]['name'] == joint]

    def select(skinned):
        mesh, material = -1, None
        for tag, payload, ancestors in chunks:
            if tag == 0xca5e0601:
                mesh += 1
            if tag == 0xca5e0e02:
                material, count = unpack('<II', payload)
                if (material, count) not in ((0, 1), (1, material_count)):
                    raise ValueError('Unexpected armed creature material group')
            if (tag == 0xca5e0601 or 0xca5e0601 in ancestors) and (mesh == mesh_index) != skinned:
                continue
            if tag in (0xca5e0e02, 0xca5e0e06) and (material == 1) != skinned:
                continue
            if tag == 0xca5e0e02 and not skinned:
                payload = pack('<II', tie, 1)
            yield tag, payload, ancestors

    original_chunks = reader.chunks
    try:
        reader.chunks = lambda _: select(True)
        model = reader.parse(raw, scene_root_names=True)
    finally:
        reader.chunks = original_chunks
    rigid_reader = SimpleNamespace(chunks=lambda _: select(False), parse=reader.parse,
                                   require=reader.require, finite=reader.finite)
    part, _, report = pipeline.rigid.read_rigid_parts(raw, rigid_reader, excluded_names=())
    if ((len(model['points']), len(model['polygons']), len(part['points']), len(part['polygons']))
            != (body_points, body_faces, part_points, part_faces)
            or not all(model[key] == part[key] for key in ('bones', 'ties', 'textures'))
            or len(model['uv_sets']) != 1 or len(part['uv_sets']) != 1):
        raise ValueError('Armed creature mesh or bind contract changed')
    point_offset, normal_offset, uv_offset = len(model['points']), len(model['normals']), len(model['uv_sets'][0])
    model['points'].extend(part['points'])
    model['normals'].extend(part['normals'])
    model['uv_sets'][0].extend(part['uv_sets'][0])
    model['polygons'].extend(tuple(i + point_offset for i in face[:3])
                             + tuple(i + normal_offset for i in face[3:]) for face in part['polygons'])
    model['texture_polygons'].extend(tuple(i + uv_offset for i in face) for face in part['texture_polygons'])
    model['weights'].extend(part['weights'])
    return model, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--alias-batch', action='store_true')
    group.add_argument('--mound', action='store_true')
    group.add_argument('--armed', action='store_true')
    group.add_argument('--abysmal', action='store_true')
    args = parser.parse_args()
    family = 'aos_aliases' if args.alias_batch else FAMILY
    forms = ALIAS_FORMS if args.alias_batch else FORMS
    manifest_path = HERE / 'aos-creature-alias-inputs.json' if args.alias_batch else MANIFEST
    if args.mound:
        family, forms, manifest_path = 'aos_mound', MOUND_FORMS, HERE / 'aos-mound-inputs.json'
    if args.armed:
        family, forms, manifest_path = 'aos_armed', ARMED_FORMS, HERE / 'aos-armed-inputs.json'
    if args.abysmal:
        family, forms, manifest_path = 'aos_abysmal', ABYSMAL_FORMS, HERE / 'aos-abysmal-inputs.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    table = checked(BASE / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(BASE / 'aos-creature-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / f'{family.replace("_", "-")}-preview'
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    destination = ROOT / 'Viewer/local-art/creatures' / family
    destination.mkdir(parents=True, exist_ok=True)
    models = []
    match = pipeline.helper.match_animation
    for body, (kind, native_classes, joints, motions) in forms.items():
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        parse = pipeline.td.parse
        if body in ARMED_PARTS:
            raw = members[f'client/models/monsters/{kind}_lod2.grn'].read_bytes()
            mesh, rigid_report = decode_armed(pipeline, raw, ARMED_PARTS[body])
            pipeline.td.parse = lambda data, **opts: mesh if data == raw and not opts.get('animations_only') else parse(data, **opts)
        if body in ALIASES:
            alias = ALIASES[body]
            pipeline.helper.match_animation = lambda animation, mesh: match_alias(animation, mesh, match, alias)
        elif body == 319:
            pipeline.helper.match_animation = lambda animation, mesh: match_mound(animation, mesh, match)
        elif body == 312:
            pipeline.helper.match_animation = lambda animation, mesh: match_abysmal(animation, mesh, match)
        try:
            row, = pipeline.prepare(kind.split('_')[0], Inputs(), names, selected, native,
                                    selected_kinds={kind})
        finally:
            pipeline.helper.match_animation = match
            pipeline.td.parse = parse
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
        if body in ALIASES:
            row['animation_joint_alias'] = dict(zip(('source', 'bind', 'parent'), ALIASES[body]))
        if body == 319:
            row['motion_matching_omitted_unweighted_leaves'] = sorted(MOUND_HELPERS)
        if body in ARMED_PARTS:
            row['rigid_import'] = rigid_report
        if body == 312:
            if row.get('rejected_source_clips') != {
                    'Fly': {'member': 'client/models/monsters/abysmal_horror_fly.grn', 'error': 'Duplicate bone names'}}:
                raise ValueError('Unexpected Abysmal Horror source motion rejection')
            row['animation_joint_aliases'] = {name: target for name, (target, _) in ABYSMAL_ALIASES.items()}
        renderer = 'Presentation/OccurrenceCreatureVisual.gd'
        if body in (311, 312, 313, 315, 316, 319):
            renderer = 'Presentation/SourcePreservingCreatureVisual.gd'
            row['limb_support'] = 'plane'
            dependency = 'Presentation/SourceGroundLookup.gd'
            row['art_dependency_sha256'][f'res://{dependency}'] = SHA(ROOT / 'Viewer' / dependency)
        row['presentation_script'] = f'res://{renderer}'
        row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
        for treatment in ('original', 'rounded', 'modern'):
            filename = f'{kind}-{treatment}.gltf'
            copyfile(pipeline.OUTPUT / filename, destination / filename)
            row['assets'][treatment] = f'res://local-art/creatures/{family}/{filename}'
            row['asset_sha256'][treatment] = SHA(destination / filename)
        models.append(row)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': SHA(manifest_path)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
