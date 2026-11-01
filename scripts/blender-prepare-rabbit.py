"""Bake pinned CC0 rabbit constraints and explicit additional categories.

Use trusted Blender with factory-startup, disable-autoexec and python-exit-code1.
This recipe prepares local candidates; it never installs a native body route.
"""
import bpy,hashlib,json,math,importlib.util
from mathutils import Matrix
from pathlib import Path
project=Path(__file__).resolve().parents[1];root=project/'work/creatures/rabbit';out=project/'Viewer/local-art/rabbit';out.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('rabbit_gaits',project/'scripts/creature-rabbit-gaits.py');gaits=importlib.util.module_from_spec(spec);spec.loader.exec_module(gaits)
pins=json.loads((project/'scripts/rabbit-inputs.json').read_text(encoding='utf-8'));source=root/'rabbit.blend'
assert source.stat().st_size==pins['bytes'] and hashlib.sha256(source.read_bytes()).hexdigest()==pins['sha256']
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
assert 'CC0 - Public Domain' in bpy.data.texts['License'].as_string()
mesh=bpy.data.objects['Rabbit'];fur=bpy.data.objects['Fur'];rig=bpy.data.objects['Armature'];scene=bpy.context.scene;source_fps=scene.render.fps/scene.render.fps_base;fps=120;scale=.028
assert len(mesh.data.vertices)==893 and len(rig.data.bones)==37
def skin_weights(obj,maximum_loss):
    # The legacy file contains weights slightly above1. Normalize their ratios
    # before Blender's exporter validates/clamps them. Limit the derived skin
    # explicitly, so floor measurements use the same weights as the GLTF.
    bones={b.name for b in rig.data.bones};maximum_count=0;lost=0.;total_range=[math.inf,-math.inf]
    for vertex in obj.data.vertices:
        values=sorted([(g.group,g.weight) for g in vertex.groups if obj.vertex_groups[g.group].name in bones and g.weight>0.],key=lambda pair:pair[1],reverse=True)
        assert values,('Unweighted source vertex',obj.name,vertex.index)
        total=sum(v for _,v in values);total_range=[min(total_range[0],total),max(total_range[1],total)];maximum_count=max(maximum_count,len(values))
        loss=sum(v for _,v in values[8:])/total;lost=max(lost,loss)
        assert loss<=maximum_loss,('Skin influence loss exceeds declared budget',obj.name,vertex.index,loss)
        retained=sum(v for _,v in values[:8])
        for group,value in values[:8]:obj.vertex_groups[group].add([vertex.index],value/retained,'REPLACE')
        for group,_ in values[8:]:obj.vertex_groups[group].remove([vertex.index])
    probe=obj.data.copy();changed=probe.validate(verbose=False,clean_customdata=False);bpy.data.meshes.remove(probe)
    assert not changed,('Legacy mesh still needs an explicit repair',obj.name)
    return {'maximum_input_influences':maximum_count,'input_weight_sum_range':total_range,'maximum_discarded_weight_fraction':lost,'maximum_allowed_loss_fraction':maximum_loss,'method':'Ratio normalization; at most eight positive joint influences. Original numerical tails only; refined interpolation has an explicit0.2-percent budget. Points, polygons, UVs and rig remain unchanged.'}
source_weights={obj.name:skin_weights(obj,1e-12) for obj in [mesh,fur]}
for pin in pins['packed_images']:
    assert hashlib.sha256(bytes(bpy.data.images[pin['name']].packed_file.data)).hexdigest()==pin['sha256']
for track in rig.animation_data.nla_tracks:track.mute=True
for obj in list(bpy.data.objects):
    if obj not in [mesh,fur,rig]:bpy.data.objects.remove(obj,do_unlink=True)
for obj in [mesh,fur,rig]:obj.hide_set(False);obj.hide_viewport=False;obj.hide_render=False
for obj in [mesh,fur]:
    for modifier in obj.modifiers:
        if modifier.type=='ARMATURE':modifier.use_deform_preserve_volume=False
