"""Extend the fixed human rig with pinned CC0 ranged and authored human actions.

Run with Blender, after prepare-human-motion.py; --female selects the female rig.
The accepted 45-clip input is retained locally, so reruns do not accumulate error.
Rider poses cover the human only, not a mount model or mounting gameplay.
"""
import bpy, json, math, hashlib, sys, shutil, importlib.util
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path(__file__).resolve().parents[1]
FEMALE='--female' in sys.argv
ART=ROOT/('Viewer/local-art/free-equipment-female' if FEMALE else 'Viewer/local-art/free-equipment')
OUT=ART/'motion'; BASE=ART/'motion-foundation'; BASE.mkdir(exist_ok=True)
meta=json.loads((OUT/'motion.json').read_text())
if not meta.get('coverage_extension'):
 assert len(meta['clips'])==45, 'Expected the accepted foundation'
 for name in ['human-motion.glb','motion.json']:shutil.copy2(OUT/name,BASE/name)
meta=json.loads((BASE/'motion.json').read_text())
PINS=json.loads((ROOT/'scripts/human-coverage-inputs.json').read_text())
for file,digest in PINS['animation_files'].items():
 assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==digest, file
bpy.context.preferences.filepaths.file_preview_type='NONE'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps=30
def load(path):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));return set(bpy.data.objects)-before
objects=load(BASE/'human-motion.glb');rig=next(o for o in objects if o.type=='ARMATURE')
body=next(o for o in objects if o.name=='Body')
actions={t.name:t.strips[0].action for t in rig.animation_data.nla_tracks}
for t in rig.animation_data.nla_tracks:t.mute=True
def sample(action,frame):
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
 return {p.name:p.matrix_basis.copy() for p in rig.pose.bones}
sample(actions['Idle'],1)
target_ref={p.name:rig.matrix_world@p.matrix for p in rig.pose.bones}
neutral=sample(actions['Idle'],1);guard=sample(actions['Sword_Idle'],1)
source_folder=ROOT/PINS['animation_folder'];sources={}
for group in ['General','CombatRanged']:
 before=set(bpy.data.actions);obs=load(source_folder/('Rig_Medium_'+group+'.glb'))
 source=next(o for o in obs if o.type=='ARMATURE')
 source_actions={a.name.split('.')[0]:a for a in set(bpy.data.actions)-before}
 for t in source.animation_data.nla_tracks:t.mute=True
 sources[group]=(source,source_actions)
source,sa=sources['General'];source.animation_data.action=sa['Idle_A'];source.animation_data.action_slot=sa['Idle_A'].slots[0]
bpy.context.scene.frame_set(int(sa['Idle_A'].frame_range[0]));bpy.context.view_layer.update()
source_ref={p.name:source.matrix_world@p.matrix for p in source.pose.bones}
mapping={'spine_01':'spine','spine_03':'chest','head':'head'}
for side in ['l','r']:
 for target,src in [('upperarm','upperarm'),('lowerarm','lowerarm'),('hand','hand')]:mapping[target+'_'+side]=src+'.'+side
native=[b for b in rig.data.bones if not b.name.startswith('robe_')]
world=rig.matrix_world.copy();worldq=world.to_quaternion()
def apply_basis(basis):
 for p in rig.pose.bones:p.matrix_basis=basis.get(p.name,Matrix.Identity(4))
 bpy.context.view_layer.update()
def aim(name,child,target):
 p=rig.pose.bones[name];origin=p.matrix.translation.copy()
 direction=rig.pose.bones[child].matrix.translation-origin
 rotation=direction.rotation_difference(target-origin)
 matrix=(rotation@p.matrix.to_quaternion()).to_matrix().to_4x4();matrix.translation=origin;p.matrix=matrix
 bpy.context.view_layer.update()
def ik(a,b,c,target,pole):
 pa=rig.pose.bones[a].matrix.translation.copy();pb=rig.pose.bones[b].matrix.translation.copy();pc=rig.pose.bones[c].matrix.translation.copy()
 la=(pb-pa).length;lb=(pc-pb).length;delta=target-pa;d=min(la+lb-.002,max(abs(la-lb)+.002,delta.length));axis=delta.normalized()
 bend=pole-pa-axis*(pole-pa).dot(axis)
 if bend.length<1e-5:bend=axis.cross(Vector((1,0,0)))
 x=(la*la-lb*lb+d*d)/(2*d);knee=pa+axis*x+bend.normalized()*math.sqrt(max(0,la*la-x*x))
 aim(a,b,knee);aim(b,c,pa+axis*d)
