"""Build traceable category equipment on the existing male/female human skeleton.

Inputs are hash pinned. Source meshes/materials are retained for rigid props;
tailored armour, jewellery, bows and cloth variants are authored here.
Generated game-ready art is deliberately local and ignored by Git.
"""
import bpy,bmesh,json,sys,math,hashlib,importlib.util
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];FEMALE='--female' in sys.argv
ART=ROOT/('Viewer/local-art/free-equipment-female' if FEMALE else 'Viewer/local-art/free-equipment')
OUT=ART/'coverage';OUT.mkdir(exist_ok=True)
PINS=json.loads((ROOT/'scripts/human-coverage-inputs.json').read_text())
RECIPES=json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets']
PROPS_ONLY='--props-only' in sys.argv
ARMOUR_ONLY='--armour-only' in sys.argv
TAILORING_ONLY='--tailoring-only' in sys.argv
if TAILORING_ONLY:RECIPES=[r for r in RECIPES if r['kind']=='tailoring']
if ARMOUR_ONLY:RECIPES=[r for r in RECIPES if r['kind']=='shell']
if PROPS_ONLY:RECIPES=[r for r in RECIPES if r['kind']=='prop']
for file,digest in PINS['foundation']['files'].items():assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==digest,file
for file,digest in PINS['material_files'].items():assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==digest,file
for record in PINS['gear'].values():
 for file,digest in record['files'].items():assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==digest,file
bpy.context.preferences.filepaths.file_preview_type='NONE'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def load(path):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));return set(bpy.data.objects)-before
objects=load(ART/'equipment-base.glb');rig=next(o for o in objects if o.type=='ARMATURE');body=next(o for o in objects if o.name=='Body')
for t in rig.animation_data.nla_tracks:t.mute=True
idle=next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name=='Idle')
rig.animation_data.action=idle;rig.animation_data.action_slot=idle.slots[0];bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
idle_pose={p.name:p.matrix.copy() for p in rig.pose.bones}
# Read prepared action references without changing the destination bind skeleton.
mo=load(ART/'motion/human-motion.glb');mr=next(o for o in mo if o.type=='ARMATURE')
ma={t.name:t.strips[0].action for t in mr.animation_data.nla_tracks}
for t in mr.animation_data.nla_tracks:t.mute=True
held_poses={}
for name in ['Bow_Idle','Crossbow_Idle']:
 mr.animation_data.action=ma[name];mr.animation_data.action_slot=ma[name].slots[0];bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
 held_poses[name]={p.name:p.matrix.copy() for p in mr.pose.bones}
for extra in mo:bpy.data.objects.remove(extra,do_unlink=True)
rig.animation_data_clear()
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
local=rig.matrix_world.inverted()@body.matrix_world
height_ratio=rig.data.bones['head'].head_local.z/1.5793484
def mat(name):
 m=bpy.data.materials.new('Coverage_'+name);m.use_nodes=True;s=m.node_tree.nodes.get('Principled BSDF')
 s.inputs['Roughness'].default_value=.77;s.inputs['Base Color'].default_value=(.27,.22,.16,1)
 if name in ['plate','mail','studded_metal','jewel']:
  s.inputs['Metallic'].default_value=.9;s.inputs['Roughness'].default_value=.33 if name!='mail' else .57;s.inputs['Base Color'].default_value=(.33,.36,.4,1)
 if name=='jewel':s.inputs['Base Color'].default_value=(.62,.37,.09,1)
 if name in ['linen','leather','studded']:
  color=ROOT/('Viewer/Art/MedievalKit/textures/Linen_Color.jpg' if name=='linen' else 'work/human-wardrobe-2/materials/Leather001_1K-JPG_Color.jpg')
  normal=ROOT/('Viewer/Art/MedievalKit/textures/Fabric045_2K-JPG_NormalGL.jpg' if name=='linen' else 'work/human-wardrobe-2/materials/Leather001_1K-JPG_NormalGL.jpg')
  n=m.node_tree.nodes;l=m.node_tree.links;t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(color),check_existing=True);l.new(t.outputs['Color'],s.inputs['Base Color'])
  t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(normal),check_existing=True);t.image.colorspace_settings.name='Non-Color';nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.3;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],s.inputs['Normal'])
 if name=='mail':
  # A neutral tile of interlocked steel rings, generated at export resolution.
  path=ROOT/'work/human-coverage-session/mail-rings.png'
  if not path.exists():
   im=bpy.data.images.new('Authored interlocked ring tile',256,256);pixels=[]
   for y in range(256):
    for x in range(256):
     row=y//16;xx=((x+(10 if row%2 else 0))%20)-10;yy=y%16-8;r=math.sqrt((xx/8)**2+(yy/6)**2)
     value=.13 if not .65<r<1.1 else (.72 if yy<0 else .42)
     pixels.extend([value,value*1.02,min(1.,value*1.07),1.])
   im.pixels=pixels;im.filepath_raw=str(path);im.file_format='PNG';im.save()
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(path),check_existing=True);m.node_tree.links.new(t.outputs['Color'],s.inputs['Base Color'])
 return m
