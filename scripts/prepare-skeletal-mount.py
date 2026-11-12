"""Recover the body-793 mount and its own original skeletal motion."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
from shutil import copyfile
import subprocess
from tempfile import TemporaryDirectory


SCRIPTS = Path(__file__).resolve().parent
ROOT = next(parent for parent in SCRIPTS.parents if (parent / 'scripts/import-third-dawn.py').is_file())
ART = ROOT / 'Viewer/local-art/mounts'
SCENE = 'skeletal-mount-enhanced.scn'
MANIFEST = 'skeletal-mount.json'
GRANNY = runpy.run_path(str(ROOT / 'scripts/import-third-dawn.py'))
REFINE = runpy.run_path(str(ROOT / 'scripts/third-dawn-subdivide.py'))['refine']
CLIPS = {
    'Attack': ('attack1', 44, 'c4289068efbc25b344321bb764da205f2f70c3eb658c68e5a3310aabfe7f6f25'),
    'Attack2': ('attack2', 44, '077af0b7e0c228bf0280e1f691d024d5c82a4d30e72ce7a616798c9fd473c7d1'),
    'Death': ('die1', 44, '95b0bc982ccdc37c915a948b949cbde40b10aa51974d90797f61f0fe78aa8266'),
    'Eat': ('eat', 44, '7e961c6d8396bb27fa978ed0705d8937775c8230640f47687a6cad0f6fd0fda4'),
    'Fidget': ('fidget', 43, '55f6d2ee2775d217d55d3b6a6755a4c45c5d7900c0f36e4a542ce0a1f280490a'),
    'Fidget2': ('fidget2', 44, '7e961c6d8396bb27fa978ed0705d8937775c8230640f47687a6cad0f6fd0fda4'),
    'Hit': ('gethit', 43, 'e8313c2fd4a6107402afee893c4582bade029b122e0a5a8f65ca3df102e145cb'),
    'Idle': ('idle', 44, '7a77c826cfb0c7fbc09e09cddf1f8099a235d284ff906b20647ce433886ecf74'),
    'Run': ('run', 43, '7e751486c830b77360a2027d700ec83b53cd4f879cbb910e92b2d6d255d7b22d'),
    'Walk': ('walk', 44, '2cac49befdf736d77b824cbb39009e47031e8e65dfc6f5106c1d74be522605da'),
}


def verify(source, name, digest, members):
    data = (source / name).read_bytes()
    assert hashlib.sha256(data).hexdigest() == digest, name
    members[name] = digest
    return data


def rig_tracks(animation, model):
    model_names = {bone['name'] for bone in model['bones']}
    source_names = {bone['name'] for bone in animation['bones']}
    missing = model_names - source_names
    assert missing == {'npc_skeletal_mount'}
    weighted = {model['bones'][model['ties'][binding]]['name']
                for point in model['weights'] for binding, weight in point if weight > 0}
    assert not missing.intersection(weighted), 'A weighted joint is missing from the source motion'
    for bone in animation['bones']:
        if bone['name'] in model_names:
            assert animation['bones'][bone['parent']]['name'] in model_names, bone['name']
    kept = [track for track in animation['tracks'] if track['name'] in model_names]
    assert len(kept) == 33 and {track['name'] for track in kept} == model_names - missing
    excluded = sorted(source_names - model_names)
    # The removed motion tracks affect no node or ancestor in the actual mesh rig.
    # Retain the original animation skeleton and indices for source transforms.
    return dict(animation, tracks=kept), excluded


def export_sources(source, study):
    members = {}
    table = verify(source, 'models.txt', 'bac2a817c30773a0d3c1943b61555df4373a0eadbc1b10dfbc94f55d1615b97a', members)
    assert b'793\t2\t0\tFFFFFFFF\t0\t1.3\t1.3\t1.3\tskeletal_mount' in table
    model = GRANNY['parse'](verify(source, 'Animals/skeletal_mount_lod2.grn',
        '47a969bf63eb9e97e422e4d2c14106bf4a8e81ccae649d407f734ff0dfea0fe8', members))
    texture_name, = model['textures']
    assert texture_name == 'skeletal_mount_256.tga'
    texture = GRANNY['png_from_tga'](verify(source, f'Maps/{texture_name}',
        '0beb979b56a661cadd01f2c5a3ea3c68d12f6d1389d7101e4d5bd002a69d5eab', members))
    assert (len(model['points']), len(model['polygons']), len(model['bones'])) == (503, 858, 34)
    animations = {}
    excluded = {}
    for clip, (name, tracks, digest) in CLIPS.items():
        animation = GRANNY['parse'](verify(source, f'Animals/skeletal_mount_{name}.grn', digest, members))
        assert len(animation['tracks']) == tracks
        animations[clip], excluded[clip] = rig_tracks(animation, model)
    influences = 8 if max(map(len, model['weights'])) > 4 else 4
    refined, recipe = REFINE(model, levels=1, maximum=.017, max_influences=influences)
    assert refined['bones'] == model['bones']
    reports = {}
    for treatment, geometry in [('original', model), ('rounded', refined)]:
        output = study / f'body-793-{treatment}.gltf'
        result = GRANNY['export_gltf'](geometry, animations, texture, output, 1.65,
                                       measure_motion_bounds=True, max_influences=influences)
        reports[treatment] = dict(result, sha256=hashlib.sha256(output.read_bytes()).hexdigest())
        print(treatment, result['triangles'], 'triangles,', result['bones'], 'joints,', len(result['clips']), 'clips')
    receipt = {'body': 793, 'mount_item': 0x3ebb, 'members': members, 'scenes': reports, 'refinement': recipe,
               'unweighted_animation_only_branches': excluded,
               'aliases': {'Fidget2': 'Eat uses the identical source payload'},
               'native_classes': ['SkeletalMount', 'HellSteed', 'GrizzledMare', 'RedDeath']}
    (study / 'source.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')


def check_installed(destination=ART):
    manifest = json.loads((destination / MANIFEST).read_text(encoding='utf-8'))
    if manifest.get('schema') != 1 or set(manifest) != {'schema', SCENE}:
        raise ValueError('The local manifest does not identify the Skeletal Mount scene.')
    if hashlib.sha256((destination / SCENE).read_bytes()).hexdigest() != manifest[SCENE]:
        raise ValueError('The installed Skeletal Mount scene differs from its manifest.')


def install(study, destination=ART):
    destination.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=destination) as temporary:
        staged = Path(temporary)
        copyfile(study / SCENE, staged / SCENE)
        manifest = {'schema': 1, SCENE: hashlib.sha256((staged / SCENE).read_bytes()).hexdigest()}
        (staged / MANIFEST).write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        check_installed(staged)
        (staged / SCENE).replace(destination / SCENE)
        (staged / MANIFEST).replace(destination / MANIFEST)
    check_installed(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models', type=Path, help='Private Third Dawn Models directory')
    parser.add_argument('--study', type=Path, default=ROOT / 'work/creatures/skeletal-mount-bake')
    parser.add_argument('--godot', type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--install', action='store_true')
    mode.add_argument('--check-installed', action='store_true')
    args = parser.parse_args()
    if args.check_installed:
        check_installed()
        print('Skeletal Mount: installed source-rig scene verified.')
        return
    if args.models is None or not (args.models / 'models.txt').is_file():
        parser.error('Supply the private Models directory with --models.')
    godot = args.godot or next((ROOT / '.tools/godot').glob('*console.exe'), None)
    if godot is None or not godot.is_file():
        parser.error('Supply the local Godot 4 console executable with --godot.')
    source = args.models.resolve()
    study = args.study.resolve()
    if study.is_relative_to(source):
        parser.error('Use a separate output directory for the generated art.')
    study.mkdir(parents=True, exist_ok=True)
    export_sources(source, study)
    profile = study / 'godot-user'
    profile.mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile))
    engine = [str(godot.resolve()), '--headless', '--path', str(ROOT / 'Viewer')]
    for script, extra in [('check-skeletal-mount-source', []), ('bake-dark-horse-breath', ['--skeletal']),
                          ('bake-skeletal-mount-enhanced', [])]:
        subprocess.run([*engine, '--log-file', str(study / f'{script}.log'), '--script',
                        str(SCRIPTS / f'{script}.gd'), '--', f'--study={study.as_posix()}', *extra],
                       env=env, check=True, timeout=180)
    if args.install:
        install(study)
    print(f'Skeletal Mount: original-rig scene prepared in {study}.')


if __name__ == '__main__':
    main()
