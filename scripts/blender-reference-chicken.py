"""Independent, disabled-script source evaluation for imported skin comparison."""
import bpy, hashlib, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'work/creatures/chicken';SRC=BASE/'source/extracted'
pins=json.loads((ROOT/'scripts/chicken-inputs.json').read_text(encoding='utf-8'))
for member in pins['members']:assert hashlib.sha256((SRC/member['path']).read_bytes()).hexdigest()==member['sha256']
bpy.ops.wm.open_mainfile(filepath=str(SRC/'chickenV2.blend'),load_ui=False,use_scripts=False)
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
scene=bpy.context.scene;rig=next(o for o in scene.objects if o.type=='ARMATURE')
source_basis={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
meshes=[o for o in scene.objects if o.type=='MESH' and o.name in ['Chicken','Eyes']]
assert len(meshes)==2
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
def vertices():
 result=[]
 for mesh in meshes:
  obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=obj.to_mesh()
  result.extend(obj.matrix_world@v.co for v in data.vertices);obj.to_mesh_clear()
 return result
rig.animation_data.action=bpy.data.actions['Idle1'];scene.frame_set(1);bpy.context.view_layer.update()
points=vertices();low=min(v.z for v in points);scale=.45/(max(v.z for v in points)-low)
rows=[]
for action in bpy.data.actions:
 if action.name in ['Stand','StopPecking']:continue
 rig.animation_data.action=None
 for bone in rig.pose.bones:bone.matrix_basis=source_basis[bone.name]
 rig.animation_data.action=action;start,end=map(float,action.frame_range)
 for sample in range(17):
  phase=sample/16;at=start+(end-start)*phase;scene.frame_set(math.floor(at),subframe=at%1);bpy.context.view_layer.update()
  points=vertices();floor=max(0.,-(min(v.z for v in points)-low)*scale)
  bones={b.name:rig.matrix_world@b.matrix.translation for b in rig.pose.bones}
  rows.append({'clip':action.name,'phase':phase,'source_floor_raise':floor,'points':[[v.x*scale,(v.z-low)*scale+floor,-v.y*scale] for v in points],'bones':{k:[v.x*scale,(v.z-low)*scale+floor,-v.y*scale] for k,v in bones.items()}})
 print('SOURCE SKIN REFERENCE',action.name,flush=True)
path=BASE/'source-reference.json';path.write_text(json.dumps({'source_pin_sha256':hashlib.sha256((ROOT/'scripts/chicken-inputs.json').read_bytes()).hexdigest(),'source_sha256':hashlib.sha256((SRC/'chickenV2.blend').read_bytes()).hexdigest(),'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'scale':scale,'source_vertices':len(points),'samples':rows},separators=(',',':'))+'\n')
print('SOURCE SKIN REFERENCE COMPLETE',len(rows),len(points),flush=True)
