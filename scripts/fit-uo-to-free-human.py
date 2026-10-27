"""Prepare a pinned CC0 MakeHuman base and privately refit two local UO garments.
Run with the repository's Blender, never with downloaded scripts.
"""
import bpy, json, math, hashlib, sys
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
import bmesh
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'work/free-human'
FEMALE='--female' in sys.argv
OUT=ROOT/('Viewer/local-art/free-human-female' if FEMALE else 'Viewer/local-art/free-human')
OUT.mkdir(parents=True,exist_ok=True)
MORPHS={'gender_female':1.0,'muscle_max':.15} if FEMALE else {'gender_male':1.0,'muscle_max':.35}
BASE_ONLY='--base-only' in sys.argv
EVIDENCE={'source':json.loads((SRC/'download-manifest.json').read_text()),'morphs':MORPHS,'method':'Semantic segment fit + source garment weight remap + nearest-surface collision correction','garments':{}}
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
# Avoid writing thumbnail caches outside the workspace.
bpy.context.preferences.filepaths.file_preview_type='NONE'
def load(path):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));return list(set(bpy.data.objects)-before)
def bake(ob):
 keys=ob.data.shape_keys
 if not keys:return
 basis=keys.key_blocks[0]
 positions=[v.co.copy() for v in basis.data]
 for key in keys.key_blocks[1:]:
  weight=MORPHS.get(key.name,0.)
  if weight:
   for i,v in enumerate(key.data):positions[i]+=(v.co-basis.data[i].co)*weight
 ob.shape_key_clear()
 for v,co in zip(ob.data.vertices,positions):v.co=co
 ob.data.update()
objs=load(SRC/'base_body_anim.glb')
rig=next(ob for ob in objs if ob.type=='ARMATURE')
body=next(ob for ob in objs if ob.type=='MESH' and ob.name=='Body')
meshes=[ob for ob in objs if ob.type=='MESH' and ob.vertex_groups]
for ob in list(objs):
 if ob.type=='MESH' and not ob.vertex_groups:bpy.data.objects.remove(ob,do_unlink=True)
for ob in meshes:bake(ob)
male_skin=SRC/'male-skin/young_lightskinned_male_diffuse.png'
if not male_skin.exists():raise RuntimeError('Extract the CC0 male skin from the recorded official system asset pack first')
for mat in body.data.materials:
 if mat.name.startswith('Skin'):
  tree=mat.node_tree;shader=next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED')
  image=tree.nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(str(male_skin))
  tree.links.new(image.outputs['Color'],shader.inputs['Base Color'])
  shader.inputs['Roughness'].default_value=.62
EVIDENCE['male_skin_source']=json.loads((SRC/'male-skin-source.json').read_text())
EVIDENCE['male_skin_sha256']=hashlib.sha256(male_skin.read_bytes()).hexdigest()
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks:tr.mute=True
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
# Joint sidecar describes global joint offsets in glTF coordinates.
joints=json.loads((SRC/'base_body.joints.json').read_text())
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for bone in rig.data.edit_bones:
 delta=Vector((0,0,0))
 for morph,w in MORPHS.items():
  v=joints['morphs'].get(morph,{}).get(bone.name,[0,0,0]);delta+=Vector((v[0],-v[2],v[1]))*w
 bone.use_connect=False;bone.head+=delta;bone.tail+=delta
bpy.ops.object.mode_set(mode='OBJECT')
for file in (['hair_short02.glb','clothing_briefs.glb','clothing_bra.glb'] if FEMALE else ['hair_short02.glb','clothing_briefs.glb']):
 imported=load(SRC/file)
 for ob in imported:
  if ob.type=='MESH' and ob.vertex_groups:
   bake(ob);world=ob.matrix_world.copy();ob.parent=rig;ob.matrix_world=world
   for mod in ob.modifiers:
    if mod.type=='ARMATURE':mod.object=rig
   meshes.append(ob)
 for ob in imported:
  if ob not in meshes:bpy.data.objects.remove(ob,do_unlink=True)
