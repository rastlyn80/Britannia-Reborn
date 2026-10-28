"""Retarget pinned CC0 humanoid motion and rebake existing garment controls.

Blender background script. Never changes body geometry, bind pose or native
mobile position. Generated GLBs stay in ignored local-art.
"""
import bpy,sys,json,math,hashlib,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
ROOT=Path(__file__).resolve().parents[1]
PINS=json.loads((ROOT/'scripts/human-motion-inputs.json').read_text())
for file,digest in PINS['files'].items():assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==digest,'Changed animation input '+file
FEMALE='--female' in sys.argv
ART=ROOT/('Viewer/local-art/free-equipment-female' if FEMALE else 'Viewer/local-art/free-equipment')
OUT=ART/'motion';OUT.mkdir(parents=True,exist_ok=True)
FPS=30
CLIPS={
 'Idle':(1,'Idle_Loop',True),'Walk':(1,'Walk_Loop',True),
 'Run':(1,'Jog_Fwd_Loop',True),'Sprint':(1,'Sprint_Loop',True),
 'Sword_Idle':(1,'Sword_Idle',True),'Sword_Attack':(1,'Sword_Attack',False),
 'Punch_Jab':(1,'Punch_Jab',False),'Punch_Cross':(1,'Punch_Cross',False),
 'Hit':(1,'Hit_Chest',False),'Death':(1,'Death01',False),
 'Cast':(1,'Spell_Simple_Shoot',False),'Interact':(1,'Interact',False),
 'Jump_Start':(1,'Jump_Start',False),'Jump':(1,'Jump_Loop',True),
 'Jump_Land':(1,'Jump_Land',False),
 'Sword_A':(2,'Sword_Regular_A',False),'Sword_B':(2,'Sword_Regular_B',False),
 'Sword_C':(2,'Sword_Regular_C',False),'Sword_Block':(2,'Sword_Block',False),
 'Heavy_Attack':(2,'Sword_Regular_C',False),
 'Harvest':(2,'Farm_Harvest',False),'Chop':(2,'TreeChopping_Loop',True),
 'Consume':(2,'Consume',False),'Yes':(2,'Yes',False),
}
bpy.context.preferences.filepaths.file_preview_type='NONE'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps=FPS
def load(path):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));return set(bpy.data.objects)-before
objects=load(ART/'equipment-base.glb')
rig=next(o for o in objects if o.type=='ARMATURE');body=next(o for o in objects if o.name=='Body')
original_idle=next(tr.strips[0].action for tr in rig.animation_data.nla_tracks if tr.name=='Idle')
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.action=original_idle;rig.animation_data.action_slot=original_idle.slots[0]
bpy.context.scene.frame_set(int(original_idle.frame_range[0]));bpy.context.view_layer.update()
target_reference={p.name:rig.matrix_world@p.matrix for p in rig.pose.bones}
rig.animation_data_clear()
for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.matrix_basis=Matrix.Identity(4)
robe_objects=load(ART/'runtime/part-robe.glb')
robe=next(o for o in robe_objects if o.type=='MESH' and o.name.startswith('Free_'))
for modifier in robe.modifiers:
 if modifier.type=='ARMATURE':modifier.object=rig
robe.parent=rig
garments=[robe]
for name in ['skirt','kilt']:
 imported=load(ART/'expansion'/(name+'.glb'))
 cloth=next(o for o in imported if o.type=='MESH' and o.name.startswith('Extra_'))
 for modifier in cloth.modifiers:
  if modifier.type=='ARMATURE':modifier.object=rig
 cloth.parent=rig;garments.append(cloth)
