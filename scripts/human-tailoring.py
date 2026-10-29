"""Original headwear and held accessories on the pinned CC0 human rig."""
import bpy,bmesh,math
from mathutils import Vector,Matrix

class Tailor:
 def __init__(self,rig,body,art,materials,held_pose):
  self.rig=rig;self.art=art;self.materials=materials;self.held_pose=held_pose
  self.ratio=rig.data.bones['head'].head_local.z/1.5793484;self.head=rig.data.bones['head'].head_local.copy()
 def reset(self):self.vertices=[];self.faces=[];self.weights=[];self.uvs=[];self.face_material=[]
 def material(self,name,colour,metal=0.,rough=.86):
  if name in self.materials:return self.materials[name]
  mat=bpy.data.materials.new('Tailoring_'+name);mat.use_nodes=True;s=mat.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*colour,1);s.inputs['Roughness'].default_value=rough;s.inputs['Metallic'].default_value=metal;s.inputs['Specular IOR Level'].default_value=.28
  if not metal:
   nodes=mat.node_tree.nodes;links=mat.node_tree.links;image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(str(self.art.parents[1]/'Art/MedievalKit/textures/Fabric045_2K-JPG_NormalGL.jpg'),check_existing=True);image.image.colorspace_settings.name='Non-Color';normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.22;links.new(image.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],s.inputs['Normal'])
  self.materials[name]=mat;return mat
 def vertex(self,p,w,uv):self.vertices.append(p);self.weights.append(w);self.uvs.append(uv);return len(self.vertices)-1
 def face(self,indices,material):self.faces.append(tuple(indices));self.face_material.append(material)
 def grid(self,rows,cols,point,weight,material,reverse=False):
  start=len(self.vertices)
  for j in range(rows+1):
   for i in range(cols+1):
    u=i/cols;v=j/rows;p=point(u,v);self.vertex(p,weight(p,u,v),(u*2,v*3))
  for j in range(rows):
   for i in range(cols):
    a=start+j*(cols+1)+i;ids=(a,a+1,a+cols+2,a+cols+1);self.face(reversed(ids) if reverse else ids,material)
 def tube(self,points,radii,weight,material,sides=10):
  start=len(self.vertices)
  for j,p in enumerate(points):
   d=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized();u=d.cross(Vector((0,1,0)))
   if u.length<.01:u=d.cross(Vector((1,0,0)))
   u.normalize();v=d.cross(u).normalized()
   for i in range(sides):
    a=math.tau*i/sides;co=p+radii[j]*(u*math.cos(a)+v*math.sin(a));self.vertex(co,weight(co),(i/sides,j/len(points)))
  for j in range(len(points)-1):
   for i in range(sides):a=start+j*sides+i;b=start+j*sides+(i+1)%sides;self.face((a,b,b+sides,a+sides),material)
  self.face([start+i for i in reversed(range(sides))],material);self.face([start+(len(points)-1)*sides+i for i in range(sides)],material)
 def weight(self,p):
  neck=self.rig.data.bones['neck_01'].head_local.z;k=max(0.,min(1.,(p.z-neck)/.12))
  return {'neck_01':1-k,'head':k}
 def headwear(self,key):
  r=self.ratio;h=self.head;head=lambda p:{'head':1.}
  felt=self.material('felt',(.11,.135,.16),rough=.93);tape=self.material('hat_band',(.22,.13,.06));gold=self.material('brass',(.52,.35,.12),.82,.46)
  cream=self.material('bonnet',(.57,.49,.37));red=self.material('jester_wine',(.32,.075,.065));blue=self.material('jester_blue',(.075,.17,.25))
  def crown(u,v):
   a=u*math.tau;theta=v*math.pi/2;return h+Vector((.102*r*math.cos(theta)*math.sin(a),.122*r*math.cos(theta)*math.cos(a),(.045+.135*math.sin(theta))*r))
  self.grid(20,64,crown,lambda p,u,v:head(p),cream if key=='bonnet' else (red if key=='jester_hat' else felt),True)
  if key in ['tricorne_hat','feathered_hat']:
   def brim(u,v):
    a=u*math.tau;rx=(.100+.120*v)*r;ry=(.120+.095*v)*r
    fold=(.015+.09*(.5+.5*math.cos(3*a))**3)*v**2 if key=='tricorne_hat' else .018*v+.09*v*v*max(0.,math.sin(a))**4
    return h+Vector((rx*math.sin(a),ry*math.cos(a),(.052+fold)*r))
   self.grid(14,96,brim,lambda p,u,v:head(p),felt,True)
   edge=[brim(i/96,1) for i in range(97)];self.tube(edge,[.003*r]*len(edge),head,tape,8)
   band=[h+Vector((.102*r*math.sin(i*math.tau/64),.122*r*math.cos(i*math.tau/64),.064*r)) for i in range(65)];self.tube(band,[.008*r]*len(band),head,tape,8)
   if key=='feathered_hat':
    # Solid two-sided feather vanes with fine ribs; no alpha texture input.
    feather=self.material('feather',(.59,.48,.30));shaft=self.material('quill',(.28,.22,.12))
    for offset in [0.,.04]:
     def p(u,v):
      centre=h+Vector(((.09+.16*v)*r,(.015+offset+.075*v*v)*r,(.08+.30*v-.06*v*v)*r));width=math.sin(math.pi*v)**.7*.032*r
      return centre+Vector(((u*2-1)*width,0,-(u*2-1)*width*.5))
     self.grid(32,2,p,lambda co,u,v:head(co),feather)
     line=[p(.5,i/32) for i in range(33)];self.tube(line,[.0015*r]*len(line),head,shaft,6)
  elif key=='bonnet':
   # Gathered rim around the scalp; the face remains open below the brow.
   rim=[h+Vector((.104*r*math.sin(a),.124*r*math.cos(a),(.045+.002*math.sin(a*24))*r)) for a in [i*math.tau/96 for i in range(97)]]
   self.tube(rim,[.005*r]*len(rim),head,cream,8)
   for side in [-1,1]:
    path=[h+Vector((side*.092*r,0,.055*r)),h+Vector((side*.075*r,-.055*r,-.065*r)),h+Vector((side*.014*r,-.088*r,-.095*r))]
    points=[path[i].lerp(path[i+1],j/10) for i in range(2) for j in range(10)]+[path[-1]]
    self.tube(points,[.004*r]*len(points),head,cream,6)
  elif key=='jester_hat':
   for i,a in enumerate([0.,math.tau/3,math.tau*2/3]):
    points=[h+Vector((math.sin(a)*(.065+.16*t)*r,math.cos(a)*(.06+.12*t)*r,(.13+.19*math.sin(t*math.pi*.9)-.02*t)*r)) for t in [j/24 for j in range(25)]]
    self.tube(points,[(.051*(1-j/24)**.8+.003)*r for j in range(25)],head,blue if i%2==0 else red,16)
    self.tube([points[-1]-Vector((0,0,.003*r)),points[-1]+Vector((0,0,.012*r))],[.011*r,.011*r],head,gold,12)
  elif key=='chain_coif':
   # Mail hood: the jaw/front remains open, and the cowl follows the neck.
   mail=self.materials['mail'];self.face_material=[mail]*len(self.faces)
   neck=self.rig.data.bones['neck_01'].head_local.z
   def cowl(u,v):
    a=(-1.95+u*3.9);z=h.z+.055*r+(neck-h.z-.035*r)*v
    return Vector((math.sin(a)*(.100+.020*v)*r,h.y+math.cos(a)*(.092+.035*v)*r,z))
   self.grid(18,64,cowl,lambda p,u,v:self.weight(p),mail,True)

 def box(self,centre,size,bone,material):
  start=len(self.vertices)
  for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:self.vertex(centre+Vector((x*size.x/2,y*size.y/2,z*size.z/2)),{bone:1.},((x+1)/2,(z+1)/2))
  for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:self.face([start+i for i in face],material)
 def prop(self,key,lit):
  bone='hand_l' if key=='lantern' else 'hand_r';weight=lambda p:{bone:1.}
  brass=self.material('brass',(.52,.35,.12),.82,.46);iron=self.material('lantern_iron',(.12,.15,.17),.85,.54)
  if key=='spellbook':
   leather=self.material('book_leather',(.075,.14,.10),rough=.8);paper=self.material('parchment',(.58,.49,.32),rough=.96)
   self.box(Vector((-.07,0,.07)),Vector((.145,.034,.22)),bone,paper)
   for side in [-1,1]:
    self.box(Vector((-.07,side*.023,.07)),Vector((.16,.009,.238)),bone,leather)
    for x in [-.139,-.001]:
     for z in [-.033,.173]:self.box(Vector((x,side*.029,z)),Vector((.023,.004,.024)),bone,brass)
   self.box(Vector((-.149,0,.07)),Vector((.012,.052,.24)),bone,leather)
   # Raised front tooling and three spine bands distinguish a bound tome.
   self.box(Vector((-.07,-.030,.07)),Vector((.045,.004,.065)),bone,brass)
   for z in [-.005,.07,.145]:self.box(Vector((-.155,0,z)),Vector((.006,.057,.009)),bone,brass)
  else:
   candle=self.material('wax',(.62,.53,.36),rough=.94)
   for z in [-.33,-.14]:self.box(Vector((0,-.025,z)),Vector((.12,.105,.018)),bone,iron)
   for x in [-.049,.049]:
    for y in [-.064,.014]:self.tube([Vector((x,y,-.325)),Vector((x,y,-.14))],[.0045,.0045],weight,brass,10)
   roof=[Vector((0,-.025,-.105)),Vector((0,-.025,-.14))];self.tube(roof,[.020,.072],weight,iron,4)
   handle=[Vector((.054*math.cos(i*math.pi/24),-.025,-.108+.108*math.sin(i*math.pi/24))) for i in range(25)];self.tube(handle,[.004]*len(handle),weight,brass,10)
   self.tube([Vector((0,-.025,-.32)),Vector((0,-.025,-.25))],[.020,.020],weight,candle,16)
   if lit:
    flame=self.material('lantern_flame',(1.,.35,.065),rough=1.);s=flame.node_tree.nodes.get('Principled BSDF');s.inputs['Emission Color'].default_value=(1.,.24,.025,1);s.inputs['Emission Strength'].default_value=2.
    self.tube([Vector((0,-.025,-.25)),Vector((0,-.025,-.235)),Vector((.004,-.025,-.205))],[.002,.014,.001],weight,flame,16)
  # The local hand Y axis runs from wrist to fingers. Keep all solid object
  # geometry below the cuff and place the handle/spine at the closed palm.
  transform=self.rig.data.bones[bone].matrix_local
  if key=='spellbook':self.vertices=[transform@Vector((p.x+.15,p.z+.115,-p.y+.025)) for p in self.vertices]
  else:self.vertices=[transform@Vector((p.x,.095-p.z,p.y+.025)) for p in self.vertices]

 def build(self,key,lit=False):
  self.reset()
  if key in ['lantern','spellbook']:self.prop(key,lit)
  else:self.headwear(key)
  name=key+('_lit' if lit else '')
  data=bpy.data.meshes.new('Tailored_'+name);data.from_pydata(self.vertices,[],self.faces);data.update();ob=bpy.data.objects.new('Extra_'+name,data);bpy.context.collection.objects.link(ob)
  mats=list(dict.fromkeys(self.face_material))
  for mat in mats:data.materials.append(mat);mat.use_backface_culling=False
  uv=data.uv_layers.new(name='UVMap')
  for polygon,mat in zip(data.polygons,self.face_material):
   polygon.material_index=mats.index(mat);polygon.use_smooth=key not in ['spellbook','lantern']
   for li in polygon.loop_indices:uv.data[li].uv=self.uvs[data.loops[li].vertex_index]
  for bone in sorted({b for w in self.weights for b in w}):ob.vertex_groups.new(name=bone)
  for i,w in enumerate(self.weights):
   for bone,value in w.items():
    if value>1e-7:ob.vertex_groups[bone].add([i],value,'REPLACE')
  bm=bmesh.new();bm.from_mesh(data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
  bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free();data.update()
  # A real hem thickness gives close views a cloth edge without a body shell.
  if key not in ['lantern','spellbook']:
   solid=ob.modifiers.new('Tailored cloth thickness','SOLIDIFY');solid.thickness=.0018*self.ratio;solid.offset=0.
   bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.modifier_apply(modifier=solid.name)
  return name,ob
