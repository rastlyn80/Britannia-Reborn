"""Validate and decode the private Third Dawn Bog Thing source."""
import json
from pathlib import Path
import runpy

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
WORK = ROOT / 'work/creatures/bog-thing'
SOURCE = ROOT / 'work/third-dawn/late-source-research/uoaos-source'
MANIFEST = SCRIPTS / 'bog-thing-inputs.json'
MIXED = runpy.run_path(str(SCRIPTS / 'prepare-gazer-larva-source.py'))


def inputs():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    native = manifest['native_class_source']
    for folder, files in ((SOURCE, manifest['files']), (ROOT / 'Server/ModernUO', [native])):
        for item in files:
            path = folder / item['path']
            assert path.stat().st_size == item['bytes'] and MIXED['sha'](path) == item['sha256'], path
    table = (SOURCE / 'Models/models.txt').read_text(encoding='latin-1')
    row, = (line.split() for line in table.splitlines() if line.startswith('780\t'))
    assert row[:3] == ['780', '0', '0'] and row[-4:] == ['1.3', '1.3', '1.3', 'bog_thing']
    assert manifest['model_table_assignment'] == {'body': 780, 'stem': 'bog_thing', 'scale': [1.3] * 3}
    assert manifest['authored_unit_factor'] == .001
    return manifest


def decode(manifest, tools):
    path = SOURCE / 'Models/Monsters/bog_thing_lod2.grn'
    return MIXED['decode'](path.read_bytes(), manifest['parts'], tools,
                           body_shape=(733, 1375, 58), rigid_shape=(10, 15))


def footprint(model):
    corners = [point for polygon in model['polygons'] for point in polygon[:3]]
    unique = {point: corner for corner, point in enumerate(corners)
              if point < 733 and model['points'][point][2] <= 50}
    assert len(unique) == 103
    return list(unique.values())


def main():
    model, _ = decode(inputs(), MIXED['pipeline']())
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / 'owned-raw-ir.json').write_text(
        json.dumps(model, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
    (WORK / 'owned-footprint.json').write_text(json.dumps(footprint(model)), encoding='utf-8')
    print('BOG THING SOURCE: 58 bones, 1,375 body triangles, 13 rigid pieces and 103 footprint points')


if __name__ == '__main__':
    main()
