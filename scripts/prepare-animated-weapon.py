"""Prepare the original halberd as an authored Animated Weapon presentation."""
import json
import math
from pathlib import Path
import runpy

TOOLS = runpy.run_path(str(Path(__file__).with_name('prepare-hydra.py')))
ROOT, BASE, SHA, checked = (TOOLS[key] for key in ('ROOT', 'BASE', 'SHA', 'checked'))
MANIFEST = Path(__file__).with_name('animated-weapon-inputs.json')
FAMILY = 'animated_weapon'
MOTIONS = {
    'Idle': (1.8, (0, .08, 0), (-.17, -.07, -.17), (0, .16, 0)),
    'Walk': (1.1, (0, .11, 0), (-.12, -.24, -.12), (-.14, .14, -.14)),
    'Run': (.7, (0, .18, 0), (-.24, -.36, -.24), (-.2, .2, -.2)),
    'Attack': (.86, (0, .21, 0), (-.7, .36, -.12), (-1.25, 1.25, 0)),
    'Hit': (.52, (0, -.15, 0), (-.15, .45, -.15), (0, -.42, 0)),
    'Fidget': (1.4, (0, .12, 0), (-.17, -.42, -.17), (0, .85, 0)),
    'Death': (.88, (0, -.42, -.91), (-.17, .64, 0), (0, .56, .8)),
}


def rotation(pitch, yaw):
    x, w = math.sin(pitch / 2), math.cos(pitch / 2)
    z, s = math.sin(yaw / 2), math.cos(yaw / 2)
    return [x * s, x * z, w * z, w * s]


def main():
    pins = json.loads(MANIFEST.read_text(encoding='utf-8'))
    members = {name: checked(BASE / 'animated-weapon-source' / name, digest)
               for name, digest in pins['files'].items()}
    for name, digest in pins['native'].items():
        checked(ROOT / 'Server/ModernUO' / name, digest)
    pipe = TOOLS['TOOLS']['pipeline']()
    raw = members['Client/Models/Others/Weapon_Halberd_Lod2.grn'].read_bytes()
    model = pipe.td.parse(raw, scene_root_names=True)
    joint = 'weapon_halberd'
    if (len(model['points']) != 37 or len(model['polygons']) != 70 or model['ties'] != [1]
            or model['weights'] or model['bones'][1]['name'] != joint or model['textures'] != ['weapons_512.tga']):
        raise ValueError('Unexpected archived halberd geometry or joint')
    model['weights'] = [[(0, 1.0)] for _ in model['points']]
    model, _ = pipe.normalise_bind(raw, model)
    atlas = pipe.td.png_from_tga(members['Client/Models/Maps/Weapons_512.tga'].read_bytes())
    clips = {}
    for name, (duration, lifts, pitches, yaws) in MOTIONS.items():
        times = [0., duration * .42, duration]
        clips[name] = {'bones': model['bones'], 'tracks': [{
            'name': joint,
            'translation': {'times': times, 'values': [[0., 0., .91 + lift] for lift in lifts]},
            'rotation': {'times': times, 'values': [rotation(pitch, yaw) for pitch, yaw in zip(pitches, yaws)]},
        }]}
    destination = ROOT / 'Viewer/local-art/creatures' / FAMILY
    destination.mkdir(parents=True, exist_ok=True)
    asset = destination / 'animated-weapon.gltf'
    height = max(point[2] for point in model['points']) - min(point[2] for point in model['points'])
    stats = pipe.td.export_gltf(model, clips, atlas, asset, height, preserve_hover_clips=list(clips))
    _, native = pipe.native_bodies()
    profile = pipe.body_profiles()[692]
    if profile != 'monster':
        raise ValueError(f'Unexpected Animated Weapon native action profile: {profile}')
    renderer = 'Presentation/SourcePreservingCreatureVisual.gd'
    ground = 'Presentation/SourceGroundLookup.gd'
    row = {
        'kind': FAMILY, 'family': FAMILY, 'status': 'prepared', 'profile': profile,
        'bodies': [{'body': 692, 'native': 'Animated Weapon', 'scale': [1., 1., 1.],
                    'native_profile': profile, 'native_sources': native[692]}],
        'native_constructor_hues': {'AnimatedWeapon': 0}, 'limb_support': 'plane',
        'presentation_script': 'res://' + renderer,
        'presentation_script_sha256': SHA(ROOT / 'Viewer' / renderer),
        'art_dependency_sha256': {'res://' + ground: SHA(ROOT / 'Viewer' / ground)},
        'assets': dict.fromkeys(('original', 'rounded', 'modern'), f'res://local-art/creatures/{FAMILY}/{asset.name}'),
        'asset_sha256': dict.fromkeys(('original', 'rounded', 'modern'), SHA(asset)),
        'stats': {name: stats for name in ('original', 'rounded', 'modern')},
        'clip_sources': {},
        'surface': 'Original weapon atlas with the shared creature hue material',
        'authored_clips': {name: 'Authored rigid halberd motion; the original body 692 motion is available only as sprite frames.' for name in clips},
        'source_interpretation': 'Original archived halberd and atlas are a visual match for the classic floating polearm. No exact body 692 mesh assignment was recovered.',
        'inputs': [{'member': name, 'sha256': digest} for name, digest in pins['files'].items()],
        'archive_sha256': pins['installer_sha256'],
    }
    pending = destination / 'preparation.pending'
    pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': SHA(MANIFEST)}, indent=2) + '\n')
    pending.replace(destination / 'preparation.json')
    print('ANIMATED WEAPON: original 70-triangle halberd, seven authored rigid motions')


if __name__ == '__main__':
    main()
