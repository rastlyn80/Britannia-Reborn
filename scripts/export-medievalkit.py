"""Blender script: export selected static MedievalKit modules to glTF (one folder each).

usage: blender -b MedievalKit.blend --python scripts/export-medievalkit.py -- OUTPUT_DIR Module1,Module2,...
The owner then merges the folders into Viewer/Art/MedievalKit with shared textures
(see Viewer/Art/MedievalKit/manifest.json for the exported set and file hashes).
"""
import bpy, sys, os, json
args = sys.argv[sys.argv.index('--')+1:]
out, names = os.path.abspath(args[0]), args[1].split(',')
os.makedirs(out, exist_ok=True)
layer = bpy.context.view_layer
def include(lc):
    lc.exclude = False
    lc.hide_viewport = False
    for c in lc.children: include(c)
include(layer.layer_collection)
report = {}
for name in names:
    o = bpy.data.objects.get(name)
    if o is None: report[name] = 'missing'; continue
    for other in layer.objects: other.select_set(False)
    o.hide_set(False); o.hide_viewport = False
    o.select_set(True)
    layer.objects.active = o
    os.makedirs(os.path.join(out, name), exist_ok=True)
    saved = o.matrix_world.copy()
    o.matrix_world.translation = (0, 0, 0)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name, name + '.gltf'), export_format='GLTF_SEPARATE',
        export_texture_dir='textures', use_selection=True, export_apply=True, export_yup=True,
        export_animations=False, export_lights=False, export_cameras=False, export_extras=False)
    o.matrix_world = saved
    report[name] = {'triangles': sum(len(p.vertices) - 2 for p in o.data.polygons), 'dimensions': [round(v, 3) for v in o.dimensions]}
json.dump(report, open(os.path.join(out, 'export-report.json'), 'w'), indent=1)
