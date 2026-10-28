"""Hedge section for the clipped hedges: keep only the foliage of the pinned
hedge_scan (its posts, tags and emissive bits are dropped) and cut a one-tile
section from the long run. Run on the reduced hedge_scan.glb:
  blender -b --python scripts/blender-hedge-section.py -- IN.glb OUT.glb
"""
import bpy, bmesh, sys
from mathutils import Vector
src, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.context.scene.objects):
    if o.type == 'MESH' and not all(m and m.name == 'model' for m in o.data.materials):
        bpy.data.objects.remove(o)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts = [v.co for v in o.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
size = hi - lo
axis = 0 if size.x > size.y else 1
mid = (lo[axis] + hi[axis]) / 2
half = min(size.x, size.y) * 1.2
bm = bmesh.new(); bm.from_mesh(o.data)
for sign in (1, -1):
    normal = Vector((0, 0, 0)); normal[axis] = sign
    co = Vector((0, 0, 0)); co[axis] = mid + sign * half
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=normal, clear_outer=True)
bm.to_mesh(o.data); bm.free()
o.data.update()
print('kept', len(o.data.polygons), 'faces; section', 2 * half, 'of', size[axis])
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=88, export_draco_mesh_compression_enable=False)
