"""Build fitted doublet and authored cloak on the existing human skeleton.

No additional bones or executable asset inputs. Called by the expansion builder.
"""
import bpy,bmesh,math,hashlib,json,struct
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]

def body_surface(rig,body):
 body.data.calc_loop_triangles();transform=rig.matrix_world.inverted()@body.matrix_world
 coords=[transform@v.co for v in body.data.vertices];faces=[tuple(t.vertices) for t in body.data.loop_triangles]
 return BVHTree.FromPolygons(coords,faces,all_triangles=True),coords,faces

def bind_surface(ob,body,tree,coords,faces,clearance,only_upper=False):
 """Rebind reshaped boundary vertices to their actual nearest skin triangle."""
 names={group.index:group.name for group in body.vertex_groups}
 for vertex in ob.data.vertices:
  if only_upper and vertex.co.z<1.24:continue
  point,normal,face,distance=tree.find_nearest(vertex.co)
  if point is None:continue
  signed=(vertex.co-point).dot(normal)
  if distance<.12 and signed<clearance:vertex.co+=normal*(clearance-signed)
  values={};references=faces[face];factors=[1/max((coords[i]-point).length,.0001)**2 for i in references];total=sum(factors)
  for i,factor in zip(references,factors):
   for group in body.data.vertices[i].groups:values[names[group.group]]=values.get(names[group.group],0.)+group.weight*factor/total
  for group_index in [group.group for group in vertex.groups]:ob.vertex_groups[group_index].remove([vertex.index])
  chosen=sorted(values.items(),key=lambda item:-item[1])[:4];total=sum(value for name,value in chosen)
  for name,value in chosen:
   group=ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name);group.add([vertex.index],value/total,'REPLACE')

def material_factor(path,factor):
 """Retain a constant PBR tint through Blender's textured material export."""
 raw=path.read_bytes();size,tag=struct.unpack_from('<II',raw,12);assert tag==0x4e4f534a
 data=json.loads(raw[20:20+size])
 for mat in data['materials']:
  if mat['name'].startswith('Civilian_Wool'):mat.setdefault('pbrMetallicRoughness',{})['baseColorFactor']=factor
 chunk=json.dumps(data,separators=(',',':')).encode();chunk+=b' '*((-len(chunk))%4)
 tail=raw[20+size:];path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(chunk)+len(tail))+struct.pack('<II',len(chunk),tag)+chunk+tail)

def surface(leather):
 mat=bpy.data.materials.new('Civilian_Leather' if leather else 'Civilian_Wool');mat.use_nodes=True
 nodes=mat.node_tree.nodes;links=mat.node_tree.links;shader=nodes.get('Principled BSDF')
 shader.inputs['Roughness'].default_value=.72 if leather else .9
 shader.inputs['Specular IOR Level'].default_value=.28
 folder=ROOT/'work/human-wardrobe-2/materials' if leather else ROOT/'Viewer/Art/MedievalKit/textures'
 colour='Leather001_1K-JPG_Color.jpg' if leather else 'Linen_Color.jpg'
 normal='Leather001_1K-JPG_NormalGL.jpg' if leather else 'Fabric045_2K-JPG_NormalGL.jpg'
 tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(folder/colour),check_existing=True);links.new(tex.outputs['Color'],shader.inputs['Base Color'])
 if not leather:
  tint=nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1.;tint.inputs[2].default_value=(.16,.22,.12,1.)
  links.new(tex.outputs['Color'],tint.inputs[1]);links.new(tint.outputs[0],shader.inputs['Base Color'])
 image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(str(folder/normal),check_existing=True);image.image.colorspace_settings.name='Non-Color'
 bump=nodes.new('ShaderNodeNormalMap');bump.inputs['Strength'].default_value=.3
 links.new(image.outputs['Color'],bump.inputs['Color']);links.new(bump.outputs['Normal'],shader.inputs['Normal'])
 return mat

def finish(ob,rig,name,mat):
 ob.name='Extra_'+name;ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
 for modifier in ob.modifiers:
  if modifier.type=='ARMATURE':modifier.object=rig
 if not any(m.type=='ARMATURE' for m in ob.modifiers):ob.modifiers.new('Shared human rig','ARMATURE').object=rig
 ob.data.materials.clear();ob.data.materials.append(mat)
 for face in ob.data.polygons:face.material_index=0;face.use_smooth=True

