"""Convert selected small props from the owner's Dexsoft Medieval Village packs.

The owner's licensed packs stay outside Git. This copies the chosen OBJ meshes,
writes a trimmed MTL with only the materials they use, converts their TGA
albedo/normal textures to PNG with Godot import settings, and writes
OUTPUT_ROOT/props/catalog.json. The client uses these props when present and
keeps its CC0 or procedural models otherwise.

Requires Pillow in an isolated Python environment.
usage:
    python import-dexsoft-props.py OUTPUT_ROOT DEXSOFT_EXTRACTED_ROOT
DEXSOFT_EXTRACTED_ROOT holds the unpacked "Dexsoft ... Model Pack" folders.
"""
import hashlib
import json
import os
import re
import sys

from PIL import Image

# (OBJ model name, catalogue name, prop kind). Kinds are matched by the client.
PROPS = [
    ('f1_barrel', 'barrel_a', 'barrel'),
    ('f1_barrel2', 'barrel_b', 'barrel'),
    ('f1_crate', 'crate_a', 'crate'),
    ('f1_tub', 'tub_a', 'tub'),
    ('v3_haystack', 'haystack_a', 'haystack'),
]
MAX_TEXTURE = 1024
IMPORT_SETTINGS = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/normal_map={normal}
mipmaps/generate=true
"""


def find_models(root):
    found = {}
    for folder, _, files in os.walk(root):
        for name in files:
            if name.lower().endswith('.obj'):
                found.setdefault(name[:-4], os.path.join(folder, name))
    return found


def materials(path):
    """First definition of each material in an MTL: {name: [lines]}."""
    result, current = {}, None
    for line in open(path, encoding='utf-8', errors='replace'):
        line = line.strip()
        if line.startswith('newmtl '):
            name = line[7:].strip()
            current = None if name in result else name
            if current:
                result[current] = []
        elif current and line and not line.startswith('#'):
            result[current].append(line)
    return result


def texture_file(folder, stem):
    for name in os.listdir(folder):
        base, ext = os.path.splitext(name)
        if ext.lower() in ('.tga', '.png', '.jpg') and base.lower() == stem.lower():
            return os.path.join(folder, name)
    return None


def convert_texture(source, target, normal):
    image = Image.open(source).convert('RGB')
    if max(image.size) > MAX_TEXTURE:
        image.thumbnail((MAX_TEXTURE, MAX_TEXTURE))
    image.save(target)
    if not os.path.exists(target + '.import'):
        open(target + '.import', 'w', encoding='utf-8', newline='\n').write(IMPORT_SETTINGS.format(normal=1 if normal else 0))
    return hashlib.sha256(open(source, 'rb').read()).hexdigest()


def main():
    out = os.path.join(os.path.abspath(sys.argv[1]), 'props')
    models = find_models(sys.argv[2])
    catalog = {}
    for model, name, kind in PROPS:
        if model not in models:
            print('missing', model)
            continue
        obj = models[model]
        folder = os.path.dirname(obj)
        text = open(obj, encoding='utf-8', errors='replace').read()
        used = sorted(set(re.findall(r'^usemtl\s+(\S+)', text, re.M)))
        library = re.search(r'^mtllib\s+(.+)$', text, re.M)
        defined = materials(os.path.join(folder, library.group(1).strip())) if library else {}
        target = os.path.join(out, name)
        os.makedirs(target, exist_ok=True)
        mtl, hashes = [], {}
        for material in used:
            mtl.append('newmtl ' + material)
            mtl.append('Kd 1 1 1')
            albedo = next((l.split(None, 1)[1] for l in defined.get(material, []) if l.startswith('map_Kd ')), '')
            stem = os.path.splitext(albedo)[0]
            source = texture_file(folder, stem) if stem else None
            if source:
                png = material + '_albedo.png'
                hashes[os.path.basename(source)] = convert_texture(source, os.path.join(target, png), False)
                mtl.append('map_Kd ' + png)
                base = re.sub(r'_d$', '', stem, flags=re.I)
                normal = next((p for p in (texture_file(folder, base + s) for s in ('_N', 'N')) if p), None)
                if normal:
                    png = material + '_normal.png'
                    hashes[os.path.basename(normal)] = convert_texture(normal, os.path.join(target, png), True)
                    mtl.append('map_bump ' + png)
            mtl.append('')
        text = re.sub(r'^mtllib\s+.+$', 'mtllib ' + name + '.mtl', text, flags=re.M)
        open(os.path.join(target, name + '.obj'), 'w', encoding='utf-8', newline='\n').write(text)
        open(os.path.join(target, name + '.mtl'), 'w', encoding='utf-8', newline='\n').write('\n'.join(mtl))
        vertices = [tuple(map(float, l.split()[1:4])) for l in text.splitlines() if l.startswith('v ')]
        catalog[name] = {
            'kind': kind, 'source': os.path.relpath(obj, sys.argv[2]).replace('\\', '/'),
            'sha256': hashlib.sha256(open(obj, 'rb').read()).hexdigest(), 'textures': hashes,
            'triangles': sum(len(l.split()) - 3 for l in text.splitlines() if l.startswith('f ')),
            'bounds': [[min(v[i] for v in vertices) for i in range(3)], [max(v[i] for v in vertices) for i in range(3)]],
        }
        print('converted', name, catalog[name]['triangles'], 'triangles')
    json.dump({'licence': 'Owner-purchased Dexsoft model packs; local use only, never committed.', 'items': catalog},
              open(os.path.join(out, 'catalog.json'), 'w', encoding='utf-8'), indent=1)


if __name__ == '__main__':
    main()
