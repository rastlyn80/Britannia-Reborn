"""Preserve evaluated CC0 cat motion; author measured running and other actions.

Use trusted Blender --factory-startup --disable-autoexec --python-exit-code 1.
No scripts from the source blend are enabled, and no game input is read.
"""
import bpy,hashlib,json,math
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
PINS=json.loads((ROOT/'scripts/cat-inputs.json').read_text(encoding='utf-8'))
SOURCE=ROOT/'work/creatures/animals-vol2/source'/PINS['member'];OUT=ROOT/'Viewer/local-art/cat';OUT.mkdir(parents=True,exist_ok=True)
assert SOURCE.stat().st_size==PINS['member_bytes'] and hashlib.sha256(SOURCE.read_bytes()).hexdigest()==PINS['member_sha256']
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
mesh=bpy.data.objects['Cat'];rig=bpy.data.objects['CatArmature'];scene=bpy.context.scene
assert sum(len(p.vertices)-2 for p in mesh.data.polygons)==807 and len(rig.data.bones)==24
for collection in bpy.data.collections:collection.hide_viewport=False;collection.hide_render=False
for obj in list(bpy.data.objects):
    if obj not in [mesh,rig]:bpy.data.objects.remove(obj,do_unlink=True)
for obj in [mesh,rig]:obj.hide_viewport=False;obj.hide_render=False;obj.hide_set(False)
for modifier in mesh.modifiers:
    if modifier.type=='ARMATURE':modifier.use_deform_preserve_volume=False
FPS=240;SOURCE_FPS=scene.render.fps/scene.render.fps_base;SCALE=.1
NAMES={'Bone':'bip01','Bone.001':'bip01 spine','Bone.002':'bip01 neck','Bone.003':'bip01 head',
    **{'Bone.%03d'%i:'tail'+str(i-3) for i in range(4,8)},
    **dict(zip(['Bone.%03d'%i for i in range(8,20)],['bip01 l thigh','bip01 l calf','bip01 l foot','bip01 r thigh','bip01 r calf','bip01 r foot',
        'bip01 r upperarm','bip01 r forearm','bip01 r hand','bip01 l upperarm','bip01 l forearm','bip01 l hand']))}
samples={};clips={};source_endpoints={}
for label,source_name in [('Idle','Idle'),('Walk','Walking')]:
    action=bpy.data.actions[source_name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    start,end=action.frame_range;duration=(end-start)/SOURCE_FPS;frames=[]
    for i in range(round(duration*FPS)+1):
        at=start+(end-start)*i/round(duration*FPS);scene.frame_set(math.floor(at),subframe=at%1);bpy.context.view_layer.update()
        frames.append({NAMES.get(b.name,b.name):b.matrix.copy() for b in rig.pose.bones})
    samples[label]=frames;clips[label]={'duration':duration,'loop':True,'source_action':source_name,'origin':'Baked evaluated Quaternius CC0 '+source_name+' clip; not recovered UO choreography'}
    source_endpoints[label]=max((frames[0][name].translation-frames[-1][name].translation).length*SCALE for name in frames[0])
rig.animation_data_clear();rig.animation_data_create()
for old,new in NAMES.items():rig.data.bones[old].name=new
for bone in rig.pose.bones:
    for constraint in list(bone.constraints):bone.constraints.remove(constraint)
    bone.rotation_mode='QUATERNION';bone.matrix_basis=Matrix.Identity(4)
scene.render.fps=FPS;scene.render.fps_base=1.

def apply_delta(pose,name,delta):
    bone=rig.data.bones[name]
    for child in [bone,*bone.children_recursive]:pose[child.name]=delta@pose[child.name]
def turn(pose,name,axis,angle):
    pivot=pose[name].translation.copy();apply_delta(pose,name,Matrix.Translation(pivot)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-pivot))
def shift(pose,name,delta):apply_delta(pose,name,Matrix.Translation(Vector(delta)))
def envelope(u):return math.sin(math.pi*u)**2
def smooth(u):u=max(0.,min(1.,u));return u*u*(3-2*u)
def aim(pose,a,b,target):
    origin=pose[a].translation;before=pose[b].translation-origin;after=target-origin
    assert min(before.length,after.length)>1e-7
    rotation=before.rotation_difference(after).to_matrix().to_4x4();apply_delta(pose,a,Matrix.Translation(origin)@rotation@Matrix.Translation(-origin))
