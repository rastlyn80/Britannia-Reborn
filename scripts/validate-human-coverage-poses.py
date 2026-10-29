"""Finite poses, floor clearance and rigid manufactured plate edges.

Actual opacity/skin coverage is separately tested by HumanArmourCoverageTests.gd
against an independently rendered full body, including its complete seat.
"""
import bpy,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
rows=[];failures=[]
names=[r['key'] for r in json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets'] if r['kind']=='shell']
for female in [False,True]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 bpy.ops.import_scene.gltf(filepath=str(art/'motion/human-motion.glb'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 for track in rig.animation_data.nla_tracks:track.mute=True
 clothes={}
 for name in names:
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(art/'coverage'/(name+'.glb')))
  ob=next(o for o in set(bpy.data.objects)-before if o.type=='MESH' and o.name.startswith('Extra_'))
  for modifier in ob.modifiers:
   if modifier.type=='ARMATURE':modifier.object=rig
  ob.parent=rig
  rigid={v.index:next((g.group for g in v.groups if g.weight>.99999),None) for v in ob.data.vertices}
  # Cloth blends and joins between independently articulated parts excluded.
  edges=[(e.vertices[0],e.vertices[1],(ob.matrix_world@ob.data.vertices[e.vertices[0]].co-ob.matrix_world@ob.data.vertices[e.vertices[1]].co).length) for e in ob.data.edges if rigid[e.vertices[0]] is not None and rigid[e.vertices[0]]==rigid[e.vertices[1]]]
  clothes[name]=(ob,[(a,b,d) for a,b,d in edges if d>.001])
 actions=[track.strips[0].action for track in rig.animation_data.nla_tracks if track.name in ['Idle','Walk','Run','Sword_A','Cast','Bow_Attack','Crossbow_Attack','Turn','Salute','Fidget3']]
 for action in actions:
  rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
  for phase in [i/8 for i in range(8)]:
   frame=action.frame_range[0]+(action.frame_range[1]-action.frame_range[0])*phase
   bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
   deps=bpy.context.evaluated_depsgraph_get()
   for name,(ob,edges) in clothes.items():
    ev=ob.evaluated_get(deps);points=[ev.matrix_world@v.co for v in ev.data.vertices]
    finite=all(math.isfinite(c) for p in points for c in p)
    drift=max([abs((points[a]-points[b]).length/d-1.) for a,b,d in edges]+[0.])
    low=min(p.z for p in points)
    row={'female':female,'piece':name,'clip':action.name.split('.')[0],'phase':phase,'finite':finite,'rigid_edges_checked':len(edges),'maximum_rigid_edge_relative_error':drift,'min_height':low}
    rows.append(row)
    if not finite or drift>.001 or low<-.025:failures.append(row)
out=ROOT/'outputs/human-coverage-session';out.mkdir(exist_ok=True)
(out/'armour-pose-validation.json').write_text(json.dumps({'samples':rows,'failures':failures,'scope':'Two bodies, 15 armour parts, ten actions/eight phases. Finite poses, 25 mm floor allowance and <=0.1% rigid edge deformation. GPU opacity/skin coverage is separate. Not universal triangle collision.'},indent=2))
print('COVERAGE ARMOUR:',len(rows),'poses,',len(failures),'failures; max rigid edge error',max(r['maximum_rigid_edge_relative_error'] for r in rows))
if failures:raise RuntimeError(str(failures[:5]))
