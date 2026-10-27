"""Convert trees, bushes and small plants from owner-purchased .unitypackage files.

The owner's licensed packages stay outside Git. This tool writes converted
meshes and textures to Viewer/local-art (ignored), plus catalogues the client
reads when present; without them the client keeps the CC0 library models.
Tree Creator trees and bushes are converted only when they ship their baked
"<Name>_Textures" atlas, because their mesh UVs refer to that atlas layout.
Small plants (ferns, ground cover, grass) are mesh prefabs: their FBX and the
albedo texture of their material are resolved through Unity asset GUIDs.

Requires UnityPy (MIT, https://github.com/K0lb3/UnityPy) in an isolated Python
environment, for example:
    python -m venv .tools/unitypy
    .tools/unitypy/Scripts/python -m pip install UnityPy
usage:
    python import-unity-nature.py OUTPUT_ROOT PACKAGE [PACKAGE ...]
OUTPUT_ROOT receives trees/, bushes/ and plants/ with a catalog.json each.
"""
import hashlib
import json
import os
import re
import sys
import tarfile

import UnityPy


def package_files(package):
    """Return {asset path: tar member} for prefabs and baked tree atlases."""
    names, blobs = {}, {}
    with tarfile.open(package, 'r:gz') as tar:
        for member in tar:
            if not member.isfile():
                continue
            guid, _, leaf = member.name.lstrip('./').partition('/')
            if leaf == 'pathname':
                names[guid] = tar.extractfile(member).read().decode('utf-8', 'replace').splitlines()[0].strip()
            elif leaf == 'asset':
                blobs[guid] = member.name
    return {names[g]: blobs[g] for g in names if g in blobs}


def slug(text):
    return re.sub(r'[^a-z0-9]+', '_', text.lower()).strip('_')


def category(path):
    path = path.replace('\\', '/')
    if '/Bush' in path:
        return 'bushes'
    if '/Trees/' in path:
        return 'trees'
    return ''


def convert(package, out_root, catalogues):
    files = package_files(package)
    prefabs = [p for p in files if p.endswith('.prefab') and category(p)]
    with tarfile.open(package, 'r:gz') as tar:
        read = lambda path: tar.extractfile(tar.getmember(files[path])).read()
        for prefab in sorted(prefabs):
            stem = prefab[:-len('.prefab')]
            atlas = stem + '_Textures/diffuse.png'
            if atlas not in files:
                continue
            env = UnityPy.load(read(prefab))
            mesh, materials = None, []
            for obj in env.objects:
                if obj.type.name == 'Mesh' and mesh is None:
                    mesh = obj.read()
                elif obj.type.name == 'MeshRenderer':
                    renderer = obj.read()
                    for pointer in renderer.m_Materials:
                        try:
                            materials.append(pointer.read().m_Name)
                        except Exception:  # noqa: BLE001 - external material
                            materials.append('')
            if mesh is None:
                continue
            text = mesh.export()
            # Godot splits OBJ surfaces by material: tag each submesh group.
            def tag(match):
                index = int(match.group(1))
                name = materials[index] if index < len(materials) else ''
                return match.group(0) + '\nusemtl ' + ('leaves' if 'leaf' in name.lower() else 'bark')
            text = re.sub(r'^g Mesh_(\d+)$', tag, text, flags=re.M)
            name = slug(os.path.basename(stem))
            group = category(prefab)
            catalogue = catalogues.setdefault(group, {})
            folder = os.path.join(out_root, group, name)
            os.makedirs(folder, exist_ok=True)
            open(os.path.join(folder, name + '.obj'), 'w', encoding='utf-8', newline='\n').write(text)
            atlas_bytes = read(atlas)
            write_texture(os.path.join(folder, 'diffuse.png'), atlas_bytes)
            vertices = [tuple(map(float, line.split()[1:4])) for line in text.splitlines() if line.startswith('v ')]
            low = [min(v[i] for v in vertices) for i in range(3)]
            high = [max(v[i] for v in vertices) for i in range(3)]
            catalogue[name] = {
                'source': os.path.basename(package), 'prefab': prefab,
                'triangles': sum(1 for line in text.splitlines() if line.startswith('f ')),
                'bounds': [low, high], 'materials': materials,
                'atlasSha256': hashlib.sha256(atlas_bytes).hexdigest(),
            }
            print('converted', group, name, catalogue[name]['triangles'], 'triangles')