# Merge duplicated source animation actions into a deliberately small test set.
for tr in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(tr)
for label,name in [('Idle','idle'),('Walk','walk'),('Run','run')]:
 action=bpy.data.actions.get(name)
 if not action:raise RuntimeError('Missing '+name)
 action.name=label
 track=rig.animation_data.nla_tracks.new();track.name=label
 strip=track.strips.new(label,0,action);track.mute=True
rig.animation_data.action=None
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
# Target collision mesh in Blender's world Z-up space.
coords=[body.matrix_world@v.co for v in body.data.vertices]
body.data.calc_loop_triangles()
bvh=BVHTree.FromPolygons(coords,[t.vertices[:] for t in body.data.loop_triangles],all_triangles=True)
for ob in meshes:
 if ob.name.startswith(('Cloth_briefs','Cloth_bra')):
  for v in ob.data.vertices:
   p,n,face,dist=bvh.find_nearest(v.co)
   if p is not None and dist<.06 and (v.co-p).dot(n)<.009:
    v.co=p+n*.009
  for mat in ob.data.materials:
   node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
   for socket in ['Base Color','Alpha']:
    for link in list(node.inputs[socket].links):mat.node_tree.links.remove(link)
   node.inputs['Base Color'].default_value=(.035,.045,.06,1)
   node.inputs['Alpha'].default_value=1.
   node.inputs['Roughness'].default_value=.88
MAP={'bip01 pelvis':'pelvis','bip01 spine':'spine_01','bip01 spine1':'spine_02','bip01 spine2':'spine_03','bip01 neck':'neck_01','bip01 head':'head'}
for side,short in [('l','l'),('r','r')]:
 for old,new in [('clavicle','clavicle'),('upperarm','upperarm'),('forearm','lowerarm'),('hand','hand'),('thigh','thigh'),('calf','calf'),('foot','foot'),('toe0','ball')]:MAP['bip01 '+side+' '+old]=new+'_'+short
 MAP['bip01 '+side+' finger1']='index_01_'+short
NEXT={'pelvis':'spine_01','spine_01':'spine_02','spine_02':'spine_03','spine_03':'neck_01','neck_01':'head'}
for side in ['l','r']:
 for a,b in [('clavicle','upperarm'),('upperarm','lowerarm'),('lowerarm','hand'),('hand','index_01'),('thigh','calf'),('calf','foot'),('foot','ball')]:NEXT[a+'_'+side]=b+'_'+side
