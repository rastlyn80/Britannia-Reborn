"""Convert Tree Creator trees from owner-purchased .unitypackage files for local use.

The owner's licensed packages stay outside Git. This tool writes converted
meshes and their pre-baked atlases to Viewer/local-art/trees (ignored), plus a
catalogue the client reads when present; without it the client keeps the CC0
library trees. Only trees that ship their baked "<Name>_Textures" atlas are
converted, because the Tree Creator mesh UVs refer to that atlas layout.

Requires UnityPy (MIT, https://github.com/K0lb3/UnityPy) in an isolated Python
environment, for example:
    python -m venv .tools/unitypy
    .tools/unitypy/Scripts/python -m pip install UnityPy
usage:
    python import-unity-trees.py OUTPUT_ROOT PACKAGE [PACKAGE ...]
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


def convert(package, out_root, catalogue):
    files = package_files(package)
    prefabs = [p for p in files if p.endswith('.prefab') and '/Trees/' in p.replace('\\', '/')]
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
            folder = os.path.join(out_root, name)
            os.makedirs(folder, exist_ok=True)
            open(os.path.join(folder, name + '.obj'), 'w', encoding='utf-8', newline='\n').write(text)
            atlas_bytes = read(atlas)
            open(os.path.join(folder, 'diffuse.png'), 'wb').write(atlas_bytes)
            vertices = [tuple(map(float, line.split()[1:4])) for line in text.splitlines() if line.startswith('v ')]
            low = [min(v[i] for v in vertices) for i in range(3)]
            high = [max(v[i] for v in vertices) for i in range(3)]
            catalogue[name] = {
                'source': os.path.basename(package), 'prefab': prefab,
                'triangles': sum(1 for line in text.splitlines() if line.startswith('f ')),
                'bounds': [low, high], 'materials': materials,
                'atlasSha256': hashlib.sha256(atlas_bytes).hexdigest(),
            }
            print('converted', name, catalogue[name]['triangles'], 'triangles')


def main():
    out_root = os.path.abspath(sys.argv[1])
    os.makedirs(out_root, exist_ok=True)
    catalogue_path = os.path.join(out_root, 'catalog.json')
    catalogue = json.load(open(catalogue_path, encoding='utf-8')) if os.path.exists(catalogue_path) else {}
    for package in sys.argv[2:]:
        convert(package, out_root, catalogue)
    json.dump({'licence': 'Owner-purchased Unity Asset Store packages; local use only, never committed.', 'trees': catalogue},
              open(catalogue_path, 'w', encoding='utf-8'), indent=1)
    print('catalogue:', len(catalogue), 'trees ->', catalogue_path)


if __name__ == '__main__':
    main()
