"""Fit the selected pinned CC0 ponytail to the fixed male skeleton in Blender."""
import bpy,bmesh,json,hashlib,urllib.request
from pathlib import Path
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'work/character-polish/hair';SRC.mkdir(parents=True,exist_ok=True)
OUT=ROOT/'Viewer/local-art/free-equipment'
PINS={'ponytail01':'944efb6fb4bc223017697d4838ba27ec95c58866f2c98eac661e32f50467ebed'}
META=json.loads((ROOT/'work/free-human/hair.json').read_text())
EVIDENCE={}
bpy.context.preferences.filepaths.file_preview_type='NONE'
for style,pin in PINS.items():
 name=f'hair_{style}.glb';path=SRC/name
 url='https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/output/'+name
 if not path.exists():path.write_bytes(urllib.request.urlopen(url,timeout=60).read())
 assert hashlib.sha256(path.read_bytes()).hexdigest()==pin
 assert next(s for s in META['styles'] if s['id']==style)['license']=='CC0'
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'Viewer/local-art/free-human/free-human.glb'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 rig.animation_data_clear()
 for p in rig.pose.bones:p.matrix_basis.identity()
 bpy.context.view_layer.update()
 body=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='Body')
 body.data.calc_loop_triangles()
 bvh=BVHTree.FromPolygons([body.matrix_world@v.co for v in body.data.vertices],[tuple(t.vertices) for t in body.data.loop_triangles],all_triangles=True)
 for o in list(bpy.data.objects):
  if o!=rig:bpy.data.objects.remove(o,do_unlink=True)
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));imported=set(bpy.data.objects)-before
 bpy.context.view_layer.update()
 # glTF imports also create hidden custom bone-shape meshes. Select the
 # named skinned asset, never the first arbitrary mesh in an unordered set.
 hair=next(o for o in imported if o.type=='MESH' and o.vertex_groups and o.name.startswith('Hair_'+style))
 keys=hair.data.shape_keys
 if keys:
  basis=keys.key_blocks[0];positions=[v.co.copy() for v in basis.data]
  for key in keys.key_blocks[1:]:
   amount={'gender_male':1.,'muscle_max':.35}.get(key.name,0.)
   if amount:
    for i,v in enumerate(key.data):positions[i]+=(v.co-basis.data[i].co)*amount
  hair.shape_key_clear()
  for v,co in zip(hair.data.vertices,positions):v.co=co
 # Coarse scalp cards can cut through a curved head between their vertices.
 # Subdivide the scalp region before fitting; preserve UVs and deform weights.
 bm=bmesh.new();bm.from_mesh(hair.data)
 edges=[e for e in bm.edges if all((hair.matrix_world@v.co).z>1.55 for v in e.verts)]
 bmesh.ops.subdivide_edges(bm,edges=edges,cuts=2,use_grid_fill=True)
 bm.to_mesh(hair.data);bm.free()
 corrected=0;max_push=0.
 for v in hair.data.vertices:
  co=hair.matrix_world@v.co
  if co.z<1.42:continue
  point,normal,face,distance=bvh.find_nearest(co)
  if distance<.15 and (co-point).dot(normal)<.025:
   target=point+normal*.025;max_push=max(max_push,(target-co).length);v.co=hair.matrix_world.inverted()@target;corrected+=1
 world=hair.matrix_world.copy();hair.parent=rig;hair.matrix_world=world
 for mod in hair.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
 for o in imported:
  if o!=hair:bpy.data.objects.remove(o,do_unlink=True)
 rig.animation_data_clear()
 for p in rig.pose.bones:p.matrix_basis.identity()
 bpy.context.view_layer.update()
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);hair.select_set(True);bpy.context.view_layer.objects.active=rig
 target=OUT/name
 bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
 EVIDENCE[style]=dict(url=url,source_sha256=pin,licence='CC0-1.0',morphs={'gender_male':1.,'muscle_max':.35},scalp_subdivision_cuts=2,scalp_clearance_m=.025,corrected_vertices=corrected,max_push_m=max_push,output_sha256=hashlib.sha256(target.read_bytes()).hexdigest())
(OUT/'hair-provenance.json').write_text(json.dumps(EVIDENCE,indent=2))
print('CC0 ponytail prepared',json.dumps(EVIDENCE))