samples={};clips={}
for label,name in [('Idle','Sitting.000'),('Run','Running'),('Death','Dying.000'),('Guarding','Guarding'),('Jump','Jump')]:
    action=bpy.data.actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    start,end=action.frame_range;duration=(end-start)/source_fps;count=round(duration*fps)+1;frames=[]
    for i in range(count):
        at=start+(end-start)*i/(count-1);scene.frame_set(math.floor(at),subframe=at%1);bpy.context.view_layer.update();frames.append({bone.name:bone.matrix.copy() for bone in rig.pose.bones})
    samples[label]=frames;clips[label]={'source_action':name,'duration':duration,'loop':label in ['Idle','Run','Guarding'],'origin':'Baked evaluated CC0 source constraints; no UO choreography recovered'}

# These are declared category adaptations on the retained source skeleton.
# Walk preserves every running pose in a slower hop; other additions are
# authored, not extra captured clips or recovered original UO choreography.
samples['Walk']=samples['Run'];clips['Walk']={'duration':clips['Run']['duration']*1.5,'loop':True,'source_action':'Running','origin':'Authored slower-hop timing of the complete licensed Running cycle'}
def rotate(matrices,name,axis,angle):
    pivot=matrices[name].translation.copy();change=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,axis)@Matrix.Translation(-pivot)
    for bone in [rig.data.bones[name],*rig.data.bones[name].children_recursive]:matrices[bone.name]=change@matrices[bone.name]
for label,duration in [('Attack',.6),('Hit',.45),('Eat',2.4),('Fidget',2.),('Alert',1.2)]:
    frames=[];count=round(duration*fps)+1
    for i in range(count):
        u=i/(count-1);a=math.sin(math.pi*u)**2;matrices={name:matrix.copy() for name,matrix in samples['Idle'][0].items()}
        if label=='Attack':rotate(matrices,'Neck','X',.16*a);rotate(matrices,'Head','X',.22*a)
        elif label=='Hit':rotate(matrices,'Spine','Z',.10*a);rotate(matrices,'Neck','X',-.18*a)
        elif label=='Eat':rotate(matrices,'Neck','X',.65*a);rotate(matrices,'Head','X',.18*a+.025*a*math.sin(math.tau*u*6))
        elif label=='Alert':rotate(matrices,'Neck','X',-.16*a);rotate(matrices,'Head','Z',.12*a*math.sin(math.pi*u));rotate(matrices,'Ear_L','Y',.12*a);rotate(matrices,'Ear_R','Y',-.12*a)
        else:
            rotate(matrices,'Head','Z',.12*a*math.sin(math.tau*u));rotate(matrices,'Ear_L','Y',.28*a*math.sin(math.tau*u*3));rotate(matrices,'Ear_R','Y',-.20*a*math.sin(math.tau*u*3+.4))
        frames.append(matrices)
    samples[label]=frames;clips[label]={'duration':duration,'loop':label=='Fidget','origin':'Authored '+label+' category on the original CC0 rig; no captured or original UO choreography claim'}
rig.animation_data_clear();rig.animation_data_create();export_fps=240;scene.render.fps=export_fps;scene.render.fps_base=1.
for bone in rig.pose.bones:
    for constraint in list(bone.constraints):bone.constraints.remove(constraint)
    bone.rotation_mode='QUATERNION';bone.matrix_basis=Matrix.Identity(4)
