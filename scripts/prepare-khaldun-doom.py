"""Build the private source candidates for Spectral Armour and Restless Soul."""

import json
from pathlib import Path
import runpy

TOOLS = runpy.run_path(str(Path(__file__).with_name('prepare-hydra.py')))
ROOT, BASE, SHA, checked = (TOOLS[key] for key in ('ROOT', 'BASE', 'SHA', 'checked'))
MANIFEST = Path(__file__).with_name('khaldun-doom-inputs.json')
FAMILY = 'khaldun_doom'
ART = ROOT / 'Viewer/local-art/creatures' / FAMILY
TREATMENTS = ('original', 'rounded', 'modern')
GHOST = 'Client/Models/Humans/Player_Ghost_Lod2.grn'
GHOST_ATLAS = 'Client/Models/Maps/UT128_player_ghost.tga'
SWORD = 'Client/Models/Others/Weapon_Scimitar_Lod2.grn'
SWORD_ATLAS = 'Client/Models/Maps/Weapons_512.tga'
PEOPLE_ACTIONS = {0: 'Walk', 1: 'Walk', 2: 'Run', 3: 'Run', 4: 'Idle',
                  5: 'Fidget', 20: 'Hit', 21: 'Death'}


def ghost_model(pipeline, members, motions):
    raw = members[GHOST].read_bytes()
    mesh = pipeline.td.parse(raw, scene_root_names=True)
    assert (len(mesh['points']), len(mesh['polygons']), len(mesh['bones'])) == (208, 412, 40)
    assert mesh['textures'] == ['ut128_player_ghost.tga'] and not mesh['tracks']
    mesh, _ = pipeline.normalise_bind(raw, mesh)
    clips, omitted = {}, {}
    for name, path in motions.items():
        raw = members[path].read_bytes()
        animation = pipeline.td.parse(raw, animations_only=True, scene_root_names=True, scale_shear_tracks=True)
        animation, _ = pipeline.normalise_bind(raw, animation)
        clips[name], omitted[name] = pipeline.helper.match_animation(animation, mesh)
        assert len(clips[name]['tracks']) in (31, 33)
    return mesh, clips, omitted


def sword_model(pipeline, members):
    raw = members[SWORD].read_bytes()
    mesh = pipeline.td.parse(raw, scene_root_names=True)
    assert (len(mesh['points']), len(mesh['polygons']), mesh['ties']) == (48, 92, [1])
    assert mesh['textures'] == ['weapons_512.tga'] and not mesh['weights'] and not mesh['tracks']
    joint = mesh['bones'][1]['name']
    assert joint == 'weapon_scimitar'
    mesh['weights'] = [[(0, 1.0)] for _ in mesh['points']]
    mesh, _ = pipeline.normalise_bind(raw, mesh)
    donor = runpy.run_path(str(Path(__file__).with_name('prepare-animated-weapon.py')))
    clips = {}
    for name, (duration, lifts, pitches, yaws) in donor['MOTIONS'].items():
        times = [0.0, duration * 0.42, duration]
        clips[name] = {'bones': mesh['bones'], 'tracks': [{
            'name': joint,
            'translation': {'times': times, 'values': [[0.0, 0.0, 0.69 + 0.74 * lift] for lift in lifts]},
            'rotation': {'times': times, 'values': [donor['rotation'](pitch, yaw) for pitch, yaw in zip(pitches, yaws)]},
        }]}
    return mesh, clips


def presentation(kind, body, native_class, display_name, hue, body_type, actions,
                 pins, assets, stats, renderer, dependencies):
    paths = {name: f'res://local-art/creatures/{FAMILY}/{path.name}' for name, path in assets.items()}
    return {
        'kind': kind, 'family': FAMILY, 'status': 'prepared', 'profile': 'monster',
        'bodies': [{'body': body, 'native': display_name, 'native_profile': body_type.lower(),
                    'native_sources': [pins['native'][native_class]], 'scale': [1.0, 1.0, 1.0]}],
        'native_body_type': body_type,
        'classic_action_categories': {str(slot): actions.get(slot, '') for slot in range(35)},
        'native_constructor_hues': {native_class: hue}, 'limb_support': 'plane',
        'presentation_script': f'res://{renderer}', 'presentation_script_sha256': SHA(ROOT / 'Viewer' / renderer),
        'art_dependency_sha256': {f'res://{path}': SHA(ROOT / 'Viewer' / path) for path in dependencies},
        'assets': paths, 'asset_sha256': {name: SHA(path) for name, path in assets.items()},
        'stats': stats, 'archive_sha256': pins['installer_sha256'],
    }


