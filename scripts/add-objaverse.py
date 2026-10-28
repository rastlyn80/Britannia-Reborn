"""Pin free (CC0 / CC-BY 4.0) realistic models from the Objaverse 1.0 mirror of
Sketchfab into Viewer/Art/Objaverse, reduced to a game budget.

Each model's licence, author and page come from Sketchfab's public API and are
checked before download: only CC0 and CC-BY 4.0 are accepted. The GLB is fetched
from the public Hugging Face dataset (allenai/objaverse), hashed, then reduced
in Blender (scripts/blender-objaverse-reduce.py: ground-centred, decimated to
the triangle budget, textures capped) and the output hashed. The manifest keeps
source and output hashes plus attribution; NOTICE.md lists every CC-BY credit.

usage: python add-objaverse.py NAME=GLB_PATH[@TRIANGLES] [...]
       GLB_PATH as in object-paths.json, e.g. 000-085/3f3e5490...cf.glb
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'Viewer', 'Art', 'Objaverse')
BLENDER = os.path.join(ROOT, '.tools', 'blender', 'blender-5.2.1-windows-x64', 'blender.exe')
HF = 'https://huggingface.co/datasets/allenai/objaverse/resolve/main/glbs/'
AGENT = {'User-Agent': 'BritanniaReborn-asset-pinning/0.1'}
ACCEPTED = {'cc0': 'https://creativecommons.org/publicdomain/zero/1.0/', 'by': 'https://creativecommons.org/licenses/by/4.0/'}


def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=300) as response:
        return response.read()


def sha256(path):
    with open(path, 'rb') as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def write_notice(manifest):
    lines = ['# Objaverse / Sketchfab models', '',
             'Realistic models from Sketchfab, fetched from the public Objaverse 1.0 mirror',
             '(https://huggingface.co/datasets/allenai/objaverse) and reduced for the game by',
             'scripts/add-objaverse.py. Only CC0-1.0 and CC-BY-4.0 models are pinned; the manifest',
             'records each source page, author, licence, source and output SHA-256.', '',
             '## Attribution', '']
    for entry in sorted(manifest['assets'], key=lambda a: a['id']):
        lines.append('- "%s" by %s (%s), %s, %s. Reduced (decimated, textures resized) for this project.'
                     % (entry['title'], entry['author'], entry['page'], entry['license'], entry['licenseUrl']))
    with open(os.path.join(TARGET, 'NOTICE.md'), 'w', encoding='utf-8', newline='\n') as handle:
        handle.write('\n'.join(lines) + '\n')


def main():
    os.makedirs(TARGET, exist_ok=True)
    manifest_path = os.path.join(TARGET, 'manifest.json')
    manifest = json.load(open(manifest_path, encoding='utf-8')) if os.path.exists(manifest_path) else {'assets': []}
    known = {a['id'] for a in manifest['assets']}
    work = tempfile.mkdtemp(prefix='objaverse-')
    for arg in sys.argv[1:]:
        name, rest = arg.split('=', 1)
        path, _, budget = rest.partition('@')
        if name in known:
            print('already pinned', name)
            continue
        uid = os.path.splitext(os.path.basename(path))[0]
        try:
            info = json.loads(fetch('https://api.sketchfab.com/v3/models/' + uid))
        except Exception as error:  # removed or private on Sketchfab: licence unverifiable
            print('skip', name, 'licence lookup failed:', error)
            continue
        licence = (info.get('license') or {}).get('slug', '')
        if licence not in ACCEPTED:
            print('skip', name, 'licence', licence)
            continue
        source = os.path.join(work, uid + '.glb')
        with open(source, 'wb') as handle:
            handle.write(fetch(HF + path))
        output_dir = os.path.join(TARGET, name)
        os.makedirs(output_dir, exist_ok=True)
        output = os.path.join(output_dir, name + '.glb')
        report = os.path.join(work, uid + '.json')
        subprocess.run([BLENDER, '-b', '--factory-startup', '--python', os.path.join(ROOT, 'scripts', 'blender-objaverse-reduce.py'),
                        '--', source, output, budget or '30000', report], check=True, capture_output=True)
        stats = json.load(open(report, encoding='utf-8'))
        manifest['assets'].append({
            'id': name, 'title': info.get('name', uid), 'uid': uid,
            'page': 'https://sketchfab.com/3d-models/' + uid,
            'author': (info.get('user') or {}).get('displayName') or (info.get('user') or {}).get('username', ''),
            'license': 'CC0-1.0' if licence == 'cc0' else 'CC-BY-4.0', 'licenseUrl': ACCEPTED[licence],
            'sourceUrl': HF + path, 'sourceSha256': sha256(source), 'sourceTriangles': stats['source_triangles'],
            'file': name + '/' + name + '.glb', 'sha256': sha256(output), 'triangles': stats['triangles'],
            'size': stats['size'], 'processing': 'ground-centred, decimated to %s triangles, textures capped at 1024 px' % (budget or '30000')})
        known.add(name)
        print('pinned', name, licence, stats['source_triangles'], '->', stats['triangles'])
        with open(manifest_path, 'w', encoding='utf-8', newline='\n') as handle:
            json.dump(manifest, handle, indent=2)
        write_notice(manifest)


if __name__ == '__main__':
    main()
