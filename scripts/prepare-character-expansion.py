"""Fit a second CC0 equipment/cosmetics batch to each fixed native human rig."""
import bpy,bmesh,json,hashlib,sys,importlib.util
from pathlib import Path
from collections import defaultdict
from mathutils import Vector,Matrix
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'))
from mhclo_inspect import parse_obj,parse_proxy
spec=importlib.util.spec_from_file_location('robe_motion',ROOT/'scripts/robe-motion.py');motion=importlib.util.module_from_spec(spec);spec.loader.exec_module(motion)
FEMALE='--female' in sys.argv
ART=ROOT/('Viewer/local-art/free-equipment-female' if FEMALE else 'Viewer/local-art/free-equipment')
OUT=ART/'expansion';OUT.mkdir(parents=True,exist_ok=True)
SRC=ROOT/'work/character-expansion/assets'
PIN=json.loads((ROOT/'scripts/character-expansion-inputs.json').read_text())
ITEMS={
 'skirt':('toigo_long_full_skirt','skirt'),
 'kilt':('toigo_long_full_skirt','kilt'),
 'gloves':('toigo_gloves_short','gloves'),
 'helmet':('grinsegold_corinthian_helmet','head'),
 'closed_helmet':('javherre_casco_caballero_templario_templar_knight_helmet','head'),
 'sword':('joepal_crude_sword','weapon'),
 'hammer':('culturalibre_war_hammer','weapon'),
 'staff':('culturalibre_magic_sceptre','weapon'),
 'beard_long':('rehmanpolanski_beard_viking','head'),
 'beard_short':('rehmanpolanski_beard_viking','short_beard'),
 'beard_goatee':('culturalibre_faun_beard','head'),
 'beard_moustache':('rehmanpolanski_moustache_viking','head'),
 'hair_bob':('bob02','hair'), 'hair_long':('long01','hair'),
 'hair_ponytail':('ponytail01','hair'), 'hair_afro':('afro01','hair')}
bpy.context.preferences.filepaths.file_preview_type='NONE'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ART/'equipment-base.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='Body')
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
for pose in rig.pose.bones:pose.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
# Recover hm08 identities through its unchanged UV topology, including seams.
raw=parse_obj(ROOT/'work/free-equipment/base.obj');uv_map=defaultdict(set)
for face,uvs in zip(raw['faces'],raw['face_uv']):
 for vi,ti in zip(face,uvs):
  if vi in raw['body_ids']:uv_map[tuple(round(x,5) for x in raw['uv'][ti])].add(vi)
keys=list(uv_map);tree=KDTree(len(keys))
for i,uv in enumerate(keys):tree.insert((uv[0],uv[1],0),i)
tree.balance();original_to_target={}
for poly in body.data.polygons:
 for li in poly.loop_indices:
  uv=body.data.uv_layers.active.data[li].uv;_,i,error=tree.find((uv.x,uv.y,0))
  assert error<1e-5 and len(uv_map[keys[i]])==1
  original_to_target[next(iter(uv_map[keys[i]]))]=body.data.loops[li].vertex_index
local=rig.matrix_world.inverted()@body.matrix_world
def oldco(p):return Vector((p[0]*.1,-p[2]*.1,p[1]*.1))
ids=list(original_to_target);oldtree=KDTree(len(ids))
for i,original in enumerate(ids):oldtree.insert(oldco(raw['points'][original]),i)
oldtree.balance();full=[];weights=[]
def vertex_weights(i):return {body.vertex_groups[g.group].name:g.weight for g in body.data.vertices[i].groups if g.weight>1e-7}
for i,p in enumerate(raw['points']):
 if i in original_to_target:
  vi=original_to_target[i];full.append(local@body.data.vertices[vi].co);weights.append(vertex_weights(vi))
 else:
  point=oldco(p);near=oldtree.find_n(point,3);factors=[1/max(d,.0001)**2 for _,_,d in near];total=sum(factors);co=point.copy();w={}
  for (old,index,d),factor in zip(near,factors):
   vi=original_to_target[ids[index]];k=factor/total;co+=(local@body.data.vertices[vi].co-old)*k
   for name,value in vertex_weights(vi).items():w[name]=w.get(name,0.)+k*value
  full.append(co);weights.append(w)
