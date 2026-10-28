"""Sample the exact shared-rig skirt attachments against animated leg geometry."""
import bpy,json
from collections import Counter,defaultdict
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
bpy.context.preferences.filepaths.file_preview_type='NONE'
rows=[];failures=[]
def hem_landmarks(mesh):
 # glTF splits UV seams; weld equal positions for topology analysis only.
 canonical={};reverse=defaultdict(list);index_to_key={}
 for vertex in mesh.vertices:
  key=tuple(round(c,6) for c in vertex.co);canonical.setdefault(key,len(canonical));i=canonical[key];index_to_key[vertex.index]=i;reverse[i].append(vertex.index)
 edges=Counter()
 for poly in mesh.polygons:
  indices=[index_to_key[i] for i in poly.vertices]
  for a,b in zip(indices,indices[1:]+indices[:1]):
   if a!=b:edges[tuple(sorted((a,b)))]+=1
 graph=defaultdict(set)
 for (a,b),count in edges.items():
  if count==1:graph[a].add(b);graph[b].add(a)
 groups=[];remaining=set(graph)
 while remaining:
  stack=[remaining.pop()];group=set(stack)
  while stack:
   for n in graph[stack.pop()]:
    if n in remaining:remaining.remove(n);group.add(n);stack.append(n)
  groups.append([original for i in group for original in reverse[i]])
 assert groups,'No physical garment boundary found'
 hem=min(groups,key=lambda ids:sum(mesh.vertices[i].co.z for i in ids)/len(ids))
 assert max(mesh.vertices[i].co.z for i in hem)<max(v.co.z for v in mesh.vertices)-.2,'Hem could not be separated from waist'
 return hem
for female in [False,True]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 bpy.ops.import_scene.gltf(filepath=str(art/'equipment-base.glb'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 body=next(o for o in bpy.data.objects if o.name=='Body')
 for tr in rig.animation_data.nla_tracks:tr.mute=True
 actions=[a for a in bpy.data.actions if a.name in ['Idle','Walk','Run']]
 leg_ids=[v.index for v in body.data.vertices if .25<(body.matrix_world@v.co).z<.88 and sum(g.weight for g in v.groups if body.vertex_groups[g.group].name.startswith(('thigh','calf','foot')))>.5]
 for piece in ['skirt','kilt']:
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(art/'expansion'/(piece+'.glb')));imported=set(bpy.data.objects)-before
  cloth=next(o for o in imported if o.type=='MESH' and o.name.startswith('Extra_'))
  for mod in cloth.modifiers:
   if mod.type=='ARMATURE':mod.object=rig
  cloth.parent=rig
  hem_ids=hem_landmarks(cloth.data)
  for action in actions:
   rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
   for phase in [i/16 for i in range(16)]:
    f=action.frame_range[0]+(action.frame_range[1]-action.frame_range[0])*phase;bpy.context.scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get();ev=cloth.evaluated_get(deps);ev.data.calc_loop_triangles();coords=[ev.matrix_world@v.co for v in ev.data.vertices];hem_top=max(coords[i].z for i in hem_ids)
    tree=BVHTree.FromPolygons(coords,[tuple(t.vertices) for t in ev.data.loop_triangles],all_triangles=True);skin=body.evaluated_get(deps);outside=0;checked=0;outliers=[]
    for i in leg_ids:
     p=skin.matrix_world@skin.data.vertices[i].co
     if p.z<max(.5,hem_top+.025):continue
     left=tree.ray_cast(Vector((-2,p.y,p.z)),Vector((1,0,0)),4.)[0];right=tree.ray_cast(Vector((2,p.y,p.z)),Vector((-1,0,0)),4.)[0];checked+=1
     if left is None or right is None or not left.x-.003<=p.x<=right.x+.003:
      outside+=1
      if len(outliers)<8:outliers.append({'vertex':i,'point':list(p),'left':list(left) if left is not None else None,'right':list(right) if right is not None else None})
    min_z=min(p.z for p in coords)
    row={'female':female,'piece':piece,'clip':action.name,'phase':phase,'checked':checked,'outside':outside,'min_height':min_z,'opening_top':hem_top};rows.append(row)
    if outside or min_z<.01:failures.append(dict(row,outliers=outliers))
  for ob in imported:bpy.data.objects.remove(ob,do_unlink=True)
report={'samples':rows,'failures':failures,'scope':'Two fixed bodies, side-ray enclosure above animated openings, native Idle/Walk/Run only; not cloth physics or all actions.'}
(ROOT/'outputs/third-dawn/expanded-skirt-validation.json').write_text(json.dumps(report,indent=2))
print('EXPANDED SKIRTS:',len(rows),'poses,',len(failures),'failures')
if failures:raise RuntimeError(str(failures[:5]))
