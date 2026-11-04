"""Export the retained Third Dawn Mongbat airborne death into ignored local art."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/third-dawn/uotdb.zip'
ART = ROOT / 'Viewer/local-art/creatures'
PREFIX = 'uotdb/uotd/Models/'
PINS = {
    'Monsters/mongbats_mongbat_lod2.grn': 'b3f572d98468059591528128ed142dbad43a9a7c6e2059dd91fd111132305363',
    'Maps/mongbats_mongbat_v04.tga': '2235b156683455641ed9b8db6da90af694171c6ef27a0b952edc56b87db60187',
    'Monsters/mongbats_mongbat_idle.grn': '270943dade052217993939a5d6c0417f3a679a37b0a305ff9640c6252fa8fff2',
    'Monsters/mongbats_mongbat_dieinair.grn': '827418387deb1794a55101cf24259d98ccba635febb0a71ab30d727b2dc40df6',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    prep = runpy.run_path(str(ROOT / 'scripts/prepare-creatures.py'))
    reader = prep['td']
    with ZipFile(SOURCE) as archive:
        source = {name: archive.read(PREFIX + name) for name in PINS}
    assert {name: sha(data) for name, data in source.items()} == PINS
    raw = source['Monsters/mongbats_mongbat_lod2.grn']
    model, repair = prep['helper'].audit.repair_invalid_normals(raw)
    model, _ = prep['normalise_bind'](raw, model)
    model, omitted = prep['visible_vertices'](model)
    assert len(model['bones']) == 58 and len(model['points']) == 214
    atlas, = model['textures']
    texture = reader.png_from_tga(source['Maps/' + atlas])
    clips = {}
    for label, name in [('Idle', 'idle'), ('AirDeath', 'dieinair')]:
        data = source[f'Monsters/mongbats_mongbat_{name}.grn']
        motion = reader.parse(data, animations_only=True, scene_root_names=True)
        clips[label], _ = prep['normalise_bind'](data, motion)
    z = [point[2] for point in model['points']]
    output = ART / 'mongbat-air-death-donor.gltf'
    stats = reader.export_gltf(model, clips, texture, output, 1.2 * (max(z) - min(z)),
                               floor_sample_rate=120, preserve_vertical_clips=('AirDeath',),
                               measure_motion_bounds=True)
    assert stats['clips']['AirDeath']['matched_tracks'] == 55 and not stats['clips']['AirDeath']['missing']
    report = {
        'source_sha256': PINS,
        'gltf_sha256': sha(output.read_bytes()),
        'recipe_sha256': sha(Path(__file__).read_bytes()),
        'normal_repair': repair,
        'omitted_vertices': omitted,
        'stats': stats,
    }
    (ART / 'mongbat-air-death-donor.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('MONGBAT AIR DEATH DONOR:', stats['clips']['AirDeath']['matched_tracks'], 'matching tracks')


if __name__ == '__main__':
    main()
