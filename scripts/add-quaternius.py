"""Copy selected CC0 Quaternius glTF models (and their buffers/textures) from the
pinned archives unpacked under work/assets into Viewer/Art/Quaternius/<Folder>,
recording SHA-256 hashes in Viewer/Art/Quaternius/manifest.json.

usage: python add-quaternius.py PACK_GLTF_DIR TARGET_FOLDER Model1,Model2,...
"""
import hashlib
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
source, folder, names = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
target = os.path.join(ROOT, 'Viewer', 'Art', 'Quaternius', folder)
manifest_path = os.path.join(ROOT, 'Viewer', 'Art', 'Quaternius', 'manifest.json')
manifest = json.load(open(manifest_path, encoding='utf-8'))
known = {entry['path'] for entry in manifest['files']}
for name in names:
    gltf = json.load(open(os.path.join(source, name + '.gltf'), encoding='utf-8'))
    files = [name + '.gltf'] + [b['uri'] for b in gltf.get('buffers', [])] + [i['uri'] for i in gltf.get('images', [])]
    for leaf in files:
        destination = os.path.join(target, leaf)
        if not os.path.exists(destination):
            shutil.copy(os.path.join(source, leaf), destination)
        path = folder + '/' + leaf
        if path not in known:
            digest = hashlib.sha256(open(destination, 'rb').read()).hexdigest().upper()
            manifest['files'].append({'path': path, 'sha256': digest})
            known.add(path)
            print('added', path)
manifest['files'].sort(key=lambda entry: entry['path'].lower())
json.dump(manifest, open(manifest_path, 'w', encoding='utf-8'), indent=2)
