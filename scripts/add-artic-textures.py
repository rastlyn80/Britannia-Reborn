"""Pin public-domain tapestry photographs from the Art Institute of Chicago.

Images of public-domain artworks in the AIC collection are released under CC0
(https://www.artic.edu/open-access/open-access-images). Each picture is fetched
through the museum's IIIF service at 1024 px wide, cropped to the hanging's
proportions, saved to Viewer/Art/Tapestries/<name>.jpg and recorded in its
manifest (artwork page, IIIF URL, crop and SHA-256 of the saved file).

usage: python add-artic-textures.py NAME=ARTWORK_ID[:ASPECT] [...]
       ASPECT is width/height of the hanging (default 0.7).
"""
import hashlib
import io
import json
import os
import sys
import urllib.error
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'Viewer', 'Art', 'Tapestries')
AGENT = {'User-Agent': 'BritanniaReborn-asset-sourcing/0.1', 'AIC-User-Agent': 'BritanniaReborn (asset sourcing)'}


def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=120) as response:
        return response.read()


def main():
    os.makedirs(TARGET, exist_ok=True)
    manifest_path = os.path.join(TARGET, 'manifest.json')
    manifest = json.load(open(manifest_path, encoding='utf-8')) if os.path.exists(manifest_path) else {
        'source': 'Art Institute of Chicago open access (CC0 images of public-domain artworks)',
        'licence': 'CC0-1.0', 'textures': {}}
    for arg in sys.argv[1:]:
        name, spec = arg.split('=')
        artwork, _, aspect = spec.partition(':')
        aspect = float(aspect or 0.7)
        info = json.loads(fetch(f'https://api.artic.edu/api/v1/artworks/{artwork}?fields=id,title,date_display,artist_display,image_id,is_public_domain'))['data']
        if not info.get('is_public_domain'):
            raise SystemExit(f'{artwork} is not public domain')
        # 843 px is the museum's standard public size; larger when it allows.
        for width in (1024, 843):
            iiif = f"https://www.artic.edu/iiif/2/{info['image_id']}/full/{width},/0/default.jpg"
            try:
                image = Image.open(io.BytesIO(fetch(iiif))).convert('RGB')
                break
            except urllib.error.HTTPError:
                image = None
        if image is None:
            raise SystemExit(f'{artwork}: no image served')
        # Trim the photograph's mount and margins (6% a side), then centre
        # crop to the hanging's proportions.
        w, h = image.size
        image = image.crop((int(w * 0.06), int(h * 0.06), int(w * 0.94), int(h * 0.94)))
        trim = (int(w * 0.06), int(h * 0.06))
        w, h = image.size
        if w / h > aspect:
            cw, ch = int(h * aspect), h
        else:
            cw, ch = w, int(w / aspect)
        box = ((w - cw) // 2, (h - ch) // 2, (w - cw) // 2 + cw, (h - ch) // 2 + ch)
        image = image.crop(box)
        box = (box[0] + trim[0], box[1] + trim[1], box[2] + trim[0], box[3] + trim[1])
        path = os.path.join(TARGET, name + '.jpg')
        image.save(path, quality=88)
        manifest['textures'][name] = {
            'artwork': int(artwork), 'title': info['title'], 'date': info.get('date_display'),
            'artist': info.get('artist_display'), 'page': f'https://www.artic.edu/artworks/{artwork}',
            'iiif': iiif, 'crop': list(box), 'crop_of': [w + 2 * trim[0], h + 2 * trim[1]], 'file': name + '.jpg',
            'sha256': hashlib.sha256(open(path, 'rb').read()).hexdigest()}
        print('pinned', name, info['title'])
    with open(manifest_path, 'w', encoding='utf-8', newline='\n') as handle:
        json.dump(manifest, handle, indent=1, ensure_ascii=False)
        handle.write('\n')
    with open(os.path.join(TARGET, 'NOTICE.md'), 'w', encoding='utf-8', newline='\n') as handle:
        handle.write('# Tapestry photographs\n\nPhotographs of public-domain tapestries from the Art Institute of Chicago, '
                     'released under CC0-1.0 (https://www.artic.edu/open-access/open-access-images). Cropped to each '
                     'hanging\'s proportions by scripts/add-artic-textures.py; manifest.json records each artwork page, '
                     'IIIF source, crop box and SHA-256. Credit is kept although CC0 does not require it.\n\n')
        for name, entry in sorted(manifest['textures'].items()):
            handle.write(f"- {name}.jpg: {entry['title']} ({entry['date']}), {entry['artist']}. {entry['page']}\n")


if __name__ == '__main__':
    main()
