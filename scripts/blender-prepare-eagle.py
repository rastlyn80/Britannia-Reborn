"""Pinned independent eagle: preserve donor flight and author grounded actions.

Run trusted Blender with --factory-startup --disable-autoexec --python-exit-code 1.
This prepares an unaccepted candidate, never installs a native body route.
"""
import bpy, hashlib, json, math
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
PINS=json.loads((ROOT/'scripts/eagle-inputs.json').read_text(encoding='utf-8'))
SOURCE=ROOT/'work/creatures/animals-vol2/source'/PINS['member']
OUT=ROOT/'Viewer/local-art/eagle';OUT.mkdir(parents=True,exist_ok=True)
assert SOURCE.stat().st_size==PINS['member_bytes'] and hashlib.sha256(SOURCE.read_bytes()).hexdigest()==PINS['member_sha256']
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
rig=bpy.data.objects['EagleArmature'];mesh=bpy.data.objects['Eagle'];scene=bpy.context.scene
assert len(rig.data.bones)==24 and sum(len(p.vertices)-2 for p in mesh.data.polygons)==1532
for collection in bpy.data.collections:collection.hide_viewport=False;collection.hide_render=False
for obj in list(bpy.data.objects):
    if obj not in [rig,mesh]:bpy.data.objects.remove(obj,do_unlink=True)
for obj in [rig,mesh]:obj.hide_viewport=False;obj.hide_render=False;obj.hide_set(False)
donor_modifiers=[{'name':m.name,'type':m.type,'viewport_enabled':m.show_viewport,'render_enabled':m.show_render,'levels':getattr(m,'levels',None)} for m in mesh.modifiers]
for modifier in list(mesh.modifiers):
    if modifier.type=='ARMATURE':modifier.use_deform_preserve_volume=False
    elif modifier.type=='SUBSURF':mesh.modifiers.remove(modifier)
FPS=120;SCALE=.15;SOURCE_FPS=scene.render.fps/scene.render.fps_base
object_anchor=list(rig.location);mesh_to_rig=rig.matrix_world.inverted()@mesh.matrix_world
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
samples={};clips={};source_loop_gap={}
for name,donor in [('AirIdle','Idle'),('Fly','Flying')]:
    action=bpy.data.actions[donor];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    start,end=action.frame_range;duration=(end-start)/SOURCE_FPS;count=round(duration*FPS)+1;frames=[]
    for i in range(count):
        at=start+(end-start)*i/(count-1);scene.frame_set(math.floor(at),subframe=at%1);bpy.context.view_layer.update()
        frames.append({b.name:b.matrix.copy() for b in rig.pose.bones})
    samples[name]=frames;clips[name]={'duration':duration,'loop':False,'source_action':donor,'support_policy':'airborne','origin':'Evaluated Quaternius donor '+donor+'; source timing preserved, not recovered UO motion'}
    source_loop_gap[name]=max((frames[0][n].translation-frames[-1][n].translation).length*SCALE for n in frames[0])
rig.animation_data_clear();rig.animation_data_create()
for bone in rig.pose.bones:
    bone.rotation_mode='QUATERNION';bone.matrix_basis=Matrix.Identity(4)
    for constraint in list(bone.constraints):bone.constraints.remove(constraint)
# Preserve the mesh-to-rig bind transform. Only the donor object anchor is
# normalized; zeroing the mesh or its parent inverse would corrupt skinning.
rig.location=(0.,0.,0.)
scene.render.fps=FPS;scene.render.fps_base=1.
for material in mesh.data.materials:
    colour=tuple(material.node_tree.nodes['Diffuse BSDF'].inputs['Color'].default_value)
    material.node_tree.nodes.clear();shader=material.node_tree.nodes.new('ShaderNodeBsdfPrincipled');output=material.node_tree.nodes.new('ShaderNodeOutputMaterial');material.node_tree.links.new(shader.outputs['BSDF'],output.inputs['Surface'])
    shader.inputs['Base Color'].default_value=colour;shader.inputs['Roughness'].default_value=.88;shader.inputs['Metallic'].default_value=0.;material.name='Eagle'+material.name
for polygon in mesh.data.polygons:polygon.use_smooth=True
container=bpy.data.objects.new('IndependentEagleScale',None);scene.collection.objects.link(container);container.scale=(SCALE,)*3;container.rotation_euler.z=math.pi;rig.parent=container

def copy(pose):return {n:m.copy() for n,m in pose.items()}
def smooth(u):u=max(0.,min(1.,u));return u*u*(3.-2.*u)
def pulse(u):return math.sin(math.pi*u)**2
def delta(pose,name,transform):
    for bone in [rig.data.bones[name],*rig.data.bones[name].children_recursive]:pose[bone.name]=transform@pose[bone.name]
