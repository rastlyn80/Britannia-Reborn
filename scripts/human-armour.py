"""Tailored armour: continuous clothing beneath separate manufactured plates.

Never copies the body's triangles into an armour surface. Soft layers come from
the traced CC0 fitted wardrobe; rigid plates are constructed around rig/body
measurements, with thickness, rolled edges, joint overlaps and fastenings.
"""
import bpy,math,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
CACHE={}
def texture(name,pixels):
 out=ROOT/'work/human-coverage-session/armour-materials';out.mkdir(exist_ok=True)
 height,width=pixels.shape[:2];image=bpy.data.images.new(name,width,height)
 if 'normal' in name:image.colorspace_settings.name='Non-Color'
 image.pixels.foreach_set(pixels.astype(np.float32).ravel());image.filepath_raw=str(out/(name+'.png'));image.file_format='PNG';image.save()
 return image
def coloured(path,name,factor):
 image=bpy.data.images.load(str(path),check_existing=True);data=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(data);data=data.reshape(image.size[1],image.size[0],4);data[:,:,:3]*=factor
 return texture(name,data)
def material(kind):
 if kind in CACHE:return CACHE[kind]
 lining=kind=='lining';name='Armour_Lining_Charcoal' if lining else 'Armour_'+kind
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;s=n.get('Principled BSDF')
 s.inputs['Base Color'].default_value=(.40,.44,.48,1);s.inputs['Roughness'].default_value=.50;s.inputs['Metallic'].default_value=.92
 if kind in ['lining','leather']:
  path=ROOT/('Viewer/Art/MedievalKit/textures/Linen_Color.jpg' if lining else 'work/human-wardrobe-2/materials/Leather001_1K-JPG_Color.jpg')
  img=coloured(path,'armour_'+kind,(.16,.18,.20) if lining else (.52,.40,.29))
  t=n.new('ShaderNodeTexImage');t.image=img;l.new(t.outputs['Color'],s.inputs['Base Color'])
  s.inputs['Roughness'].default_value=.92 if lining else .83;s.inputs['Metallic'].default_value=0.;s.inputs['Specular IOR Level'].default_value=.22
  path=ROOT/('Viewer/Art/MedievalKit/textures/Fabric045_2K-JPG_NormalGL.jpg' if lining else 'work/human-wardrobe-2/materials/Leather001_1K-JPG_NormalGL.jpg')
  img=bpy.data.images.load(str(path),check_existing=True);img.colorspace_settings.name='Non-Color'
  t=n.new('ShaderNodeTexImage');t.image=img;normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.18;l.new(t.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs['Normal'],s.inputs['Normal'])
 elif kind=='mail':
  size=512;y,x=np.mgrid[0:size,0:size];u=x/size*8;v=y/size*8
  dx=((u+(np.floor(v)%2)*.5+.5)%1)-.5;dy=((v+.5)%1)-.5
  distance=np.abs(np.sqrt((dx/.45)**2+(dy/.34)**2)-1.)
  height=np.sqrt(np.maximum(0.,1-(distance/.19)**2))
  rgba=np.ones((size,size,4),np.float32);rgba[:,:,:3]=(.085+height*.30)[:,:,None]*np.array([.92,.97,1.])
  t=n.new('ShaderNodeTexImage');t.image=texture('armour_chain_steel',rgba);l.new(t.outputs['Color'],s.inputs['Base Color'])
  gx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*2.8;gy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*2.8
  normal=np.stack((-gx,-gy,np.ones_like(gx)),axis=2);normal/=np.linalg.norm(normal,axis=2)[:,:,None];rgba[:,:,:3]=normal*.5+.5
  t=n.new('ShaderNodeTexImage');t.image=texture('armour_chain_normal',rgba);t.image.colorspace_settings.name='Non-Color';nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.75;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],s.inputs['Normal']);s.inputs['Roughness'].default_value=.53
 else:
  # Subtle directional machining, rather than the broad shiny skin highlights
  # of the rejected body-derived shells.
  size=256;y,x=np.mgrid[0:size,0:size];rng=np.random.default_rng(7341);noise=rng.normal(0,.012,(size,size));streak=.012*np.sin(x*.43)+noise
  rgba=np.ones((size,size,4),np.float32);rgba[:,:,:3]=np.clip(np.array([.40,.44,.48])+streak[:,:,None],0,1)
  t=n.new('ShaderNodeTexImage');t.image=texture('armour_satin_steel',rgba);l.new(t.outputs['Color'],s.inputs['Base Color'])
 CACHE[kind]=m;return m
