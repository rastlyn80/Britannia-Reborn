"""Rebake cloth after fitting changes, retaining the prepared human motion.

Blender background; run the full preparation first. This fast iteration path
does not retarget or alter any of the 53 native joint animation curves.
"""
import bpy,sys,json,hashlib,importlib.util
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/('Viewer/local-art/free-equipment-female' if '--female' in sys.argv else 'Viewer/local-art/free-equipment')
for argument in sys.argv:
 if argument.startswith('--art-dir='):ART=Path(argument.split('=',1)[1]).resolve()
OUT=ART/'motion';metadata=json.loads((OUT/'motion.json').read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps=metadata['fps']
bpy.ops.import_scene.gltf(filepath=str(OUT/'human-motion.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=next(o for o in bpy.data.objects if o.name=='Body')
tracks=list(rig.animation_data.nla_tracks);actions=[t.strips[0].action for t in tracks]
assert {t.name for t in tracks}==set(metadata['clips'])
for track in tracks:track.mute=True
garments=[]
for path in [ART/'runtime/part-robe.glb',ART/'expansion/skirt.glb',ART/'expansion/kilt.glb']:
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));imported=set(bpy.data.objects)-before
 cloth=next(o for o in imported if o.type=='MESH' and o.name.startswith(('Free_','Extra_')))
 for modifier in cloth.modifiers:
  if modifier.type=='ARMATURE':modifier.object=rig
 cloth.parent=rig;garments.append(cloth)
spec=importlib.util.spec_from_file_location('cloth',ROOT/'scripts/robe-motion.py');cloth=importlib.util.module_from_spec(spec);spec.loader.exec_module(cloth)
metadata['garments']=cloth.bake_envelopes(rig,body,garments,actions)
metadata['garment_recipe_sha256']=hashlib.sha256((ROOT/'scripts/robe-motion.py').read_bytes()).hexdigest()
rig.animation_data.action=None
for pose in rig.pose.bones:pose.matrix_basis=Matrix.Identity(4)
for track in tracks:track.mute=False
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'human-motion.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,export_materials='NONE',export_morph=False)
(OUT/'motion.json').write_text(json.dumps(metadata,indent=2))
print('HUMAN CLOTH REBAKED',metadata['female'],len(actions))