M={n:mat(n) for n in ['linen','leather','studded','plate','mail','studded_metal','jewel','wood']}
def finish(ob,key):
 ob.name='Extra_'+key;ob.data.name='Coverage_'+key;ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
 for mod in list(ob.modifiers):
  if mod.type=='ARMATURE':ob.modifiers.remove(mod)
 mod=ob.modifiers.new('Shared human skeleton','ARMATURE');mod.object=rig
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
 path=OUT/(key+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
 record={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'vertices':len(ob.data.vertices),'polygons':len(ob.data.polygons),'materials':[m.name for m in ob.data.materials],'bones':sorted(g.name for g in ob.vertex_groups if any(any(w.group==g.index and w.weight>0 for w in v.groups) for v in ob.data.vertices))}
 bpy.data.objects.remove(ob,do_unlink=True);return record
def mesh(key,coords,faces,weights,material):
 data=bpy.data.meshes.new(key);data.from_pydata(coords,[],faces);data.update();ob=bpy.data.objects.new(key,data);bpy.context.collection.objects.link(ob)
 for name in sorted({n for w in weights for n in w}):ob.vertex_groups.new(name=name)
 for i,w in enumerate(weights):
  total=sum(w.values())
  for n,v in w.items():ob.vertex_groups[n].add([i],v/total,'REPLACE')
 data.materials.append(material)
 uv=data.uv_layers.new(name='UVMap')
 for p in data.polygons:
  p.use_smooth=True
  for li in p.loop_indices:
   co=data.vertices[data.loops[li].vertex_index].co;uv.data[li].uv=(co.x*4,co.z*4)
 return ob
def bodyweight(v):return {body.vertex_groups[g.group].name:g.weight for g in v.groups if g.weight>1e-5}
spec=importlib.util.spec_from_file_location('armour',ROOT/'scripts/human-armour.py');armour=importlib.util.module_from_spec(spec);spec.loader.exec_module(armour)
def shell(row):return armour.build(rig,body,ART,row)
def tube(coords,faces,weights,points,radius,bone,sides=8):
 start=len(coords)
 for j,p in enumerate(points):
  direction=(points[min(len(points)-1,j+1)]-points[max(0,j-1)]).normalized();u=direction.cross(Vector((0,1,0)))
  if u.length<.01:u=direction.cross(Vector((1,0,0)))
  u.normalize();v=direction.cross(u).normalized()
  for k in range(sides):coords.append(p+radius*(math.cos(k*math.tau/sides)*u+math.sin(k*math.tau/sides)*v));weights.append({bone:1.})
 for j in range(len(points)-1):
  for k in range(sides):a=start+j*sides+k;b=start+j*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides))
 faces.extend([tuple(start+k for k in reversed(range(sides))),tuple(start+(len(points)-1)*sides+k for k in range(sides))])
