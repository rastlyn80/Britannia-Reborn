"""Expand source B-Bone deformation into ordinary skin joints without remeshing.

Uses Blender's documented segment matrix/weight interpolation semantics:
https://docs.blender.org/api/5.2/bpy.types.PoseBone.html#bpy.types.PoseBone.bbone_segment_matrix
"""
import bpy
def expand(rig,meshes):
 bpy.context.view_layer.update();specs=[];rest={};mapping={}
 for bone in rig.pose.bones:
  if bone.bone.bbone_segments<=1:continue
  segments=bone.bone.bbone_segments
  for i in range(segments+1):
   name='SourceBB_'+bone.name.replace('.','_')+'_'+str(i)
   specs.append({'source':bone.name,'index':i,'name':name,'segments':segments,'length':bone.bone.length/segments})
   rest[name]=bone.bone.matrix_local@bone.bbone_segment_matrix(i,rest=True)
 names={s['source'] for s in specs}
 for mesh in meshes:
  matrix=rig.matrix_world.inverted()@mesh.matrix_world;vertices=[]
  for vertex in mesh.data.vertices:
   values={mesh.vertex_groups[g.group].name:g.weight for g in vertex.groups if g.weight>0}
   for name in names:
    if name not in values:continue
    weight=values.pop(name);index,blend=rig.pose.bones[name].bbone_segment_index(matrix@vertex.co)
    for i,factor in [(index,1.-blend),(index+1,blend)]:
     target=next(s['name'] for s in specs if s['source']==name and s['index']==i)
     if factor>0:values[target]=values.get(target,0.)+weight*factor
   assert len(values)<=8,(mesh.name,vertex.index,len(values));vertices.append(values)
  mapping[mesh.name]=vertices
 bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
 for spec in specs:
  bone=rig.data.edit_bones.new(spec['name']);bone.matrix=rest[spec['name']];bone.length=spec['length'];bone.use_deform=True
 bpy.ops.object.mode_set(mode='OBJECT')
 for spec in specs:spec['rest_correction']=[list(r) for r in rest[spec['name']].inverted()@rig.data.bones[spec['name']].matrix_local]
 for mesh in meshes:
  for name in names:
   if mesh.vertex_groups.get(name):mesh.vertex_groups.remove(mesh.vertex_groups[name])
  for spec in specs:
   if not mesh.vertex_groups.get(spec['name']):mesh.vertex_groups.new(name=spec['name'])
  for i,values in enumerate(mapping[mesh.name]):
   for name,weight in values.items():mesh.vertex_groups[name].add([i],weight,'REPLACE')
 bpy.context.view_layer.update()
 return specs
