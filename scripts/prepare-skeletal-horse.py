import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
root=Path(__file__).resolve().parents[1];source=root/'work/skeletal-source/horse-skeleton.glb'
assert hashlib.sha256(source.read_bytes()).hexdigest()=='08d6dc96f600318d34f42e1f718a61f897aa09a31fb963bbd59ab23d21091c88'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source))
scan=next(o for o in bpy.data.objects if o.type=='MESH')
points=[scan.matrix_world@v.co for v in scan.data.vertices]
lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
upper=[p for p in points if p.z>lo.z+(hi.z-lo.z)*.9];flip=-1 if sum(p.y for p in upper)/len(upper)>0 else 1
# Anatomical scan has no ears: fit skull top at 2.0 m. Keep uniform proportions.
scale=2.0/(hi.z-lo.z)
for v,p in zip(scan.data.vertices,points):v.co=Vector(((p.x-(lo.x+hi.x)/2)*scale*flip,(p.y-(lo.y+hi.y)/2)*scale*flip,(p.z-lo.z)*scale))
scan.matrix_world.identity();scan.name='SkeletalHorse'
bpy.context.view_layer.objects.active=scan;scan.select_set(True)
modifier=scan.modifiers.new('Game triangle budget','DECIMATE');modifier.ratio=.12;bpy.ops.object.modifier_apply(modifier=modifier.name)
scan.select_set(False)
before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(root/'Viewer/local-art/horses/warhorse-regions.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
horse=next(o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Warhorse'))
tree=KDTree(len(horse.data.vertices))
for v in horse.data.vertices:tree.insert(horse.matrix_world@v.co,v.index)
tree.balance()
for group in horse.vertex_groups:scan.vertex_groups.new(name=group.name)
for v in scan.data.vertices:
 weights={}
 for _,index,distance in tree.find_n(v.co,4):
  amount=1/max(.015,distance)**3
  for g in horse.data.vertices[index].groups:weights[g.group]=weights.get(g.group,0)+g.weight*amount
 best=sorted(weights.items(),key=lambda x:-x[1])[:4];total=sum(w for _,w in best)
 assert total>0
 for index,w in best:scan.vertex_groups[index].add([v.index],w/total,'REPLACE')
modifier=scan.modifiers.new('Accepted horse motion rig','ARMATURE');modifier.object=rig;scan.parent=rig
for o in list(bpy.data.objects):
 if o.type=='MESH' and o!=scan:bpy.data.objects.remove(o,do_unlink=True)
for polygon in scan.data.polygons:polygon.use_smooth=True
# The scan material is genuine bone albedo; retain it, with matte nonmetallic response.
for material in scan.data.materials:
 if material and material.use_nodes:
  for node in material.node_tree.nodes:
   if node.type=='BSDF_PRINCIPLED':node.inputs['Roughness'].default_value=.82;node.inputs['Metallic'].default_value=0
# Fit the socket to the actual scanned spinal surface. Only unweighted
# attachment bones move; the accepted deformation hierarchy stays intact.
back=sorted(v.co.z for v in scan.data.vertices if abs(v.co.x)<.12 and abs(v.co.y-.086)<.20)
assert back
seat_height=back[int(.95*(len(back)-1))]+.035
socket_delta=seat_height-rig.data.bones['saddle_socket'].head_local.z
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for name in ['saddle_socket','stirrup_L','stirrup_R']:
 bone=rig.data.edit_bones[name];bone.head.z+=socket_delta;bone.tail.z+=socket_delta
bpy.ops.object.mode_set(mode='OBJECT')
rig.data.pose_position='POSE'
output=root/'Viewer/local-art/mounts/skeletal-horse.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_animations=True,export_skins=True)
report={'source':'https://renderlyst.site/library/models/horse-skeleton.glb','original':'https://sketchfab.com/3d-models/horse-skeleton-eaca504567604e879b8ab2cf2763025e','creator':'Diego Luján García','licence':'CC BY 4.0','licence_url':'https://creativecommons.org/licenses/by/4.0/','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'rig':'Accepted locally licensed Warhorse Lite 39-joint rig and clips; preserve its separate licence','modifications':'Uniform scale, orientation/floor calibration, decimation, smooth normals, four-neighbour spatial skin transfer (at most four normalised influences)','triangle_count':sum(len(p.vertices)-2 for p in scan.data.polygons),'flip_xy':flip,'uniform_scale':scale,'seat_height_m':seat_height,'socket_delta_m':socket_delta}
(output.with_suffix('.provenance.json')).write_text(json.dumps(report,indent=2));print('SKELETAL PREPARED',report)