def authored(row):
 key=row['key'];kind=row['kind'];coords=[];faces=[];weights=[]
 if kind=='bow':
  bone='hand_l';reference=held_poses['Bow_Idle'];T=rig.data.bones[bone].matrix_local@reference[bone].inverted()
  hand=reference[bone].translation+Vector((0,-.025,0));points=[T@(hand+Vector((0,-.12*(1-(i/20)**2),i/20*.68))) for i in range(-20,21)]
  tube(coords,faces,weights,points,.016,bone)
  string=[points[0],T@(hand+Vector((0,.025,0))),points[-1]];tube(coords,faces,weights,string,.0013,bone,6)
  return mesh(key,coords,faces,weights,M['wood'])
 if kind=='jewel':
  if key=='necklace':centres=[(Vector((0,0,1.425*height_ratio)),Vector((.105,0,0)),Vector((0,.075,0)),'neck_01')]
  elif key=='earrings':centres=[(rig.data.bones['head'].head_local+Vector((s*.082,0,.03)),Vector((.012,0,0)),Vector((0,0,.021)),'head') for s in [-1,1]]
  else:
   bone='hand_r' if key=='ring' else 'lowerarm_r';p=rig.data.bones[bone].head_local.copy();axis=(rig.data.bones[bone].tail_local-p).normalized();u=axis.cross(Vector((0,0,1))).normalized();v=axis.cross(u).normalized();rad=.010 if key=='ring' else .031
   if key=='ring':p=rig.data.bones['ring_01_r'].head_local.copy();bone='ring_01_r'
   centres=[(p,u*rad,v*rad,bone)]
  for centre,u,v,bone in centres:tube(coords,faces,weights,[centre+u*math.cos(i*math.tau/40)+v*math.sin(i*math.tau/40) for i in range(41)],.0025 if key!='ring' else .0018,bone)
  return mesh(key,coords,faces,weights,M['jewel'])
 if kind in ['cap','hat']:
  head=rig.data.bones['head'].head_local;z=head.z+.01
  if key=='wizard_hat':rings=[(.16,.105,z),(.09,.085,z+.025),(.075,.07,z+.17),(.015,.02,z+.40)]
  elif key=='straw_hat':rings=[(.21,.16,z+.06),(.10,.09,z+.07),(.09,.08,z+.19),(.015,.02,z+.21)]
  else:rings=[(.091,.08,z+.005),(.095,.085,z+.08),(.070,.065,z+.135),(.005,.005,z+.16)]
  for rx,ry,height in rings:
   for i in range(40):coords.append(Vector((rx*math.cos(i*math.tau/40),head.y+ry*math.sin(i*math.tau/40),height)));weights.append({'head':1.})
  for j in range(len(rings)-1):
   for i in range(40):a=j*40+i;b=j*40+(i+1)%40;faces.append((a,b,b+40,a+40))
  return mesh(key,coords,faces,weights,M['linen'] if key!='skullcap' else M['leather'])
 raise ValueError(kind)
def prop(row):
 record=PINS['gear'][row['source']];objects=load(ROOT/'Viewer/Art/Objaverse'/record['file']);meshes=[o for o in objects if o.type=='MESH']
 bpy.ops.object.select_all(action='DESELECT')
 for ob in meshes:ob.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();ob=meshes[0]
 points=np.array([ob.matrix_world@v.co for v in ob.data.vertices]);centre=(points.max(0)+points.min(0))*.5
 shield=row['slot']=='shield';cross=row.get('stance')=='crossbow';bone='hand_l' if shield else 'hand_r'
 # Authoring frame is a neutral held prop in front of the body; convert it
 # back through the reference hand to the fixed bind pose for rigid skinning.
 reference=held_poses['Crossbow_Idle'] if cross else idle_pose
 T=rig.data.bones[bone].matrix_local@reference[bone].inverted();hand=reference[bone].translation
 if cross:
  # Both source crossbows have their limbs across X; stock axes differ.
  stock=2 if row['source']=='w_heavy_crossbow' else 0;up=1 if stock==2 else 2;width=0 if stock==2 else 1
  extent=points.max(0)-points.min(0);scale=row['length']/max(extent[width],extent[stock]);anchor=hand+Vector((0,-.18,.07))
  coords=[T@(anchor+Vector(((p[width]-centre[width])*scale,-(p[stock]-centre[stock])*scale,(p[up]-centre[up])*scale))) for p in points]
 elif shield:
  extent=points.max(0)-points.min(0);scale=row['length']/extent[2];anchor=hand+Vector((0,-.09,-.08))
  coords=[T@(anchor+Vector(((p[0]-centre[0])*scale,-(p[1]-centre[1])*scale,(p[2]-centre[2])*scale))) for p in points]
 else:
  # PCA isolates the handle/blade axis despite unlike source orientations.
  _,_,axes=np.linalg.svd(points-centre,full_matrices=False);axis=axes[0]
  if axis[np.argmax(abs(axis))]<0:axis=-axis
  if row.get('reverse_axis'):axis=-axis
  across=axes[1];normal=np.cross(across,axis);q=np.stack((across,normal,axis),axis=1);canonical=(points-centre)@q
  lo=canonical.min(0);hi=canonical.max(0);scale=row['length']/(hi[2]-lo[2]);grip=lo[2]+row['grip']*(hi[2]-lo[2]);anchor=hand+Vector((0,-.025,0))
  coords=[T@(anchor+Vector((p[0]*scale,p[1]*scale,(p[2]-grip)*scale))) for p in canonical]
 for v,co in zip(ob.data.vertices,coords):v.co=co
 for material in ob.data.materials:
  if material and material.use_nodes:
   shader=material.node_tree.nodes.get('Principled BSDF')
   if shader and not shader.inputs['Base Color'].is_linked and min(shader.inputs['Base Color'].default_value[:3])>.8:
    shader.inputs['Base Color'].default_value=(.3,.33,.36,1);shader.inputs['Metallic'].default_value=.85;shader.inputs['Roughness'].default_value=.48
 ob.vertex_groups.clear();ob.vertex_groups.new(name=bone).add(list(range(len(coords))),1.,'REPLACE')
 ob.matrix_world=Matrix.Identity(4)
 for extra in objects & set(bpy.data.objects):
  if extra!=ob:bpy.data.objects.remove(extra,do_unlink=True)
 return ob