def main():
    pins = json.loads(MANIFEST.read_text(encoding='utf-8'))
    dependencies = json.loads((ROOT / 'Server/dependencies.json').read_text(encoding='utf-8'))
    assert dependencies['modernuo']['revision'] == pins['server_pin']
    server = ROOT / 'Server/ModernUO'
    native_table = checked(server / 'Distribution/Data/bodyTable.cfg', pins['body_table_sha256'])
    native_rows = dict(line.split()[:2] for line in native_table.read_text().splitlines()
                       if line and line[0].isdigit())
    assert native_rows['637'] == 'Equipment' and '970' not in native_rows
    for record in pins['native'].values():
        checked(server / record['path'], record['sha256'])
    table = checked(BASE / 'model-table/Client/Models.txt', pins['model_table_sha256'])
    assignments = {int(fields[0]): fields for line in table.read_text(encoding='latin-1').splitlines()
                   if (fields := line.split()) and fields[0] in ('637', '970')}
    assert assignments[637][1:3] == ['4', '0'] and assignments[637][-1] == 'Weapon_Scimitar'
    assert assignments[970][1:3] == ['3', '400'] and assignments[970][-1] == 'player_ghost'
    members = {name: checked(BASE / 'khaldun-doom-source' / name, digest)
               for name, digest in pins['files'].items()}
    pipeline = TOOLS['TOOLS']['pipeline']()
    ART.mkdir(parents=True, exist_ok=True)

    sword, sword_clips = sword_model(pipeline, members)
    height = max(point[2] for point in sword['points']) - min(point[2] for point in sword['points'])
    sword_atlas = pipeline.td.png_from_tga(members[SWORD_ATLAS].read_bytes())
    asset = ART / 'spectral-scimitar.gltf'
    stats = pipeline.td.export_gltf(sword, sword_clips, sword_atlas, asset, height,
                                   preserve_hover_clips=tuple(sword_clips))
    plane = 'Presentation/SourceGroundLookup.gd'
    spectral = presentation('spectral_armour', 637, 'SpectralArmour', 'Spectral Armour', 0x8026,
                            'Equipment', PEOPLE_ACTIONS | {9: 'Attack'}, pins,
                            dict.fromkeys(TREATMENTS, asset), dict.fromkeys(TREATMENTS, stats),
                            'Presentation/SourcePreservingCreatureVisual.gd', (plane,))
    spectral.update(movement_mode='source_hover', clip_sources={},
                    authored_clips=dict.fromkeys(sword_clips, 'Authored motion adapted from the Animated Weapon recipe'),
                    inputs=[{'member': name, 'sha256': pins['files'][name]} for name in (SWORD, SWORD_ATLAS)])

    ghost, ghost_clips, omitted = ghost_model(pipeline, members, pins['ghost_motions'])
    atlas = pipeline.td.png_from_tga(members[GHOST_ATLAS].read_bytes())
    refined, refinement = pipeline.smooth.refine(ghost, levels=1, maximum=0.012, weight_smoothing=0.08)
    assets, stats = {}, {}
    for treatment, mesh in zip(TREATMENTS, (ghost, refined, refined)):
        assets[treatment] = ART / f'restless-soul-{treatment}.gltf'
        stats[treatment] = pipeline.td.export_gltf(mesh, ghost_clips, atlas, assets[treatment], 1.8,
                                                 floor_sample_rate=120)
    restless = presentation('restless_soul', 970, 'RestlessSoul', 'Restless Soul', 0x453,
                            'Empty', PEOPLE_ACTIONS | {10: 'Attack', 11: 'Attack2', 22: 'Death2'},
                            pins, assets, stats,
                            'Presentation/RestlessSoulVisual.gd',
                            (plane, 'Presentation/RestlessSoulSurface.gdshader',
                             'Presentation/SourcePreservingCreatureVisual.gd'))
    restless.update(clip_sources=pins['ghost_motions'], refinement=refinement,
                    omitted_animation_bones=omitted,
                    inputs=[{'member': name, 'sha256': pins['files'][name]} for name in members if name not in (SWORD, SWORD_ATLAS)])

    pending = ART / 'preparation.pending'
    pending.write_text(json.dumps({'models': [spectral, restless], 'input_manifest_sha256': SHA(MANIFEST)},
                                  indent=2) + '\n', encoding='utf-8')
    pending.replace(ART / 'preparation.json')
    print('KHALDUN AND DOOM: source scimitar and ghost candidates with 7 and 9 clips')


if __name__ == '__main__':
    main()