sources={};pins={}
paths={1:ROOT/'Viewer/Art/Quaternius/Animation/UAL1_Standard.glb',2:next((ROOT/'work/human-motion/ual2').rglob('UAL2_Standard.glb'))}
for number,path in paths.items():
 before=set(bpy.data.actions);source_objects=load(path);source=next(o for o in source_objects if o.type=='ARMATURE')
 actions={a.name.split('.')[0]:a for a in set(bpy.data.actions)-before}
 for track in source.animation_data.nla_tracks:track.mute=True
 sources[number]=(source,actions)
 pins[str(number)]={'file':str(path.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
reference_source,reference_actions=sources[1]
reference_action=reference_actions['Idle_Loop']
reference_source.animation_data.action=reference_action;reference_source.animation_data.action_slot=reference_action.slots[0]
bpy.context.scene.frame_set(int(reference_action.frame_range[0]));bpy.context.view_layer.update()
source_reference={p.name:reference_source.matrix_world@p.matrix for p in reference_source.pose.bones}
native=[b for b in rig.data.bones if not b.name.startswith('robe_')]
target_world=rig.matrix_world.copy();target_rotation=target_world.to_quaternion();target_inverse=target_world.inverted()
retargeted=[];metadata={}
for name,(number,original,loop) in CLIPS.items():
 source,actions=sources[number];action=actions[original]
 source.animation_data.action=action;source.animation_data.action_slot=action.slots[0]
 start,end=action.frame_range;count=round(end-start)
 segments=[(action,start,count)]
 if name in ['Sword_A','Sword_B']:
  recovery=actions[original+'_Rec'];a,b=recovery.frame_range
  segments.append((recovery,a,round(b-a)));count+=round(b-a)
 new=bpy.data.actions.new('Modern_'+name);rig.animation_data_create();rig.animation_data.action=new
 correspondence={b.name:('Head' if b.name=='head' else b.name) for b in native}
 scale=(target_world@rig.data.bones['pelvis'].head_local).z/(source.matrix_world@source.data.bones['pelvis'].head_local).z
 for frame in range(count+1):
  offset=frame;segment=segments[0]
  for candidate in segments:
   segment=candidate
   if offset<=candidate[2]:break
   offset-=candidate[2]
  source.animation_data.action=segment[0];source.animation_data.action_slot=segment[0].slots[0]
  source_frame=segment[1]+offset
  bpy.context.scene.frame_set(int(source_frame),subframe=source_frame%1);bpy.context.view_layer.update()
  desired={}
  for bone in native:
   source_name=correspondence[bone.name];sb=source.data.bones.get(source_name)
   rest=bone.matrix_local
   parent=bone.parent
   origin=(desired[parent.name]@parent.matrix_local.inverted()@rest.translation) if parent and parent.name in desired else rest.translation.copy()
   rotation=rest.to_quaternion()
   if sb and bone.name!='root':
    source_rest=source.matrix_world@sb.matrix_local
    source_pose=source.matrix_world@source.pose.bones[source_name].matrix
    target_rest=target_world@rest
    # Calibrate corresponding neutral standing poses in world space. Rest-only
    # copying treats our bent A bind as the source T bind and distorts the
    # head, elbows and finger rolls. Preserve the target's neutral anatomy.
    reference=source_reference[source_name]
    world_rotation=source_pose.to_quaternion()@reference.to_quaternion().inverted()@target_reference[bone.name].to_quaternion()
    if bone.name.startswith(('upperarm_','lowerarm_','thigh_','calf_','foot_','ball_')):
     # Limbs also need their anatomical bend plane aligned. Neutral-pose
     # rotation alone retains the target's outward knee roll and can cross
     # the ankles or lift a knee above the pelvis during a normal jog.
     target_axis=target_rest.to_quaternion()@Vector((0,1,0))
     source_axis=source_rest.to_quaternion()@Vector((0,1,0))
     align=target_axis.rotation_difference(source_axis)
     world_rotation=source_pose.to_quaternion()@source_rest.to_quaternion().inverted()@align@target_rest.to_quaternion()
    rotation=target_rotation.inverted()@world_rotation
    if bone.name=='pelvis':origin=target_inverse@target_reference[bone.name].translation+target_inverse.to_3x3()@((source_pose.translation-reference.translation)*scale)
   matrix=rotation.to_matrix().to_4x4();matrix.translation=origin;desired[bone.name]=matrix
   pose=rig.pose.bones[bone.name]
   kwargs={'parent_matrix':desired[parent.name],'parent_matrix_local':parent.matrix_local} if parent and parent.name in desired else {}
   pose.matrix_basis=bone.convert_local_to_pose(matrix,rest,invert=True,**kwargs)
   pose.keyframe_insert(data_path='rotation_quaternion',frame=frame+1,group=bone.name)
   if bone.name=='pelvis':pose.keyframe_insert(data_path='location',frame=frame+1,group=bone.name)
  if frame%30==0:print(name,frame,'/',count,flush=True)
 retargeted.append(new);metadata[name]={'source':number,'clip':original+(' + '+original+'_Rec' if len(segments)>1 else ''),'duration':count/FPS,'loop':loop,'frames':count+1}
 new.name=name
 rig.animation_data.action=None
 # Keep actions on the rig for both garment rebake and glTF NLA export.
 track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,new);track.mute=True
print('RETARGET COMPLETE',flush=True)
# Bake carry/guard variants in local joint space so an equipped hand does not
# swing a sword through the thigh. Legs keep the authored locomotion phase.
base_actions={track.name:track.strips[0].action for track in rig.animation_data.nla_tracks}
if 'Run' in base_actions:
 # The publisher's jog covers ~5.36 m/s. Build a shorter-stride intermediate
 # gait for native walking speed (~2.44 m/s) instead of playing it in slow
 # motion or accelerating the slow walk beyond a plausible cadence.
 run=base_actions['Run'];idle=base_actions['Idle'];count=metadata['Run']['frames']-1
 rig.animation_data.action=idle;rig.animation_data.action_slot=idle.slots[0]
 bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
 neutral={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
 jog=bpy.data.actions.new('Jog')
 for frame in range(count+1):
  rig.animation_data.action=run;rig.animation_data.action_slot=run.slots[0]
  bpy.context.scene.frame_set(frame+1);bpy.context.view_layer.update()
  poses={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
  rig.animation_data.action=jog
  for bone in native:
   pose=rig.pose.bones[bone.name];a=neutral[bone.name];b=poses[bone.name]
   amount=.55 if bone.name.startswith(('pelvis','thigh','calf','foot','ball')) else .72
   pose.matrix_basis=b;pose.rotation_quaternion=a.to_quaternion().slerp(b.to_quaternion(),amount)
   pose.location=a.translation.lerp(b.translation,amount)
   pose.keyframe_insert(data_path='rotation_quaternion',frame=frame+1,group=bone.name)
   if bone.name=='pelvis':pose.keyframe_insert(data_path='location',frame=frame+1,group=bone.name)
 retargeted.append(jog);base_actions['Jog']=jog
 metadata['Jog']={'source':'derivative','clip':'Jog_Fwd_Loop, shortened stride','duration':metadata['Run']['duration'],'loop':True,'frames':count+1}
 rig.animation_data.action=None;track=rig.animation_data.nla_tracks.new();track.name='Jog';track.strips.new('Jog',1,jog);track.mute=True
for prefix,stance in [('Sword','Sword_Idle'),('Unarmed','Punch_Jab')]:
 for base in (['Walk','Jog','Run','Sprint'] if prefix=='Sword' else ['Idle','Walk','Jog','Run','Sprint']):
  name=prefix+'_'+base;duration=metadata[base]['duration'];count=round(duration*FPS)
  new=bpy.data.actions.new(name)
  for frame in range(count+1):
   rig.animation_data.action=base_actions[base];rig.animation_data.action_slot=base_actions[base].slots[0]
   bpy.context.scene.frame_set(frame+1);bpy.context.view_layer.update()
   base_pose={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
   rig.animation_data.action=base_actions[stance];rig.animation_data.action_slot=base_actions[stance].slots[0]
   phase=1+(frame%max(1,round(metadata[stance]['duration']*FPS))) if prefix=='Sword' else 1
   bpy.context.scene.frame_set(phase);bpy.context.view_layer.update()
   guard_pose={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
   rig.animation_data.action=new
   for bone in native:
    pose=rig.pose.bones[bone.name];a=base_pose[bone.name];b=guard_pose[bone.name]
    weight=1. if bone.name.startswith(('clavicle','upperarm','lowerarm','hand','thumb','index','middle','ring','pinky')) else (.35 if bone.name in ['spine_02','spine_03'] else 0.)
    pose.matrix_basis=a;pose.rotation_quaternion=a.to_quaternion().slerp(b.to_quaternion(),weight)
    pose.keyframe_insert(data_path='rotation_quaternion',frame=frame+1,group=bone.name)
    if bone.name=='pelvis':pose.keyframe_insert(data_path='location',frame=frame+1,group=bone.name)
  retargeted.append(new);base_actions[name]=new
  metadata[name]={'source':'composite','clip':base+' + '+stance,'duration':duration,'loop':True,'frames':count+1}
  rig.animation_data.action=None;track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,new);track.mute=True
rig.animation_data.action=base_actions['Idle'];rig.animation_data.action_slot=base_actions['Idle'].slots[0]
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
neutral={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
bow=bpy.data.actions.new('Bow')
rig.animation_data.action=bow
for frame in range(37):
 phase=frame/36
 bend=math.sin(math.pi*phase)**2
 for bone in native:
  pose=rig.pose.bones[bone.name];pose.matrix_basis=neutral[bone.name]
  angle={'spine_01':.15,'spine_02':.17,'spine_03':.12,'neck':.06,'head':.06}.get(bone.name,0.)
  if angle:pose.rotation_quaternion=pose.rotation_quaternion@Quaternion((1,0,0),angle*bend)
  pose.keyframe_insert(data_path='rotation_quaternion',frame=frame+1,group=bone.name)
  if bone.name=='pelvis':pose.keyframe_insert(data_path='location',frame=frame+1,group=bone.name)
retargeted.append(bow);base_actions['Bow']=bow
metadata['Bow']={'source':'derivative','clip':'Neutral standing with smooth courtesy bow','duration':1.2,'loop':False,'frames':37}
rig.animation_data.action=None;track=rig.animation_data.nla_tracks.new();track.name='Bow';track.strips.new('Bow',1,bow);track.mute=True
# Cloth-safe attacks keep a stable lower-body guard and retain the authored
# upper-body strike. Wide lunges and fast high-knee gaits need different cloth
# topology/physics; never hide the legs to make those motions appear to fit.
for base in ['Sword_Attack','Sword_A','Sword_B','Sword_C','Heavy_Attack','Punch_Jab','Punch_Cross','Cast']:
 name=base+'_Cloth';count=metadata[base]['frames']-1;new=bpy.data.actions.new(name)
 stance='Sword_Idle' if base.startswith(('Sword','Heavy')) else 'Unarmed_Idle'
 for frame in range(count+1):
  rig.animation_data.action=base_actions[base];rig.animation_data.action_slot=base_actions[base].slots[0]
  bpy.context.scene.frame_set(frame+1);bpy.context.view_layer.update();authored={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
  rig.animation_data.action=base_actions[stance];rig.animation_data.action_slot=base_actions[stance].slots[0]
  bpy.context.scene.frame_set(1+frame%metadata[stance]['frames']);bpy.context.view_layer.update();guard={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
  rig.animation_data.action=new
  for bone in native:
   pose=rig.pose.bones[bone.name];a=guard[bone.name];b=authored[bone.name]
   lower=bone.name.startswith(('root','pelvis','thigh','calf','foot','ball'))
   amount=0. if lower else 1.
   pose.matrix_basis=a if lower else b
   pose.keyframe_insert(data_path='rotation_quaternion',frame=frame+1,group=bone.name)
   if bone.name=='pelvis':pose.keyframe_insert(data_path='location',frame=frame+1,group=bone.name)
 retargeted.append(new);base_actions[name]=new
 metadata[name]={'source':'composite','clip':base+' with stable '+stance+' lower body','duration':metadata[base]['duration'],'loop':False,'frames':count+1,'garment_safe':True}
 rig.animation_data.action=None;track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,new);track.mute=True
spec=importlib.util.spec_from_file_location('robe_motion',ROOT/'scripts/robe-motion.py');garment=importlib.util.module_from_spec(spec);spec.loader.exec_module(garment)
# A body with different leg lengths must be grounded again after retargeting.
# Translate only the presentation pelvis by one constant per clip; preserve
# authored vertical bounce/flight and leave the authoritative root stationary.
for name,action in base_actions.items():
 if name in ['Death','Jump','Jump_Start','Jump_Land']:continue
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 minimum=100.
 for frame in range(metadata[name]['frames']):
  bpy.context.scene.frame_set(frame+1);bpy.context.view_layer.update()
  minimum=min(minimum,*[(rig.matrix_world@rig.pose.bones['foot_'+side].matrix.translation).z for side in ['l','r']])
 shift=.085-minimum
 for frame in range(metadata[name]['frames']):
  bpy.context.scene.frame_set(frame+1);bpy.context.view_layer.update()
  pose=rig.pose.bones['pelvis'];matrix=pose.matrix.copy();matrix.translation.z+=shift/rig.matrix_world.to_scale().z;pose.matrix=matrix
  pose.keyframe_insert(data_path='location',frame=frame+1,group='pelvis')
 metadata[name]['grounding_offset_m']=shift
garment_report=garment.bake_envelopes(rig,body,garments,retargeted)
# Measure each body's stance-foot travel; runtime chooses a nearby gait and
# scales cadence from this result, not a guessed universal metres/second.
for name,action in base_actions.items():
 if not metadata[name]['loop']:continue
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 points={side:[] for side in ['l','r']}
 for frame in range(metadata[name]['frames']):
  bpy.context.scene.frame_set(frame+1);bpy.context.view_layer.update()
  for side in points:points[side].append(rig.matrix_world@rig.pose.bones['foot_'+side].matrix.translation)
 velocities=[]
 for side,positions in points.items():
  floor=min(p.z for p in positions)
  for a,b in zip(positions,positions[1:]):
   speed=abs(b.y-a.y)*FPS
   if max(a.z,b.z)<floor+.045 and speed>.08:velocities.append(speed)
 velocities.sort()
 metadata[name]['stance_speed_mps']=velocities[len(velocities)//2] if velocities else 0.
 # Publisher root-motion counterparts: 1.3m/40f, 5m/28f, 5.5m/20f.
 base=name.split('_')[-1]
 pace={'Walk':1.3/(40/FPS),'Jog':5/(28/FPS)*.55,'Run':5/(28/FPS),'Sprint':5.5/(20/FPS)}.get(base,0.)
 if pace:metadata[name]['native_speed_mps']=pace*scale
for track in rig.animation_data.nla_tracks:track.mute=False
rig.animation_data.action=None
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'human-motion.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,export_materials='NONE',export_morph=False)
(OUT/'motion.json').write_text(json.dumps({'female':FEMALE,'fps':FPS,'sources':pins,'clips':metadata,'garments':garment_report,'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'garment_recipe_sha256':hashlib.sha256((ROOT/'scripts/robe-motion.py').read_bytes()).hexdigest(),'source_manifest_sha256':hashlib.sha256((ROOT/'scripts/human-motion-inputs.json').read_bytes()).hexdigest()},indent=2))
print('HUMAN MOTION BUILT',FEMALE,len(metadata),flush=True)