material=bpy.data.materials.new('CC0 rabbit natural fur');material.use_nodes=True;nodes=material.node_tree.nodes;shader=nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.9
image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images['rabbot-skinn'];material.node_tree.links.new(image.outputs['Color'],shader.inputs['Base Color'])
material.node_tree.links.new(image.outputs['Alpha'],shader.inputs['Alpha']);material.surface_render_method='DITHERED'
normal=nodes.new('ShaderNodeTexImage');normal.image=bpy.data.images['rabbit-NORM'];normal.image.colorspace_settings.name='Non-Color';mapping=nodes.new('ShaderNodeNormalMap');mapping.inputs['Strength'].default_value=.35;material.node_tree.links.new(normal.outputs['Color'],mapping.inputs['Color']);material.node_tree.links.new(mapping.outputs['Normal'],shader.inputs['Normal'])
mesh.data.materials.clear();mesh.data.materials.append(material)
for polygon in mesh.data.polygons:polygon.use_smooth=True
fur_material=bpy.data.materials.new('CC0 rabbit source alpha fur');fur_material.use_nodes=True;fur_material.surface_render_method='DITHERED';fur_shader=fur_material.node_tree.nodes.get('Principled BSDF');fur_shader.inputs['Roughness'].default_value=.95
fur_image=fur_material.node_tree.nodes.new('ShaderNodeTexImage');fur_image.image=bpy.data.images['Fur-skin'];fur_material.node_tree.links.new(fur_image.outputs['Color'],fur_shader.inputs['Base Color']);fur_material.node_tree.links.new(fur_image.outputs['Alpha'],fur_shader.inputs['Alpha']);fur.data.materials.clear();fur.data.materials.append(fur_material)
for polygon in fur.data.polygons:polygon.use_smooth=True
container=bpy.data.objects.new('RabbitScale',None);scene.collection.objects.link(container);container.scale=(scale,)*3
motion_node=bpy.data.objects.new('RabbitMotion',None);scene.collection.objects.link(motion_node);motion_node.parent=container;motion_node.animation_data_create();rig.parent=motion_node
assert mesh.parent==rig

def set_pose(matrices):
    for bone in rig.pose.bones:
        inherited=bone.parent.bone.matrix_local@matrices[bone.parent.name].inverted() if bone.parent else Matrix.Identity(4)
        bone.matrix_basis=bone.bone.matrix_local.inverted()@inherited@matrices[bone.name]

