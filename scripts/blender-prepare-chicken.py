"""Bake pinned CC0 hen constraints and curved bones; no native route installed.
Use trusted Blender with factory-startup, disable-autoexec and python-exit-code1.
"""
import bpy,bmesh,hashlib,json,math
from mathutils import Matrix
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'work/creatures/chicken';SRC=BASE/'source/extracted';OUT=ROOT/'Viewer/local-art/chicken';OUT.mkdir(parents=True,exist_ok=True)
pins=json.loads((ROOT/'scripts/chicken-inputs.json').read_text(encoding='utf-8'));assert hashlib.sha256((BASE/'source/chicken_0.zip').read_bytes()).hexdigest()==pins['sha256']
for member in pins['members']:assert hashlib.sha256((SRC/member['path']).read_bytes()).hexdigest()==member['sha256']
bpy.ops.wm.open_mainfile(filepath=str(SRC/'chickenV2.blend'),load_ui=False,use_scripts=False);scene=bpy.context.scene
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
rig=next(o for o in scene.objects if o.type=='ARMATURE');meshes=[o for o in scene.objects if o.type=='MESH' and o.name!='Cylinder'];assert {o.name for o in meshes}=={'Chicken','Eyes'}
source_basis={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
source_objects=[{'name':o.name,'hide_render':o.hide_render,'hide_viewport':o.hide_viewport,'materials':[m.name if m else None for m in o.data.materials] if o.type=='MESH' else None} for o in scene.objects]
for obj in list(scene.objects):
 if obj not in meshes+[rig]:bpy.data.objects.remove(obj,do_unlink=True)
actions=list(bpy.data.actions);idle=next(a for a in actions if a.name=='Idle1');rig.animation_data.action=idle;scene.frame_set(1);bpy.context.view_layer.update()
points=[]
for mesh in meshes:
 obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=obj.to_mesh();points.extend(obj.matrix_world@v.co for v in data.vertices);obj.to_mesh_clear()
low=min(p.z for p in points);high=max(p.z for p in points);scale=.45/(high-low);parent=bpy.data.objects.new('ChickenScale',None);scene.collection.objects.link(parent)
for obj in [o for o in scene.objects if o!=parent and o.parent is None]:obj.parent=parent
parent.scale=(scale,)*3;parent.location.z=-low*scale
albedo=bpy.data.images.load(str(SRC/'textures/UV-Texture.png'),check_existing=False);normal=bpy.data.images.load(str(SRC/'textures/ChickenNorm.png'),check_existing=False);normal.colorspace_settings.name='Non-Color';materials=[]
for mesh in meshes:
 bm=bmesh.new();bm.from_mesh(mesh.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh.data);bm.free()
 for index,old in enumerate(list(mesh.data.materials)):
  mat=bpy.data.materials.new(old.name+'_PBR');mat.use_nodes=True;bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.85;bsdf.inputs['Metallic'].default_value=0.;bsdf.inputs['Base Color'].default_value=tuple(old.diffuse_color)
  if old.name=='Comb':bsdf.inputs['Base Color'].default_value=(.55,.015,.01,1.)
  if mesh.name=='Eyes':bsdf.inputs['Base Color'].default_value=(.025,.012,.004,1.);bsdf.inputs['Roughness'].default_value=.35
  if old.name=='Chicken':
   tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=albedo;mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=normal;n=mat.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.6;mat.node_tree.links.new(tex.outputs['Color'],n.inputs['Color']);mat.node_tree.links.new(n.outputs['Normal'],bsdf.inputs['Normal'])
  mesh.data.materials[index]=mat;materials.append({'name':old.name,'source_diffuse':list(old.diffuse_color),'uses_maps':old.name=='Chicken'})
 for polygon in mesh.data.polygons:polygon.use_smooth=True

scene=bpy.context.scene;rig=next(o for o in scene.objects if o.type=='ARMATURE');meshes=[o for o in scene.objects if o.type=='MESH'];source_fps=scene.render.fps;actions=[a for a in bpy.data.actions if a.name not in ['Stand','StopPecking']]
weight_report={}
for mesh in meshes:
 sums=[];maximum=0
 for vertex in mesh.data.vertices:
  values=[(g.group,g.weight) for g in vertex.groups if mesh.vertex_groups[g.group].name in rig.data.bones and g.weight>0.]
  total=sum(v for _,v in values);assert total>0 and len(values)<=8;sums.append(total);maximum=max(maximum,len(values))
  for group,value in values:mesh.vertex_groups[group].add([vertex.index],value/total,'REPLACE')
 weight_report[mesh.name]={'source_sum_range':[min(sums),max(sums)],'max_influences':maximum,'discarded_by_recipe':0,'policy':'Normalize positive source ratios before exporter clamp/rounding; actual imported full-skin comparison bounds numerical tail loss. Original mesh points/UVs and source bone hierarchy retained; seven explicit B-Bone segment joints added.'}
bb_namespace={};exec((ROOT/'scripts/chicken-bbone.py').read_text(),bb_namespace);segment_specs=bb_namespace['expand'](rig,meshes)
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
rig.animation_data.action=None
scale_root=next(o for o in scene.objects if o.name=='ChickenScale');ground=bpy.data.objects.new('Grounding',None);scene.collection.objects.link(ground);scale_root.parent=ground;ground.animation_data_create()
names=[b.name for b in rig.data.bones];samples={};FPS=120
for action in actions:
 rig.animation_data.action=None
 for bone in rig.pose.bones:bone.matrix_basis=source_basis.get(bone.name,Matrix.Identity(4))
 rig.animation_data.action=action;start,end=map(float,action.frame_range);duration=(end-start)/source_fps;count=max(2,round(duration*FPS)+1);frames=[]
 for i in range(count):
  frame=start+(end-start)*i/(count-1);scene.frame_set(math.floor(frame),subframe=frame%1);bpy.context.view_layer.update();worlds={b.name:(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones}
  for spec in segment_specs:
   source=rig.pose.bones[spec['source']];worlds[spec['name']]=rig.matrix_world@source.matrix@source.bbone_segment_matrix(spec['index'],rest=False)@Matrix(spec['rest_correction'])
  frames.append(worlds)
 samples[action.name]={'duration':duration,'frames':frames}
rig.animation_data.action=None
for bone in rig.pose.bones:
 for constraint in list(bone.constraints):bone.constraints.remove(constraint)
 bone.rotation_mode='QUATERNION'
 bone.bone.bbone_segments=1
scene.render.fps=FPS;maximum=0.;corrections={}
for label,clip in samples.items():
 action=bpy.data.actions.new('Baked_'+label);rig.animation_data.action=action;floor_action=bpy.data.actions.new('Floor_'+label);ground.animation_data.action=floor_action;values=[]
 for i,worlds in enumerate(clip['frames']):
  at=1+clip['duration']*FPS*i/(len(clip['frames'])-1);scene.frame_set(math.floor(at),subframe=at%1);ground.location.z=0.;bpy.context.view_layer.update();inverse=rig.matrix_world.inverted();local={name:inverse@matrix for name,matrix in worlds.items()}
  for bone in rig.pose.bones:
   inherited=bone.parent.bone.matrix_local@local[bone.parent.name].inverted() if bone.parent else Matrix.Identity(4);bone.matrix_basis=bone.bone.matrix_local.inverted()@inherited@local[bone.name]
  bpy.context.view_layer.update();error=max(max(abs((rig.matrix_world@b.matrix)[r][c]-worlds[b.name][r][c]) for r in range(4) for c in range(4)) for b in rig.pose.bones);maximum=max(maximum,error);assert error<.0001,(label,i,error)
  lowest=math.inf
  for mesh in meshes:
   obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=obj.to_mesh();lowest=min(lowest,min((obj.matrix_world@v.co).z for v in data.vertices));obj.to_mesh_clear()
  ground.location.z=max(0.,-lowest);values.append(ground.location.z);ground.keyframe_insert(data_path='location',frame=at)
  for bone in rig.pose.bones:
   for channel in ['location','rotation_quaternion','scale']:bone.keyframe_insert(data_path=channel,frame=at,group=bone.name)
 for obj,act in [(rig,action),(ground,floor_action)]:
  track=obj.animation_data.nla_tracks.new();track.name=label;strip=track.strips.new(label,1,act);strip.action_slot=act.slots[0];track.mute=True;obj.animation_data.action=None
 corrections[label]=[min(values),max(values)];print('BAKED SOURCE',label,len(clip['frames']),'frames',flush=True)
ground.location=(0,0,0)
for obj in [rig,ground]:
 for track in obj.animation_data.nla_tracks:track.mute=False
bpy.ops.object.select_all(action='SELECT');path=OUT/'chicken-source.glb';bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_merge_animation='NLA_TRACK',export_anim_slide_to_zero=True,export_force_sampling=True,export_tangents=True,export_influence_nb=8)
(OUT/'preparation.json').write_text(json.dumps({'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'bbone_recipe_sha256':hashlib.sha256((ROOT/'scripts/chicken-bbone.py').read_bytes()).hexdigest(),'source_pin_sha256':hashlib.sha256((ROOT/'scripts/chicken-inputs.json').read_bytes()).hexdigest(),'source':pins,'fps':FPS,'bones':len(names),'source_fps':source_fps,'weight_policy':weight_report,'bbone_segments':segment_specs,'max_source_world_matrix_element_error':maximum,'corrections':corrections,'clips':{k:{'duration':v['duration'],'samples':len(v['frames'])} for k,v in samples.items()},'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':'Private full evaluated source/floor bake; imported full-skin fidelity/gaits/native/corpse/distribution pending.'},indent=2)+'\n');print('CHICKEN EVALUATED BAKE',len(samples),'clips',maximum,'max source joint error')
