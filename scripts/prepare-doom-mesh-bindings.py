"""Rebuild the two Doom bodies using their own skin palettes and exact weapons."""

import json
from pathlib import Path
import runpy


folder = Path(__file__).resolve().parent
root = folder.parent
source = runpy.run_path(str(root / 'scripts/prepare-aos-creatures.py'))
mesh_palettes = runpy.run_path(str(folder / 'grn-mesh-palettes.py'))['mesh_palettes']
pipeline = source['LATE']['TOOLS']['pipeline']()
trial = root / 'Viewer/local-art/creatures/doom-binding-trial'


def armoured_mesh(raw, body):
    layout = source['ARMED_PARTS'][body]
    mesh_index, _, _, points, _, weapon_points, _ = layout
    mesh, rigid = source['decode_armed'](pipeline, raw, layout)
    palettes, skins = mesh_palettes(raw, pipeline.td)
    assert len(palettes) == 2 and len(rigid['parts']) == 1
    assert skins[mesh_index][0] == points and skins[1 - mesh_index][0] == 0
    assert mesh['ties'] == [joint for _, joints in palettes.values() for joint in joints]
    offset, joints = palettes[mesh_index + 1]
    weapon_offset, weapon_joints = palettes[2 - mesh_index]
    assert len(weapon_joints) == 1 and len(mesh['weights']) == points + weapon_points
    assert rigid['parts'][0]['bone_tie'] == weapon_offset
    assert all(row == [(weapon_offset, 1.)] for row in mesh['weights'][points:])
    assert max(index for row in mesh['weights'][:points] for index, _ in row) == len(joints) - 1
    mesh['weights'][:points] = [[(offset + index, weight) for index, weight in row]
                                for row in mesh['weights'][:points]]
    return mesh, rigid, {'body_mesh': mesh_index, 'palette_ids_in_file_order': list(palettes),
                         'body_palette_offset': offset, 'body_palette_joint_count': len(joints),
                         'weapon_palette_offset': weapon_offset}


def main():
    manifest_path = root / 'scripts/aos-armed-inputs.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    base, checked = source['BASE'], source['checked']
    table = checked(base / 'model-table/Client/Models.txt', manifest['model_table_sha256'])
    members = {name.lower(): checked(base / 'aos-creature-source' / name, digest)
               for name, digest in manifest['files'].items()}

    class Inputs:
        def read(self, name):
            return members[name].read_bytes()

    pipeline.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
    pipeline.OUTPUT = trial
    trial.mkdir(parents=True, exist_ok=True)
    rows = pipeline.table_rows(table.read_bytes())
    _, native = pipeline.native_bodies()
    names = {name: name for name in members}
    models = []
    for body, (kind, classes, joints, motions) in source['ARMED_FORMS'].items():
        selected = [row for row in rows if row['stem'] != kind or row['body'] == body]
        raw = members[f'client/models/monsters/{kind}_lod2.grn'].read_bytes()
        mesh, rigid, palette = armoured_mesh(raw, body)
        parse = pipeline.td.parse
        pipeline.td.parse = lambda data, **opts: mesh if data == raw and not opts.get('animations_only') else parse(data, **opts)
        try:
            row, = pipeline.prepare(kind.split('_')[0], Inputs(), names, selected, native, selected_kinds={kind})
        finally:
            pipeline.td.parse = parse
        assert row['status'] == 'prepared' and row['bodies'][0]['body'] == body
        assert row['stats']['original']['bones'] == joints and len(row['clip_sources']) == motions
        row.update(family='aos_armed', rigid_import=rigid, mesh_local_palette=palette,
                   native_constructor_hues=dict.fromkeys(classes, 0))
        models.append(row)
        print(kind, palette)
    (trial / 'preparation.json').write_text(json.dumps({'family': 'aos_armed', 'models': models}, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