def turn(pose,name,axis,angle):
    pivot=pose[name].translation.copy();delta(pose,name,Matrix.Translation(pivot)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-pivot))
def shift(pose,name,offset):delta(pose,name,Matrix.Translation(Vector(offset)))
def local(pose,name):
    parent=rig.data.bones[name].parent
    inherited=rest[parent.name]@pose[parent.name].inverted() if parent else Matrix.Identity(4)
    return rest[name].inverted()@inherited@pose[name]
def blend(a,b,u):
    result={}
    for bone in rig.data.bones:
        x=local(a,bone.name);y=local(b,bone.name);xt,xr,xs=x.decompose();yt,yr,ys=y.decompose()
        basis=Matrix.LocRotScale(xt.lerp(yt,u),xr.slerp(yr,u),xs.lerp(ys,u))
        inherited=result[bone.parent.name]@rest[bone.parent.name].inverted() if bone.parent else Matrix.Identity(4)
        result[bone.name]=inherited@rest[bone.name]@basis
    return result
def pose_set(pose):
    for bone in rig.pose.bones:bone.matrix_basis=local(pose,bone.name)
    bpy.context.view_layer.update()
def skin_low(pose,materials=None):
    pose_set(pose);evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh()
    indices={i for p in data.polygons if materials is None or mesh.data.materials[p.material_index].name in materials for i in p.vertices}
    value=min((evaluated.matrix_world@data.vertices[i].co).z for i in indices);evaluated.to_mesh_clear();return value

perched=copy(samples['AirIdle'][0]);body=perched['Bone']@rest['Bone'].inverted()
for shoulder,yaw in [('Bone.007',-math.pi/2),('Bone.012',math.pi/2)]:
    for bone in [rig.data.bones[shoulder],*rig.data.bones[shoulder].children_recursive]:perched[bone.name]=body@rest[bone.name]
    turn(perched,shoulder,'X',math.pi/2);turn(perched,shoulder,'Z',yaw)
    # Coherent feather-fan packing avoids the donor's collapsed LBS panels at
    # alternating 180-degree elbow bends. It is authored packing, not anatomy
    # recovery or simulated individual feathers. Scale axes follow the bone,
    # so glTF TRS can represent the transformation without hidden shear.
    pivot=perched[shoulder].copy();packing=pivot@Matrix.Diagonal((1.,.55,.3,1.))@pivot.inverted();delta(perched,shoulder,packing)
turn(perched,'Bone','X',.4)
for name in ['Bone.016','Bone.020']:turn(perched,name,'X',-.4)
for name in ['Bone.007','Bone.012']:turn(perched,name,'X',-.12)
turn(perched,'Bone.004','X',-.6)
perched_low=skin_low(perched,{'EagleClaws','EagleBeak'})
assert skin_low(perched)>=perched_low-.001,'Fold wings/tail above the soles; do not lift the whole bird to hide penetration'
shift(perched,'Bone',(0.,0.,-perched_low/SCALE))

# Donor flight has a constant measured clearance across the complete cycle.
# Never let the current lowest feather drive the torso up/down each frame.
flight_low=min(skin_low(p) for frames in samples.values() for p in frames)
flight_lift=(.08-flight_low)/SCALE
original_samples={name:[copy(p) for p in frames] for name,frames in samples.items()}
for frames in samples.values():
    for pose in frames:shift(pose,'Bone',(0.,0.,flight_lift))

# A short, explicit closing interval preserves every evaluated source frame
# before returning to the start. Raw Fly/AirIdle comparisons remain separate.
run_frames=[copy(p) for p in samples['Fly']];close_count=round(.12*FPS)
for i in range(1,close_count+1):run_frames.append(blend(samples['Fly'][-1],samples['Fly'][0],smooth(i/close_count)))
samples['Run']=run_frames;clips['Run']={'duration':(len(run_frames)-1)/FPS,'loop':True,'support_policy':'airborne','origin':'Donor Flying plus declared 0.12-second local-TRS closing interval; constant full-cycle measured clearance'}