body.data.calc_loop_triangles()
bvh=BVHTree.FromPolygons([local@v.co for v in body.data.vertices],[tuple(t.vertices) for t in body.data.loop_triangles],all_triangles=True)
def material(folder,filename,cosmetic=False,metal=False):
 fields={}
 for line in (folder/filename).read_text(errors='replace').splitlines():
  fields_line=line.split()
  if fields_line and not fields_line[0].startswith(('#','//')):fields[fields_line[0]]=' '.join(fields_line[1:])
 mat=bpy.data.materials.new('Expansion_'+folder.name);mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;shader=nodes.get('Principled BSDF')
 shader.inputs['Roughness'].default_value=.78 if cosmetic else (.4 if metal else .85)
 shader.inputs['Metallic'].default_value=.6 if metal else 0.
 if 'diffuseTexture' in fields:
  tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(folder/fields['diffuseTexture']),check_existing=True);links.new(tex.outputs['Color'],shader.inputs['Base Color'])
  if cosmetic:
   links.new(tex.outputs['Alpha'],shader.inputs['Alpha']);mat.surface_render_method='DITHERED';mat.use_transparency_overlap=False
 else:shader.inputs['Base Color'].default_value=(.22,.16,.10,1)
 if metal and 'diffuseTexture' not in fields:shader.inputs['Base Color'].default_value=(.32,.35,.39,1)
 if folder.name=='toigo_long_full_skirt':
  # Use the project's traced CC0 woven linen instead of the floral print.
  for link in list(shader.inputs['Base Color'].links):links.remove(link)
  tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'Viewer/Art/MedievalKit/textures/Linen_Color.jpg'),check_existing=True);links.new(tex.outputs['Color'],shader.inputs['Base Color'])
  normal_image=nodes.new('ShaderNodeTexImage');normal_image.image=bpy.data.images.load(str(ROOT/'Viewer/Art/MedievalKit/textures/Fabric045_2K-JPG_NormalGL.jpg'),check_existing=True);normal_image.image.colorspace_settings.name='Non-Color';normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;links.new(normal_image.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],shader.inputs['Normal'])
 if 'normalmapTexture' in fields:
  tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(folder/fields['normalmapTexture']),check_existing=True);tex.image.colorspace_settings.name='Non-Color';normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],shader.inputs['Normal'])
 return mat
def export(path,ob,materials='EXPORT'):
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True,export_materials=materials)
 return hashlib.sha256(path.read_bytes()).hexdigest()
