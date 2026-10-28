"""Blender worker for scripts/reduce-polyhaven.py --split.

usage: blender -b --factory-startup --python blender-split-variants.py -- SOURCE OUTPUT_PREFIX TRIANGLES REPORT.json
Poly Haven nature sets lay several variants out in a row in one file. Each
top-level object (with its children) becomes its own glTF, OUTPUT_PREFIX_N.gltf:
transforms applied, decimated to TRIANGLES, ground-centred, textures capped at
1024 px. All variants share one textures/ folder, so the set's maps are stored
and loaded on the GPU once, not once per variant.
"""
import json
import sys

import bpy
from mathutils import Matrix, Vector

source, prefix, budget, report = sys.argv[sys.argv.index('--') + 1:][:4]
budget = int(budget)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
roots = sorted([o for o in bpy.context.scene.objects if o.parent is None and (o.type == 'MESH' or any(c.type == 'MESH' for c in o.children_recursive))], key=lambda o: o.name)


def meshes_of(root):
    return [o for o in [root] + list(root.children_recursive) if o.type == 'MESH']


for image in bpy.data.images:
    if image.size[0] > 1024 or image.size[1] > 1024:
        scale = 1024 / max(image.size[0], image.size[1])
        image.scale(max(1, int(image.size[0] * scale)), max(1, int(image.size[1] * scale)))

variants = []
for index, root in enumerate(roots):
    bpy.ops.object.select_all(action='DESELECT')
    meshes = meshes_of(root)
    for obj in [root] + list(root.children_recursive):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    total = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        total += len(obj.data.loop_triangles)
    if total > budget:
        for obj in meshes:
            modifier = obj.modifiers.new('reduce', 'DECIMATE')
            modifier.ratio = budget / total
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier='reduce')
    low, high = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for obj in meshes:
        for v in obj.data.vertices:
            p = obj.matrix_world @ v.co
            low = Vector(map(min, low, p))
            high = Vector(map(max, high, p))
    shift = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for obj in meshes:
        obj.data.transform(Matrix.Translation(-shift))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.select_set(True)
    output = '%s_%d.gltf' % (prefix, index)
    bpy.ops.export_scene.gltf(filepath=output, export_format='GLTF_SEPARATE', export_texture_dir='textures', use_selection=True,
                              export_image_format='JPEG', export_jpeg_quality=88, export_draco_mesh_compression_enable=False)
    after = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        after += len(obj.data.loop_triangles)
    size = high - low
    variants.append({'name': root.name, 'file': output, 'source_triangles': total, 'triangles': after,
                     'size': [round(size.x, 3), round(size.z, 3), round(size.y, 3)]})

with open(report, 'w') as handle:
    json.dump({'variants': variants}, handle)