def solve_leg(pose,upper,lower,paw,target):
    a=pose[upper].translation.copy();b=pose[lower].translation.copy();c=pose[paw].translation.copy();paw_basis=pose[paw].to_3x3()
    first=(b-a).length;second=(c-b).length;goal=target-a;distance=goal.length
    assert distance>1e-6 and distance<first+second+.00001,('Unreachable cat gait target',upper,distance,first+second)
    direction=goal.normalized();along=(first*first-second*second+distance*distance)/(2*distance)
    pole=(b-a)-direction*(b-a).dot(direction)
    if pole.length<1e-6:pole=Vector((1.,0.,0.))-direction*direction.x
    knee=a+direction*along+pole.normalized()*math.sqrt(max(0.,first*first-along*along))
    aim(pose,upper,lower,knee);aim(pose,lower,paw,target)
    result=pose[paw].copy();result.translation=target;result.to_3x3()
    for i in range(3):
        for j in range(3):result[i][j]=paw_basis[i][j]
    pose[paw]=result
    assert (pose[paw].translation-target).length<1e-6
    return max(abs((pose[lower].translation-pose[upper].translation).length-first),abs((pose[paw].translation-pose[lower].translation).length-second))*SCALE

LEGS=[('l upperarm','l forearm','l hand',0.),('r upperarm','r forearm','r hand',.08),('l thigh','l calf','l foot',.5),('r thigh','r calf','r foot',.58)]
length_error=0.;gait_diagnostics=[]
for label,duration in [('Run',1/3),('Gallop',1/3),('Attack',.65),('Attack2',.7),('Hit',.45),('Eat',2.4),('Fidget',2.4),('Alert',1.2),('Death',1.1)]:
    frames=[];count=round(duration*FPS)+1
    for i in range(count):
        u=i/(count-1);amount=envelope(u);pose={name:matrix.copy() for name,matrix in samples['Idle'][0].items()}
        if label in ['Run','Gallop']:
            # A true authored bound, not a sped-up Walking alias. Short stance
            # traverses 0.18m per paw over 0.1s, matching 1.8m/s native motion.
            shift(pose,'bip01',(0.,0.,-.45+.08*math.cos(math.tau*u*2)))
            turn(pose,'bip01 spine','Y',.08*math.sin(math.tau*u))
            turn(pose,'tail1','Y',-.12*math.sin(math.tau*u))
            stance=.3 if label=='Run' else .18/(6.8*duration)
            for upper,lower,paw,offset in LEGS:
                upper,lower,paw=['bip01 '+n for n in [upper,lower,paw]];phase=(u+offset)%1.;target=samples['Idle'][0][paw].translation.copy()
                # Hind rest paws sit behind the hip. Centre the running
                # stance beneath the measured hip, rather than adding the
                # entire stride to that already extended rest offset.
                target.x=samples['Idle'][0][upper].translation.x
                if phase<stance:target.x+=.9-1.8*phase/stance
                else:
                    swing=(phase-stance)/(1.-stance);target.x+=-.9+1.8*smooth(swing);target.z+=.6*math.sin(math.pi*swing)
                length_error=max(length_error,solve_leg(pose,upper,lower,paw,target))
            gait_diagnostics.append({'clip':label,'phase':u,'root_height_m':pose['bip01'].translation.z*SCALE,'paws':{paw:list(pose['bip01 '+paw].translation*SCALE) for _,_,paw,_ in LEGS}})
        elif label=='Eat':
            turn(pose,'bip01 neck','Y',1.65*amount);turn(pose,'bip01 head','Y',-1.0*amount)
            turn(pose,'bip01 head','Z',.035*amount*math.sin(math.tau*u*6))
        elif label in ['Attack','Attack2']:
            side='l' if label=='Attack' else 'r';turn(pose,'bip01 neck','Z',(.12 if side=='l' else -.12)*amount)
            turn(pose,'bip01 '+side+' upperarm','Y',-.85*amount);turn(pose,'bip01 '+side+' forearm','Z',(.25 if side=='l' else -.25)*amount)
            turn(pose,'bip01 '+side+' hand','Y',.35*amount)
        elif label=='Hit':
            turn(pose,'bip01 spine','Z',.12*amount);turn(pose,'bip01 neck','Y',-.18*amount)
        elif label=='Death':
            collapse=smooth(u/.8);turn(pose,'bip01','X',1.6*collapse);shift(pose,'bip01',(0.,0.,-1.6*collapse))
            for upper,lower,paw,_ in LEGS:turn(pose,'bip01 '+lower,'Y',.4*collapse)
            turn(pose,'bip01 neck','Y',.25*collapse)
        else:
            turn(pose,'bip01 neck','Z',.35*amount*math.sin(math.tau*u));turn(pose,'tail1','Y',.18*amount*math.sin(math.tau*u*2))
        frames.append(pose)
    samples[label]=frames;clips[label]={'duration':duration,'loop':label in ['Run','Gallop','Fidget'],'origin':'Authored cat category on the preserved CC0 rig; not licensed source motion or original UO choreography'}

