"""Recover the original Gargoyle airborne death for local rig comparison."""

import hashlib
import json
from pathlib import Path
import runpy
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "Viewer/local-art/creatures"
PREFIX = 'uotdb/uotd/Models/'
MODEL = 'Monsters/gargoyles_gargoyle_lod2.grn'
IDLE = 'Monsters/gargoyles_gargoyle_idle.grn'
AIR_DEATH = 'Monsters/gargoyles_gargoyle_dieinair.grn'
TEXTURE = 'Maps/Gargoyles_gargoyle.tga'
PINS = {
    MODEL: 'e3cab199481bec1006c85900f256f80ba63a3f2235816e5a86508b2e68ed8f4b',
    IDLE: 'a9a5dcb8151e75cdc6173ddb261b3a37fcf64453403b65b0833dfe945272178d',
    AIR_DEATH: 'cf6f2004ff41e8b1cd2b85fc7f6e3767023c9505109323b36e92ede0ce7dd5f6',
    TEXTURE: '041278f061fa9692fe2e0fd444906e27dbe3cad05d36dbc3e0fe7f86f73fc282',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    prep = runpy.run_path(str(ROOT / 'scripts/prepare-creatures.py'))
    reader = prep['td']
    with ZipFile(ROOT / 'work/third-dawn/uotdb.zip') as archive:
        source = {key: archive.read(PREFIX + key) for key in PINS}
    assert {key: sha(data) for key, data in source.items()} == PINS
    raw = source[MODEL]
    model = reader.parse(raw, scene_root_names=True)
    assert (len(model['bones']), len(model['points'])) == (55, 259)
    model, _ = prep['normalise_bind'](raw, model)
    model, omitted = prep['visible_vertices'](model)
    clips = {}
    for label, key in [('Idle', IDLE), ('AirDeath', AIR_DEATH)]:
        raw = source[key]
        motion = reader.parse(raw, animations_only=True, scene_root_names=True)
        clips[label], _ = prep['normalise_bind'](raw, motion)
    output = ART / 'gargoyle-air-death-donor.gltf'
    heights = [point[2] for point in model['points']]
    stats = reader.export_gltf(model, clips, reader.png_from_tga(source[TEXTURE]), output,
                               1.2 * (max(heights) - min(heights)), floor_sample_rate=120,
                               preserve_vertical_clips=('AirDeath',), measure_motion_bounds=True)
    assert stats['clips']['AirDeath']['matched_tracks'] == 54 and not stats['clips']['AirDeath']['missing']
    report = {'source_sha256': PINS, 'gltf_sha256': sha(output.read_bytes()),
              'omitted_vertices': omitted, 'recipe_sha256': sha(Path(__file__).read_bytes()), 'stats': stats}
    (ART / 'gargoyle-air-death-donor.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('GARGOYLE AIR DEATH:', stats['clips']['AirDeath'])


if __name__ == "__main__":
    main()
