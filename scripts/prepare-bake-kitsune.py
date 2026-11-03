"""Build the pinned textured Bake Kitsune skin and recover its original motions."""
import json
from pathlib import Path
import runpy
from shutil import copyfile
import struct

HERE = Path(__file__).resolve().parent
LATE = runpy.run_path(str(HERE / 'prepare-hydra.py'))
ROOT, BASE, SHA = (LATE[key] for key in ('ROOT', 'BASE', 'SHA'))
MANIFEST = HERE / 'bake-kitsune-inputs.json'
KIND = 'kitsun_tsuki'
FAMILY = 'bake_kitsune'
HELPER_IDS = (1, 2, 45, 4, 5)
HELPER_BONES = {'l_tailbone', 'l_tailbone01', 'jawbone', 'm_tailbone', 'm_tailbone01'}


def visible_chunks(entries):
    """Remove only the pinned untextured bone shapes and their face tables."""
    group = 0
    object_ids, point_counts, weight_counts = [], [], []
    face_tables = 0
    for tag, payload, ancestors in entries:
        if tag == 0xca5e0601:
            group += 1
            if group > 1:
                continue
        if 0xca5e0601 in ancestors and group > 1:
            if tag == 0xca5e0801:
                point_counts.append(len(payload) // 12)
            if tag == 0xca5e0702:
                weight_counts.append(struct.unpack_from('<I', payload)[0])
            if tag == 0xca5e0f04:
                object_ids.append(struct.unpack('<I', payload)[0])
            if tag == 0xca5e0803:
                raise ValueError('Kitsune helper has texture coordinates')
            continue
        if tag == 0xca5e0e06 and len(payload) == 60 and struct.unpack_from('<I', payload)[0] == 14:
            face_tables += 1
            continue
        yield tag, payload, ancestors
    if (group != 6 or tuple(object_ids) != HELPER_IDS or point_counts != [9] * 5
            or weight_counts != [0] * 5 or face_tables != 5):
        raise ValueError('Unexpected Kitsune bone-shape layout')


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    table = BASE / 'model-table/Client/Models.txt'
    if SHA(table) != manifest['model_table_sha256']:
        raise ValueError('Unexpected Bake Kitsune model table')
    members = {}
    for name, digest in manifest['files'].items():
        path = BASE / 'horde-kitsune-rune-source' / name
        if SHA(path) != digest:
            raise ValueError(f'Unexpected Bake Kitsune archive member: {name}')
        members[name.lower()] = path

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline = LATE['TOOLS']['pipeline']()
    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = BASE / 'horde-kitsune-rune-preview'
    mesh = next(path.read_bytes() for name, path in members.items()
                if name.endswith('/kitsun_tsuki_lod2.grn'))
    chunks = pipeline.td.chunks

    def scoped_chunks(raw):
        return visible_chunks(chunks(raw)) if raw == mesh else chunks(raw)

    pipeline.td.chunks = scoped_chunks
    skin = pipeline.td.parse(mesh, scene_root_names=True)
    weighted = {skin['bones'][skin['ties'][index]]['name']
                for weights in skin['weights'] for index, weight in weights if weight > 0}
    if not HELPER_BONES <= weighted:
        raise ValueError('Kitsune must retain visible skin on all original jaw and tail joints')

    rows = pipeline.table_rows(table.read_bytes())
    rows = [row for row in rows if row['stem'] != KIND or row['body'] == 246]
    _, native = pipeline.native_bodies()
    row, = pipeline.prepare('kitsun', Inputs(), {name: name for name in members}, rows, native,
                            selected_kinds={KIND})
    if row['status'] != 'prepared' or len(row['clip_sources']) != 11:
        raise ValueError(f'Unexpected Bake Kitsune conversion: {row.get("blocker")}')
    identity, = row['bodies']
    if identity['body'] != 246 or row['stats']['original']['bones'] != 37:
        raise ValueError('Unexpected Bake Kitsune native identity or rig')
    destination = ROOT / 'Viewer/local-art/creatures' / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    row.update(family=FAMILY, native_constructor_hues={'BakeKitsune': 0},
               assets={}, asset_sha256={}, art_dependency_sha256={},
               excluded_untextured_object_ids=list(HELPER_IDS),
               retained_weighted_helper_joints=sorted(HELPER_BONES))
    renderer = 'Presentation/OccurrenceCreatureVisual.gd'
    row['presentation_script'] = f'res://{renderer}'
    row['presentation_script_sha256'] = SHA(ROOT / 'Viewer' / renderer)
    for treatment in ('original', 'rounded', 'modern'):
        filename = f'{KIND}-{treatment}.gltf'
        copyfile(pipeline.OUTPUT / filename, destination / filename)
        row['assets'][treatment] = f'res://local-art/creatures/{FAMILY}/{filename}'
        row['asset_sha256'][treatment] = SHA(destination / filename)
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(destination / 'preparation.json')


if __name__ == '__main__':
    main()
