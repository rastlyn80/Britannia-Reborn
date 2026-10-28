"""Fit new fixed-body garments against sampled runtime poses.

Move clothing vertices in bind space using their actual blended skin transform;
preserve UVs, bones and motion. This is an offline fit, not runtime cloth physics.
"""
import bpy,json,hashlib,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
REQUESTS=['Idle','Walk','Jog','Run','Sprint','Sword_Idle','Sword_A','Cast','Bow','Fidget_Talk','Fidget_Look','Jump']

def fit(art,only=None):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(art/'motion/human-motion.glb'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=next(o for o in bpy.data.objects if o.name=='Body')
 for track in rig.animation_data.nla_tracks:track.mute=True
 actions={track.name:track.strips[0].action for track in rig.animation_data.nla_tracks}
 clothes={}
 for name in (only or ['doublet','cloak','shoes','sandals']):
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(art/'expansion'/(name+'.glb')))
  ob=next(o for o in set(bpy.data.objects)-before if o.type=='MESH' and o.name.startswith('Extra_'))
  for modifier in ob.modifiers:
   if modifier.type=='ARMATURE':modifier.object=rig
  ob.parent=rig;clothes[name]=ob
 history=[];totals={name:0. for name in clothes};pose_cache={}
 neighbours={i:set() for i in range(len(clothes['cloak'].data.vertices))}
 for edge in clothes['cloak'].data.edges:
  a,b=edge.vertices;neighbours[a].add(b);neighbours[b].add(a)
 for iteration in range(8):
  corrections={name:{} for name in clothes};penetrations=0
  for request in REQUESTS:
   for step in range(8):
    phase=step/8
    for name,ob in clothes.items():
     actual=('Jog' if request in ['Run','Sprint'] else ('Sword_A_Cloth' if request=='Sword_A' else request)) if name=='cloak' else request
     action=actions[actual];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
     frame=action.frame_range[0]+(action.frame_range[1]-action.frame_range[0])*phase;bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
     deps=bpy.context.evaluated_depsgraph_get();key=(actual,step)
     if key not in pose_cache:
      skin=body.evaluated_get(deps);skin.data.calc_loop_triangles();skin_points=[skin.matrix_world@v.co for v in skin.data.vertices]
      tree=BVHTree.FromPolygons(skin_points,[tuple(t.vertices) for t in skin.data.loop_triangles],all_triangles=True)
      minimum=min(0.,min(p.z for p in skin_points))-.018
      transforms={bone.name:rig.pose.bones[bone.name].matrix@bone.matrix_local.inverted() for bone in rig.data.bones}
      pose_cache[key]=(tree,minimum,transforms)
     tree,minimum,transforms=pose_cache[key]
     cloth=ob.evaluated_get(deps)
     for vertex in cloth.data.vertices:
      p=cloth.matrix_world@vertex.co;point,normal,face,distance=tree.find_nearest(p);push=Vector()
      if point is not None and distance<.055:
       signed=(p-point).dot(normal)
       if signed<.004:push+=normal*(.004-signed);penetrations+=1
      if name in ['shoes','sandals'] and p.z+push.z<minimum:push.z+=minimum-p.z-push.z
      if push.length<.0005:continue
      original=ob.data.vertices[vertex.index];skin_matrix=Matrix.Identity(4)*0.
      for group in original.groups:skin_matrix+=transforms[ob.vertex_groups[group.group].name]*group.weight
      delta=(rig.matrix_world.to_3x3()@skin_matrix.to_3x3()).inverted_safe()@push
      if delta.length>.025:delta*=.025/delta.length
      old=corrections[name].get(vertex.index,Vector())
      if delta.length>old.length:corrections[name][vertex.index]=delta
  # Spread cape contact corrections across neighbouring fabric vertices;
  # independent point pushes otherwise create saw-tooth shoulder/hip edges.
  for smoothing in range(2):
   values=corrections['cloak'];indices=set(values)
   for i in list(indices):indices.update(neighbours[i])
   corrections['cloak']={i:values.get(i,Vector())*.65+sum((values.get(j,Vector()) for j in neighbours[i]),Vector())*(.35/max(1,len(neighbours[i]))) for i in indices}
  history.append({'iteration':iteration,'near_contacts':penetrations,'corrected_vertices':{name:len(values) for name,values in corrections.items()}})
  for name,values in corrections.items():
   for index,delta in values.items():clothes[name].data.vertices[index].co+=delta;totals[name]=max(totals[name],delta.length)
   clothes[name].data.update()
  if not any(corrections.values()):break
 rig.animation_data.action=None
 for pose in rig.pose.bones:pose.matrix_basis=Matrix.Identity(4)
 spec=importlib.util.spec_from_file_location('civilian',ROOT/'scripts/human-civilian-clothes.py');civilian=importlib.util.module_from_spec(spec);spec.loader.exec_module(civilian)
 report=json.loads((art/'expansion/provenance.json').read_text())
 for name,ob in clothes.items():
  bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
  path=art/'expansion'/(name+'.glb')
  bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
  if name=='cloak':civilian.material_factor(path,[.16,.22,.12,1.])
  report['parts'][name]['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
 result={'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'pieces':list(clothes),'requested_clips':REQUESTS,'phases':8,'iterations':history,'max_single_step_m':totals,'scope':'Fixed-body bind-space correction; cloak uses runtime garment-safe actions. Not cloth physics or universal collision proof.'}
 if only:report.setdefault('civilian_pose_fit',{}).setdefault('piece_overrides',{})[','.join(only)]=result
 else:report['civilian_pose_fit']=result
 (art/'expansion/provenance.json').write_text(json.dumps(report,indent=2))
 print('CIVILIAN POSE FIT',art.name,history,flush=True)
