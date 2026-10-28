"""Prepare long hair over the fixed human wardrobe; keep scalp beneath headwear.

Independent fitted derivatives of the pinned CC0 long/ponytail inputs. The
runtime selects a cached mesh, preserving native hair ID/hue and depth testing.
"""
import bpy,bmesh,json,hashlib,sys
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]

def triangle_weights(point,triangle):
 a,b,c=triangle;u=b-a;v=c-a;w=point-a
 uu=u.dot(u);uv=u.dot(v);vv=v.dot(v);wu=w.dot(u);wv=w.dot(v);den=uu*vv-uv*uv
 if abs(den)<1e-14:return [1.,0.,0.]
 beta=(vv*wu-uv*wv)/den;gamma=(uu*wv-uv*wu)/den
 weights=[max(0.,1-beta-gamma),max(0.,beta),max(0.,gamma)];total=sum(weights)
 return [value/total for value in weights]

def prepare(art):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(art/'equipment-base.glb'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear()
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
 neck=rig.data.bones['neck_01'].head_local;head=rig.data.bones['head'].head_local
 trees=[];hood_tree=None;cloak_data=None
 for slot in ['tunic','robe','hood','shirt','doublet','cloak']:
  path=art/('runtime/part-'+slot+'.glb' if slot in ['tunic','robe','hood'] else 'expansion/'+slot+'.glb')
  before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));added=set(bpy.data.objects)-before
  mesh=next(o for o in added if o.type=='MESH' and o.name.startswith(('Free_','Extra_')))
  transform=rig.matrix_world.inverted()@mesh.matrix_world
  coords=[transform@v.co for v in mesh.data.vertices];mesh.data.calc_loop_triangles()
  torso={v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if mesh.vertex_groups[g.group].name.startswith(('head','neck','spine','clavicle','pelvis','robe_')))>.55}
  faces=[tuple(t.vertices) for t in mesh.data.loop_triangles if all(i in torso for i in t.vertices)]
  tree=BVHTree.FromPolygons(coords,faces,all_triangles=True)
  if slot=='cloak':cloak_data=(tree,faces,[{mesh.vertex_groups[g.group].name:g.weight for g in v.groups} for v in mesh.data.vertices],coords)
  if slot=='hood':hood_tree=tree
  else:trees.append(tree)
  for ob in added:bpy.data.objects.remove(ob,do_unlink=True)
 report=json.loads((art/'expansion/provenance.json').read_text())
 for style in ['long','ponytail']:
  path=art/'expansion'/('hair_'+style+'.glb');source_sha=hashlib.sha256(path.read_bytes()).hexdigest()
  for variant in ['layered','covered','hood','layered_cloak','covered_cloak','hood_cloak']:
   base_variant=variant.split('_')[0]
   before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));added=set(bpy.data.objects)-before
   hair=next(o for o in added if o.type=='MESH' and o.name.startswith('Extra_hair_'))
   transform=rig.matrix_world.inverted()@hair.matrix_world
   for vertex in hair.data.vertices:vertex.co=transform@vertex.co
   hair.parent=rig;hair.matrix_parent_inverse=Matrix.Identity(4);hair.matrix_basis=Matrix.Identity(4)
   for mod in hair.modifiers:
    if mod.type=='ARMATURE':mod.object=rig
   if base_variant!='layered':
    # Leave the actual long sections below the ears; the hood/hat supplies
    # the scalp silhouette. No depth override or hair through the face.
    bm=bmesh.new();bm.from_mesh(hair.data)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=(0,0,head.z+.12),plane_no=(0,0,1),clear_outer=True)
    bm.to_mesh(hair.data);bm.free()
   if variant.endswith('_cloak'):
    # Sparse cards can cross a curved cape between correctly fitted vertices.
    # Add local samples while preserving the original UV/alpha silhouette.
    bm=bmesh.new();bm.from_mesh(hair.data)
    edges=[edge for edge in bm.edges if edge.calc_length()>.045 and min(v.co.z for v in edge.verts)<neck.z+.05]
    bmesh.ops.subdivide_edges(bm,edges=edges,cuts=2,use_grid_fill=True)
    bm.to_mesh(hair.data);bm.free()
   moved=0;maximum=0.
   for vertex in hair.data.vertices:
    co=vertex.co;source_co=co.copy()
    if co.z>head.z+.045:continue
    center=Vector((neck.x,neck.y,co.z));direction=co-center;direction.z=0
    if direction.length<.015:continue
    direction.normalize();radius=(co-center).dot(direction)
    for tree in trees+([hood_tree] if base_variant=='hood' else []):
     if tree is None:continue
     point,normal,face,distance=tree.ray_cast(center+direction*.8,-direction, .8)
     if point is not None:radius=max(radius,(point-center).dot(direction)+.012)
    target=center+direction*radius;delta=target-co
    # Reject unrelated sleeve surfaces; preserve a compact hair silhouette.
    if delta.length>.16:delta*=.16/delta.length
    if delta.length>.0001:co+=delta
    # Tail follows the shoulders instead of rotating as one rigid head slab.
    amount=min(.85,max(0.,(head.z-co.z)/.22));weights={'head':1.-amount,'spine_03':amount}
    if variant.endswith('_cloak') and co.z<neck.z+.04:
     tree,faces,skin,coords=cloak_data
     # Lay long sections behind the cape. A radial ray misses its back
     # panel for strands originally draped in front of the shoulders.
     point,normal,face,distance=tree.ray_cast(Vector((co.x,.8,co.z)),Vector((0,-1,0)),1.6)
     if point is None:point,normal,face,distance=tree.find_nearest(co)
     if point is not None:
      co.y=max(co.y,point.y+.050);vertex.co=co
      refs=faces[face];factors=triangle_weights(point,[coords[i] for i in refs]);total=sum(factors);cape={}
      for i,factor in zip(refs,factors):
       for name,value in skin[i].items():cape[name]=cape.get(name,0.)+value*factor/total
      amount=min(1.,max(0.,(head.z-co.z-.025)/.16));weights={name:value*(1-amount) for name,value in weights.items()}
      for name,value in cape.items():weights[name]=weights.get(name,0.)+value*amount
      chosen=sorted(weights.items(),key=lambda x:-x[1])[:4];total=sum(value for name,value in chosen);weights={name:value/total for name,value in chosen}
    for index in [g.group for g in vertex.groups]:hair.vertex_groups[index].remove([vertex.index])
    for name,value in weights.items():
     group=hair.vertex_groups.get(name) or hair.vertex_groups.new(name=name);group.add([vertex.index],value,'REPLACE')
    distance=(vertex.co-source_co).length
    if distance>.0001:moved+=1;maximum=max(maximum,distance)
   name='hair_'+style+'_'+variant;hair.name='Extra_'+name
   bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);hair.select_set(True);bpy.context.view_layer.objects.active=rig
   destination=art/'expansion'/(name+'.glb')
   bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
   report['parts'][name]={'source_part':'hair_'+style,'source_sha256':source_sha,'licence':'CC0-1.0','sha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'vertices':len(hair.data.vertices),'moved_vertices':moved,'max_push_m':maximum,'scalp_trimmed':base_variant!='layered','follows_cloak':variant.endswith('_cloak'),'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
   for ob in added:bpy.data.objects.remove(ob,do_unlink=True)
 report['hair_layers']={'styles':['long','ponytail'],'variants':['layered','covered','hood','layered_cloak','covered_cloak','hood_cloak'],'clearance_m':.012,'cloak_clearance_m':.050,'scope':'Fixed-body wardrobe envelope, shoulder-following tails, cloak-specific barycentric surface bindings, scalp tucked beneath headwear; depth-tested geometry. Not strand simulation or universal collision proof.'}
 (art/'expansion/provenance.json').write_text(json.dumps(report,indent=2))
 print('LAYERED LONG HAIR READY',art.name,flush=True)

if __name__=='__main__':
 for suffix in ['','-female']:prepare(ROOT/('Viewer/local-art/free-equipment'+suffix))
