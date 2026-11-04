from pathlib import Path
import hashlib
import json
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/third-dawn/uotdb.zip'
ART = ROOT / 'Viewer/local-art/creatures'
PREFIX = 'uotdb/uotd/Models/'
PINS = {
    'Monsters/harpies_harpy_lod2.grn': '1f5c4fd1ddc4901ebf74276bd035134079666d0830501ac0a766f162045fd487',
    'Monsters/harpies_harpy_idle.grn': '90e4be6b442a9807ff29ed4a330054d3b2cde56528ee4b17d4347427fecdc05e',
    'Monsters/harpies_harpy_dieinair.grn': '278515c82e56809b82888d1970672d65a4d0e8f4a9651ca7c5465d268a044931',
    'Maps/Harpies_Harpy_v04.tga': '81910ff493f055144ecf58d2b533572f7f76f89cd242b905439ba7d2edb475c0',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    prep = runpy.run_path(str(ROOT / 'scripts/prepare-creatures.py'))
    reader = prep['td']
    with ZipFile(SOURCE) as archive:
        source = {name: archive.read(PREFIX + name) for name in PINS}
    assert {name: sha(data) for name, data in source.items()} == PINS
    raw = source['Monsters/harpies_harpy_lod2.grn']
    model = reader.parse(raw, scene_root_names=True)
    assert len(model['bones']) == 34 and len(model['points']) == 190
    model, _ = prep['normalise_bind'](raw, model)
    model, omitted = prep['visible_vertices'](model)
    assert len(model['points']) == 186 and omitted == [113, 114, 134, 135]
    texture = reader.png_from_tga(source['Maps/Harpies_Harpy_v04.tga'])
    clips = {}
    for label, name in [('Idle', 'idle'), ('AirDeath', 'dieinair')]:
        data = source[f'Monsters/harpies_harpy_{name}.grn']
        motion = reader.parse(data, animations_only=True, scene_root_names=True)
        clips[label], _ = prep['normalise_bind'](data, motion)
    z = [point[2] for point in model['points']]
    output = ART / 'harpy-air-death-donor.gltf'
    stats = reader.export_gltf(model, clips, texture, output, 1.2 * (max(z) - min(z)),
                               floor_sample_rate=120, preserve_vertical_clips=('AirDeath',),
                               measure_motion_bounds=True)
    assert stats['clips']['AirDeath']['matched_tracks'] == 31 and not stats['clips']['AirDeath']['missing']
    report = {'source_sha256': PINS, 'gltf_sha256': sha(output.read_bytes()),
              'omitted_vertices': omitted, 'recipe_sha256': sha(Path(__file__).read_bytes()), 'stats': stats}
    (ART / 'harpy-air-death-donor.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('HARPY AIR DEATH:', stats['clips']['AirDeath'])


if __name__ == '__main__':
    main()