def doublet(rig,body,art):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(art/'runtime/part-tunic.glb'));imported=set(bpy.data.objects)-before
 ob=next(o for o in imported if o.type=='MESH' and o.name.startswith('Free_tunic'))
 transform=rig.matrix_world.inverted()@ob.matrix_world
 for vertex in ob.data.vertices:vertex.co=transform@vertex.co
 neck=rig.data.bones['neck_01'].head_local.z;waist=rig.data.bones['pelvis'].head_local.z
 arm={g.index for g in ob.vertex_groups if g.name.startswith(('upperarm','lowerarm','hand'))}
 arm_weight={v.index:sum(g.weight for g in v.groups if g.group in arm) for v in ob.data.vertices}
 remove=[]
 for face in ob.data.polygons:
  centre=sum((ob.data.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
  if centre.z<waist+.005 or sum(arm_weight[i] for i in face.vertices)/len(face.vertices)>.20 or (centre.y<-.02 and centre.z>neck-.21 and abs(centre.x)<(centre.z-neck+.21)*.42):remove.append(face.index)
 bm=bmesh.new();bm.from_mesh(ob.data);bm.faces.ensure_lookup_table();bmesh.ops.delete(bm,geom=[bm.faces[i] for i in remove],context='FACES')
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 for iteration in range(8):
  updates={v:sum((e.other_vert(v).co for e in v.link_edges if e.is_boundary),Vector())/sum(e.is_boundary for e in v.link_edges) for v in bm.verts if v.is_boundary and any(e.is_boundary for e in v.link_edges)}
  for vertex,point in updates.items():vertex.co=vertex.co.lerp(point,.55)
 bm.to_mesh(ob.data);bm.free()
 # Allow a shirt underneath; preserve the neck opening and source UVs.
 for vertex in ob.data.vertices:
  radial=Vector((vertex.co.x,vertex.co.y+.01,0.))
  if radial.length>1e-7:vertex.co+=radial.normalized()*.021
 tree,coords,faces=body_surface(rig,body);bind_surface(ob,body,tree,coords,faces,.030)
 for datum in ob.data.uv_layers.active.data:datum.uv*=3.
 finish(ob,rig,'doublet',surface(True))
 for other in imported:
  if other!=ob and other.name in bpy.data.objects:bpy.data.objects.remove(other,do_unlink=True)
 return ob

def cloak(rig,body):
 neck=rig.data.bones['neck_01'].head_local.z;scale=neck/1.4825
 rows=36;columns=80;coords=[];weights=[];uvs=[];faces=[]
 levels=(.88,.65,.40,.18)
 for row in range(rows+1):
  t=row/rows;z=(neck-.035*scale)*(1-t)+.24*scale*t
  shoulder=min(1.,t/.13);shoulder=shoulder*shoulder*(3-2*shoulder)
  span=2.05-.75*shoulder;rx=(.105+.23*shoulder+.04*t)*scale
  lower=max(0.,min(1.,(.99-z)/.20));lower=lower*lower*(3-2*lower);rx*=1.-.25*lower
  ry=(.145-.015*shoulder)*scale;middle=(-.05+.18*shoulder)*scale
  for column in range(columns+1):
   u=column/columns;angle=(u*2-1)*span
   fold=.012*scale*math.sin(angle*9)*t
   co=Vector((rx*math.sin(angle),middle+ry*math.cos(angle)+fold,z+.07*scale*t**5*math.sin(angle)**2))
   if z>=.95:
    amount=max(0.,min(1.,(z-.95)/.35));w={'pelvis':1-amount,'spine_03':amount}
   elif z>=levels[0]:
    k=(.95-z)/(.95-levels[0]);w={'pelvis':1-k,'robe_back_0':k}
   elif z<=levels[-1]:w={'robe_back_3':1.}
   else:
    i=next(i for i in range(3) if levels[i]>=z>=levels[i+1]);k=(levels[i]-z)/(levels[i]-levels[i+1]);w={'robe_back_'+str(i):1-k,'robe_back_'+str(i+1):k}
   coords.append(co);weights.append(w);uvs.append((u*3,t*4))
 for row in range(rows):
  for column in range(columns):
   a=row*(columns+1)+column;b=a+columns+1;faces.append((a,a+1,b+1,b))
 mesh=bpy.data.meshes.new('Civilian_cloak');mesh.from_pydata(coords,[],faces);mesh.update();ob=bpy.data.objects.new('Extra_cloak',mesh);bpy.context.collection.objects.link(ob)
 uv=mesh.uv_layers.new(name='UVMap')
 for face in mesh.polygons:
  for loop in face.loop_indices:uv.data[loop].uv=uvs[mesh.loops[loop].vertex_index]
 for name in sorted({name for w in weights for name in w}):ob.vertex_groups.new(name=name)
 for i,w in enumerate(weights):
  for name,value in w.items():
   if value>1e-7:ob.vertex_groups[name].add([i],value,'REPLACE')
 # Follow shoulders only near the collar, with a continuous weight field.
 # Unsmoothed nearest-triangle weights create spikes at the moving armhole.
 tree,points,triangles=body_surface(rig,body);bind_surface(ob,body,tree,points,triangles,.035,True)
 adjacent={v.index:set() for v in ob.data.vertices}
 for edge in ob.data.edges:
  a,b=edge.vertices;adjacent[a].add(b);adjacent[b].add(a)
 for iteration in range(6):
  positions={};skin={}
  for vertex in ob.data.vertices:
   if vertex.co.z<1.18:continue
   ids=[vertex.index]+list(adjacent[vertex.index]);values={}
   positions[vertex.index]=vertex.co.lerp(sum((ob.data.vertices[i].co for i in ids),Vector())/len(ids),.3)
   for i in ids:
    for group in ob.data.vertices[i].groups:values[group.group]=values.get(group.group,0.)+group.weight/len(ids)
   chosen=sorted(values.items(),key=lambda x:-x[1])[:4];total=sum(value for index,value in chosen);skin[vertex.index]=[(index,value/total) for index,value in chosen]
  for index,point in positions.items():
   vertex=ob.data.vertices[index];vertex.co=point
   for group in [g.group for g in vertex.groups]:ob.vertex_groups[group].remove([index])
   for group,value in skin[index]:ob.vertex_groups[group].add([index],value,'REPLACE')
 finish(ob,rig,'cloak',surface(False));return ob

def shoes(rig,body,art):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(art/'runtime/part-boots.glb'));imported=set(bpy.data.objects)-before
 ob=next(o for o in imported if o.type=='MESH' and o.name.startswith('Free_boots'))
 transform=rig.matrix_world.inverted()@ob.matrix_world
 for vertex in ob.data.vertices:vertex.co=transform@vertex.co
 cutoff=rig.data.bones['foot_l'].head_local.z+.065
 bm=bmesh.new();bm.from_mesh(ob.data)
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=(0,0,cutoff),plane_no=(0,0,1),clear_outer=True)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 bm.to_mesh(ob.data);bm.free()
 tree,coords,faces=body_surface(rig,body);bind_surface(ob,body,tree,coords,faces,.006)
 finish(ob,rig,'shoes',surface(True))
 for other in imported:
  if other!=ob and other.name in bpy.data.objects:bpy.data.objects.remove(other,do_unlink=True)
 return ob

def build(rig,body,art,out,export):
 evidence={}
 for name,ob in [('doublet',doublet(rig,body,art)),('cloak',cloak(rig,body)),('shoes',shoes(rig,body,art))]:
  path=out/(name+'.glb');export(path,ob)
  if name=='cloak':material_factor(path,[.16,.22,.12,1.])
  evidence[name]={'asset':{'doublet':'rehmanpolanski_viking_tunic','shoes':'rehmanpolanski_viking_boots','cloak':'project-authored cloak topology'}[name],'kind':{'doublet':'torso','shoes':'footwear','cloak':'cloak'}[name],'vertices':len(ob.data.vertices),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'licence':'CC0 source mesh/material; project derivative' if name!='cloak' else 'project-authored geometry; CC0 linen/fabric','author':'RehmanPolanski / Britannia Reborn' if name!='cloak' else 'Britannia Reborn','recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
  bpy.data.objects.remove(ob,do_unlink=True)
 return evidence