def rider(frame,count,name):
 p=rig.pose.bones['pelvis'];m=p.matrix.copy();m.translation.z+=.28+(.004 if name=='Rider_Idle' else .026 if name=='Rider_Run' else .012)*math.sin(2*math.pi*frame/count);p.matrix=m;bpy.context.view_layer.update()
 hip=p.matrix.translation.copy()
 for side,sign in [('l',1),('r',-1)]:
  foot=hip+Vector((sign*.30,-.08,-.60));ik('thigh_'+side,'calf_'+side,'foot_'+side,foot,hip+Vector((sign*.32,-.8,-.25)))
  # Keep the sole approximately level in stirrups.
  p=rig.pose.bones['foot_'+side];m=rig.data.bones[p.name].matrix_local.copy();m.translation=p.matrix.translation;p.matrix=m
 bpy.context.view_layer.update()
new_actions=[]
recipes={
 'Bow_Attack':('Ranged_Bow_Draw','Ranged_Bow_Release'),
 'Crossbow_Attack':('Ranged_2H_Shoot','Ranged_2H_Reload'),
 'Bow_Idle':('Ranged_Bow_Aiming_Idle',),'Crossbow_Idle':('Ranged_2H_Aiming',),
 'Turn':(), 'Salute':(), 'Fidget3':(),
 'Rider_Idle':(),'Rider_Walk':(),'Rider_Run':(),'Rider_Attack':(),
 'Rider_Bow':('Ranged_Bow_Draw','Ranged_Bow_Release'),
 'Rider_Crossbow':('Ranged_2H_Shoot','Ranged_2H_Reload'),'Rider_Slap':()
}
ranged_wrists={}
recipes={name:recipes[name] for name in ["Bow_Idle","Crossbow_Idle"]+list(n for n in recipes if n not in ["Bow_Idle","Crossbow_Idle"])}
for name,clips in recipes.items():
 source,sa=sources['CombatRanged']
 segments=[(sa[c],round(sa[c].frame_range[0]),round(sa[c].frame_range[1]-sa[c].frame_range[0])) for c in clips]
 count=sum(s[2] for s in segments) if segments else (48 if name in ['Salute','Fidget3'] else 36)
 count=max(2,count);new=bpy.data.actions.new(name)
 for frame in range(count+1):
  phase=frame/count;wave=math.sin(math.pi*phase)**2
  basis=sample(actions['Sword_A'],1+phase*(actions['Sword_A'].frame_range[1]-1)) if name=='Rider_Attack' else (guard if name.startswith('Rider') else neutral)
  rig.animation_data.action=None;apply_basis(basis)
  if clips:
   offset=frame
   for segment in segments:
    if offset<=segment[2]:break
    offset-=segment[2]
   source.animation_data.action=segment[0];source.animation_data.action_slot=segment[0].slots[0]
   bpy.context.scene.frame_set(segment[1]+min(offset,segment[2]));bpy.context.view_layer.update()
   apply_basis(basis)
   desired={}
   for bone in native:
    p=rig.pose.bones[bone.name];matrix=p.matrix.copy()
    if bone.name in mapping:
     sn=mapping[bone.name];pose=source.matrix_world@source.pose.bones[sn].matrix
     rotation=pose.to_quaternion()@source_ref[sn].to_quaternion().inverted()@target_ref[bone.name].to_quaternion()
     # Match the anatomical axes of unlike A/T bind poses.
     if bone.name.startswith(('upperarm','lowerarm')):
      sr=source.matrix_world@source.data.bones[sn].matrix_local;tr=world@bone.matrix_local
      align=(tr.to_quaternion()@Vector((0,1,0))).rotation_difference(sr.to_quaternion()@Vector((0,1,0)))
      rotation=pose.to_quaternion()@sr.to_quaternion().inverted()@align@tr.to_quaternion()
     q=worldq.inverted()@rotation;matrix=q.to_matrix().to_4x4();matrix.translation=p.matrix.translation
    # Parents have just moved; nonmapped descendants inherit their neutral basis.
    if bone.name in mapping:p.matrix=matrix;bpy.context.view_layer.update()
  if clips:
   # Retain the source torso timing, but solve the unlike arm proportions to
   # shared grip targets. This also establishes a consistent prop fit frame.
   ratio=rig.data.bones['head'].head_local.z/1.5793484
   if 'Bow' in name:
    draw=min(1.,phase*2.5) if not name.endswith('Idle') else 1.
    right=Vector((-.12,-.12,1.43)).lerp(Vector((.10,-.40,1.39)),1-draw)
    left=Vector((.23,-.48,1.40))
   else:
    right=Vector((-.11,-.30,1.27));left=Vector((.13,-.48,1.31))
    if not name.endswith('Idle'):right+=Vector((0,.025*math.sin(phase*math.tau),.015*math.sin(phase*math.tau)))
   for side,target,sign in [('r',right,-1),('l',left,1)]:ik('upperarm_'+side,'lowerarm_'+side,'hand_'+side,target*ratio,Vector((sign*.55,-.15,1.15))*ratio)
   # Hold the calibrated wrist frame while the arms draw/reload. Inheriting
   # the IK parent's roll used to rotate the prop through ninety degrees.
   family='bow' if 'Bow' in name else 'crossbow'
   for side in ['l','r']:
    p=rig.pose.bones['hand_'+side];key=(family,side)
    if key not in ranged_wrists:ranged_wrists[key]=p.matrix.to_quaternion()
    m=ranged_wrists[key].to_matrix().to_4x4();m.translation=p.matrix.translation;p.matrix=m
   bpy.context.view_layer.update()
  if name=='Turn':
   p=rig.pose.bones['pelvis'];p.rotation_quaternion=p.rotation_quaternion@Quaternion(Vector((0,1,0)),.35*math.sin(2*math.pi*phase))
   for side,offset in [('l',0),('r',math.pi)]:
    p=rig.pose.bones['thigh_'+side];p.rotation_quaternion=p.rotation_quaternion@Quaternion(Vector((1,0,0)),.13*math.sin(2*math.pi*phase+offset))
  if name=='Salute':
   start=rig.pose.bones['hand_r'].matrix.translation.copy();target=rig.pose.bones['head'].matrix.translation+Vector((-.16,-.12,.045))
   amount=max(0.,min(1.,phase*4,(1-phase)*4));before=rig.pose.bones['hand_r'].matrix.to_quaternion();ik('upperarm_r','lowerarm_r','hand_r',start.lerp(target,amount),Vector((-.65,-.2,1.5)))
   p=rig.pose.bones['hand_r'];m=before.slerp(Matrix(((0,1,0),(-1,0,0),(0,0,1))).to_quaternion(),amount).to_matrix().to_4x4();m.translation=p.matrix.translation;p.matrix=m
  if name=='Fidget3':
   for side,sign in [('l',1),('r',-1)]:
    start=rig.pose.bones['hand_'+side].matrix.translation.copy();target=Vector((sign*.09,-.20,1.16))
    ik('upperarm_'+side,'lowerarm_'+side,'hand_'+side,start.lerp(target,wave),Vector((sign*.5,-.25,1.0)))
   p=rig.pose.bones['head'];p.rotation_quaternion=p.rotation_quaternion@Quaternion(Vector((0,1,0)),.18*math.sin(2*math.pi*phase))
  if name.startswith('Rider'):
   rider(frame,count,name)
   if name=='Rider_Slap':
    start=rig.pose.bones['hand_r'].matrix.translation.copy();target=rig.pose.bones['pelvis'].matrix.translation+Vector((-.30,-.36,-.12))
    ik('upperarm_r','lowerarm_r','hand_r',start.lerp(target,wave),Vector((-.55,-.15,1.5)))
  rig.animation_data.action=new
  if new.slots:rig.animation_data.action_slot=new.slots[0]
  for p in rig.pose.bones:
   p.rotation_mode='QUATERNION';p.keyframe_insert(data_path='rotation_quaternion',frame=frame+1,group=p.name)
   if p.name=='pelvis':p.keyframe_insert(data_path='location',frame=frame+1,group=p.name)
  if frame%40==0:print('COVERAGE MOTION',name,frame,count,flush=True)
 new_actions.append(new);actions[name]=new
 meta['clips'][name]={'source':'KayKit CC0' if clips else 'Britannia Reborn authored','clip':' + '.join(clips) if clips else name,'duration':count/30,'frames':count+1,'loop':name.endswith(('Idle','Walk','Run')),'rider_human_only':name.startswith('Rider')}
 if name in ['Rider_Walk','Rider_Run']:meta['clips'][name]['native_speed_mps']=2.44 if name.endswith('Walk') else 4.88
 rig.animation_data.action=None;t=rig.animation_data.nla_tracks.new();t.name=name;t.strips.new(name,1,new);t.mute=True