evidence={'female':FEMALE,'source_manifest_sha256':hashlib.sha256((ROOT/'scripts/character-expansion-inputs.json').read_bytes()).hexdigest(),'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'parts':{}}
for slot,(asset,kind) in ITEMS.items():
 record=PIN['assets'][asset];folder=SRC/record['folder'];proxy=parse_proxy(next(folder.glob('*.mhclo')));obj=parse_obj(folder/proxy['fields']['obj_file']);assert len(obj['points'])==len(proxy['rows'])
 scales={axis:abs(full[a][component]-full[b][component])/distance for axis,component in [('x',0),('y',2),('z',1)] for a,b,distance in [proxy['fields'][axis+'_scale']]}
 coords=[];skin=[]
 for refs,ws,offset in proxy['rows']:
  co=sum((full[i]*w for i,w in zip(refs,ws)),Vector())+Vector((offset[0]*scales['x'],-offset[2]*scales['z'],offset[1]*scales['y']))
  w={}
  for i,amount in zip(refs,ws):
   for name,value in weights[i].items():w[name]=w.get(name,0.)+amount*value
  if kind=='kilt':
   co.z=.95-(.95-co.z)*.48
   flare=max(0.,min(1.,(.95-co.z)/.4));co.x*=1.-.32*flare;co.y=-.015+(co.y+.015)*(1.-.25*flare)
   radial=Vector((co.x,co.y+.015,0.))
   if radial.length>1e-6:co+=radial.normalized()*.008
  chin=(rig.data.bones['head'].head_local.z+rig.data.bones['neck_01'].head_local.z)*.5
  if kind=='short_beard' and co.z<chin:co.z=chin-(chin-co.z)*.30
  if kind in ['head','hair','short_beard']:w={'head':1.}
  elif kind in ['skirt','kilt']:
   # Share the existing continuous garment panels; retain legs underneath.
   w=motion.control_weights(co) or {'pelvis':1.}
  if kind not in ['weapon','skirt','kilt']:
   point,normal,face,distance=bvh.find_nearest(co)
   clearance=.006 if kind=='gloves' else (.009 if kind=='hair' else .003)
   if point is not None and distance<.06 and (co-point).dot(normal)<clearance:co+=normal*(clearance-(co-point).dot(normal))
  chosen=sorted(((n,v) for n,v in w.items() if v>1e-7),key=lambda x:-x[1])[:4];total=sum(v for _,v in chosen);assert total>0
  coords.append(co);skin.append([(n,v/total) for n,v in chosen])
 if kind=='weapon':
  votes={side:sum(v for w in skin for n,v in w if n.endswith('_'+side) and n.startswith(('hand','index','middle','ring','pinky','thumb'))) for side in ['l','r']}
  source_hand='hand_'+max(votes,key=votes.get)
  # Rigid props retain the fitted author's grip, remapped to the native right hand.
  if source_hand!='hand_r':
   transform=rig.data.bones['hand_r'].matrix_local@rig.data.bones[source_hand].matrix_local.inverted();coords=[transform@co for co in coords]
  skin=[[('hand_r',1.)] for co in coords]
 mesh=bpy.data.meshes.new('Extra_'+slot);mesh.from_pydata(coords,[],obj['faces']);mesh.update();ob=bpy.data.objects.new('Extra_'+slot,mesh);bpy.context.collection.objects.link(ob)
 uv=mesh.uv_layers.new(name='UVMap')
 for poly,uvs in zip(mesh.polygons,obj['face_uv']):
  for li,ti in zip(poly.loop_indices,uvs):uv.data[li].uv=Vector(obj['uv'][ti])*(4. if kind in ['skirt','kilt'] else 1.)
  poly.use_smooth=kind!='weapon'
 for name in sorted({n for w in skin for n,v in w}):ob.vertex_groups.new(name=name)
 for i,w in enumerate(skin):
  for name,value in w:ob.vertex_groups[name].add([i],value,'REPLACE')
 ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4);mod=ob.modifiers.new('Shared human rig','ARMATURE');mod.object=rig
 mesh.materials.append(material(folder,proxy['fields']['material'],slot.startswith(('hair','beard')),slot in ['helmet','closed_helmet','sword','hammer','staff']))
 evidence['parts'][slot]={'asset':asset,'kind':kind,'vertices':len(coords),'sha256':export(OUT/(slot+'.glb'),ob),'licence':record['license'],'author':record['author']}
 bpy.data.objects.remove(ob,do_unlink=True)
# Orthogonal hand coverage avoids doubling every equipment combination in the
# base builder. Keep all existing UVs, binds and the rest of each body mask.
for bits in range(32):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ART/'runtime'/('body-mask-%02d.glb'%bits)));imported=set(bpy.data.objects)-before
 mask=next(o for o in imported if o.type=='MESH' and o.name.startswith('Body'))
 for mod in mask.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
 mask.parent=rig
 hand_ids={v.index for v in mask.data.vertices if sum(g.weight for g in v.groups if mask.vertex_groups[g.group].name.startswith(('hand','index','middle','ring','pinky','thumb')))>.5}
 bm=bmesh.new();bm.from_mesh(mask.data);bm.verts.ensure_lookup_table();remove=[f for f in bm.faces if any(v.index in hand_ids for v in f.verts)];bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(mask.data);bm.free()
 export(OUT/('body-mask-%02d-gloves.glb'%bits),mask,'NONE')
 for ob in imported:bpy.data.objects.remove(ob,do_unlink=True)
(OUT/'provenance.json').write_text(json.dumps(evidence,indent=2));print('EXPANSION READY',FEMALE,len(evidence['parts']),'pieces and 32 hand-coverage masks')
