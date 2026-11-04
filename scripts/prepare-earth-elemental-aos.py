"""Build the private Earth Elemental candidate from pinned Age of Shadows inputs."""

import argparse
import hashlib
import json
from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
RESEARCH = ROOT / 'work/third-dawn/late-source-research'
ART = ROOT / 'Viewer/local-art/creatures/earth-aos'
STEM = 'elementals_earth_elemental'
TREATMENTS = ('original', 'rounded', 'modern')
VISUAL = 'Presentation/SourceEarthElementalVisual.gd'
CLASSES = ['EarthElemental', 'SummonedEarthElemental', 'PlagueSpawn']
CLASSIC = {
    11: ('StoneGesture', [0, 1, 2, 3, 4], 5, 'afa4d8f4832115305d94b2c1c36609dca3c21dbff2ab13871841b81c9caf1406'),
    12: ('Assemble', [2, 4], 15, 'ecea2f0cccf3b3416d2b43ab7d19f84d6c47997e43810f2875b629a7df926cd0'),
}
TABLE_SHA = 'bac2a817c30773a0d3c1943b61555df4373a0eadbc1b10dfbc94f55d1615b97a'
CABINETS = {
    'client7.cab': ('models', '8180b7c2b7cb4ca6e868a3ff460e25c0e6aa710367b8d5487d2d455bfef29859'),
    'client10.cab': ('models/maps', '92e9b23c0c226a0d20af5402af7624b188d3bf6e1c4adb510c9d0575d2daa1d9'),
    'client11.cab': ('models/monsters', '307a6b91c4d5459080d1fe8a74ae4fe0b91dea8a21a2866ca91e7dc7ba92f1a8'),
}
MESH_SHA = '3a8c74365bbce5f8316400d20f7062ece52b7e95f103324241d14a4bf6e1452e'
ATLAS_SHA = '77657e1d8f6c1273199343f75fed78a5e45ffc954d0ad7d9befa1820e7014bf0'
MOTIONS = {
    'Idle': ('idle', '35762c0753f0ed982a0f219de562e59eed88a4658671f18f3b3db44c447ce34c'),
    'Walk': ('walk', 'e595d637a1b851eba91b5eb2ea34a0a7dc8b25ca838d2fa98dea9e92ca1750fd'),
    'Run': ('run', '7691717dc6fd507f177c71307828f777b489913d34b069effc03cb4a7506cfac'),
    'Attack': ('attack1', 'fa4dd841663cfe74de1197022582ef73b17dc5bcd4d282448a7f200300c8d53b'),
    'Hit': ('gethit', 'd439ad8e2e071c2e98aabcfebc808bebd1e099fe1f499ae1291130e109e95d05'),
    'Death': ('die1', '2305fae7a8d6e01747e185be9f86bacdec1009028446b9fca109cde2c7eb76cf'),
    'Fidget': ('fidget', '0b57772cef437a9e048a682449f57b8082fc3386b5306db40bf3fc75326d9fc2'),
}


def checked(path, expected):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError(f'Age of Shadows input differs from its pinned hash: {path.name}')
    return data


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def candidate():
    report = json.loads((ART / 'source.json').read_text(encoding='utf-8'))
    row, = report['models']
    if report['recipe_sha256'] != sha(Path(__file__)):
        raise ValueError('Rebuild Earth Elemental source geometry after a recipe change')
    bake = json.loads((ART / 'bake.json').read_text(encoding='utf-8'))
    if bake['recipe_sha256'] != sha(ROOT / 'scripts/bake-earth-elemental-aos.gd'):
        raise ValueError('Rebake Earth Elemental gestures after a recipe change')
    for label in TREATMENTS:
        gltf = ART / f'{label}.gltf'
        scene = ART / f'{label}.scn'
        if sha(gltf) != row['asset_sha256'][label] or sha(gltf) != bake['assets'][label]['source']:
            raise ValueError(f'Unverified Earth Elemental {label} glTF')
        checked(scene, bake['assets'][label]['scene'])
    for filename, digest in row['art_dependency_sha256'].items():
        checked(ART.parent / filename, digest)
    ledger = json.loads((ROOT / 'outputs/creatures/actions.json').read_text(encoding='utf-8'))
    references = {}
    for slot, (_, directions, frames, expected) in CLASSIC.items():
        source, = (item for item in ledger['original_mul_group_candidates']
                   if (item['body'], item['group']) == (14, slot) and 'matching_classic_route' in item)
        records = source['directions']
        hashes = ''.join(item['payload_sha256'] for item in records).encode('ascii')
        if (source['archive'], source['graphic'], source['mobtype_prefers_uop'],
                [item['direction'] for item in records], {item['frames'] for item in records},
                hashlib.sha256(hashes).hexdigest()) != ('anim.mul', 14, False, directions, {frames}, expected):
            raise ValueError(f'Earth Elemental Classic reference changed for slot {slot}')
        references[str(slot)] = dict(body=14, group=slot, archive='anim.mul', directions=directions,
                                     frames=frames, directional_payload_sha256=expected)
    row.update(
        family='earth_elemental_aos',
        presentation_script=f'res://{VISUAL}',
        presentation_script_sha256=sha(ROOT / 'Viewer' / VISUAL),
        classic_action_categories={str(slot): recipe[0] for slot, recipe in CLASSIC.items()},
        authored_action_reference=references['11'],
        classic_motion_references=references,
        authored_action_scene_sha256={label: bake['assets'][label]['scene'] for label in TREATMENTS},
        authored_replacements={
            'StoneGesture': 'One-shot reuse of the recovered Age of Shadows fidget for the Classic arm gesture',
            'Assemble': 'Authored emergence timing and lowering using the reversed Age of Shadows collapse',
        },
        native_constructor_hue_ranges={
            'EarthElemental': [[0, 0]], 'SummonedEarthElemental': [[0, 0]], 'PlagueSpawn': [[0x11, 0x1f]],
        },
        assets={label: f'res://local-art/creatures/earth-aos/{label}.scn' for label in TREATMENTS},
    )
    row['asset_sha256'] = row['authored_action_scene_sha256']
    return row


