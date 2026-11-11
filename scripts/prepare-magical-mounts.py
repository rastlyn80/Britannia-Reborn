# SPDX-License-Identifier: GPL-3.0-or-later
"""Build the optional ki-rin and unicorn scenes from privately extracted Third Dawn data."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
from shutil import copyfile
from subprocess import run
import sys


SCRIPTS = Path(__file__).resolve().parent
ROOT = next(parent for parent in SCRIPTS.parents if (parent / 'Viewer/project.godot').is_file())
FORMS = {
    132: ('kirin-late-modern.gltf', 'kirin-late-grounded.scn', 'kirin-ethereal-grounded.scn'),
    122: ('unicorn-modern.gltf', 'unicorn-grounded.scn', 'unicorn-ethereal-grounded.scn'),
}


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models', type=Path, required=True, help='Private Third Dawn Models directory')
    parser.add_argument('--study', type=Path, default=ROOT / 'work/magical-equines')
    parser.add_argument('--godot', type=Path)
    parser.add_argument('--install', action='store_true', help='Install the completed scenes in Viewer/local-art/mounts')
    args = parser.parse_args()
    godot = args.godot or next((ROOT / '.tools/godot').glob('*console.exe'), None)
    if godot is None or not godot.is_file():
        parser.error('Specify the local Godot 4 console executable with --godot.')
    if not all((args.models / folder).is_dir() for folder in ('Animals', 'Monsters', 'Maps')):
        parser.error('The private Models directory needs its Animals, Monsters and Maps subfolders.')
    study = args.study.resolve()
    study.mkdir(parents=True, exist_ok=True)
    for name, destination in [('prepare-kirin-source.py', study / '132'),
                              ('prepare-unicorn-source.py', study / '122'),
                              ('prepare-ethereal-equines.py', study)]:
        run([sys.executable, '-B', str(SCRIPTS / name), '--models', str(args.models.resolve()),
             '--output-dir', str(destination)], check=True)
    engine = [str(godot.resolve()), '--headless', '--path', str(ROOT / 'Viewer')]
    for body, (living_source, living_scene, _) in FORMS.items():
        folder = study / str(body)
        for input_file, output_file in [(living_source, living_scene), ('ethereal-original.gltf', 'ethereal-grounded.scn')]:
            run([*engine, '--log-file', str(folder / (Path(output_file).stem + '-bake.log')),
                 '--script', str(SCRIPTS / 'ground-magical-equine.gd'), '--',
                 f'--input={folder / input_file}', f'--output={folder / output_file}'], check=True)
    run([*engine, '--log-file', str(study / 'fit-actions.log'),
         '--script', str(SCRIPTS / 'bake-magical-equine-actions.gd'), '--', f'--study={study}'], check=True)
    destination = ROOT / 'Viewer/local-art/mounts' if args.install else study / 'prepared'
    destination.mkdir(parents=True, exist_ok=True)
    manifest = {'schema': 1}
    scenes = {}
    for body, (_, living_scene, spectral_scene) in FORMS.items():
        folder = study / str(body)
        report = json.loads((folder / 'enhanced-bake.json').read_text(encoding='utf-8'))
        living = folder / 'enhanced-original.scn'
        if report['body'] != body or report['sha256'] != digest(living):
            raise ValueError(f'The fitted scene for body {body} changed.')
        scenes.update({living_scene: living, spectral_scene: folder / 'ethereal-grounded.scn'})
    for name, path in scenes.items():
        if path.read_bytes()[:4] not in (b'RSRC', b'RSCC'):
            raise ValueError(f'Invalid local bundled scene: {path.name}')
        target = destination / name
        if path != target:
            pending = destination / (name + '.pending')
            copyfile(path, pending)
            pending.replace(target)
        manifest[name] = digest(path)
    pending_manifest = destination / 'magical-equines.pending'
    pending_manifest.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    pending_manifest.replace(destination / 'magical-equines.json')
    print(f'Prepared four original magical equine scenes in {destination}.')


if __name__ == '__main__':
    main()