def mesh(name,coords,faces,weights,mat):
 data=bpy.data.meshes.new(name);data.from_pydata(coords,[],faces);data.update();ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob)
 for bone in sorted({n for w in weights for n in w}):ob.vertex_groups.new(name=bone)
 for i,w in enumerate(weights):
  total=sum(w.values())
  for bone,value in w.items():ob.vertex_groups[bone].add([i],value/total,'REPLACE')
 data.materials.append(mat);uv=data.uv_layers.new(name='UVMap')
 for p in data.polygons:
  p.use_smooth=True;normal=p.normal;axis=max(range(3),key=lambda i:abs(normal[i]));axes=[i for i in range(3) if i!=axis]
  for li in p.loop_indices:
   co=data.vertices[data.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]/.08,co[axes[1]]/.08)
 return ob
def finish_plate(ob,thickness=.004):
 bpy.context.view_layer.objects.active=ob
 solid=ob.modifiers.new('Metal plate thickness','SOLIDIFY');solid.thickness=thickness;solid.offset=0;solid.use_even_offset=True;bpy.ops.object.modifier_apply(modifier=solid.name)
 bevel=ob.modifiers.new('Rolled manufactured edges','BEVEL');bevel.width=.0025;bevel.segments=2;bevel.limit_method='ANGLE';bevel.angle_limit=.35;bpy.ops.object.modifier_apply(modifier=bevel.name)
 return ob
def join(obs):
 bpy.ops.object.select_all(action='DESELECT')
 for ob in obs:ob.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();return obs[0]
def cloth(rig,art,name,mat,lining=False,body=None):
 path=art/('runtime/part-'+name+'.glb' if name in ['pants','tunic','boots'] else 'expansion/'+name+'.glb')
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));added=set(bpy.data.objects)-before
 ob=next(o for o in added if o.type=='MESH' and o.name.startswith(('Free_','Extra_')))
 transform=rig.matrix_world.inverted()@ob.matrix_world;coords=[transform@v.co for v in ob.data.vertices]
 ob.parent=None;ob.matrix_world=Matrix.Identity(4)
 for v,co in zip(ob.data.vertices,coords):v.co=co
 for mod in list(ob.modifiers):ob.modifiers.remove(mod)
 ob.data.materials.clear();ob.data.materials.append(mat)
 for p in ob.data.polygons:p.material_index=0;p.use_smooth=True
 for extra in added & set(bpy.data.objects):
  if extra!=ob:bpy.data.objects.remove(extra,do_unlink=True)
 if lining and body is not None:
  body.data.calc_loop_triangles();T=rig.matrix_world.inverted()@body.matrix_world
  points=[T@v.co for v in body.data.vertices];tree=BVHTree.FromPolygons(points,[tuple(t.vertices) for t in body.data.loop_triangles],all_triangles=True)
  for vertex in ob.data.vertices:
   p,normal,face,distance=tree.find_nearest(vertex.co)
   if p is None or distance>.13:continue
   vertex.co=p+normal*(.016 if name=='pants' else .012)
   # The lining remains tailored clothing topology with a complete seat.
   # Rebind moved vertices to the corresponding body surface, not old baggy folds.
   tri=body.data.loop_triangles[face];factors=[1/max((points[i]-p).length,.0001)**2 for i in tri.vertices];total=sum(factors);weights={}
   for i,factor in zip(tri.vertices,factors):
    for group in body.data.vertices[i].groups:
     bone=body.vertex_groups[group.group].name;weights[bone]=weights.get(bone,0.)+factor/total*group.weight
   for index in [g.group for g in vertex.groups]:ob.vertex_groups[index].remove([vertex.index])
   chosen=sorted(weights.items(),key=lambda pair:-pair[1])[:4];total=sum(value for _,value in chosen)
   for bone,value in chosen:
    group=ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone);group.add([vertex.index],value/total,'REPLACE')
 if mat.name=='Armour_mail':
  uv=ob.data.uv_layers.active
  for p in ob.data.polygons:
   axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=axis]
   for li in p.loop_indices:
    co=ob.data.vertices[ob.data.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]/.08,co[axes[1]]/.08)
 return ob
def ring_piece(name,rings,bone,mat,steps=32):
 coords=[];faces=[]
 # centre, radial X, radial Y; arbitrary orientation supports limb segments.
 for centre,u,v in rings:
  for i in range(steps):coords.append(centre+u*math.cos(i*math.tau/steps)+v*math.sin(i*math.tau/steps))
 for j in range(len(rings)-1):
  for i in range(steps):a=j*steps+i;b=j*steps+(i+1)%steps;faces.append((a,b,b+steps,a+steps))
 return mesh(name,coords,faces,[{bone:1.} for _ in coords],mat)