IMPORT_SETTINGS = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
mipmaps/generate=true
"""


def write_texture(path, data):
    """Write a foliage texture plus Godot import settings: mipmapped, VRAM compressed."""
    open(path, 'wb').write(data)
    if not os.path.exists(path + '.import'):
        open(path + '.import', 'w', encoding='utf-8', newline='\n').write(IMPORT_SETTINGS)


def guid_text(raw):
    return ''.join(f'{b & 0xF:x}{b >> 4:x}' for b in bytes(raw))


def plants(package, out_root, catalogues):
    """Mesh prefabs under grass/plant/groundcover/fern folders: FBX plus albedo."""
    from io import BytesIO
    from PIL import Image
    files = package_files(package)
    by_guid = {}
    with tarfile.open(package, 'r:gz') as tar:
        for member in tar:
            if member.isfile() and member.name.endswith('/pathname'):
                by_guid[member.name.split('/')[-2]] = tar.extractfile(member).read().decode('utf-8', 'replace').splitlines()[0].strip()
    wanted = [p for p in files if p.endswith('.prefab') and re.search(r'/(Grass|Plants|Groundcover|Ferns?)[^/]*/', p, re.I)]
    with tarfile.open(package, 'r:gz') as tar:
        read = lambda path: tar.extractfile(tar.getmember(files[path])).read()
        for prefab in sorted(wanted):
            env = UnityPy.load(read(prefab))
            externals = next(iter(env.files.values())).externals
            refs = [by_guid.get(guid_text(getattr(e, 'guid', b''))) for e in externals]
            mesh = next((r for r in refs if r and r.lower().endswith('.fbx') and r in files), None)
            material = next((r for r in refs if r and r.endswith('.mat') and r in files), None)
            if not mesh or not material:
                continue
            texture = None
            material_env = UnityPy.load(read(material))
            material_file = next(iter(material_env.files.values()))
            for obj in material_env.objects:
                if obj.type.name != 'Material':
                    continue
                for prop, texenv in obj.read().m_SavedProperties.m_TexEnvs:
                    if getattr(prop, 'name', str(prop)) == '_MainTex' and texenv.m_Texture.m_FileID > 0:
                        texture = by_guid.get(guid_text(material_file.externals[texenv.m_Texture.m_FileID - 1].guid))
            if not texture or texture not in files:
                continue
            name = slug(os.path.basename(prefab[:-len('.prefab')]))
            folder = os.path.join(out_root, 'plants', name)
            os.makedirs(folder, exist_ok=True)
            open(os.path.join(folder, name + '.fbx'), 'wb').write(read(mesh))
            png = BytesIO()
            Image.open(BytesIO(read(texture))).convert('RGBA').save(png, 'PNG')
            write_texture(os.path.join(folder, 'albedo.png'), png.getvalue())
            catalogues.setdefault('plants', {})[name] = {'source': os.path.basename(package), 'prefab': prefab, 'mesh': mesh, 'texture': texture}
            print('converted plants', name)


def main():
    out_root = os.path.abspath(sys.argv[1])
    catalogues = {}
    for group in ('trees', 'bushes', 'plants'):
        path = os.path.join(out_root, group, 'catalog.json')
        if os.path.exists(path):
            catalogues[group] = json.load(open(path, encoding='utf-8')).get('items', {})
    for package in sys.argv[2:]:
        convert(package, out_root, catalogues)
        plants(package, out_root, catalogues)
    for group, items in catalogues.items():
        os.makedirs(os.path.join(out_root, group), exist_ok=True)
        json.dump({'licence': 'Owner-purchased Unity Asset Store packages; local use only, never committed.', 'items': items},
                  open(os.path.join(out_root, group, 'catalog.json'), 'w', encoding='utf-8'), indent=1)
        print('catalogue', group, len(items))


if __name__ == '__main__':
    main()
