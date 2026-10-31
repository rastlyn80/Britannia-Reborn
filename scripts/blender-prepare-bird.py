"""Authored bird categories on the pinned CC0 shrike rig; no source scripts run."""
import bpy, hashlib, json, math, struct, tempfile
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/birds/shrike'
OUT = ROOT / 'Viewer/local-art/birds'
TEMP = (ROOT / 'work/birds/temp').resolve()
assert TEMP.is_relative_to((ROOT / 'work').resolve())
TEMP.mkdir(exist_ok=True);tempfile.tempdir = str(TEMP)
PINS = json.loads((ROOT / 'scripts/bird-inputs.json').read_text(encoding='utf-8'))
for record in PINS['files']:
    assert hashlib.sha256((SOURCE / record['member']).read_bytes()).hexdigest() == record['sha256']
FOLDER = SOURCE / 'bird_yellow_billed_shrike'
bpy.ops.wm.open_mainfile(filepath=str(FOLDER / 'bird_shrike1.blend'), load_ui=False, use_scripts=False)
mesh = bpy.data.objects['Bird_YBShrike'];rig = bpy.data.objects['Bird_YBShrike Rig']
# glTF/Godot uses linear blend skinning. Author floor support against that
# same deformation, rather than Blender's source dual-quaternion preview.
mesh.modifiers['Armature'].use_deform_preserve_volume = False
for obj in list(bpy.data.objects):
    if obj not in [mesh, rig]:bpy.data.objects.remove(obj, do_unlink=True)
material = bpy.data.materials.new('CC0 shrike feather PBR');material.use_nodes = True
nodes = material.node_tree.nodes;links = material.node_tree.links;shader = nodes.get('Principled BSDF')
def texture(name, colour=False):
    image = bpy.data.images.load(str(FOLDER / 'textures' / ('bird_shrike1_' + name + '.png')), check_existing=False)
    image.colorspace_settings.name = 'sRGB' if colour else 'Non-Color'
    node = nodes.new('ShaderNodeTexImage');node.image = image;return node
diff = texture('diff', True)
links.new(diff.outputs['Color'], shader.inputs['Base Color']);links.new(diff.outputs['Alpha'], shader.inputs['Alpha'])
normal = nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value = .65
links.new(texture('norm').outputs['Color'], normal.inputs['Color']);links.new(normal.outputs['Normal'], shader.inputs['Normal'])
links.new(texture('rgh').outputs['Color'], shader.inputs['Roughness']);shader.inputs['Metallic'].default_value = 0.
material.surface_render_method = 'DITHERED';mesh.data.materials.clear();mesh.data.materials.append(material)

FPS = 30
scene = bpy.context.scene;scene.render.fps = FPS
rig.animation_data_clear();rig.animation_data_create()
rest = {b.name:b.matrix_local.copy() for b in rig.data.bones}
controls = {}
disabled = []
for bone in rig.pose.bones:
    basis = bone.matrix_basis.copy();bone.rotation_mode = 'QUATERNION';bone.matrix_basis = basis
    for constraint in bone.constraints:
        if bone.name in ['head', 'Wing.002.L', 'Wing.002.R']:
            constraint.mute = True;disabled.append(bone.name + '/' + constraint.name)

def smooth(t):
    t = max(0., min(1., t));return t*t*(3.-2.*t)

def turn(axis, angle):return Matrix.Rotation(angle, 4, axis)

authored = {}
def target_world(name):
    if name not in authored:
        parent = rig.pose.bones[name].parent
        authored[name] = (target_world(parent.name) @ rest[parent.name].inverted() if parent else Matrix.Identity(4)) @ rest[name] @ controls.get(name, Matrix.Identity(4))
    return authored[name]

def set_target(name, matrix):
    bone = rig.pose.bones[name];parent = bone.parent
    inherited = target_world(parent.name) @ rest[parent.name].inverted() if parent else Matrix.Identity(4)
    # Explicit local conversion avoids reading Blender's previous evaluated
    # pose while several controls are being authored in one frame.
    bone.matrix_basis = rest[name].inverted() @ inherited.inverted() @ matrix
    authored[name] = matrix.copy()

def pose_world(name, rotation=None, offset=None):
    bone = rig.pose.bones[name];parent = bone.parent
    inherited = target_world(parent.name) @ rest[parent.name].inverted() if parent else Matrix.Identity(4)
    basis = rest[name].copy()
    if rotation is not None:
        pivot = basis.translation.copy()
        basis = Matrix.Translation(pivot) @ rotation @ Matrix.Translation(-pivot) @ basis
    if offset is not None:basis.translation += Vector(offset)
    set_target(name, inherited @ basis)

