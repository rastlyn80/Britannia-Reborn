"""Install the owner's redrawn shop/guild sign faces into the client (local only).

Copies outputs/item-catalog/signs/modern/<graphic>_<name>_flat.png (square sign
artwork) to the ignored Viewer/local-art/signs/<graphic>.png at 1024 px with
mipmapped Godot import settings and writes catalog.json. Presentation/LocalSignArt.gd
paints them on square hanging boards for both graphics of each sign pair; without
them the client keeps its plain boards. The artwork is a generated reinterpretation
of proprietary references (see the source folder's provenance.json): never commit it.

usage: python install-sign-art.py [SOURCE_DIR]
"""
import hashlib
import json
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'Viewer', 'local-art', 'signs')
IMPORT_SETTINGS = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
mipmaps/generate=true
"""


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'outputs', 'item-catalog', 'signs', 'modern')
    os.makedirs(TARGET, exist_ok=True)
    catalog = {'licence': 'Owner-supplied generated sign artwork from proprietary references; local use only, never committed.', 'signs': {}}
    for name in sorted(os.listdir(source)):
        match = re.match(r'^(\d+)_(.+)_flat\.png$', name)
        if not match:
            continue
        graphic, label = int(match.group(1)), match.group(2)
        image = Image.open(os.path.join(source, name)).convert('RGB')
        if image.width != image.height:
            side = min(image.size)
            image = image.crop(((image.width - side) // 2, (image.height - side) // 2, (image.width + side) // 2, (image.height + side) // 2))
        image = image.resize((1024, 1024), Image.LANCZOS)
        target = os.path.join(TARGET, f'{graphic}.png')
        image.save(target)
        with open(target + '.import', 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(IMPORT_SETTINGS)
        catalog['signs'][str(graphic)] = {'label': label.replace('_', ' '), 'source': name,
                                          'sha256': hashlib.sha256(open(os.path.join(source, name), 'rb').read()).hexdigest()}
    with open(os.path.join(TARGET, 'catalog.json'), 'w', encoding='utf-8', newline='\n') as handle:
        json.dump(catalog, handle, indent=1)
    print(f'installed {len(catalog["signs"])} sign faces -> {TARGET}')


if __name__ == '__main__':
    main()
