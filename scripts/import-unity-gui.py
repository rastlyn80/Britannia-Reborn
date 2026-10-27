"""Convert window art and fonts from the owner's "Necromancer GUI" Unity package.

The owner's licensed package stays outside Git. This writes the parchment
window, buttons, ribbons, seal, frames and the bundled Kingthings fonts into the
ignored Viewer/local-art/gui folder as PNG/TTF plus Godot import settings and a
catalog.json. The client's UiSkin uses them when present and draws its own
parchment style otherwise.

Requires Pillow (for TGA) in an isolated Python environment.
usage:
    python import-unity-gui.py OUTPUT_FOLDER "Necromancer GUI.unitypackage"
"""
import hashlib
import io
import json
import os
import sys
import tarfile

from PIL import Image

PREFIX = 'Assets/Necromancer GUI/controls/'
IMAGES = ['window', 'button', 'buttonOver', 'Label', 'Divider', 'GoldLeaf', 'WaxSeal', 'RibbonRed', 'RibbonBlue',
          'RibbonGreen', 'RibbonYellow', 'IconFrame', 'TextFieldNormal', 'TextFieldSelect', 'ScrollThumb',
          'WinScrollVert', 'Check', 'CheckBox', 'SliderThumb', 'Skull']
FONTS = ['Kingthings_Calligraphica.ttf', 'Kingthings_Calligraphica_Light.ttf', 'Kingthings_Calligraphica_Italic.ttf']
IMPORT_SETTINGS = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
"""


def read_all(package, wanted):
    with tarfile.open(package, 'r:gz') as tar:
        names, assets = {}, {}
        for member in tar:
            if not member.isfile():
                continue
            guid, _, leaf = member.name.lstrip('./').partition('/')
            if leaf == 'pathname':
                names[tar.extractfile(member).read().decode('utf-8', 'replace').splitlines()[0].strip()] = guid
            elif leaf == 'asset':
                assets[guid] = member
        return {path: tar.extractfile(assets[names[path]]).read() for path in wanted if path in names and names[path] in assets}


def main():
    out, package = os.path.abspath(sys.argv[1]), sys.argv[2]
    os.makedirs(out, exist_ok=True)
    wanted = [PREFIX + n + '.tga' for n in IMAGES] + [PREFIX + f for f in FONTS]
    data = read_all(package, wanted)
    catalog = {}
    for name in IMAGES:
        raw = data.get(PREFIX + name + '.tga')
        if raw is None:
            print('missing', name)
            continue
        image = Image.open(io.BytesIO(raw)).convert('RGBA')
        target = os.path.join(out, name + '.png')
        image.save(target)
        if not os.path.exists(target + '.import'):
            open(target + '.import', 'w', encoding='utf-8', newline='\n').write(IMPORT_SETTINGS)
        catalog[name + '.png'] = {'size': list(image.size), 'sha256': hashlib.sha256(raw).hexdigest()}
    for name in FONTS:
        raw = data.get(PREFIX + name)
        if raw is None:
            print('missing', name)
            continue
        open(os.path.join(out, name), 'wb').write(raw)
        catalog[name] = {'sha256': hashlib.sha256(raw).hexdigest()}
    json.dump({'licence': 'Owner-purchased Unity Asset Store package (art: Jason Wentzel; fonts: Kevin King); local use only, never committed.',
               'source': os.path.basename(package), 'items': catalog},
              open(os.path.join(out, 'catalog.json'), 'w', encoding='utf-8'), indent=1)
    print('converted', len(catalog), 'GUI files')


if __name__ == '__main__':
    main()