def wing_pose(side, sign, weight, phase, clip):
    # A coherent folded feather fan is preferable to twisting the source's
    # merged feather cards at alternating joints. The entire licensed wing
    # folds back along the flank and opens for the authored low-flight gait.
    pivot = rest['shoulder.'+side].translation.copy()
    folded = Matrix(((0.,0.,-sign),(sign,0.,0.),(0.,-1.,0.))).to_quaternion()
    flap = (turn('Y',-sign*.9*math.sin(math.tau*phase*(3. if clip=='Run' else 2.))) @ turn('Z',sign*.06)).to_quaternion()
    rotation = folded.slerp(flap,weight).to_matrix().to_4x4()
    # Tuck the source feather chord against the flank without shortening
    # its flight span. This authored packing is not feather simulation.
    packing = Matrix.Diagonal(Vector((1.,.22+.78*weight,1.,1.)))
    fold = Matrix.Translation(pivot) @ rotation @ packing @ Matrix.Translation(-pivot)
    body = target_world('ribcage') @ rest['ribcage'].inverted()
    for name in ['shoulder.'+side,'Wing.'+side,'Wing.001.'+side,'Wing.002.'+side,'w_feather.'+side,'w_feather.001.'+side]:
        set_target(name,body @ fold @ rest[name])

def frame_pose(clip, u):
    authored.clear()
    for bone in rig.pose.bones:bone.matrix_basis = controls.get(bone.name, Matrix.Identity(4))
    cycle = math.sin(math.tau*u)
    hop = max(0., math.sin(math.pi*u))**2
    flying = clip in ['Run', 'Fly']
    weight = 1. if flying else .45*hop if clip == 'Walk' else 0.
    if clip == 'TakeOff':weight = smooth(u)
    if clip == 'Land':weight = 1.-smooth(u)
    call = math.sin(math.pi*u)**2 if clip == 'Cast' else 0.
    feed = smooth(u/.24)*(1.-smooth((u-.76)/.24)) if clip == 'Eat' else 0.
    lunge = math.sin(math.pi*u)**4 if clip.startswith('Attack') else 0.
    hit = math.sin(math.pi*u)**2 if clip == 'Hit' else 0.
    dying = smooth(u) if clip.startswith('Death') else 0.
    root_offset = .018*hop if clip == 'Walk' else .1*weight
    # All movement is inside the model rig; the native entity stays fixed.
    pose_world('root', turn('Y', (1.45 if clip != 'Death2' else -1.45)*dying), (0., 0., root_offset))
    pitch = -.28*(1.-weight) + .025*cycle if clip in ['Idle', 'Walk', 'Run', 'Fly', 'TakeOff', 'Land'] else -.28
    pose_world('pelvis_control', turn('X', pitch), (0., -.009*lunge, .002*math.sin(math.tau*u*2.) if clip == 'Idle' else 0.))
    pose_world('neck', turn('X', .72*feed - .18*lunge + .2*hit))
    scan = .2*math.sin(math.tau*u) if clip in ['Idle', 'Fidget', 'Alert'] else 0.
    if clip == 'Alert':scan *= .3
    pose_world('head', turn('Z', scan) @ turn('X', .28*feed + .13*math.sin(math.tau*u*3.)*feed + .25*hit))
    pose_world('beak.B', turn('X', -.15*lunge - .1*feed*(.5+.5*math.sin(math.tau*u*4.)) - .28*call))
    pose_world('tail_base', turn('Z', .06*cycle*(1.-dying)) @ turn('X', -.08*weight))
    for side, sign in [('L', 1.), ('R', -1.)]:
        stretch = .22*math.sin(math.pi*u)**4 if clip == 'Fidget' else 0.
        wing_pose(side,sign,max(weight,stretch,.3*call),u,clip)
        delta = Vector((0., .008*cycle*sign if clip == 'Walk' else 0., .006*hop if clip == 'Walk' else .009*weight))
        matrix = target_world('foot_ctl.'+side).copy();matrix.translation += delta;set_target('foot_ctl.'+side, matrix)
    bpy.context.view_layer.update()
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    temporary = evaluated.to_mesh()
    low = min((evaluated.matrix_world @ v.co).z for v in temporary.vertices)
    evaluated.to_mesh_clear()
    # Airborne wing strokes must not move the torso up/down merely to keep
    # the lowest feather at one height. Positive hop/flight clearance survives.
    correction = -low if clip.startswith('Death') else max(0., -low)
    matrix = target_world('root').copy();matrix.translation.z += correction;set_target('root', matrix)
    bpy.context.view_layer.update()
    return low, root_offset

clips = {'Idle':(2.,True), 'Walk':(.64,True), 'Run':(.6,True), 'Fly':(.8,True),
         'TakeOff':(.5,False), 'Land':(.5,False), 'Eat':(1.8,False), 'Attack':(.48,False),
         'Attack2':(.6,False), 'Attack3':(.72,False), 'Hit':(.5,False), 'Death':(.85,False),
         'Death2':(.85,False), 'Fidget':(2.,True), 'Alert':(1.,False), 'Cast':(1.1,False)}
