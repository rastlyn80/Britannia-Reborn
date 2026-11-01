"""Independent CC0 dolphin trial: authored rig and cetacean action categories.

Run with Blender --background --factory-startup --disable-autoexec
--python-exit-code 1 --python scripts/blender-prepare-dolphin.py.
No source scripts or proprietary meshes/rigs/actions are used.
"""
import bpy, hashlib, json, math, tempfile
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT=Path(__file__).resolve().parents[1]
PINS=json.loads((ROOT/'scripts/dolphin-inputs.json').read_text(encoding='utf-8'))
SOURCE=ROOT/'work/creatures/dolphin-free'/PINS['file']
OUT=ROOT/'Viewer/local-art/dolphin';OUT.mkdir(parents=True,exist_ok=True)
TEMP=ROOT/'work/creatures/dolphin-free/temp';TEMP.mkdir(parents=True,exist_ok=True);tempfile.tempdir=str(TEMP)
assert SOURCE.stat().st_size==PINS['bytes'] and hashlib.sha256(SOURCE.read_bytes()).hexdigest()==PINS['sha256']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==6 and not bpy.data.armatures and not bpy.data.actions
source_triangles=sum(len(o.data.loop_triangles) or sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
for obj in meshes:
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if len(obj.data.polygons)>10000:
        modifier=obj.modifiers.new('Bounded study-mesh reduction','DECIMATE');modifier.ratio=.28
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    # Keep the licensed 3.04 m adult silhouette; roots stay on the water plane.
    for polygon in obj.data.polygons:polygon.use_smooth=True

data=bpy.data.armatures.new('Authored dolphin rig');rig=bpy.data.objects.new('DolphinRig',data);bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
specs={
 'root':((0,0,0),(0,0,.2),None),
 'body':((.55,0,0),(-.35,0,0),'root'),
 'head':((.65,0,0),(1.5,0,0),'body'),
 'tail_base':((-.35,0,0),(-.7,0,0),'body'),
 'tail_mid':((-.7,0,0),(-1.05,0,0),'tail_base'),
 'tail_tip':((-1.05,0,0),(-1.4,0,0),'tail_mid'),
 'flukes':((-1.4,0,0),(-1.52,0,0),'tail_tip'),
 'flipper.L':((.35,.15,-.12),(.0,.47,-.23),'body'),
 'flipper.R':((.35,-.15,-.12),(.0,-.47,-.23),'body')}
for name,(head,tail,parent) in specs.items():
    bone=data.edit_bones.new(name);bone.head=head;bone.tail=tail
    if parent:bone.parent=data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')

def smooth(t):
    t=max(0.,min(1.,t));return t*t*(3.-2.*t)

def weights(point):
    x,y,z=point
    # Stations are in the licensed mesh's longitudinal X axis. At most
    # two axial and one flipper influence avoid hard joints and loose tips.
    stations=[(-1.48,'flukes'),(-1.16,'tail_tip'),(-.85,'tail_mid'),(-.48,'tail_base'),(.1,'body'),(.92,'head')]
    if x<=stations[0][0]:result={stations[0][1]:1.}
    elif x>=stations[-1][0]:result={stations[-1][1]:1.}
    else:
        for (a,first),(b,second) in zip(stations,stations[1:]):
            if a<=x<=b:
                t=smooth((x-a)/(b-a));result={first:1.-t,second:t};break
    flipper=smooth((abs(y)-.18)/.16)*smooth((-z-.08)/.10)*smooth((x+.35)/.20)*(1.-smooth((x-.4)/.25))
    if flipper>0.:
        result={name:w*(1.-flipper) for name,w in result.items()};result['flipper.L' if y>0 else 'flipper.R']=flipper
    return {name:value for name,value in result.items() if value>1e-7}

for obj in meshes:
    groups={name:obj.vertex_groups.new(name=name) for name in specs}
    for vertex in obj.data.vertices:
        values=weights(vertex.co);assert abs(sum(values.values())-1.)<1e-5 and len(values)<=3
        for name,value in values.items():groups[name].add([vertex.index],value,'REPLACE')
    modifier=obj.modifiers.new('Authored linear skin','ARMATURE');modifier.object=rig;modifier.use_deform_preserve_volume=False;obj.parent=rig

FPS=30;scene=bpy.context.scene;scene.render.fps=FPS
rig.animation_data_create()
rest={bone.name:bone.matrix_local.to_quaternion() for bone in data.bones}
for bone in rig.pose.bones:bone.rotation_mode='QUATERNION'

def rotate(name,axis,angle):
    rig.pose.bones[name].rotation_quaternion=rest[name].inverted() @ Quaternion(axis,angle) @ rest[name]

def pose(clip,u):
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    offset=Vector((0.,0.,0.))
    pulse=math.sin(math.pi*u)**2;cycle=math.sin(math.tau*u)
    active=clip in ['Walk','Run'];amp=.22 if clip=='Run' else .14 if active else .035
    dying=smooth(u) if clip in ['Death','Death2'] else 0.
    for i,name in enumerate(['tail_base','tail_mid','tail_tip','flukes']):
        rotate(name,(0,1,0),amp*(1.+i*.25)*math.sin(math.tau*u-i*.65)*(1.-dying))
    rotate('body',(0,1,0),.025*cycle if active else .008*cycle)
    if clip in ['Jump','Roll']:
        # Closed root trajectories: breach and barrel roll return to the
        # native anchor; the entity itself is never moved by animation.
        offset.z=1.1*pulse
        rotate('root',(0,1,0),-.65*math.sin(math.tau*u))
        if clip=='Roll':rotate('body',(1,0,0),math.tau*smooth(u))
    elif clip in ['Attack','Attack2','Attack3']:
        offset.x=.26*pulse
        rotate('head',(0,1,0),-.11*pulse)
        if clip!='Attack':rotate('body',(0,0,1),(.25 if clip=='Attack2' else -.25)*pulse)
    elif clip=='Hit':rotate('body',(0,1,0),.22*pulse)
    elif clip in ['Fidget','Fidget2']:rotate('head',(0,0,1),.20*cycle)
    elif clip=='Cast':offset.z=.12*pulse
    if dying:rotate('body',(1,0,0),math.pi*dying*(1. if clip=='Death' else -1.))
    for side,sign in [('L',1),('R',-1)]:rotate('flipper.'+side,(1,0,0),sign*(.09*cycle+.12*pulse if clip=='Roll' else .06*cycle))
    rig.pose.bones['root'].location=rest['root'].inverted() @ offset

clips={'Idle':(2.4,True),'Walk':(1.0,True),'Run':(.65,True),'Attack':(.75,False),'Attack2':(.8,False),'Attack3':(.85,False),
 'Hit':(.55,False),'Death':(1.4,False),'Death2':(1.4,False),'Fidget':(2.4,True),'Fidget2':(2.6,True),'Jump':(1.6,False),'Roll':(2.0,False),'Cast':(1.2,False)}
metadata={}
for name,(duration,loop) in clips.items():
    action=bpy.data.actions.new(name);rig.animation_data.action=action
    count=round(duration*FPS)+1
    for frame in range(count):
        scene.frame_set(frame+1);pose(name,frame/(count-1))
        for bone in rig.pose.bones:
            for channel in ['location','rotation_quaternion']:bone.keyframe_insert(data_path=channel,frame=frame+1,group=bone.name)
    track=rig.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,1,action);strip.action_slot=action.slots[0];track.mute=True
    metadata[name]={'duration':(count-1)/FPS,'loop':loop,'origin':'Authored independent rig/category; not recovered UO choreography'}
    rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=False
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
# Original mesh is +X forward; project actors face +Z in Godot.
rig.rotation_euler.z=-math.pi/2
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
path=OUT/'dolphin.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,
 export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,export_yup=True,
 export_texcoords=True,export_normals=True,export_tangents=True,export_influence_nb=4)
report={'sources':PINS,'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
 'bones':len(specs),'source_triangles':source_triangles,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'clips':metadata,
 'scope':'Independent licensed candidate, authored rig/weights/motions. Actual GPU skin, hues, native water/actions and corpse acceptance required before install.'}
(OUT/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('DOLPHIN CANDIDATE:',report['triangles'],'triangles;',len(clips),'authored categories',flush=True)
