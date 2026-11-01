"""Bake the pinned CC0 rat's actual constrained rig; keep source comparison.

Run using trusted Blender --factory-startup --disable-autoexec. Source scripts
are disabled again when opening the blend. No game input is read by this recipe.
"""
import bpy, hashlib, json, math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[1]
PINS=json.loads((ROOT/'scripts/rat-inputs.json').read_text(encoding='utf-8'))
SOURCE=ROOT/'work/creatures/rat-cc0/source'
OUT=ROOT/'Viewer/local-art/rat'
OUT.mkdir(parents=True,exist_ok=True)
for pin in PINS['files']:
    path=SOURCE/pin['member']
    assert path.stat().st_size==pin['bytes'] and hashlib.sha256(path.read_bytes()).hexdigest()==pin['sha256']
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'rat.blend'),load_ui=False,use_scripts=False)
mesh=bpy.data.objects['Rat'];rig=bpy.data.objects['Rat_Armature'];scene=bpy.context.scene
SOURCE_FPS=scene.render.fps/scene.render.fps_base
FPS=60
source_actions={name:bpy.data.actions[name] for name in ['idle-loop','walk-loop','run-loop','attack','death']}
source_triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons)
assert source_triangles==270 and len(rig.data.bones)==21
for modifier in mesh.modifiers:
    if modifier.type=='ARMATURE':modifier.use_deform_preserve_volume=False
for obj in list(bpy.data.objects):
    if obj not in [mesh,rig]:bpy.data.objects.remove(obj,do_unlink=True)
for collection in bpy.data.collections:collection.hide_viewport=False;collection.hide_render=False
for obj in [mesh,rig]:obj.hide_viewport=False;obj.hide_render=False;obj.hide_set(False)

# Capture evaluated IK/tracking, not merely the control curves. Exported motion
# keeps every source bone; original constraints are then removed, not evaluated
# a second time over the baked poses.
samples={};metadata={}
for label,name in [('Idle','idle-loop'),('Walk','walk-loop'),('Run','run-loop'),('Attack','attack'),('Death','death')]:
    action=source_actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    start,end=action.frame_range;duration=(end-start)/SOURCE_FPS;count=round(duration*FPS)+1
    frames=[]
    for frame in range(count):
        at=start+(end-start)*frame/(count-1);scene.frame_set(math.floor(at),subframe=at%1);bpy.context.view_layer.update()
        frames.append({bone.name:bone.matrix.copy() for bone in rig.pose.bones})
    samples[label]=frames
    metadata[label]={'duration':duration,'loop':label in ['Idle','Walk','Run'],'origin':'Baked evaluated CC0 author clip '+name+'; not recovered UO choreography','source_action':name}
rig.animation_data_clear();rig.animation_data_create();scene.render.fps=FPS;scene.render.fps_base=1.
for bone in rig.pose.bones:
    for constraint in list(bone.constraints):bone.constraints.remove(constraint)
    bone.rotation_mode='QUATERNION';bone.matrix_basis=Matrix.Identity(4)

# Additional actions are authored over a neutral evaluated source pose. Their
# paths remain distinct, and are never described as extra recovered clips.
def envelope(u):return math.sin(math.pi*u)**2
def rotate(matrices,name,axis,angle):
    pivot=matrices[name].translation.copy();change=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-pivot)
    parent=rig.data.bones[name]
    for bone in [parent,*parent.children_recursive]:matrices[bone.name]=change@matrices[bone.name]
for label,duration in [('Hit',.45),('Fidget',2.),('Eat',2.4),('Attack2',.8),('Alert',1.2)]:
    frames=[];count=round(duration*FPS)+1
    for frame in range(count):
        u=frame/(count-1);a=envelope(u);matrices={name:matrix.copy() for name,matrix in samples['Idle'][0].items()}
        if label=='Eat':
            rotate(matrices,'neck','X',.65*a);rotate(matrices,'head','X',-.5*a)
            rotate(matrices,'mouth','X',.18*a*(.5+.5*math.sin(math.tau*u*7)))
        elif label=='Hit':
            rotate(matrices,'spine','Z',.18*a);rotate(matrices,'neck','X',-.16*a)
        elif label=='Attack2':
            rotate(matrices,'neck','Z',.4*a*math.cos(math.pi*u));rotate(matrices,'head','X',-.18*a)
            rotate(matrices,'mouth','X',.35*a)
        else:
            rotate(matrices,'neck','Z',(.38 if label=='Fidget' else .2)*a*math.sin(math.tau*u))
            rotate(matrices,'tailbone','Z',.18*a*math.sin(math.tau*u*2))
        frames.append(matrices)
    samples[label]=frames;metadata[label]={'duration':duration,'loop':label=='Fidget','origin':'Authored rat category on the CC0 rig; not source or UO choreography'}

