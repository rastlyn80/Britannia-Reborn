"""Convert the water normal/foam texture from the owner's Tasharen Water package.

The owner's licensed package stays outside Git. This writes, into the ignored
Viewer/local-art/water folder, the tileable normal map (RGB) and foam mask
(alpha) of "Tasharen Water.psd" as two PNGs plus Godot import settings. The
water shader uses them when present and keeps its analytic ripples otherwise.

Requires Pillow (for the PSD) in an isolated Python environment.
usage:
    python import-unity-water.py OUTPUT_FOLDER "Tasharen Water.unitypackage"
"""
import hashlib
import io
import json
import os
import sys
import tarfile

from PIL import Image

SOURCE = 'Assets/Tasharen/Water/Tasharen Water.psd'
IMPORT_SETTINGS = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
mipmaps/generate=true
"""


def read(package, wanted):
    with tarfile.open(package, 'r:gz') as tar:
        names, assets = {}, {}
        for member in tar:
            guid, _, leaf = member.name.lstrip('./').partition('/')
            if leaf == 'pathname':
                names[tar.extractfile(member).read().decode('utf-8', 'replace').splitlines()[0].strip()] = guid
            elif leaf == 'asset':
                assets[guid] = member
        if wanted not in names:
            raise SystemExit(f'{wanted} not found in {package}')
        return tar.extractfile(assets[names[wanted]]).read()


def write(path, image):
    image.save(path)
    if not os.path.exists(path + '.import'):
        open(path + '.import', 'w', encoding='utf-8', newline='\n').write(IMPORT_SETTINGS)


def main():
    out, package = os.path.abspath(sys.argv[1]), sys.argv[2]
    os.makedirs(out, exist_ok=True)
    data = read(package, SOURCE)
    image = Image.open(io.BytesIO(data)).convert('RGBA')
    write(os.path.join(out, 'normal.png'), image.convert('RGB'))
    write(os.path.join(out, 'foam.png'), image.getchannel('A').convert('L'))
    json.dump({'licence': 'Owner-purchased Unity Asset Store package; local use only, never committed.',
               'source': os.path.basename(package), 'asset': SOURCE, 'sha256': hashlib.sha256(data).hexdigest()},
              open(os.path.join(out, 'catalog.json'), 'w', encoding='utf-8'), indent=1)
    print('converted water normal/foam', image.size)


if __name__ == '__main__':
    main()
