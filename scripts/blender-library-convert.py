"""Blender worker for scripts/import-owner-library.py (owner-licensed packs, local only).

usage: blender -b --factory-startup --python blender-library-convert.py -- JOBS.json REPORT.json
Each job: {"source": model .obj/.fbx, "output": .glb, "search": [texture dirs], "max_triangles": n}.
Imports one model, repairs missing/unbound textures by file-name search, sits the
model on the ground centred at the origin, decimates above the triangle budget,
caps textures at 1024 px and exports a self-contained GLB.
"""
import json
import os
import re
import sys

import bpy

IMAGE_EXT = ('.png', '.jpg', '.jpeg', '.tga', '.dds', '.bmp', '.tif', '.tiff')
NORMAL_HINT = re.compile(r'(_n|_nm|_nrm|_normal|normal|_norm|_bump|n)$', re.I)


def index_textures(folders):
    found = {}
    for folder in folders:
        for root, _, files in os.walk(folder):
            for name in files:
                if name.lower().endswith(IMAGE_EXT):
                    found.setdefault(os.path.splitext(name)[0].lower(), os.path.join(root, name))
    return found


def stem(path):
    return os.path.splitext(os.path.basename(path.replace('\\', '/')))[0].lower()


def diffuse_for(textures, names):
    """Best diffuse texture for material/model names: exact, then suffixed, then prefix."""
    for name in names:
        name = name.lower()
        for key in (name, name + '_d', name + '_diffuse', name + '_diff', name + '_col', name + '_color', name + '_albedo', name + '_basecolor', 'mat_' + name, name + '_1'):
            if key in textures:
                return textures[key]
    for name in names:
        name = name.lower()
        if len(name) < 3:
            continue
        options = [k for k in textures if k.startswith(name) and not NORMAL_HINT.search(k)]
        if options:
            return textures[sorted(options, key=len)[0]]
    return None


def normal_for(textures, diffuse):
    base = stem(diffuse)
    for suffix in ('_n', '_nm', '_nrm', '_normal', 'n', '_norm'):
        for candidate in (base + suffix, re.sub(r'(_d|_diffuse|_diff|_col)$', '', base) + suffix):
            if candidate in textures:
                return textures[candidate]
    return None


def load_image(path):
    image = bpy.data.images.load(path, check_existing=True)
    if max(image.size) > 1024:
        factor = 1024 / max(image.size)
        image.scale(max(1, int(image.size[0] * factor)), max(1, int(image.size[1] * factor)))
    return image


def repair_material(material, textures, model_stem):
    material.use_nodes = True
    tree = material.node_tree
    bsdf = next((n for n in tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is None:
        bsdf = tree.nodes.new('ShaderNodeBsdfPrincipled')
        output = next((n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL'), None) or tree.nodes.new('ShaderNodeOutputMaterial')
        tree.links.new(bsdf.outputs[0], output.inputs[0])
    base = bsdf.inputs['Base Color']
    image_node = base.links[0].from_node if base.is_linked and base.links[0].from_node.type == 'TEX_IMAGE' else None
    path = None
    if image_node and image_node.image:
        current = bpy.path.abspath(image_node.image.filepath)
        if os.path.exists(current) and image_node.image.size[0] > 0:
            path = current
        else:
            path = textures.get(stem(current))
    if path is None:
        path = diffuse_for(textures, [re.sub(r'\.\d+$', '', material.name), model_stem])
    if path is None:
        return False
    if image_node is None:
        image_node = tree.nodes.new('ShaderNodeTexImage')
        tree.links.new(image_node.outputs['Color'], base)
    image_node.image = load_image(path)
    if image_node.image.depth in (32, 64) and not bsdf.inputs['Alpha'].is_linked and not path.lower().endswith(('.jpg', '.jpeg')):
        tree.links.new(image_node.outputs['Alpha'], bsdf.inputs['Alpha'])
    normal = normal_for(textures, path)
    if normal and not bsdf.inputs['Normal'].is_linked:
        node = tree.nodes.new('ShaderNodeTexImage')
        node.image = load_image(normal)
        node.image.colorspace_settings.name = 'Non-Color'
        mapper = tree.nodes.new('ShaderNodeNormalMap')
        tree.links.new(node.outputs['Color'], mapper.inputs['Color'])
        tree.links.new(mapper.outputs['Normal'], bsdf.inputs['Normal'])
    bsdf.inputs['Metallic'].default_value = 0.0
    bsdf.inputs['Roughness'].default_value = max(0.6, bsdf.inputs['Roughness'].default_value)
    return True


def convert(job):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = job['source']
    if source.lower().endswith('.obj'):
        bpy.ops.wm.obj_import(filepath=source)
    elif source.lower().endswith('.fbx'):
        bpy.ops.import_scene.fbx(filepath=source)
    else:
        raise ValueError('unsupported ' + source)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    if not meshes:
        raise ValueError('no meshes')
    textures = index_textures([os.path.dirname(source)] + job.get('search', []))
    repaired = missing = 0
    for material in bpy.data.materials:
        if repair_material(material, textures, stem(source)):
            repaired += 1
        else:
            missing += 1
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    triangles = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    budget = job.get('max_triangles', 6000)
    if triangles > budget:
        ratio = budget / triangles
        for obj in meshes:
            modifier = obj.modifiers.new('budget', 'DECIMATE')
            modifier.ratio = ratio
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier='budget')
    low = [min(v.co[i] for o in meshes for v in o.data.vertices) for i in range(3)]
    high = [max(v.co[i] for o in meshes for v in o.data.vertices) for i in range(3)]
    shift = (-(low[0] + high[0]) / 2, -(low[1] + high[1]) / 2, -low[2])
    for obj in meshes:
        for vertex in obj.data.vertices:
            vertex.co.x += shift[0]
            vertex.co.y += shift[1]
            vertex.co.z += shift[2]
    final = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    os.makedirs(os.path.dirname(job['output']), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=job['output'], export_format='GLB', export_yup=True, export_apply=True,
                              export_animations=False, export_lights=False, export_cameras=False)
    return {'triangles': final, 'source_triangles': triangles, 'size': [high[i] - low[i] for i in range(3)],
            'materials_textured': repaired, 'materials_untextured': missing}


def main():
    args = sys.argv[sys.argv.index('--') + 1:]
    jobs = json.load(open(args[0], encoding='utf-8'))
    report = {}
    for job in jobs:
        try:
            report[job['output']] = convert(job)
        except Exception as error:  # report and continue with the next model
            report[job['output']] = {'error': str(error)}
    json.dump(report, open(args[1], 'w', encoding='utf-8'), indent=1)


main()
