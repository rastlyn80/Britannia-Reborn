"""Game-budget copies of pinned CC0 Poly Haven models.

The pinned originals in Viewer/Art/PolyHaven stay unmodified (their hashes are
verified by scripts/prepare-polyhaven.ps1). Heavy ones that appear hundreds of
times in the city get a reduced copy in Viewer/Art/Reduced/<id>/<id>.glb, made
by scripts/blender-objaverse-reduce.py (ground-centred, decimated, textures
capped at 1024 px); the manifest records the source file, its SHA-256 and the
output hash.

usage: python reduce-polyhaven.py ASSET_ID=TRIANGLES [...]
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'Viewer', 'Art', 'PolyHaven')
TARGET = os.path.join(ROOT, 'Viewer', 'Art', 'Reduced')
BLENDER = os.path.join(ROOT, '.tools', 'blender', 'blender-5.2.1-windows-x64', 'blender.exe')


def sha256(path):
    with open(path, 'rb') as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def main():
    os.makedirs(TARGET, exist_ok=True)
    manifest_path = os.path.join(TARGET, 'manifest.json')
    manifest = json.load(open(manifest_path, encoding='utf-8')) if os.path.exists(manifest_path) else {
        'notice': 'Reduced copies of CC0-1.0 Poly Haven models (https://polyhaven.com/license); originals pinned in Art/PolyHaven.',
        'assets': []}
    manifest['assets'] = [a for a in manifest['assets'] if a['id'] not in {arg.split('=')[0] for arg in sys.argv[1:]}]
    work = tempfile.mkdtemp(prefix='reduce-')
    for arg in sys.argv[1:]:
        asset_id, budget = arg.split('=')
        source = os.path.join(SOURCE, asset_id, asset_id + '_1k.gltf')
        output_dir = os.path.join(TARGET, asset_id)
        os.makedirs(output_dir, exist_ok=True)
        output = os.path.join(output_dir, asset_id + '.glb')
        report = os.path.join(work, asset_id + '.json')
        subprocess.run([BLENDER, '-b', '--factory-startup', '--python', os.path.join(ROOT, 'scripts', 'blender-objaverse-reduce.py'),
                        '--', source, output, budget, report], check=True, capture_output=True)
        stats = json.load(open(report, encoding='utf-8'))
        manifest['assets'].append({'id': asset_id, 'source': 'Art/PolyHaven/%s/%s_1k.gltf' % (asset_id, asset_id), 'sourceSha256': sha256(source),
                                   'license': 'CC0-1.0', 'page': 'https://polyhaven.com/a/' + asset_id, 'file': asset_id + '/' + asset_id + '.glb',
                                   'sha256': sha256(output), 'sourceTriangles': stats['source_triangles'], 'triangles': stats['triangles']})
        print('reduced', asset_id, stats['source_triangles'], '->', stats['triangles'])
    with open(manifest_path, 'w', encoding='utf-8', newline='\n') as handle:
        json.dump(manifest, handle, indent=2)


if __name__ == '__main__':
    main()