# Reuse the exact accepted garment envelope algorithm for every new action.
garments=[]
for path,prefix in [(ART/'runtime/part-robe.glb','Free_'),(ART/'expansion/skirt.glb','Extra_'),(ART/'expansion/kilt.glb','Extra_')]:
 obs=load(path);ob=next(o for o in obs if o.type=='MESH' and o.name.startswith(prefix))
 for mod in ob.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
 ob.parent=rig;garments.append(ob)
spec=importlib.util.spec_from_file_location('robe',ROOT/'scripts/robe-motion.py');robe=importlib.util.module_from_spec(spec);spec.loader.exec_module(robe)
report=robe.bake_envelopes(rig,body,garments,new_actions)
for t in rig.animation_data.nla_tracks:t.mute=False
rig.animation_data.action=None
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'human-motion.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,export_materials='NONE',export_morph=False)
meta['coverage_extension']={'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'foundation_sha256':hashlib.sha256((BASE/'human-motion.glb').read_bytes()).hexdigest(),'source_manifest_sha256':hashlib.sha256((ROOT/'scripts/human-coverage-inputs.json').read_bytes()).hexdigest(),'garments':report,'scope':'Human rider poses only; horse model and mounting gameplay remain deferred.'}
(OUT/'motion.json').write_text(json.dumps(meta,indent=2));print('COVERAGE MOTION READY',FEMALE,len(meta['clips']),flush=True)