def export(treatment,refine):
    rig.animation_data.action=None;motion_node.animation_data.action=None;motion_node.location=(0.,0.,0.)
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    if refine:
        subdivision=mesh.modifiers.new('Declared one-level rest-space refinement','SUBSURF');subdivision.levels=1;bpy.context.view_layer.objects.active=mesh;bpy.ops.object.modifier_move_up(modifier=subdivision.name);bpy.ops.object.modifier_apply(modifier=subdivision.name)
    weights={obj.name:skin_weights(obj,.002 if refine else 1e-12) for obj in [mesh,fur]}
    gait_reports={};treatment_samples=dict(samples);treatment_clips={k:dict(v) for k,v in clips.items()}
    if treatment=='modern':
        for label,duration,speed in [('Walk',2/3,1.8),('Run',.2,6.8)]:
            treatment_samples[label],gait_reports[label]=gaits.reconcile(mesh,rig,samples[label],duration,speed,scale)
            stored_duration=treatment_clips[label]['duration']
            gait_reports[label].update(exported_duration=stored_duration,reference_stance_speed_mps=speed*duration/stored_duration,runtime_reference_rate=stored_duration/duration)
            treatment_clips[label].update(origin='Authored common-root stance adaptation of the retained licensed Running pose cycle. Original key density/duration retained; physical cycle speed comes from declared runtime playback rate, not destructive export retiming. No relative joint retargeting or recovered UO choreography')
    tracks=[];maximum_error=0.;corrections={}
    for label,frames in treatment_samples.items():
        action=bpy.data.actions.new(treatment+'_'+label);rig.animation_data.action=action;parent_action=bpy.data.actions.new(treatment+'_'+label+'_presentation_parent');motion_node.animation_data.action=parent_action;values=[]
        for i,matrices in enumerate(frames):
            at=1+treatment_clips[label]['duration']*export_fps*i/(len(frames)-1);scene.frame_set(math.floor(at),subframe=at%1);motion_node.location=(0.,0.,0.);set_pose(matrices);bpy.context.view_layer.update()
            maximum_error=max(maximum_error,max((bone.matrix.translation-matrices[bone.name].translation).length*scale for bone in rig.pose.bones))
            low=math.inf
            for obj in [mesh,fur]:
                evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());data=evaluated.to_mesh();low=min(low,min(v.co.z for v in data.vertices));evaluated.to_mesh_clear()
            correction=max(0.,-low) if treatment=='modern' else 0.
            # A separate ancestor moves both independent roots together, with
            # every original rig curve left intact between sampled keys too.
            offset=gait_reports[label]['offsets_m'][i] if label in gait_reports else 0.
            motion_node.location=(0.,-offset/scale,correction);motion_node.keyframe_insert(data_path='location',frame=at)
            bpy.context.view_layer.update()
            shifted_error=max((bone.matrix.translation-matrices[bone.name].translation).length*scale for bone in rig.pose.bones)
            assert shifted_error<.00001,('Root correction changed the relative source skeleton',label,i,shifted_error)
            values.append(correction*scale)
            for bone in rig.pose.bones:
                for channel in ['location','rotation_quaternion','scale']:bone.keyframe_insert(data_path=channel,frame=at,group=bone.name)
        track=rig.animation_data.nla_tracks.new();track.name=label;strip=track.strips.new(label,1,action);strip.action_slot=action.slots[0];track.mute=True;tracks.append(track);rig.animation_data.action=None
        track=motion_node.animation_data.nla_tracks.new();track.name=label;strip=track.strips.new(label,1,parent_action);strip.action_slot=parent_action.slots[0];track.mute=True;tracks.append(track);motion_node.animation_data.action=None
        corrections[label]={'range_m':[min(values),max(values)],'policy':'Negative complete-skin penetration only; genuine positive source hop retained' if treatment=='modern' else 'Unmodified source/declared category pose; negative source clearance retained for comparison'}
    assert maximum_error<.00001,maximum_error
    for track in tracks:track.mute=False
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [container,motion_node,rig,mesh,fur]:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig;path=out/('rabbit-'+treatment+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_merge_animation='NLA_TRACK',export_anim_slide_to_zero=True,export_force_sampling=True,export_frame_step=1,export_yup=True,export_texcoords=True,export_normals=True,export_tangents=True,export_influence_nb=8)
    for obj in [rig,motion_node]:
        for track in list(obj.animation_data.nla_tracks):obj.animation_data.nla_tracks.remove(track)
    return {'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'maximum_evaluated_bake_position_error_m':maximum_error,'weight_policy':weights,'floor_corrections':corrections,'gait_reconciliation':gait_reports,'triangles':{obj.name:sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in [mesh,fur]},'clips':treatment_clips}

report={'status':'Prepared candidate only; no accepted route, native gameplay or coverage','source':pins,'source_weight_normalisation':source_weights,'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'gait_recipe_sha256':hashlib.sha256((project/'scripts/creature-rabbit-gaits.py').read_bytes()).hexdigest(),'source_pin_sha256':hashlib.sha256((project/'scripts/rabbit-inputs.json').read_bytes()).hexdigest(),'source_fps':source_fps,'source_bake_rate':fps,'sample_rate':export_fps,'scale':scale,'bones':37,'nameplate_tips':[{'bone':name,'local_tip':[0.,rig.data.bones[name].length,0.]} for name in ['Ear_L.001','Ear_R.001']],'clips':clips,'refinement':'One declared rest-space Catmull-Clark pass on body; original source alpha fur cards, UVs, packed albedo and normal images retained','limits':'Requires actual imported eight-influence skins, genuine source hop and floor/support proof, distinct action review, both native Rabbit/JackRabbit constructors, hues, selection/camera, matching cadaver and clean public distribution before acceptance','treatments':{}}
for treatment,refine in [('source',False),('modern',True)]:report['treatments'][treatment]=export(treatment,refine)
(out/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('RABBIT CANDIDATE PREPARATION:',{t:r['triangles'] for t,r in report['treatments'].items()})
