"""Blender worker for scripts/add-objaverse.py.

usage: blender -b --factory-startup --python blender-objaverse-reduce.py -- SOURCE.glb OUTPUT.glb TRIANGLES REPORT.json
Imports one GLB, applies transforms, sits it on the ground centred at the
origin (Y up after export), decimates every mesh proportionally to the triangle
budget, caps textures at 1024 px and exports a self-contained GLB.
"""
import json
import sys

import bpy
from mathutils import Vector

source, output, budget, report = sys.argv[sys.argv.index('--') + 1:][:4]
budget = int(budget)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for obj in [o for o in bpy.context.scene.objects if o.type != 'MESH']:
    bpy.data.objects.remove(obj)


def triangles():
    total = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        total += len(obj.data.loop_triangles)
    return total


source_triangles = triangles()
if source_triangles > budget:
    ratio = budget / source_triangles
    for obj in meshes:
        modifier = obj.modifiers.new('reduce', 'DECIMATE')
        modifier.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier='reduce')

low = Vector((1e9, 1e9, 1e9))
high = Vector((-1e9, -1e9, -1e9))
for obj in meshes:
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        low = Vector((min(low.x, p.x), min(low.y, p.y), min(low.z, p.z)))
        high = Vector((max(high.x, p.x), max(high.y, p.y), max(high.z, p.z)))
shift = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
for obj in meshes:
    obj.data.transform(__import__('mathutils').Matrix.Translation(-shift))

for image in bpy.data.images:
    if image.size[0] > 1024 or image.size[1] > 1024:
        scale = 1024 / max(image.size[0], image.size[1])
        image.scale(max(1, int(image.size[0] * scale)), max(1, int(image.size[1] * scale)))

bpy.ops.export_scene.gltf(filepath=output, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=88, export_draco_mesh_compression_enable=False)
size = high - low
with open(report, 'w') as handle:
    json.dump({'source_triangles': source_triangles, 'triangles': triangles(), 'size': [round(size.x, 3), round(size.z, 3), round(size.y, 3)]}, handle)
