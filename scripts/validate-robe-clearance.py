"""Independent geometric checks of the exported robe in Blender.

Checks 48 native poses: side-ray enclosure of retained leg vertices above
the animated hem (and 0.50 m), plus floor clearance. Open hems are intentionally
excluded. This supplements rendered review; it is not universal collision proof.
"""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
FEMALE='--female' in sys.argv
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.file_preview_type='NONE'
bpy.ops.import_scene.gltf(filepath=str(ROOT/('Viewer/local-art/free-equipment-female/equipment-robe.glb' if FEMALE else 'Viewer/local-art/free-equipment/equipment-robe.glb')))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Body'))
robe=next(o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Free_robe'))
ids=[v.index for v in body.data.vertices if .25<(body.matrix_world@v.co).z<.85]
hem_ids=[v.index for v in robe.data.vertices if (robe.matrix_world@v.co).z<.18]
cuff_ids=[v.index for v in robe.data.vertices if .85<(robe.matrix_world@v.co).z<1.0 and abs((robe.matrix_world@v.co).x)>.37 and sum(g.weight for g in v.groups if robe.vertex_groups[g.group].name.startswith(('lowerarm','hand')))>.5] if FEMALE else []
if FEMALE:assert cuff_ids,'Could not identify shorter-body sleeve cuffs'
assert hem_ids,'Could not identify the authored lower opening'
for tr in rig.animation_data.nla_tracks:tr.mute=True
rows=[];failures=[]
for action in bpy.data.actions:
 if action.name not in ['Idle','Walk','Run']:continue
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 for phase in [i/16 for i in range(16)]:
  f=action.frame_range[0]+(action.frame_range[1]-action.frame_range[0])*phase
  bpy.context.scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
  cloth=robe.evaluated_get(deps);cloth.data.calc_loop_triangles()
  coords=[cloth.matrix_world@v.co for v in cloth.data.vertices]
  hem_top=max(coords[i].z for i in hem_ids)
  tree=BVHTree.FromPolygons(coords,[tuple(t.vertices) for t in cloth.data.loop_triangles],all_triangles=True)
  ev=body.evaluated_get(deps);outside=0;checked=0
  for i in ids:
   p=ev.matrix_world@ev.data.vertices[i].co
   if p.z<max(.50,hem_top+.02):continue
   left=tree.ray_cast(Vector((-2,p.y,p.z)),Vector((1,0,0)),4.)[0]
   right=tree.ray_cast(Vector((2,p.y,p.z)),Vector((-1,0,0)),4.)[0]
   checked+=1
   if left is None or right is None or not left.x-.003<=p.x<=right.x+.003:outside+=1
  low=min(p.z for p in coords)
  hands=[rig.matrix_world@rig.pose.bones['hand_'+side].head for side in ['l','r']]
  cuff_distance=max((min((coords[i]-hand).length for hand in hands) for i in cuff_ids),default=0.)
  if cuff_distance>.25:failures.append(dict(clip=action.name,phase=phase,cuff_distance=cuff_distance,reason='Sleeve cuff no longer follows wrist'))
  if outside or low<.015:failures.append(dict(clip=action.name,phase=phase,outside=outside,min_height=low))
  rows.append(dict(clip=action.name,phase=phase,checked_leg_vertices=checked,outside=outside,min_robe_height=low,max_opening_height=hem_top,cuff_distance=cuff_distance))
report=dict(asset='equipment-robe.glb',sex='female' if FEMALE else 'male',cuff_landmarks=len(cuff_ids),samples=rows,failures=failures,limitation='Side-ray enclosure above the animated opening and 0.50 m; fixed body, native Idle/Walk/Run only; not general cloth physics or all animation coverage')
(ROOT/'outputs/third-dawn'/('female-robe-clearance-validation.json' if FEMALE else 'robe-clearance-validation.json')).write_text(json.dumps(report,indent=2))
print('Robe clearance:',len(rows),'poses,',sum(r['checked_leg_vertices'] for r in rows),'leg samples,',len(failures),'failures')
if failures:raise RuntimeError(str(failures))
