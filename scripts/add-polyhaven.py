"""Pin CC0 Poly Haven models (1k glTF) into Viewer/Art/PolyHaven and its manifest.

Downloads each model's glTF, binary and 1k textures from the official API,
checks the published MD5, records SHA-256 hashes; scripts/prepare-polyhaven.ps1
then verifies (or re-downloads) them like the existing pinned models.

usage: python add-polyhaven.py ASSET_ID [ASSET_ID ...]
       python add-polyhaven.py --texture ASSET_ID [...]   (1k colour/normal/roughness
       maps into Viewer/Art/Surfaces, verified by scripts/prepare-surfaces.ps1)
"""
import hashlib
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'Viewer', 'Art', 'PolyHaven')
AGENT = {'User-Agent': 'UltimaClone-local-world-viewer/0.1'}


def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=120) as response:
        return response.read()


def textures(ids):
    target = os.path.join(ROOT, 'Viewer', 'Art', 'Surfaces')
    manifest_path = os.path.join(target, 'manifest.json')
    manifest = json.load(open(manifest_path, encoding='utf-8'))
    known = {entry['id'] for entry in manifest['sets']}
    for asset_id in ids:
        if asset_id in known:
            print('already pinned', asset_id)
            continue
        info = json.loads(fetch(f'https://api.polyhaven.com/info/{asset_id}'))
        files = json.loads(fetch(f'https://api.polyhaven.com/files/{asset_id}'))
        maps = []
        for role, key in (('albedo', 'Diffuse'), ('normal', 'nor_gl'), ('roughness', 'Rough')):
            if key not in files:
                print('skip', asset_id, '(no', key, 'map)')
                maps = []
                break
            entry = files[key]['1k']['jpg']
            data = fetch(entry['url'])
            if hashlib.md5(data).hexdigest() != entry['md5']:
                raise SystemExit('MD5 mismatch for ' + entry['url'])
            name = os.path.basename(entry['url'])
            with open(os.path.join(target, name), 'wb') as handle:
                handle.write(data)
            maps.append({'role': role, 'file': name, 'url': entry['url'], 'sha256': hashlib.sha256(data).hexdigest(),
                         'sourceMd5': entry['md5'], 'bytes': len(data)})
        if not maps:
            continue
        size = [round(v / 1000.0, 2) for v in info.get('dimensions', [2000, 2000])[:2]]
        manifest['sets'].append({'id': asset_id, 'name': info.get('name', asset_id), 'source': f'https://polyhaven.com/a/{asset_id}',
                                 'license': 'CC0-1.0', 'licenseUrl': 'https://polyhaven.com/license',
                                 'authors': list(info.get('authors', {}).keys()), 'sizeMeters': size, 'maps': maps})
        print('pinned texture', asset_id, size)
        # Saved after every set, so an interrupted run keeps what it pinned.
        with open(manifest_path, 'w', encoding='utf-8', newline='\r\n') as handle:
            json.dump(manifest, handle, indent=1)
    # The surfaces manifest is kept with CRLF line endings.
    with open(manifest_path, 'w', encoding='utf-8', newline='\r\n') as handle:
        json.dump(manifest, handle, indent=1)


def main():
    if sys.argv[1:2] == ['--texture']:
        textures(sys.argv[2:])
        return
    manifest_path = os.path.join(TARGET, 'manifest.json')
    manifest = json.load(open(manifest_path, encoding='utf-8'))
    known = {asset['id'] for asset in manifest['assets']}
    for asset_id in sys.argv[1:]:
        if asset_id in known:
            print('already pinned', asset_id)
            continue
        info = json.loads(fetch(f'https://api.polyhaven.com/info/{asset_id}'))
        gltf = json.loads(fetch(f'https://api.polyhaven.com/files/{asset_id}'))['gltf']['1k']['gltf']
        sources = [(f'{asset_id}/{os.path.basename(gltf["url"])}', gltf['url'], gltf['md5'])]
        sources += [(f'{asset_id}/{path}', entry['url'], entry['md5']) for path, entry in gltf['include'].items()]
        files = []
        for path, url, md5 in sources:
            data = fetch(url)
            if hashlib.md5(data).hexdigest() != md5:
                raise SystemExit(f'MD5 mismatch for {url}')
            destination = os.path.join(TARGET, path)
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            open(destination, 'wb').write(data)
            files.append({'path': path, 'url': url, 'sourceMd5': md5, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
        manifest['assets'].append({'id': asset_id, 'name': info.get('name', asset_id), 'source': f'https://polyhaven.com/a/{asset_id}',
                                   'authors': list(info.get('authors', {}).keys()), 'polycount': info.get('polycount'), 'files': files})
        print('pinned', asset_id, len(files), 'files')
    with open(manifest_path, 'w', encoding='utf-8', newline='\n') as handle:
        json.dump(manifest, handle, indent=2)


if __name__ == '__main__':
    main()