def rivet(point,bone,radius=.0035):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=radius,location=point);ob=bpy.context.object
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);ob.vertex_groups.new(name=bone).add(list(range(len(ob.data.vertices))),1.,'REPLACE');ob.data.materials.append(material('steel'));return ob
def studded(ob):
 # Sparse real rivets on cloth, inheriting each supporting vertex's skinning.
 pieces=[ob]
 for v in list(ob.data.vertices)[::83]:
  if v.normal.y>-.35:continue
  p=rivet(v.co+v.normal*.004,'pelvis');p.vertex_groups.clear()
  for group in v.groups:p.vertex_groups.new(name=ob.vertex_groups[group.group].name).add(list(range(len(p.data.vertices))),group.weight,'REPLACE')
  pieces.append(p)
 return join(pieces)
def limb(rig,body,slot,kind):
 pieces=[];world=rig.matrix_world.inverted()@body.matrix_world;body_points=[world@v.co for v in body.data.vertices]
 for side in ['l','r']:
  names=['upperarm_'+side,'lowerarm_'+side] if slot=='arms' else ['thigh_'+side,'calf_'+side]
  for name in names:
   bone=rig.data.bones[name];next_name=('lowerarm_'+side if name.startswith('upperarm') else 'hand_'+side) if slot=='arms' else ('calf_'+side if name.startswith('thigh') else 'foot_'+side)
   a=bone.head_local;b=rig.data.bones[next_name].head_local;axis=b-a;length=axis.length;axis.normalize();u=axis.cross(Vector((0,1,0)))
   if u.length<.01:u=axis.cross(Vector((1,0,0)))
   u.normalize();v=axis.cross(u).normalized();rings=[]
   for t in [.10,.18,.42,.68,.87,.94]:
    centre=a+(b-a)*t;samples=[p for vertex,p in zip(body.data.vertices,body_points) if any(body.vertex_groups[g.group].name==name and g.weight>.2 for g in vertex.groups) and abs((p-a).dot(axis)/length-t)<.10 and (p-centre).length<.18]
    rx=max([abs((p-centre).dot(u)) for p in samples]+[.035]);ry=max([abs((p-centre).dot(v)) for p in samples]+[.035])
    ease=.024 if kind=='plate' else .014
    rings.append((centre,u*(rx+ease),v*(ry+ease)))
   mat=material('steel' if kind=='plate' else 'mail' if kind=='mail' else 'leather')
   ob=finish_plate(ring_piece(name,rings,name,mat),.004 if kind=='plate' else .003)
   pieces.append(ob)
   if kind in ['plate','studded']:
    for t in [.18,.87]:pieces.append(rivet(a+(b-a)*t+v*(rings[2][2].length+.004),name))
  if kind=='plate':
   # The elbow/knee gets an independent curved guard; it does not stretch
   # like skin when the upper and lower limb rotate apart.
   name=names[1];b=rig.data.bones[name];centre=b.head_local;axis=(b.tail_local-centre).normalized();u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized();radius=(.075 if slot=='arms' else .09)*(rig.data.bones['head'].head_local.z/1.5793484)
   # A convex front cup, rather than an open tube aimed at the viewer.
   coords=[];faces=[];front=Vector((0,-1,0));across=axis.cross(front).normalized()
   for phi in [.015,.35,.70,1.05,1.48]:
    for i in range(32):
     angle=i*math.tau/32
     coords.append(centre+front*(radius*(.55+.45*math.cos(phi)))+across*(radius*math.sin(phi)*math.cos(angle))+axis*(radius*1.12*math.sin(phi)*math.sin(angle)))
   for j in range(4):
    for i in range(32):a=j*32+i;b=j*32+(i+1)%32;faces.append((a,b,b+32,a+32))
   pieces.append(finish_plate(mesh('Convex_joint_cup',coords,faces,[{name:1.} for _ in coords],material('steel'))))
  if kind=='plate' and slot=='arms':
   # A closed shoulder dome covers the rerebrace opening.
   name=names[0];bone=rig.data.bones[name];centre=bone.head_local;axis=(bone.tail_local-centre).normalized();u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized();scale=rig.data.bones['head'].head_local.z/1.5793484;rings=[]
   for phi in [.02,.35,.70,1.05,1.45,1.85]:
    rings.append((centre-axis*(.09*scale*math.cos(phi)),u*(.10*scale*math.sin(phi)),v*(.09*scale*math.sin(phi))))
   pieces.append(finish_plate(ring_piece('Closed_pauldron',rings,name,material('steel'))))
 if slot=='arms':
  # Continuous textile cuffs bridge the wrist/gauntlet join in bent poses.
  for side in ['l','r']:
   name='lowerarm_'+side;a=rig.data.bones[name].head_local;b=rig.data.bones['hand_'+side].head_local;axis=(b-a).normalized();u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized()
   pieces.append(ring_piece('Wrist_lining',[(b-axis*.080,u*.049,v*.045),(b+axis*.045,u*.049,v*.045)],name,material('lining')))
   pieces.append(ring_piece('Gauntlet_overlap',[(b-axis*.035,u*.050,v*.046),(b+axis*.065,u*.047,v*.043)],'hand_'+side,material('lining')))
 return join(pieces)
