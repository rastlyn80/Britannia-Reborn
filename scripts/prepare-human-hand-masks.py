"""Rebuild the existing hand masks without rebuilding accepted wardrobe meshes.

Match prepare-character-expansion.py: the glove overlaps the wrist transition,
including vertices with a small hand influence. GPU coverage independently
checks clothing opacity against the complete body, so masking cannot hide holes.
"""
import bpy,bmesh,json,hashlib
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[1]
for suffix in ['', '-female']:
 art=ROOT/('Viewer/local-art/free-equipment'+suffix);rows=[]
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(art/'equipment-base.glb'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear()
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 for bits in range(32):
  source=art/'runtime'/('body-mask-%02d.glb'%bits)
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(source));added=set(bpy.data.objects)-before
  ob=next(o for o in added if o.type=='MESH' and o.name.startswith('Body'))
  for modifier in ob.modifiers:
   if modifier.type=='ARMATURE':modifier.object=rig
  ob.parent=rig
  hands={v.index for v in ob.data.vertices if sum(g.weight for g in v.groups if ob.vertex_groups[g.group].name.startswith(('hand','index','middle','ring','pinky','thumb')))>.05}
  bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table()
  remove=[f for f in bm.faces if any(v.index in hands for v in f.verts)]
  bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(ob.data);bm.free()
  bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
  destination=art/'expansion'/('body-mask-%02d-gloves.glb'%bits)
  bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_materials='NONE')
  rows.append({'bits':bits,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'removed_faces':len(remove)})
  for extra in added:bpy.data.objects.remove(extra,do_unlink=True)
 (art/'expansion/hand-mask-provenance.json').write_text(json.dumps({'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'hand_weight_threshold':.05,'masks':rows},indent=2))
 print('HAND MASKS READY',art.name,len(rows),flush=True)