for material in mesh.data.materials:
    colour=tuple(material.node_tree.nodes['Diffuse BSDF'].inputs['Color'].default_value)
    material.use_nodes=True;material.node_tree.nodes.clear();shader=material.node_tree.nodes.new('ShaderNodeBsdfPrincipled');output=material.node_tree.nodes.new('ShaderNodeOutputMaterial');material.node_tree.links.new(shader.outputs['BSDF'],output.inputs['Surface'])
    shader.inputs['Base Color'].default_value=colour;shader.inputs['Roughness'].default_value=.9;shader.inputs['Metallic'].default_value=0.;material.name='Cat'+material.name
for polygon in mesh.data.polygons:polygon.use_smooth=True
container=bpy.data.objects.new('DomesticCatScale',None);scene.collection.objects.link(container);container.scale=(SCALE,)*3;container.rotation_euler.z=-math.pi/2;rig.parent=container

def pose_set(matrices):
    for bone in rig.pose.bones:
        inherited=bone.parent.bone.matrix_local@matrices[bone.parent.name].inverted() if bone.parent else Matrix.Identity(4)
        bone.matrix_basis=bone.bone.matrix_local.inverted()@inherited@matrices[bone.name]
def reset():
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=True
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
def export(treatment):
    corrections={};bake_error=0.;actions=[]
    for label,frames in samples.items():
        action=bpy.data.actions.new(treatment+'_'+label);rig.animation_data.action=action;corrections[label]=[]
        for i,pose in enumerate(frames):
            at=1+clips[label]['duration']*FPS*i/(len(frames)-1);scene.frame_set(math.floor(at),subframe=at%1);pose_set(pose);bpy.context.view_layer.update()
            bake_error=max(bake_error,max((bone.matrix.translation-pose[bone.name].translation).length*SCALE for bone in rig.pose.bones))
            evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh();low=min(v.co.z for v in data.vertices);evaluated.to_mesh_clear()
            correction=max(0.,-low) if treatment=='modern' else 0.;root=rig.pose.bones['bip01'];matrix=root.matrix.copy();matrix.translation.z+=correction;root.matrix=matrix;corrections[label].append(correction*SCALE)
            for bone in rig.pose.bones:
                for channel in ['location','rotation_quaternion','scale']:bone.keyframe_insert(data_path=channel,frame=at,group=bone.name)
        track=rig.animation_data.nla_tracks.new();track.name=label;strip=track.strips.new(label,1,action);strip.action_slot=action.slots[0];track.mute=True;actions.append(track);rig.animation_data.action=None
    assert bake_error<.00001,('Cat pose bake drift',bake_error)
    for track in actions:track.mute=False
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [container,rig,mesh]:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig;path=OUT/('cat-'+treatment+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_anim_slide_to_zero=True,export_yup=True,export_influence_nb=8,export_normals=True)
    result={'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'bake_position_error_max_m':bake_error,'floor_correction_max_m':{name:max(values) for name,values in corrections.items()}}
    for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
    reset();return result

report={'source':PINS,'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_triangles':807,'bones':24,'source_fps':SOURCE_FPS,'bone_aliases':NAMES,'source_loop_gap_m':source_endpoints,'clips':clips,'scale':SCALE,
    'authored_run':{'method':'Two measured source segments plus preserved paw orientation; front/rear offset bound and smooth raised swing','reference_speed_mps':1.8,'stance_fraction':.3,'stance_distance_m':.18,'gallop_reference_speed_mps':6.8,'gallop_stance_fraction':.18/(6.8/3),'duration_s':1/3,'sample_rate':FPS,'segment_length_error_max_m':length_error,'samples':gait_diagnostics},'treatments':{}}
report['treatments']['source']=export('source')
reset();bpy.context.view_layer.objects.active=mesh
sub=mesh.modifiers.new('Rounded cat silhouette','SUBSURF');sub.levels=1;bpy.ops.object.modifier_move_up(modifier=sub.name);bpy.ops.object.modifier_apply(modifier=sub.name)

def material(name,colour,roughness):
    result=bpy.data.materials.new(name);result.use_nodes=True;shader=result.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=colour;shader.inputs['Roughness'].default_value=roughness;return result
eye_mats=[material('CatEyeDark',(0.008,.006,.004,1),.22),material('CatEyeIris',(.23,.13,.025,1),.3),material('CatEyePupil',(.001,.001,.001,1),.18)]
parts=[];eye_attachments=[]
def detail_sphere(name,centre,scale,mat,bone,orientation=Matrix.Identity(4)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12 if name=='CatToe' else 16,ring_count=6 if name=='CatToe' else 8,radius=1.)
    obj=bpy.context.object;obj.name=name
    matrix=Matrix.Translation(Vector(centre))@orientation@Matrix.Diagonal((*scale,1.))
    for vertex in obj.data.vertices:vertex.co=matrix@vertex.co
    # Coordinates above are in the source mesh's bind space. Match its object
    # transform before joining; world-space parts would otherwise become ten
    # times too large under the 0.1 presentation container.
    obj.parent=rig;obj.matrix_parent_inverse=mesh.matrix_parent_inverse.copy();obj.matrix_basis=mesh.matrix_basis.copy()
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:polygon.use_smooth=True
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1.,'REPLACE');parts.append(obj)
head_surface=BVHTree.FromObject(mesh,bpy.context.evaluated_depsgraph_get())
for side in [-1,1]:
    normal=Vector((.65,side*.76,0.)).normalized();guess=Vector((2.57,side*.44,2.88));hit,_,_,_=head_surface.ray_cast(guess+normal*2.,-normal,4.)
    assert hit is not None,'Eyes require a measured actual head surface'
    # Embed the globe in the measured head instead of placing a whole sphere
    # outside the cheek. Only the iris/corneal cap protrudes a few millimetres.
    centre=hit-normal*.04;tangent=normal.cross(Vector((0.,0.,1.)));basis=Matrix((tangent,normal,Vector((0.,0.,1.)))).transposed().to_4x4()
    eye_attachments.append({'head_surface_point':list(hit),'eye_centre':list(centre),'outward':list(normal),'inset_source_units':.04})
    for index,(offset,scale) in enumerate([(0.,(.1,.075,.11)),(.06,(.08,.02,.085)),(.078,(.015,.009,.067))]):detail_sphere('CatEye',centre+normal*offset,scale,eye_mats[index],'bip01 head',basis)
# Modest toe volumes keep rounded paws readable. They inherit the actual paw
# bones and are included in skin/floor/terrain/corpse tests, not rigid props.
white=next(m for m in mesh.data.materials if m.name=='CatWhite')
for _,_,paw,_ in LEGS:
    bone='bip01 '+paw;centre=rig.data.bones[bone].tail_local.copy()
    for offset in [-.055,0.,.055]:detail_sphere('CatToe',centre+Vector((0.,offset,-.015)),(.055,.035,.025),white,bone)
bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True)
for part in parts:part.select_set(True)
bpy.context.view_layer.objects.active=mesh;bpy.ops.object.join()
report['authored_details']='Six bone-weighted eye/iris/pupil parts and twelve small paw-toe parts; no source detail or captured anatomy claimed'
report['eye_surface_attachments']=eye_attachments
report['maximum_skin_influences']=max(len(v.groups) for v in mesh.data.vertices)
assert report['maximum_skin_influences']<=8,'Keep the full interpolated source weights'
report['treatments']['modern']=export('modern')
(OUT/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('CAT CANDIDATE:',report['treatments'],'; running segment error',length_error,flush=True)