material=bpy.data.materials.new('CC0 rat matte fur');material.use_nodes=True
nodes=material.node_tree.nodes;shader=nodes.get('Principled BSDF');texture=nodes.new('ShaderNodeTexImage')
texture.image=bpy.data.images.load(str(SOURCE/'rat.png'),check_existing=False)
material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
shader.inputs['Roughness'].default_value=.9;shader.inputs['Metallic'].default_value=0.
mesh.data.materials.clear();mesh.data.materials.append(material)
for polygon in mesh.data.polygons:polygon.use_smooth=True

container=bpy.data.objects.new('OrdinaryRatScale',None);scene.collection.objects.link(container);container.scale=(.15,)*3
rig.parent=container
# The mesh is already parented to the source armature.
assert mesh.parent==rig

def bind_reset():
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=True
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()

def set_pose(matrices):
    # Assign local bases from the complete sampled world pose. Reading a
    # parent's previously evaluated matrix while assigning children makes the
    # result depend on the preceding frame and accumulates false floor lifts.
    for bone in rig.pose.bones:
        inherited=bone.parent.bone.matrix_local@matrices[bone.parent.name].inverted() if bone.parent else Matrix.Identity(4)
        bone.matrix_basis=bone.bone.matrix_local.inverted()@inherited@matrices[bone.name]

def export(treatment,subdivisions):
    bind_reset()
    active=mesh
    if subdivisions:
        active=mesh.copy();active.data=mesh.data.copy();scene.collection.objects.link(active)
        # Rest-space subdivision interpolates original skin weights and UVs.
        sub=active.modifiers.new('Rounded silhouette','SUBSURF');sub.levels=subdivisions
        bpy.context.view_layer.objects.active=active
        bpy.ops.object.modifier_move_up(modifier=sub.name)
        bpy.ops.object.modifier_apply(modifier=sub.name)
    corrections={};actions=[];bake_error=0.;clip_metadata={}
    for label,source_frames in samples.items():
        frames=source_frames
        action=bpy.data.actions.new(treatment+'_'+label);rig.animation_data.action=action;corrections[label]=[]
        duration=metadata[label]['duration']
        times=[duration*i/(len(frames)-1) for i in range(len(frames))]
        if treatment=='modern' and label in ['Walk','Run']:
            # The original 0..15-frame cycles omit the repeated frame16.
            # Reconstruct that last interval explicitly; preserve the source
            # comparison and document this authored continuity correction.
            duration+=1/SOURCE_FPS
            frames=[*source_frames,source_frames[0]];times.append(duration)
        clip_metadata[label]=dict(metadata[label],duration=duration)
        for i,matrices in enumerate(frames):
            at=1+times[i]*FPS;scene.frame_set(math.floor(at),subframe=at%1)
            set_pose(matrices)
            bpy.context.view_layer.update()
            for bone in rig.pose.bones:bake_error=max(bake_error,(bone.matrix.translation-matrices[bone.name].translation).length*.15)
            evaluated=active.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh()
            low=min(v.co.z for v in data.vertices);evaluated.to_mesh_clear()
            # Root correction uses the actual skin; crouches and airborne paws
            # stay visible. Source-only comparison retains the exact source.
            correction=max(0.,-low) if treatment!='source' else 0.
            root=rig.pose.bones['root'];matrix=root.matrix.copy();matrix.translation.z+=correction;root.matrix=matrix
            corrections[label].append(correction*.15)
            for bone in rig.pose.bones:
                for channel in ['location','rotation_quaternion','scale']:bone.keyframe_insert(data_path=channel,frame=at,group=bone.name)
        track=rig.animation_data.nla_tracks.new();track.name=label;strip=track.strips.new(label,1,action);strip.action_slot=action.slots[0];track.mute=True
        actions.append(track);rig.animation_data.action=None
    for track in actions:track.mute=False
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [container,rig,active]:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    path=OUT/('rat-'+treatment+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,
        export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,export_frame_step=1,
        export_yup=True,export_texcoords=True,export_normals=True,export_tangents=True,export_influence_nb=4)
    assert bake_error<.00001,('Constraint bake changed the sampled source/declared pose',bake_error)
    result={'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'triangles':sum(len(p.vertices)-2 for p in active.data.polygons),'clips':clip_metadata,'bake_position_error_max_m':bake_error,
        'subdivision_levels':subdivisions,'floor_correction_max_m':{name:max(values) for name,values in corrections.items()}}
    for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
    if active!=mesh:bpy.data.objects.remove(active,do_unlink=True)
    return result

report={'source':PINS,'source_fps':SOURCE_FPS,'source_triangles':source_triangles,'bones':len(rig.data.bones),'clips':metadata,
    'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'scale':.15,'treatments':{}}
for treatment,level in [('source',0),('modern',2)]:report['treatments'][treatment]=export(treatment,level)
(OUT/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('RAT CANDIDATE:',report['treatments'],flush=True)