metadata = {}
for name, (duration, loop) in clips.items():
    action = bpy.data.actions.new(name);rig.animation_data.action = action
    frames = max(2, round(duration*FPS)+1)
    for frame in range(frames):
        scene.frame_set(frame+1)
        low, clearance = frame_pose(name, frame/(frames-1))
        for bone in rig.pose.bones:
            for channel in ['location', 'rotation_quaternion', 'scale']:
                bone.keyframe_insert(data_path=channel, frame=frame+1, group=bone.name)
    track = rig.animation_data.nla_tracks.new();track.name = name
    strip = track.strips.new(name, 1, action);strip.action_slot = action.slots[0];track.mute = True
    metadata[name] = {'duration':(frames-1)/FPS, 'loop':loop, 'support_policy':'airborne' if name in ['Run','Fly','TakeOff','Land'] else 'hop' if name=='Walk' else 'grounded', 'origin':'Authored category on the licensed rig; no original UO choreography recovered.'}
    rig.animation_data.action = None
    print('BIRD AUTHORED:', name, frames, flush=True)
for track in rig.animation_data.nla_tracks:track.mute = False
for bone in rig.pose.bones:bone.matrix_basis = Matrix.Identity(4)
# The source is a small songbird; one presentation scale also serves native crows.
rig.scale *= 1.7
for track in rig.animation_data.nla_tracks:track.mute = True
source_group_max = max(len(vertex.groups) for vertex in mesh.data.vertices)
original_weights = [[(g.group,g.weight) for g in vertex.groups if g.weight>0. and
    (bone:=rig.data.bones.get(mesh.vertex_groups[g.group].name)) is not None and bone.use_deform]
    for vertex in mesh.data.vertices]
source_max_influences = max(map(len,original_weights))
def snapshots():
    result = []
    for name, info in metadata.items():
        action = bpy.data.actions[name];rig.animation_data.action = action;rig.animation_data.action_slot = action.slots[0]
        for phase in [0.,.25,.5,.75,1.]:
            at = 1.+info['duration']*FPS*phase
            scene.frame_set(int(at),subframe=at-int(at));bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());temporary = evaluated.to_mesh()
            result.append([evaluated.matrix_world @ vertex.co for vertex in temporary.vertices]);evaluated.to_mesh_clear()
    return result
def limit_weights(limit):
    for vertex, original in zip(mesh.data.vertices,original_weights):
        for group in [entry.group for entry in vertex.groups]:mesh.vertex_groups[group].remove([vertex.index])
        chosen = sorted(original,key=lambda pair:pair[1],reverse=True)[:limit];total = sum(weight for _,weight in chosen)
        assert total>0.
        # Preserve source group order too: it can affect Blender's reference
        # dual-quaternion accumulation even when the selected weights match.
        kept = {group for group,_ in chosen}
        for group, weight in original:
            if group in kept:mesh.vertex_groups[group].add([vertex.index],weight/total,'REPLACE')
    mesh.data.update();bpy.context.view_layer.update()
full_positions = snapshots();influence_errors = {}
for limit in [4,8]:
    limit_weights(limit);limited = snapshots()
    error = max((a-b).length for full, reduced in zip(full_positions,limited) for a,b in zip(full,reduced))
    influence_errors[str(limit)] = error
    print('BIRD INFLUENCE AUDIT:',limit,error,'metres',flush=True)
# Eight influences retain the source blend more closely; discarded tiny
# weights are bounded against full-weight Blender skinning across all clips.
assert influence_errors['8']<.0005,'Eight-weight reduction exceeds 0.5mm; retain more source information before export'
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:track.mute = False
for bone in rig.pose.bones:bone.matrix_basis = Matrix.Identity(4)
bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active = rig
OUT.mkdir(parents=True, exist_ok=True)
path = OUT / 'small-bird.glb'
bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
    export_force_sampling=True, export_yup=True, export_texcoords=True, export_normals=True, export_tangents=True, export_influence_nb=8)
# glTF alpha masking retains feather edges without transparent-surface sorting.
raw = path.read_bytes();length, tag = struct.unpack_from('<II', raw, 12);assert tag == 0x4e4f534a
gltf = json.loads(raw[20:20+length])
for mat in gltf['materials']:mat.update(alphaMode='MASK', alphaCutoff=.12, doubleSided=True)
payload = json.dumps(gltf,separators=(',',':')).encode();payload += b' '*((-len(payload))%4)
tail = raw[20+length:]
path.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(payload)+len(tail))+struct.pack('<II',len(payload),tag)+payload+tail)
report = {'source':PINS, 'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'clips':metadata, 'muted_authoring_constraints':disabled, 'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
          'source_max_influences':source_max_influences,'export_influences':8,'influence_reduction_error_m':influence_errors,
          'source_group_max':source_group_max,'skinning':'Linear blend; source dual-quaternion preview is deliberately disabled before authoring support clearance.',
          'scope':'Authored motion trial. Native body/hue/action/corpse and terrain acceptance still required.'}
(OUT / 'preparation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('BIRD EXPORTED:',path,flush=True)