for name,duration in [('Idle',2.),('Walk',.72),('Attack',.65),('Attack2',.75),('Hit',.45),('Eat',2.2),('Fidget',2.4),('Alert',1.1),('TakeOff',.7),('Land',.8),('Death',1.2),('Death2',1.2)]:
    frames=[];count=round(duration*FPS)+1
    for i in range(count):
        u=i/(count-1);amount=pulse(u);pose=copy(perched)
        if name in ['TakeOff','Land']:
            w=smooth(u) if name=='TakeOff' else 1.-smooth(u);pose=blend(perched,samples['Fly'][0],w)
        elif name=='Walk':
            # Wing-assisted short hops are authored separately from flight;
            # no claim is made that source Flying was a walking donor clip.
            hop=pulse(u);shift(pose,'Bone',(0.,0.,.18*hop))
            for leg,sign in [('Bone.016',1.),('Bone.020',-1.)]:turn(pose,leg,'X',.18*sign*math.sin(math.tau*u))
            for shoulder,sign in [('Bone.007',1.),('Bone.012',-1.)]:turn(pose,shoulder,'Y',sign*.16*hop)
        elif name=='Eat':
            turn(pose,'Bone.001','X',-.4*amount)
            turn(pose,'Bone.002','X',-1.1*amount);turn(pose,'Bone.003','X',.3*amount)
            turn(pose,'Bone.003','Z',.035*amount*math.sin(math.tau*u*5))
        elif name in ['Attack','Attack2']:
            turn(pose,'Bone.002','X',-.45*amount);turn(pose,'Bone.003','X',-.25*amount)
            turn(pose,'Bone.003','Z',(.18 if name=='Attack' else -.18)*amount)
        elif name=='Hit':turn(pose,'Bone.001','Z',.14*amount);turn(pose,'Bone.002','X',.25*amount)
        elif name.startswith('Death'):
            collapse=smooth(u/.85)
            for shoulder in ['Bone.007','Bone.012']:
                pivot=pose[shoulder].copy();delta(pose,shoulder,pivot@Matrix.Diagonal((1.-.5*collapse,1.,1.,1.))@pivot.inverted())
            # Close the source's broad white tail fan for the resting cadaver.
            pivot=pose['Bone.004'].copy();delta(pose,'Bone.004',pivot@Matrix.Diagonal((1.,1.,1.-.6*collapse,1.))@pivot.inverted())
            turn(pose,'Bone','Y',(1.5 if name=='Death' else -1.5)*collapse)
            turn(pose,'Bone.002','X',-.35*collapse)
            for leg in ['Bone.016','Bone.020']:turn(pose,leg,'X',.4*collapse)
        else:
            turn(pose,'Bone.003','Z',(.12 if name=='Idle' else .35)*amount*math.sin(math.tau*u))
            turn(pose,'Bone.004','Z',.05*math.sin(math.tau*u))
        frames.append(pose)
    samples[name]=frames;clips[name]={'duration':(count-1)/FPS,'loop':name in ['Idle','Walk','Fidget'],'support_policy':'transition' if name in ['TakeOff','Land'] else 'hop' if name=='Walk' else 'grounded','origin':'Authored category on preserved independent rig; not donor motion or original UO choreography'}

for category in ['Hit','Attack','Attack2','Death','Death2']:
    name='Air'+category;duration=clips[category]['duration'];count=round(duration*FPS)+1;frames=[]
    for i in range(count):
        u=i/(count-1);pose=copy(samples['Fly'][0])
        if category.startswith('Death'):
            pose=blend(pose,samples[category][i],smooth(u/.65))
        else:
            turn(pose,'Bone.002','X',(.25 if category=='Hit' else -.45)*pulse(u))
            turn(pose,'Bone.003','Z',(.18 if category!='Attack2' else -.18)*pulse(u))
        frames.append(pose)
    samples[name]=frames;clips[name]={'duration':duration,'loop':False,'support_policy':'transition' if category.startswith('Death') else 'airborne','origin':'Authored airborne '+category+' variation; donor first flight pose preserved at start, death ends at identical grounded cadaver pose'}

