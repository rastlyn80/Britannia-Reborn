"""Sample exported civilian clothing on prepared motion, using the real body.

Reports near-surface vertex penetration, severe penetration and floor clearance.
This finite vertex check does not prove triangle collision or cloth physics.
"""
import bpy,json
from pathlib import Path
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
rows=[];failures=[]
for female in [False,True]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 bpy.ops.import_scene.gltf(filepath=str(art/'motion/human-motion.glb'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=next(o for o in bpy.data.objects if o.name=='Body')
 for track in rig.animation_data.nla_tracks:track.mute=True
 clothes={}
 for name in ['doublet','cloak','shoes','sandals']:
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(art/'expansion'/(name+'.glb')))
  ob=next(o for o in set(bpy.data.objects)-before if o.type=='MESH' and o.name.startswith('Extra_'))
  for modifier in ob.modifiers:
   if modifier.type=='ARMATURE':modifier.object=rig
  ob.parent=rig;clothes[name]=ob
 actions=[track.strips[0].action for track in rig.animation_data.nla_tracks if track.name in ['Idle','Walk','Jog','Run','Sprint','Sword_Idle','Sword_A','Cast','Bow','Fidget_Talk','Fidget_Look','Jump']]
 for action in actions:
  rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
  for phase in [i/8 for i in range(8)]:
   frame=action.frame_range[0]+(action.frame_range[1]-action.frame_range[0])*phase;bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
   deps=bpy.context.evaluated_depsgraph_get();skin=body.evaluated_get(deps);skin.data.calc_loop_triangles()
   body_points=[skin.matrix_world@v.co for v in skin.data.vertices]
   body_low=min(p.z for p in body_points)
   tree=BVHTree.FromPolygons(body_points,[tuple(t.vertices) for t in skin.data.loop_triangles],all_triangles=True)
   for name,ob in clothes.items():
    requested=action.name.split('.')[0]
    actual=('Jog' if requested in ['Run','Sprint'] else ('Sword_A_Cloth' if requested=='Sword_A' else requested)) if name=='cloak' else requested
    target=next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name==actual)
    rig.animation_data.action=target;rig.animation_data.action_slot=target.slots[0]
    fitted_frame=target.frame_range[0]+(target.frame_range[1]-target.frame_range[0])*phase;bpy.context.scene.frame_set(int(fitted_frame),subframe=fitted_frame-int(fitted_frame));bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get();skin=body.evaluated_get(deps);skin.data.calc_loop_triangles();body_points=[skin.matrix_world@v.co for v in skin.data.vertices];body_low=min(p.z for p in body_points)
    tree=BVHTree.FromPolygons(body_points,[tuple(t.vertices) for t in skin.data.loop_triangles],all_triangles=True)
    ev=ob.evaluated_get(deps);points=[ev.matrix_world@v.co for v in ev.data.vertices];inside=0;deep=0;minimum=0.;checked=0;outliers=[]
    for p in points[::max(1,len(points)//1200)]:
     point,normal,face,distance=tree.find_nearest(p)
     if point is None:continue
     checked+=1;signed=(p-point).dot(normal)
     if distance<.045 and signed<-.005:inside+=1;minimum=min(minimum,signed)
     if distance<.045 and signed<-.02:
      deep+=1
      if len(outliers)<3:outliers.append({'point':list(p),'skin':list(point),'signed':signed})
    low=min(p.z for p in points)
    row={'female':female,'piece':name,'requested_clip':requested,'clip':actual,'phase':phase,'checked':checked,'near_penetrations':inside,'deep_penetrations':deep,'min_signed_distance':minimum,'min_height':low,'body_min_height':body_low,'outliers':outliers};rows.append(row)
    # Prepared feet are corrected by the live foot-contact modifier. A sole
    # may sit below bare skin; compare its thickness against the same pose.
    floor_limit=min(0.,body_low)-.025 if name in ['shoes','sandals'] else -.025
    if deep or low<floor_limit:failures.append(row)
report={'samples':rows,'failures':failures,'scope':'Two fixed bodies, 12 prepared clips, eight phases. Near-body vertex tests; footwear sole no more than 25 mm below the posed bare foot. Live foot-contact correction is separate. Not triangle collision, layered garment collision or general cloth physics.'}
(ROOT/'outputs/human-wardrobe-2').mkdir(parents=True,exist_ok=True)
(ROOT/'outputs/human-wardrobe-2/pose-validation.json').write_text(json.dumps(report,indent=2))
print('CIVILIAN GARMENTS:',len(rows),'poses,',sum(r['near_penetrations'] for r in rows),'near vertex penetrations,',len(failures),'severe failures')
if failures:raise RuntimeError(str(failures[:6]))
