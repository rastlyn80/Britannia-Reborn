"""Rebuild Centaur on its own mesh-local palette without altering the active art."""

import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import runpy
import zipfile


folder = Path(__file__).resolve().parent
root = folder.parent
mesh_palettes = runpy.run_path(str(folder / 'grn-mesh-palettes.py'))['mesh_palettes']
source_art = root / 'Viewer/local-art/creatures'
trial = source_art / 'centaur-binding-trial'
member = 'uotdb/uotd/Models/Monsters/Centaurs_centaur_LOD2.grn'
member_sha256 = '39766281d1bccdb8bcbc954508720057da48d70118b6f48616ccf7826adc4ceb'
spec = importlib.util.spec_from_file_location('centaur_pipeline', root / 'scripts/prepare-creatures.py')
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)
parse_original = pipeline.td.parse


def read_centaur(raw, **options):
    model = parse_original(raw, **options)
    if hashlib.sha256(raw).hexdigest() != member_sha256:
        return model
    assert options['skip_unskinned_helpers'] and not options.get('animations_only', False)
    palettes, weights = mesh_palettes(raw, pipeline.td)
    assert weights == [(0, 0, 0), (0, 0, 0), (225, 40, 2)]
    assert model['ties'] == [joint for _, joints in palettes.values() for joint in joints]
    # The visible mesh is the third 0x0601 group. Its weight indices start
    # again at zero in the third one-based palette, after two unskinned boxes.
    model['ties'] = palettes[3][1]
    assert max(tie for row in model['weights'] for tie, _ in row) == len(model['ties']) - 1
    return model


def main():
    trial.mkdir(parents=True, exist_ok=True)
    for suffix in ('-albedo-v1.png', '-albedo-v1.prompt.txt', '-uv-template.png'):
        file = 'centaurs_centaur' + suffix
        shutil.copyfile(source_art / file, trial / file)
    archive = root / 'work/third-dawn/uotdb.zip'
    with archive.open('rb') as stream:
        assert hashlib.file_digest(stream, 'sha256').hexdigest() == pipeline.helper.audit.ARCHIVE_HASH
    pipeline.OUTPUT = trial
    pipeline.td.parse = read_centaur
    try:
        pin, native = pipeline.native_bodies()
        with zipfile.ZipFile(archive) as handle:
            names = {name.lower(): name for name in handle.namelist()}
            rows = pipeline.table_rows(handle.read(names['uotdb/uotd/models/models.txt']))
            row, = pipeline.prepare('centaurs', handle, names, rows, native, selected_kinds={'centaurs_centaur'})
    finally:
        pipeline.td.parse = parse_original
    assert row['status'] == 'prepared' and not row['rejected_source_clips']
    assert row['stats']['original']['source_points'] == 225 and row['stats']['original']['triangles'] == 446
    assert row['stats']['original']['bones'] == 47 and len(row['clip_sources']) == 7
    print(json.dumps({'server_pin': pin, 'source_member': member, 'source_sha256': member_sha256,
                      'binding': '41 mesh-local palette entries from the third mesh group',
                      'body': 101, 'clips': list(row['clip_sources']), 'output': str(trial.relative_to(root))}, indent=2))


if __name__ == '__main__':
    main()