def reset():
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=True
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
def export(treatment,poses):
    actions=[];diagnostics={};max_error=0.;max_basis_error=0.
    for name,frames in poses.items():
        action=bpy.data.actions.new(treatment+'_'+name);rig.animation_data.action=action;adjustments=[]
        for i,pose in enumerate(frames):
            at=1+clips[name]['duration']*FPS*i/(len(frames)-1);scene.frame_set(math.floor(at),subframe=at%1);pose_set(pose)
            max_error=max(max_error,max((b.matrix.translation-pose[b.name].translation).length*SCALE for b in rig.pose.bones))
            max_basis_error=max(max_basis_error,max(max(abs(b.matrix[r][c]-pose[b.name][r][c]) for r in range(3) for c in range(3)) for b in rig.pose.bones))
            correction=0.
            if treatment=='modern':
                low=skin_low(pose)
                # Death ends exactly on its eventual static-corpse plane.
                correction=-low if name.startswith('Death') else max(0.,-low)
                if name.startswith('AirDeath'):
                    correction=max(0.,-low)-max(0.,low)*smooth((i/(len(frames)-1)-.4)/.25)
                if correction:
                    corrected=copy(pose);shift(corrected,'Bone',(0.,0.,correction/SCALE));pose_set(corrected)
            adjustments.append(correction)
            for bone in rig.pose.bones:
                for channel in ['location','rotation_quaternion','scale']:bone.keyframe_insert(data_path=channel,frame=at,group=bone.name)
        track=rig.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,1,action);strip.action_slot=action.slots[0];track.mute=True;actions.append(track);rig.animation_data.action=None
        diagnostics[name]={'floor_correction_min_m':min(adjustments),'floor_correction_max_m':max(adjustments)}
    assert max_error<.00001 and max_basis_error<.0001,('Unrepresentable eagle TRS',max_error,max_basis_error)
    for track in actions:track.mute=False
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [container,rig,mesh]:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig;path=OUT/('eagle-'+treatment+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_anim_slide_to_zero=True,export_yup=True,export_influence_nb=8,export_normals=True)
    result={'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'bake_position_error_max_m':max_error,'bake_basis_error_max':max_basis_error,'floor':diagnostics}
    for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
    reset();return result

report={'source':PINS,'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_triangles':1532,'bones':24,'source_fps':SOURCE_FPS,'sample_rate':FPS,'scale':SCALE,'donor_modifiers':donor_modifiers,'subdivision_policy':'Raw 1532-triangle cage for source comparison; donor subdivision modifier removed before measuring/exporting either skin. Modern cage receives one explicitly applied subdivision before linear skinning.','source_object_anchor_removed':object_anchor,'mesh_to_rig_bind_transform':[list(row) for row in mesh_to_rig],'source_loop_gap_m':source_loop_gap,'flight_constant_lift_m':flight_lift*SCALE,'flight_clearance_m':.08,'clips':clips,'wing_packing':{'method':'Common local-bone affine fan, no alternating folded LBS elbows','local_scale':[1.,.55,.3],'death_tail_local_scale':[1.,1.,.4],'scope':'Authored landed compression, source flight full span retained; extra wing/tail closing for cadavers'},'treatments':{}}
comparison_samples={name:original_samples.get(name,frames) for name,frames in samples.items()}
report['comparison_scope']='Source cage with raw donor AirIdle/Fly and explicitly authored remaining categories; only the former two are original donor motion.'
report['treatments']['source']=export('source',comparison_samples)
reset();bpy.context.view_layer.objects.active=mesh
sub=mesh.modifiers.new('Rounded independent feather and head cage','SUBSURF');sub.levels=1;bpy.ops.object.modifier_move_up(modifier=sub.name);bpy.ops.object.modifier_apply(modifier=sub.name)

def material(name,colour,roughness):
    result=bpy.data.materials.new(name);result.use_nodes=True;shader=result.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=colour;shader.inputs['Roughness'].default_value=roughness;return result
eye_materials=[material('EagleEyeDark',(.008,.006,.004,1),.24),material('EagleEyeIris',(.36,.19,.025,1),.32),material('EagleEyePupil',(.001,.001,.001,1),.2)]
surface=BVHTree.FromObject(mesh,bpy.context.evaluated_depsgraph_get());parts=[];attachments=[]
for side in [-1.,1.]:
    normal=Vector((side*.95,.3,.02)).normalized();guess=mesh_to_rig.inverted()@Vector((side*.38,2.13,.18))
    hit,_,_,_=surface.ray_cast(guess+normal*1.5,-normal,3.)
    assert hit is not None,('No measured eagle head surface',side)
    # Do not place a complete eyeball outside the skull. The inset globe,
    # round iris and pupil are real head-weighted geometry in bind space.
    centre=hit-normal*.045;tangent=normal.cross(Vector((0.,0.,1.))).normalized();up=tangent.cross(normal).normalized();basis=Matrix((tangent,normal,up)).transposed().to_4x4()
    attachments.append({'head_surface_point_mesh_bind':list(hit),'eye_centre_mesh_bind':list(centre),'outward':list(normal)})
    for index,(offset,scale) in enumerate([(0.,(.12,.075,.115)),(.063,(.095,.018,.09)),(.08,(.043,.01,.055))]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1.);obj=bpy.context.object;obj.name='EagleEye'
        transform=Matrix.Translation(centre+normal*offset)@basis@Matrix.Diagonal((*scale,1.))
        for vertex in obj.data.vertices:vertex.co=transform@vertex.co
        obj.parent=rig;obj.matrix_parent_inverse=mesh.matrix_parent_inverse.copy();obj.matrix_basis=mesh.matrix_basis.copy();obj.data.materials.append(eye_materials[index])
        for polygon in obj.data.polygons:polygon.use_smooth=True
        obj.vertex_groups.new(name='Bone.003').add(list(range(len(obj.data.vertices))),1.,'REPLACE');parts.append(obj)
bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True)
for part in parts:part.select_set(True)
bpy.context.view_layer.objects.active=mesh;bpy.ops.object.join()
report['eye_surface_attachments']=attachments
report['maximum_skin_influences']=max(len(v.groups) for v in mesh.data.vertices)
assert report['maximum_skin_influences']<=8
report['treatments']['modern']=export('modern',samples)
(OUT/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('EAGLE UNACCEPTED CANDIDATE',report['treatments'],flush=True)