def prepare():
    pipeline = runpy.run_path(str(ROOT / 'scripts/prepare-creatures.py'))
    td = pipeline['td']
    source = RESEARCH / 'uoaos-source/Models'
    inputs = {}

    def member(path, digest):
        data = checked(source / path, digest)
        inputs['Models/' + path] = digest
        return data

    for cabinet, (_, digest) in CABINETS.items():
        checked(RESEARCH / 'uoaos-cabinets' / cabinet, digest)
    table = pipeline['table_rows'](member('models.txt', TABLE_SHA))
    identity, = (row for row in table if row['body'] == 14)
    if identity['stem'] != STEM or identity['scale'] != [1.3] * 3:
        raise ValueError('Unexpected Earth Elemental model-table assignment')

    raw = member(f'Monsters/{STEM}_lod2.grn', MESH_SHA)
    model = td.parse(raw, scene_root_names=True)
    model, bind_repair = pipeline['normalise_bind'](raw, model)
    model, _ = pipeline['visible_vertices'](model)
    if (len(model['points']), len(model['polygons']), len(model['bones'])) != (235, 410, 21):
        raise ValueError('Unexpected Earth Elemental source geometry or skeleton')
    texture, = set(model['textures'])
    atlas = td.png_from_tga(member(f'Maps/{texture}', ATLAS_SHA))

    clips, omitted, clip_sources = {}, {}, {}
    for label, (suffix, digest) in MOTIONS.items():
        path = f'Monsters/{STEM}_{suffix}.grn'
        raw = member(path, digest)
        motion = td.parse(raw, animations_only=True, scene_root_names=True, scale_shear_tracks=True)
        motion, _ = pipeline['normalise_bind'](raw, motion)
        clips[label], omitted[label] = pipeline['helper'].match_animation(motion, model)
        if len(clips[label]['tracks']) != 20:
            raise ValueError(f'Unexpected matched Earth Elemental tracks for {label}')
        clip_sources[label] = 'Models/' + path

    rounded, refinement = pipeline['smooth'].refine(model, levels=2, maximum=0.025, weight_smoothing=0.0)
    ART.mkdir(parents=True, exist_ok=True)
    stats, paths = {}, {}
    for label, geometry in [('original', model), ('rounded', rounded)]:
        paths[label] = ART / f'{label}.gltf'
        source_height = max(p[2] for p in geometry['points']) - min(p[2] for p in geometry['points'])
        height = identity['scale'][2] * source_height
        stats[label] = td.export_gltf(geometry, clips, atlas, paths[label], height,
                                     floor_sample_rate=120, measure_motion_bounds=True)
    paths['modern'] = ART / 'modern.gltf'
    row = dict(kind=STEM, family='elementals', status='prepared', profile='monster',
               bodies=[dict(identity, native_profile='monster', native_sources=pipeline['native_bodies']()[1][14])],
               inputs=[{'member': name, 'sha256': digest} for name, digest in inputs.items()],
               stats=stats, clip_sources=clip_sources, omitted_animation_bones=omitted,
               bind_scale_normalisation=bind_repair, refinement=refinement)
    minerals = pipeline['minerals']
    modern = minerals.apply(STEM, json.loads(paths['rounded'].read_text()), row, ROOT, ART.parent)
    paths['modern'].write_text(json.dumps(modern, separators=(',', ':')), encoding='utf-8')
    row['assets'] = {label: f'res://local-art/creatures/earth-aos/{path.name}' for label, path in paths.items()}
    row['asset_sha256'] = {label: hashlib.sha256(path.read_bytes()).hexdigest() for label, path in paths.items()}
    report = {
        'models': [row],
        'recipe_sha256': sha(Path(__file__)),
        'source_url': 'https://zuluarchive.com/static/files/uoaos.zip',
        'cabinets': [{'member': f'uoaos/UOTD/{folder}/{cabinet}', 'sha256': digest}
                     for cabinet, (folder, digest) in CABINETS.items()],
        'scope': 'Private source preparation. Derived assets remain local.',
    }
    (ART / 'source.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('EARTH ELEMENTAL: 235 source points, 21 joints, seven recovered clips, 6,560 refined triangles')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', action='store_true', help='Verify the bake and write the client test entry')
    if parser.parse_args().candidate:
        (ART / 'candidate.json').write_text(json.dumps(candidate(), indent=2) + '\n', encoding='utf-8')
    else:
        prepare()