evidence={'female':FEMALE,'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'inputs_sha256':hashlib.sha256((ROOT/'scripts/human-coverage-inputs.json').read_bytes()).hexdigest(),'parts':{}}
if (PROPS_ONLY or ARMOUR_ONLY or TAILORING_ONLY) and (OUT/'provenance.json').exists():evidence=json.loads((OUT/'provenance.json').read_text())
evidence.update(female=FEMALE,recipe_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),inputs_sha256=hashlib.sha256((ROOT/'scripts/human-coverage-inputs.json').read_bytes()).hexdigest())
tailor=None
for row in RECIPES:
 kind=row['kind']
 # Separate fitted-cloth and expansion builders run after the foundation.
 if kind in ['workwear','expansion35','expansion50']:continue
 if kind=='tailoring':
  if tailor is None:
   spec=importlib.util.spec_from_file_location('tailoring',ROOT/'scripts/human-tailoring.py');tailoring=importlib.util.module_from_spec(spec);spec.loader.exec_module(tailoring);tailor=tailoring.Tailor(rig,body,ART,M,idle_pose)
  for lit in ([False,True] if row['key']=='lantern' else [False]):
   name,ob=tailor.build(row['key'],lit)
   evidence['parts'][name]=dict(finish(ob,name),kind=kind,source='Original Britannia Reborn parametric topology fitted to pinned CC0 human rig',licence='GPL-3.0-or-later original generator; selected CC0 foundation/material inputs',recipe_sha256=hashlib.sha256((ROOT/'scripts/human-tailoring.py').read_bytes()).hexdigest(),lit=lit)
  print('COVERAGE TAILORING',FEMALE,row['key'],flush=True);continue
 ob=shell(row) if kind=='shell' else (prop(row) if kind=='prop' else authored(row))
 evidence['parts'][row['key']]=dict(finish(ob,row['key']),recipe_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),kind=kind,source=row.get('source','Britannia Reborn authored on the traced CC0 body/cloth foundation'),fidelity='category replacement; original item ornament and exact silhouette require individual review')
 print('COVERAGE GEAR',FEMALE,row['key'],flush=True)
if not PROPS_ONLY and not TAILORING_ONLY:
 ob=armour.undercoat(rig,ART,body);evidence['parts']['armour_undercoat']=dict(finish(ob,'armour_undercoat'),kind='support',source='Pinned CC0 Toigo fitted shirt, neutral woven lining material',recipe_sha256=hashlib.sha256((ROOT/'scripts/human-armour.py').read_bytes()).hexdigest())
 ob=armour.boots(rig,ART);evidence['parts']['armour_boots']=dict(finish(ob,'armour_boots'),kind='support',source='Pinned CC0 Viking boots, ankle section under articulated greaves')
 evidence['armour_construction']={'recipe_sha256':hashlib.sha256((ROOT/'scripts/human-armour.py').read_bytes()).hexdigest(),'method':'Continuous tailored trousers and undercoat; independent rigid plates, overlapping waist/joint guards, thickness, rolled edges and rivets. No body-surface armour shells.'}
 evidence.pop('pose_fit',None)
(OUT/'provenance.json').write_text(json.dumps(evidence,indent=2));print('COVERAGE GEAR READY',FEMALE,len(evidence['parts']),flush=True)
