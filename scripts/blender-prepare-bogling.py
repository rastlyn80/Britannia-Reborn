import bpy,bmesh,hashlib,importlib.util,json,math,itertools
import numpy as np
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'Viewer/local-art/bogling';OUT.mkdir(parents=True,exist_ok=True)
pins=ROOT/'scripts/bogling-inputs.json'
for item in json.loads(pins.read_text())['inputs']:
 path=ROOT/item['path'];assert path.stat().st_size==item['bytes'] and hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],('Changed CC0 input',item['path'])
spec=importlib.util.spec_from_file_location('tree_kinematics',ROOT/'scripts/creature-humanoid-actions.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
BasePose=h.Pose
ALIASES={'bip01':'spine','bip01 head':'spine.008',**{'bip01 '+name:'spine.'+str(i+1).zfill(3) for i,name in enumerate(['spine','spine1','spine2','spine3'])}}
for side,letter in [('l','L'),('r','R')]:
 for role,actual in [('upperarm','upper_arm'),('forearm','forearm'),('hand','hand'),('thigh','thigh'),('calf','shin'),('foot','foot')]:ALIASES['bip01 '+side+' '+role]=actual+'.'+letter
class TreePose(BasePose):
 def __init__(self,body,idle):
  super().__init__(body,idle)
  self.names.update({key:self.names[value.replace('_','')] for key,value in ALIASES.items()})
h.Pose=TreePose
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene
source=ROOT/'work/creatures/bogling/source/extracted/Treant Package/Treant 2';fbx=source/'Tree02_FBX.fbx';bpy.ops.import_scene.fbx(filepath=str(fbx),use_image_search=False,automatic_bone_orientation=False)
rig=next(o for o in scene.objects if o.type=='ARMATURE');mesh=next(o for o in scene.objects if o.type=='MESH')
# Triangulate only faces; preserve every original point, UV and vertex group.
before_points=[tuple(v.co) for v in mesh.data.vertices];bm=bmesh.new();bm.from_mesh(mesh.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh.data);bm.free();assert before_points==[tuple(v.co) for v in mesh.data.vertices]
weight_reduction=[]
for vertex in mesh.data.vertices:
 weights=sorted([(g.group,g.weight) for g in vertex.groups if g.weight>0.],key=lambda p:p[1],reverse=True)
 if len(weights)>8:weight_reduction.append({'vertex':vertex.index,'original_influences':len(weights),'discarded_weight':sum(w for _,w in weights[8:])})
original_actions=list(bpy.data.actions);fps_source=scene.render.fps;assert len(original_actions)==10
idle=next(a for a in original_actions if a.name.endswith('|Idle'));rig.animation_data.action=idle;scene.frame_set(1);bpy.context.view_layer.update()
eval_mesh=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=eval_mesh.to_mesh();raw_points=[eval_mesh.matrix_world@v.co for v in data.vertices];eval_mesh.to_mesh_clear();low=min(p.z for p in raw_points);high=max(p.z for p in raw_points);scale=1.15/(high-low)
container=bpy.data.objects.new('SourceScale',None);scene.collection.objects.link(container)
for obj in [o for o in scene.objects if o!=container and o.parent is None]:obj.parent=container
container.scale=(scale,)*3;container.location.z=-low*scale
floor_node=bpy.data.objects.new('Grounding',None);scene.collection.objects.link(floor_node);container.parent=floor_node;floor_node.animation_data_create();anchor=bpy.data.objects.new('Bogling',None);scene.collection.objects.link(anchor);floor_node.parent=anchor;bpy.context.view_layer.update()
names=[b.name for b in rig.data.bones];indices={name:i for i,name in enumerate(names)};parents=[indices[b.parent.name] if b.parent else i for i,b in enumerate(rig.data.bones)]
def sample_world(action,frame):
 rig.animation_data.action=action;scene.frame_set(math.floor(frame),subframe=frame%1);bpy.context.view_layer.update();return {b.name:(rig.matrix_world@b.matrix).copy() for b in rig.pose.bones}
def local_pose(worlds):
 rigid={name:Matrix.LocRotScale(m.translation,m.to_quaternion(),Vector((1,1,1))) for name,m in worlds.items()};bones=[];tracks=[]
 for i,name in enumerate(names):
  m=rigid[names[parents[i]]].inverted()@rigid[name] if parents[i]!=i else rigid[name];q=m.to_quaternion();p=list(m.translation);rotation=[q.x,q.y,q.z,q.w]
  bones.append({'name':name,'parent':parents[i],'translation':p,'rotation':rotation});tracks.append({'name':name,'translation':{'times':[0.],'values':[p]},'rotation':{'times':[0.],'values':[rotation]}})
 return bones,{'bones':bones,'tracks':tracks}
base_world=sample_world(idle,1);bones,idle_pose=local_pose(base_world);body={'bones':bones,'points':[[0,0,0],[0,0,1.15]]};baseline=TreePose(body,idle_pose)
source_clips={};origin={};SAMPLE_FPS=240
mapping={'Attack_1':'Attack','Attack2':'Attack2','Attack3':'Attack3','Death1':'Death','Death2':'Death2','Death3':'Death3','Idle':'Idle','River Dance':'Dance','Run':'SourceRun','Taunt':'Fidget'}
for action in original_actions:
 start,end=map(float,action.frame_range);duration=(end-start)/fps_source;count=max(2,round(duration*SAMPLE_FPS)+1);label=mapping[action.name.split('|')[-1]]
 source_clips[label]={'duration':duration,'frames':[sample_world(action,start+(end-start)*i/(count-1)) for i in range(count)]};origin[label]='Retained Tennessippi source action '+action.name+'; common ancestor only corrects negative complete-skin penetration'
run_samples=source_clips['SourceRun']['frames']
def source_run_pose(u,blend):
 at=u*(len(run_samples)-1);a=int(at);b=min(a+1,len(run_samples)-1);v=at-a;worlds={}
 for name in names:
  first=run_samples[a][name];second=run_samples[b][name];worlds[name]=Matrix.LocRotScale(first.translation.lerp(second.translation,v),first.to_quaternion().slerp(second.to_quaternion(),v),first.to_scale().lerp(second.to_scale(),v))
 _,channels=local_pose(worlds);p=TreePose(body,channels)
 if blend<1.:
  for i in range(len(names)):
   p.positions[i]=h.mix(baseline.positions[i],p.positions[i],blend)
   q=Quaternion((baseline.rotations[i][3],*baseline.rotations[i][:3])).slerp(Quaternion((p.rotations[i][3],*p.rotations[i][:3])),blend);p.rotations[i]=[q.x,q.y,q.z,q.w]
  p.cache.clear()
 return p
scales={name:base_world[name].to_scale() for name in names}
def world_from_pose(p):
 return {name:Matrix.LocRotScale(Vector(p.world(i)[1]),Quaternion((p.world(i)[0][3],*p.world(i)[0][:3])),scales[name]) for i,name in enumerate(names)}
forward=h.unit(h.cross(h.sub(baseline.world('upper_arm.L')[1],baseline.world('upper_arm.R')[1]),[0,0,1]));source_clips_authored={};gait_reports={}
for label,speed,duration,stance,blend,drop,lift in [('Walk',1.8,128/240,.62,.45,.10,.085),('Run',5.5,96/240,.28,1.,.115,.14)]:
 frames=[];diagnostics=[];count=round(duration*SAMPLE_FPS)+1;stroke=speed*stance*duration;max_reach_error=0.
 # The minimum constant lowering is derived from both limbs over the whole
 # cycle, keeping every target inside the measured limb reach without adding
 # per-frame root bounce or stretching a bone.
 required_drop=drop
 for probe in range(257):
  u=float(probe)/256.;q=source_run_pose(u,blend)
  for side,phase in [('L',u%1.),('R',(u+.5)%1.)]:
   if phase<stance:travel=stroke*(.5-phase/stance);rise=0.
   else:
    t=(phase-stance)/(1.-stance);travel=stroke*(-.5+h.smooth(t));rise=lift*math.sin(math.pi*t)
   target=h.add(baseline.world('foot.'+side)[1],h.add(h.mul(forward,travel),[0,0,rise]));a=q.world('thigh.'+side)[1];b=q.world('shin.'+side)[1];c=q.world('foot.'+side)[1]
   length=h.length(h.sub(b,a))+h.length(h.sub(c,b));horizontal=(target[0]-a[0])**2+(target[1]-a[1])**2
   assert horizontal<(length*.975)**2,('Stride exceeds horizontal reach',label,u,side)
   allowed=math.sqrt((length*.975)**2-horizontal);required_drop=max(required_drop,a[2]-target[2]-allowed+.003)
 drop=required_drop
 assert drop<.28*1.15,('Excessive gait lowering',label,drop)
 for frame in range(count):
  u=frame/(count-1);p=source_run_pose(u,blend);p.translate('spine',[0,0,-drop]);requested=[]
  for side,phase in [('L',u%1.),('R',(u+.5)%1.)]:
   if phase<stance:travel=stroke*(.5-phase/stance);rise=0.
   else:
    t=(phase-stance)/(1.-stance);travel=stroke*(-.5+h.smooth(t));rise=lift*math.sin(math.pi*t)
   initial=baseline.world('foot.'+side)[1];target=h.add(initial,h.add(h.mul(forward,travel),[0,0,rise]));pole=h.add(baseline.world('shin.'+side)[1],h.mul(forward,.5))
   actual=p.limb('thigh.'+side,'shin.'+side,'foot.'+side,target,pole);max_reach_error=max(max_reach_error,h.length(h.sub(actual,target)))
   p.world_rotation('foot.'+side,baseline.world('foot.'+side)[0])
   for child in ['toe.'+side,'heel.02.'+side]:
    i=indices[child];p.positions[i]=list(baseline.positions[i]);p.rotations[i]=list(baseline.rotations[i]);p.cache.clear()
   requested.append({'side':side,'phase':phase,'stance':phase<stance,'target':target,'reached':actual})
  frames.append(world_from_pose(p));diagnostics.append({'phase':u,'feet':requested})
 source_clips_authored[label]={'duration':duration,'frames':frames};origin[label]='Authored measured-limb gait with retained source upper-body motion, fixed-length leg IK, explicit stance speed and raised swing; original SourceRun retained separately'
 gait_reports[label]={'reference_mps':speed,'duration':duration,'stance_fraction':stance,'stroke_m':stroke,'max_target_reach_error_m':max_reach_error,'constant_body_lowering_m':drop,'samples':diagnostics}
for label in ['Cast','Pillage']:
 clip=h.gesture(body,idle_pose,label);frames=[];count=len(clip['tracks'][0]['rotation']['times'])
 for f in range(count):
  p=TreePose(body,idle_pose)
  for i,track in enumerate(clip['tracks']):p.positions[i]=track['translation']['values'][f];p.rotations[i]=track['rotation']['values'][f]
  frames.append(world_from_pose(p))
 source_clips_authored[label]={'duration':clip['tracks'][0]['rotation']['times'][-1],'frames':frames};origin[label]='Authored source-rig reach/cast using explicit role aliases, fixed limb lengths and source stance anchors; not original UO choreography'
frames=[]
for frame in range(37):
 u=frame/36.;amount=math.sin(math.pi*u)**2;p=TreePose(body,idle_pose);left=h.unit(h.sub(baseline.world('upper_arm.L')[1],baseline.world('upper_arm.R')[1]))
 for name in ['spine.001','spine.002','spine.003','spine.004']:p.turn(name,left,-.16*amount/4)
 frames.append(world_from_pose(p))
source_clips_authored['Hit']={'duration':.6,'frames':frames};origin['Hit']='Authored distributed trunk recoil on source idle; source feet and bone lengths retained'
clips={**source_clips,**source_clips_authored};rig.animation_data.action=None
# Quantify the renderer's eight-influence reduction against the full source skin.
rest_inverse={name:(rig.matrix_world@rig.data.bones[name].matrix_local).inverted() for name in names};skin_reduction_error={};skin_fit=[]
for record in weight_reduction:
 vertex=mesh.data.vertices[record['vertex']];pairs=sorted([(mesh.vertex_groups[g.group].name,g.weight) for g in vertex.groups if g.weight>0. and mesh.vertex_groups[g.group].name in indices],key=lambda p:p[1],reverse=True);bind=mesh.matrix_world@vertex.co
 point_rows=[];labels=[]
 for label,clip in clips.items():
  for worlds in clip['frames']:
   point_rows.append([list((worlds[name]@rest_inverse[name])@bind) for name,_ in pairs]);labels.append(label)
 points=np.asarray(point_rows,dtype=np.float64);matrix=points.transpose(0,2,1).reshape(-1,len(pairs));weights=np.array([w for _,w in pairs]);weights/=weights.sum();target=matrix@weights
 best_indices=tuple(range(8));best_weights=weights[:8]/weights[:8].sum();best_errors=np.linalg.norm((matrix[:,best_indices]@best_weights-target).reshape(-1,3),axis=1);baseline_error=float(best_errors.max());best_error=baseline_error
 for subset in itertools.combinations(range(len(pairs)),8):
  basis=matrix[:,subset];delta=basis[:,:-1]-basis[:,-1,None];solution=np.linalg.lstsq(delta,target-basis[:,-1],rcond=1e-9)[0];solution=np.r_[solution,1.-solution.sum()]
  if solution.min() < -1e-7:continue
  solution=np.maximum(solution,0.);solution/=solution.sum();errors=np.linalg.norm((basis@solution-target).reshape(-1,3),axis=1);maximum=float(errors.max())
  if maximum<best_error:best_error=maximum;best_indices=subset;best_weights=solution;best_errors=errors
 for group in list(vertex.groups):mesh.vertex_groups[group.group].remove([vertex.index])
 for index,weight in zip(best_indices,best_weights):
  if weight>0.:mesh.vertex_groups[pairs[index][0]].add([vertex.index],float(weight),'REPLACE')
 skin_fit.append({'vertex':vertex.index,'original_influences':len(pairs),'baseline_top8_error_m':baseline_error,'fitted_max_error_m':best_error,'weights':{pairs[i][0]:float(w) for i,w in zip(best_indices,best_weights)}})
 for label,error in zip(labels,best_errors):skin_reduction_error[label]=max(skin_reduction_error.get(label,0.),float(error))

for bone in rig.pose.bones:bone.rotation_mode='QUATERNION'
material=bpy.data.materials.new('Source Bark and Normal');material.use_nodes=True;nodes=material.node_tree.nodes;links=material.node_tree.links;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.9
albedo=source/'Treant_2 Textures/Tree02 Albedo Dark.png';normal=source/'Treant_2 Textures/Tree02 Normal.png'
image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(str(albedo));links.new(image.outputs['Color'],bsdf.inputs['Base Color']);image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(str(normal));image.image.colorspace_settings.name='Non-Color';mapnode=nodes.new('ShaderNodeNormalMap');mapnode.inputs['Strength'].default_value=.65;links.new(image.outputs['Color'],mapnode.inputs['Color']);links.new(mapnode.outputs['Normal'],bsdf.inputs['Normal']);mesh.data.materials.clear();mesh.data.materials.append(material)
for poly in mesh.data.polygons:poly.use_smooth=True
tracks=[];max_position_error=0.;max_source_position_error=0.;corrections={};scene.render.fps=SAMPLE_FPS
for label,clip in clips.items():
 action=bpy.data.actions.new('Bogling_'+label);rig.animation_data.action=action;parent_action=bpy.data.actions.new('Ground_'+label);floor_node.animation_data.action=parent_action;values=[]
 for frame,worlds in enumerate(clip['frames']):
  at=1+clip['duration']*SAMPLE_FPS*frame/(len(clip['frames'])-1);scene.frame_set(math.floor(at),subframe=at%1);floor_node.location.z=0.;bpy.context.view_layer.update();inverse=rig.matrix_world.inverted()
  local_matrices={name:inverse@matrix for name,matrix in worlds.items()}
  for bone in rig.pose.bones:
   inherited=bone.parent.bone.matrix_local@local_matrices[bone.parent.name].inverted() if bone.parent else Matrix.Identity(4)
   bone.matrix_basis=bone.bone.matrix_local.inverted()@inherited@local_matrices[bone.name]
  bpy.context.view_layer.update();error=max(((rig.matrix_world@bone.matrix).translation-worlds[bone.name].translation).length for bone in rig.pose.bones);max_position_error=max(max_position_error,error)
  if label in source_clips:
   max_source_position_error=max(max_source_position_error,error);assert error<.00001,(label,frame,error)
  else:assert error<.001,(label,frame,error)
  evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh();bottom=min((evaluated.matrix_world@v.co).z for v in data.vertices);evaluated.to_mesh_clear();floor_node.location.z=max(0.,-bottom);values.append(floor_node.location.z);floor_node.keyframe_insert(data_path='location',frame=at)
  for bone in rig.pose.bones:
   for channel in ['location','rotation_quaternion','scale']:bone.keyframe_insert(data_path=channel,frame=at,group=bone.name)
 for obj,act in [(rig,action),(floor_node,parent_action)]:
  track=obj.animation_data.nla_tracks.new();track.name=label;strip=track.strips.new(label,1,act);strip.action_slot=act.slots[0];track.mute=True;tracks.append(track);obj.animation_data.action=None
 corrections[label]={'range_m':[min(values),max(values)],'policy':'Separate common ancestor; negative complete-skin penetration only, positive source/swing clearance retained'}
assert max_position_error<.001,max_position_error
for track in tracks:track.mute=False
bpy.ops.object.select_all(action='SELECT');path=OUT/'bogling-candidate.glb';bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_merge_animation='NLA_TRACK',export_force_sampling=True,export_frame_step=1,export_anim_slide_to_zero=True,export_yup=True,export_normals=True,export_tangents=True,export_influence_nb=8)
report={'source':'https://tennessippistudios.itch.io/treant-pack','license':'Tennessippi CC0 mesh/maps/ten source motions; authored project conversion/gaits/gestures GPL-3.0-or-later','tree':2,'source_fps':fps_source,'fps':SAMPLE_FPS,'bones':len(names),'height_target_m':1.15,'scale':scale,'skin_fit':skin_fit,'skin_reduction_max_error_m':skin_reduction_error,'weight_reduction':weight_reduction,'max_discarded_weight':max((r['discarded_weight'] for r in weight_reduction),default=0.),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'clips':{label:{'duration':v['duration'],'samples':len(v['frames']),'origin':origin[label],'floor':corrections[label]} for label,v in clips.items()},'bone_role_aliases':ALIASES,'gaits':gait_reports,'max_source_bake_position_error_m':max_source_position_error,'max_all_bake_position_error_m':max_position_error,'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'kinematics_sha256':hashlib.sha256((ROOT/'scripts/creature-humanoid-actions.py').read_bytes()).hexdigest(),'inputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [fbx,albedo,normal]},'status':'Candidate only; full imported skins, real stance speeds, source pose preservation, terrain/hue/corpse/native/public distribution gates pending'}
(OUT/'preparation.json').write_text(json.dumps(report,indent=2)+'\n');print('BOGLING CANDIDATE',len(names),'bones',len(clips),'categories','bake_error',max_position_error,'gait_reach_errors',{k:r['max_target_reach_error_m'] for k,r in gait_reports.items()})