def cuirass(rig,body,art,kind='plate'):
 T=rig.matrix_world.inverted()@body.matrix_world
 points=[T@vertex.co for vertex in body.data.vertices if sum(g.weight for g in vertex.groups if body.vertex_groups[g.group].name.startswith(('spine','pelvis')))>.5]
 pelvis=rig.data.bones['pelvis'].head_local.z;neck=rig.data.bones['neck_01'].head_local.z;scale=rig.data.bones['head'].head_local.z/1.5793484
 levels=[pelvis-.025*scale,pelvis+.13*scale,pelvis+.25*scale,neck-.16*scale,neck-.065*scale]
 rings=[]
 for j,z in enumerate(levels):
  near=[p for p in points if abs(p.z-z)<.055*scale and abs(p.x)<.27*scale]
  rx=min(.215*scale,max([abs(p.x) for p in near]+[.12*scale])+.021*scale)
  front=min([p.y for p in near]+[-.12*scale])-.050*scale;back=max([p.y for p in near]+[.09*scale])+.040*scale
  if j==len(levels)-1:rx=min(rx,.175*scale)
  rings.append((z,rx,front,back))
 coords=[];faces=[];steps=48
 for j,(z,rx,front,back) in enumerate(rings):
  for i in range(steps):
   angle=i*math.tau/steps;c=math.cos(angle);s=math.sin(angle);profile=math.copysign(abs(s)**.35,s);y=back*profile if s>=0 else -front*profile
   height=z+(.055*scale*abs(c) if j==len(rings)-1 else 0.)
   # A central keel is manufactured geometry; no breast/nipple imprint.
   if s<0:y-=.009*scale*max(0.,1-abs(c)*5)
   coords.append(Vector((rx*c,y,height)))
 for j in range(len(rings)-1):
  for i in range(steps):a=j*steps+i;b=j*steps+(i+1)%steps;faces.append((a,b,b+steps,a+steps))
 pieces=[finish_plate(mesh('Independent_cuirass',coords,faces,[{'spine_03':1.} for _ in coords],material('steel' if kind=='plate' else 'leather')))]
 if kind!='plate':
  return studded(pieces[0]) if kind=='studded' else pieces[0]
 # Overlapping fauld lames protect the waist while following the pelvis.
 for j in range(3):
  z=pelvis+.06*scale-j*.052*scale;rx=(.19+j*.018)*scale;ry=(.155+j*.008)*scale
  rings=[(Vector((0,0,z)),Vector((rx,0,0)),Vector((0,ry,0))),(Vector((0,0,z-.065*scale)),Vector((rx+.012*scale,0,0)),Vector((0,ry+.008*scale,0)))]
  pieces.append(finish_plate(ring_piece('Overlapping_fauld',rings,'pelvis',material('steel'))))
  for sign in [-1,1]:pieces.append(rivet(Vector((sign*rx*.7,-ry*.72,z-.012*scale)),'pelvis'))
 return join(pieces)
def build(rig,body,art,row):
 kind=row['material'];slot=row['slot']
 if slot=='torso':
  if kind in ['plate','leather','studded']:return cuirass(rig,body,art,kind)
  ob=cloth(rig,art,'tunic',material('mail'))
  for vertex in ob.data.vertices:vertex.co+=vertex.normal*.014
  return studded(ob) if kind=='studded' else ob
 if slot=='legs':
  # Every leg item has a complete tailored seat, crotch and inner-leg layer.
  # Plate gaps reveal cloth instead of bare skin or invisible body triangles.
  pants=cloth(rig,art,'pants',material('lining' if kind=='plate' else 'mail' if kind=='mail' else 'leather'),lining=True,body=body)
  if kind=='plate':return join([pants,limb(rig,body,'legs','plate')])
  return studded(pants) if kind=='studded' else pants
 if slot=='arms':return limb(rig,body,'arms',kind)
 neck=rig.data.bones['neck_01'].head_local;scale=rig.data.bones['head'].head_local.z/1.5793484
 rings=[(neck+Vector((0,0,-.045*scale)),Vector((.105*scale,0,0)),Vector((0,.10*scale,0))),(neck+Vector((0,0,.008*scale)),Vector((.080*scale,0,0)),Vector((0,.075*scale,0)))]
 return finish_plate(ring_piece('Closed_gorget',rings,'neck_01',material('steel' if kind=='plate' else 'leather')))
def undercoat(rig,art,body):return cloth(rig,art,'shirt',material('lining'),lining=True,body=body)

def boots(rig,art):
 import bmesh
 ob=cloth(rig,art,'boots',material('leather'))
 z=rig.data.bones['foot_l'].head_local.z+.035
 bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=(0,0,z),plane_no=(0,0,1),clear_outer=True);bm.to_mesh(ob.data);bm.free()
 return ob