old_for_target={v:k for k,v in MAP.items()}
reference_objects=[] if BASE_ONLY else load(ROOT/'Viewer/local-art/third-dawn/human.gltf')
reference_rig=None if BASE_ONLY else next(o for o in reference_objects if o.type=='ARMATURE')
def fit_garment(slot):
 imported=load(ROOT/'Viewer/local-art/third-dawn'/('gear-'+slot+'.gltf'))
 gear=next(o for o in imported if o.type=='MESH' and len(o.vertex_groups)>0)
 oldrig=next(o for o in imported if o.type=='ARMATURE')
 source_offset=(oldrig.matrix_world@oldrig.data.bones['bip01 pelvis'].head_local)-(reference_rig.matrix_world@reference_rig.data.bones['bip01 pelvis'].head_local)
 oldgroups={vg.index:vg.name for vg in gear.vertex_groups}
 transforms={}
 for old,new in MAP.items():
  if old not in oldrig.data.bones:continue
  sb=oldrig.data.bones[old];tb=rig.data.bones[new]
  s0=oldrig.matrix_world@sb.head_local;t0=rig.matrix_world@tb.head_local
  child=NEXT.get(new);oldchild=old_for_target.get(child)
  if child and oldchild not in reference_rig.data.bones:
   raise RuntimeError('No authoritative source segment for '+old+' -> '+str(oldchild))
  if child and oldchild in reference_rig.data.bones:
   s1=reference_rig.matrix_world@reference_rig.data.bones[oldchild].head_local+source_offset;t1=rig.matrix_world@rig.data.bones[child].head_local
  else:s1=oldrig.matrix_world@sb.tail_local;t1=rig.matrix_world@tb.tail_local
  sd=s1-s0;td=t1-t0
  q=sd.normalized().rotation_difference(td.normalized())
  radial=1.06 if new.startswith(('spine','pelvis')) else 1.
  def transform(p,s0=s0,t0=t0,sd=sd,td=td,q=q,radial=radial):
   d=p-s0;axis=sd.normalized();along=d.dot(axis)
   return t0+q@(axis*along*(td.length/max(sd.length,1e-5))+(d-axis*along)*radial)
  transforms[old]=transform
 newcoords=[];newweights=[]
 for v in gear.data.vertices:
  p=gear.matrix_world@v.co;co=Vector((0,0,0));weights={};total=0.
  for g in v.groups:
   if g.weight<=1e-6:continue
   old=oldgroups[g.group]
   if old not in MAP or old not in transforms:raise RuntimeError('Unmapped weighted bone '+old)
   co+=transforms[old](p)*g.weight;total+=g.weight
   new=MAP[old];weights[new]=weights.get(new,0.)+g.weight
  newcoords.append(co/max(total,1e-9));newweights.append(weights)
 for mod in list(gear.modifiers):gear.modifiers.remove(mod)
 gear.parent=None;gear.matrix_parent_inverse=Matrix.Identity(4);gear.matrix_world=Matrix.Identity(4)
 for v,p in zip(gear.data.vertices,newcoords):v.co=p
 gear.vertex_groups.clear()
 for name in sorted({n for w in newweights for n in w}):gear.vertex_groups.new(name=name)
 for i,w in enumerate(newweights):
  for name,value in w.items():gear.vertex_groups[name].add([i],value,'REPLACE')
 bpy.context.view_layer.objects.active=gear
 sub=gear.modifiers.new('Garment fitting tessellation','SUBSURF');sub.subdivision_type='SIMPLE';sub.levels=2
 bpy.ops.object.modifier_apply(modifier=sub.name)
 corrected=0;max_push=0.
 for v in gear.data.vertices:
  v.co.z=min(v.co.z,rig.data.bones['neck_01'].head_local.z+.015)
  if slot=='robe':v.co.z=max(v.co.z,.045)
  p,n,face,dist=bvh.find_nearest(v.co)
  if p is not None:
   signed=(v.co-p).dot(n)
   if signed<.012 and dist<.16:
    delta=(.012-signed)*n;v.co+=delta;max_push=max(max_push,delta.length);corrected+=1
  if slot=='robe' and v.co.z<.72:
   # A long skirt cannot keep the original calf-heavy weights on a new rig.
   # Stabilize its lower hem at the pelvis, fading into the existing weights.
   amount=max(0.,min(1.,(.72-v.co.z)/.62))
   old=[(g.group,g.weight) for g in v.groups]
   for index,weight in old:gear.vertex_groups[index].add([v.index],weight*(1-amount),'REPLACE')
   pelvis=gear.vertex_groups['pelvis'];existing=next((w for i,w in old if i==pelvis.index),0.)
   pelvis.add([v.index],existing*(1-amount)+amount,'REPLACE')
 for poly in gear.data.polygons:poly.use_smooth=True
 for vertex in gear.data.vertices:
  pairs=sorted([(g.group,g.weight) for g in vertex.groups if g.weight>1e-7],key=lambda p:-p[1])[:4]
  total=sum(w for _,w in pairs)
  if total<=0:raise RuntimeError('Unweighted fitted garment vertex')
  for group in gear.vertex_groups:group.remove([vertex.index])
  for group,weight in pairs:gear.vertex_groups[group].add([vertex.index],weight/total,'REPLACE')
 bm=bmesh.new();bm.from_mesh(gear.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(gear.data);bm.free()
 gear.name='UO_'+slot
 gear.parent=rig
 mod=gear.modifiers.new('Target human skeleton','ARMATURE');mod.object=rig
 for ob in imported:
  if ob!=gear:bpy.data.objects.remove(ob,do_unlink=True)
 EVIDENCE['garments'][slot]=dict(vertices=len(gear.data.vertices),triangles=sum(len(p.vertices)-2 for p in gear.data.polygons),corrected_vertices=corrected,max_collision_push=max_push,mapped_bones=[vg.name for vg in gear.vertex_groups])
 return gear
gears={} if BASE_ONLY else {slot:fit_garment(slot) for slot in ['shirt','robe']}
# Covered body removal is deliberately garment-specific, not a universal solver.
def masked_body(slot):
 ob=body.copy();ob.data=body.data.copy();bpy.context.collection.objects.link(ob)
 names={g.index:g.name for g in ob.vertex_groups};hide=[]
 for v in ob.data.vertices:
  covered=sum(g.weight for g in v.groups if names[g.group].startswith(('pelvis','spine','clavicle','upperarm','lowerarm')+ (('thigh','calf') if slot=='robe' else ())))
  world=ob.matrix_world@v.co
  hide.append(covered>.45 and not (world.z>1.43 and abs(world.x)<.13))
 bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table()
 faces=[f for f in bm.faces if sum(hide[v.index] for v in f.verts)>=2]
 bmesh.ops.delete(bm,geom=faces,context='FACES');bm.to_mesh(ob.data);bm.free();return ob
# Preserve the actual target body height while fitting the same display scale.
height=max(p.z for p in coords)-min(p.z for p in coords)
display_height=1.72 if FEMALE else 1.8
rig.scale=Vector((1,1,1))*(display_height/height)
rig.name='FreeHumanRig'
for slot in (['base'] if BASE_ONLY else ['base','shirt','robe']):
 replacement=masked_body(slot) if slot!='base' else body
 selection=[rig]+[o for o in meshes if o!=body and not (slot!='base' and o.name.startswith('Cloth_briefs'))]+[replacement]+([gears[slot]] if slot!='base' else [])
 bpy.ops.object.select_all(action='DESELECT')
 for ob in selection:ob.select_set(True)
 bpy.context.view_layer.objects.active=rig
 for tr in rig.animation_data.nla_tracks:tr.mute=False
 path=OUT/('free-human'+('' if slot=='base' else '-'+slot)+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_morph=False,export_yup=True,export_texcoords=True,export_normals=True)
 for tr in rig.animation_data.nla_tracks:tr.mute=True
 if slot!='base':bpy.data.objects.remove(replacement,do_unlink=True)
 EVIDENCE.setdefault('outputs',{})[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
if not FEMALE:bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'fit.blend'))
EVIDENCE['sex']='female' if FEMALE else 'male'
EVIDENCE['height_scale']=display_height/height
if not BASE_ONLY:
 EVIDENCE['full_source_skeleton_sha256']=hashlib.sha256((ROOT/'Viewer/local-art/third-dawn/human.gltf').read_bytes()).hexdigest()
 EVIDENCE['source_zip_sha256']=hashlib.sha256((ROOT/'work/third-dawn/uotdb.zip').read_bytes()).hexdigest()
else:EVIDENCE['method']='CC0 base only: fixed sex-specific morph bake, matching joints, hair, modesty garments and source animations; no UO inputs'
EVIDENCE['recipe_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
EVIDENCE['uo_inputs']={('gear-'+s+'.gltf'):hashlib.sha256((ROOT/'Viewer/local-art/third-dawn'/('gear-'+s+'.gltf')).read_bytes()).hexdigest() for s in gears}
(OUT/'provenance.json').write_text(json.dumps(EVIDENCE,indent=2))
print('FREE HUMAN FIT',json.dumps(EVIDENCE['garments']))
