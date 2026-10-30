"""Original human equipment batch, on hash-pinned, already fitted CC0 inputs.

Run with the repository Blender; generated art stays under ignored local-art.
Armour variants preserve the continuous backing, topology and skin weights.
Native-ID evidence is in human-frontier-inputs.json, not in exported game art.
"""
import bpy, bmesh, json, hashlib, sys, math, importlib.util
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[1]
FEMALE='--female' in sys.argv
ART=ROOT/('Viewer/local-art/free-equipment-female' if FEMALE else 'Viewer/local-art/free-equipment')
OUT=ART/'coverage';TMP=ROOT/'work/human-frontier';TMP.mkdir(parents=True,exist_ok=True)
PINS=json.loads((ROOT/'scripts/human-frontier-inputs.json').read_text())
ROWS=[r for r in json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets'] if r['kind']=='expansion35']
for name,digest in PINS['files'].items():
 assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def load(path):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));return set(bpy.data.objects)-before
objects=load(ART/'equipment-base.glb');rig=next(o for o in objects if o.type=='ARMATURE');body=next(o for o in objects if o.name=='Body')
for t in rig.animation_data.nla_tracks:t.mute=True
idle=next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name=='Idle')
rig.animation_data.action=idle;rig.animation_data.action_slot=idle.slots[0];bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
held={p.name:p.matrix.copy() for p in rig.pose.bones}
objects=load(ART/'motion/human-motion.glb');mr=next(o for o in objects if o.type=='ARMATURE')
for t in mr.animation_data.nla_tracks:t.mute=True
action=next(t.strips[0].action for t in mr.animation_data.nla_tracks if t.name=='Bow_Idle')
mr.animation_data.action=action;mr.animation_data.action_slot=action.slots[0];bpy.context.scene.frame_set(1);bpy.context.view_layer.update();bow_pose={p.name:p.matrix.copy() for p in mr.pose.bones}
for o in objects:bpy.data.objects.remove(o,do_unlink=True)
rig.animation_data_clear()
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
spec=importlib.util.spec_from_file_location('tailor',ROOT/'scripts/human-tailoring.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
t=module.Tailor(rig,body,ART,{},held)
iron=t.material('frontier_iron',(.24,.27,.30),.92,.52)
gold=t.material('frontier_brass',(.48,.31,.10),.8,.5)
wood=t.material('frontier_wood',(.15,.075,.031),rough=.88)
grip=t.material('frontier_binding',(.075,.058,.04),rough=.94)
cloth=t.material('frontier_indigo',(.065,.095,.14),rough=.95)
straw=t.material('frontier_straw',(.42,.31,.16),rough=.96)

def pattern(style):
 """Authored, neutral dye-friendly scale/lacing/rib tiles; never skin imagery."""
 path=TMP/(style+'.png');n=256
 u,v=np.meshgrid(np.arange(n)/n,np.arange(n)/n)
 if style=='dragon':
  row=np.floor(v*8);x=((u*8+row*.5)%1-.5)*2;y=(v*8)%1
  edge=np.abs(y-(.18+.65*np.sqrt(np.maximum(0,1-x*x))))<.07
  value=.38+.18*(1-y)-edge*.25;rgb=np.stack((value*.75,value*.89,value),-1)
 elif style.startswith('lamellar'):
  x=(u*10)%1;y=(v*9)%1;edge=(x<.07)|(y<.11)
  cord=((abs(x-.22)<.035)|(abs(x-.78)<.035))&(y<.4)
  value=np.where(edge,.13,.38+.10*y);rgb=np.stack((value*.8,value*.9,value),-1);rgb[cord]=(.48,.31,.13)
 elif style=='bone':
  x=(u*12)%1;value=.48+.20*np.sin(x*math.pi)**.6
  rgb=np.stack((value,value*.88,value*.67),-1);rgb[(v*7)%1<.035]=(.18,.16,.12)
 elif style=='mail':
  x=((u*15+np.floor(v*16)*.5)%1-.5)*2;y=((v*16)%1-.5)*2
  radius=(x*x+(y*1.25)**2)**.5;value=np.where((radius>.58)&(radius<.94),.52-.12*y,.10)
  rgb=np.stack((value*.92,value*.97,value),-1)
 else:
  value=.16+.025*np.sin(u*math.tau*94)*np.sin(v*math.tau*94);rgb=np.stack((value*.75,value*.88,value),-1)
 rgba=np.ones((n,n,4),np.float32);rgba[:,:,:3]=rgb
 im=bpy.data.images.new('Original '+style+' tile',n,n);im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(path);im.file_format='PNG';im.save()
 return im

style_materials={}
def styled(style):
 if style in style_materials:return style_materials[style]
 metal=style in ['dragon','mail','lamellar_plate','lamellar_studded']
 m=t.material('frontier_'+style,(.3,.31,.32),.9 if metal else 0.,.56 if metal else .9)
 nodes=m.node_tree.nodes;links=m.node_tree.links;s=nodes.get('Principled BSDF')
 texture=nodes.new('ShaderNodeTexImage');texture.image=pattern(style);links.new(texture.outputs['Color'],s.inputs['Base Color'])
 # Preserve the normal weave for cloth; embossed hard surfaces use their own
 # authored pattern, exported as a tangent-space normal rather than gloss.
 if metal or style=='bone':
  for link in list(s.inputs['Normal'].links):links.remove(link)
  a=np.array(texture.image.pixels[:],np.float32).reshape(256,256,4)[:,:,:3].mean(2)
  dx=(np.roll(a,-1,1)-np.roll(a,1,1))*1.8;dy=(np.roll(a,-1,0)-np.roll(a,1,0))*1.8
  normal=np.stack((-dx,-dy,np.ones_like(a)),2);normal/=np.linalg.norm(normal,axis=2)[:,:,None]
  rgba=np.ones((256,256,4),np.float32);rgba[:,:,:3]=normal*.5+.5
  im=bpy.data.images.new('Original '+style+' normal',256,256);im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(TMP/(style+'-normal.png'));im.file_format='PNG';im.save();im.colorspace_settings.name='Non-Color'
  tex=nodes.new('ShaderNodeTexImage');tex.image=im;nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.45;links.new(tex.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],s.inputs['Normal'])
 style_materials[style]=m;return m

def derivative(row):
 objects=load(ART/(row['base']+'.glb'));ob=next(o for o in objects if o.type=='MESH' and o.name.startswith(('Extra_','Free_')))
 sr=next(o for o in objects if o.type=='ARMATURE')
 assert set(b.name for b in sr.data.bones)==set(b.name for b in rig.data.bones)
 transform=sr.matrix_world.inverted()@ob.matrix_world
 assert all(abs(transform[i][j]-(i==j))<1e-5 for i in range(4) for j in range(4))
 # Retain true textile backing; no armour paint on a naked body shell.
 for i,mat in enumerate(ob.data.materials):
  if mat and mat.name.startswith('Armour_Lining'):continue
  if row['design']=='book':
   if mat and 'book_leather' in mat.name:
    colours={'necromancer_book':(.085,.065,.11),'chivalry_book':(.23,.12,.055),'bushido_book':(.14,.06,.04),'ninjitsu_book':(.045,.065,.095),'spellweaving_book':(.065,.16,.09),'mystic_book':(.075,.11,.24)}
    ob.data.materials[i]=t.material(row['key']+'_cover',colours[row['key']],rough=.87)
  else:ob.data.materials[i]=styled(row['design'])
 for extra in objects:
  if extra!=ob:bpy.data.objects.remove(extra,do_unlink=True)
 return ob

def object_from_tailor(key,smooth=False,thickness=0.):
 data=bpy.data.meshes.new('Frontier_'+key);data.from_pydata(t.vertices,[],t.faces);data.update();ob=bpy.data.objects.new('Extra_'+key,data);bpy.context.collection.objects.link(ob)
 mats=list(dict.fromkeys(t.face_material))
 for m in mats:data.materials.append(m);m.use_backface_culling=False
 uv=data.uv_layers.new(name='UVMap')
 for p,m in zip(data.polygons,t.face_material):
  p.material_index=mats.index(m);p.use_smooth=smooth
  for li in p.loop_indices:uv.data[li].uv=t.uvs[data.loops[li].vertex_index]
 for name in sorted({n for w in t.weights for n in w}):ob.vertex_groups.new(name=name)
 for i,w in enumerate(t.weights):
  for name,weight in w.items():
   if weight>1e-7:ob.vertex_groups[name].add([i],weight,'REPLACE')
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
 if thickness:
  bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
  mod=ob.modifiers.new('Real edge thickness','SOLIDIFY');mod.thickness=thickness;mod.offset=0.;bpy.ops.object.modifier_apply(modifier=mod.name)
 return ob

def hat(row):
 t.reset();d=row['design'];key=row['key'];r=t.ratio;h=t.head;head=lambda p:{'head':1.}
 if d.startswith('coif_'):
  t.materials['mail']=iron if d=='coif_metal' else (cloth if d=='coif_ninja' else styled('mail'))
  t.headwear('chain_coif');return object_from_tailor(key,True,.0018*r)
 if d=='horned':
  # Authored open helmet with curved side horns, fitted to the same cap volume.
  material=iron
 else:material=straw if d=='kasa' else (styled('lamellar_leather') if d.endswith('leather') else iron)
 def crown(u,v):
  a=u*math.tau;theta=v*math.pi/2
  return h+Vector((.107*r*math.cos(theta)*math.sin(a),.127*r*math.cos(theta)*math.cos(a),(.045+.142*math.sin(theta))*r))
 if d!='garland':t.grid(20,64,crown,lambda p,u,v:head(p),material,True)
 if d in ['jingasa','jingasa_leather','kasa']:
  radius={'heavy_jingasa':.205,'light_jingasa':.185,'small_jingasa':.155,'leather_jingasa':.17,'kasa':.235}[key]
  def brim(u,v):
   a=u*math.tau;rr=.10+(radius-.10)*v
   return h+Vector((rr*r*math.sin(a),rr*1.1*r*math.cos(a),(.08-.105*v+.018*v*v)*r))
  t.grid(12,80,brim,lambda p,u,v:head(p),material,True)
  t.tube([brim(i/80,1) for i in range(81)],[.003*r]*81,head,grip,8)
  for a in [i*math.tau/16 for i in range(16)]:
   points=[brim(a/math.tau,j/12)+Vector((0,0,.002*r)) for j in range(13)];t.tube(points,[.0015*r]*13,head,straw if d=='kasa' else gold,6)
 elif d=='kabuto':
  # Articulated-looking back/side lames leave jaw and long hair clear.
  for j in range(4):
   def lame(u,v):
    a=-1.85+3.7*u;rr=(.121+j*.008+v*.007)*r
    return h+Vector((math.sin(a)*rr,math.cos(a)*rr*1.06,(.055-j*.027-v*.025)*r))
   t.grid(2,48,lame,lambda p,u,v:head(p),iron,True)
  for a in [i*math.tau/12 for i in range(12)]:
   points=[crown(a/math.tau,j/20)+Vector((0,0,.002*r)) for j in range(20)];t.tube(points,[.002*r]*20,head,gold,6)
  if key!='standard_kabuto':
   for side in [-1,1]:
    points=[h+Vector((side*(.025+.12*q)*r,-.135*r,(.10+.17*q-.05*q*q)*r)) for q in [i/16 for i in range(17)]]
    t.tube(points,[(.012*(1-i/17)+.001)*r for i in range(17)],head,gold,10)
 elif d=='horned':
  for side in [-1,1]:
   points=[h+Vector((side*(.08+.13*q)*r,.01*r,(.13+.16*q-.06*q*q)*r)) for q in [i/20 for i in range(21)]]
   t.tube(points,[(.022*(1-i/20)+.001)*r for i in range(21)],head,straw,12)
 elif d=='garland':
  line=[h+Vector((.111*r*math.sin(i*math.tau/80),.132*r*math.cos(i*math.tau/80),.065*r)) for i in range(81)];t.tube(line,[.004*r]*81,head,wood,8)
  petal=t.material('frontier_petals',(.49,.25,.20),rough=.94)
  for j in range(12):
   a=j*math.tau/12;centre=h+Vector((.114*r*math.sin(a),.135*r*math.cos(a),.066*r))
   for k in range(5):
    b=k*math.tau/5;point=centre+Vector((math.cos(b)*.012*r,0,math.sin(b)*.012*r));t.tube([point-Vector((0,.003*r,0)),point+Vector((0,.003*r,0))],[.007*r,.005*r],head,petal,8)
 if d in ['jingasa','jingasa_leather','kasa','kabuto']:
  # A real rear opening lets the ponytail leave the helmet/brim. Keep depth
  # testing and the original scalp trim; do not draw hair through solid metal.
  kept=[i for i,face in enumerate(t.faces) if not all(t.vertices[v].y>h.y+.085*r for v in face) or not any(abs(t.vertices[v].x)<.047*r and t.vertices[v].z<h.z+.125*r for v in face)]
  t.faces=[t.faces[i] for i in kept];t.face_material=[t.face_material[i] for i in kept]
 return object_from_tailor(key,True,.002*r)

def blade(profile,y,thick,material,bone='hand_r'):
 # Thin solid blade profile with closed side walls, independent of materials.
 start=len(t.vertices);n=len(profile)
 for sign in [-1,1]:
  for x,z in profile:t.vertex(Vector((x,y+sign*thick/2,z)),{bone:1.},(x*4,z*4))
 t.face([start+i for i in reversed(range(n))],material);t.face([start+n+i for i in range(n)],material)
 for i in range(n):j=(i+1)%n;t.face((start+i,start+j,start+n+j,start+n+i),material)

def weapon(row):
 t.reset();d=row['design'];key=row['key'];bone='hand_r';weight=lambda p:{bone:1.}
 tube=lambda points,radii,mat,sides=12:t.tube([Vector(p) for p in points],radii,weight,mat,sides)
 pole=d in ['scythe','bladed_staff','double_staff','pike','lance','tetsubo','wild_staff','fishing_pole']
 if d.startswith('bow_'):
  bone='hand_l';weight=lambda p:{bone:1.}
  points=[]
  for i in range(-32,33):
   q=i/32;z=q*(.83 if d=='bow_yumi' else .68)
   if d=='bow_yumi':z+=.18*q*q
   points.append(Vector((0,-.13*(1-q*q)+.05*q**6,z)))
  t.tube(points,[.014*(1-.65*abs(i/32)) for i in range(-32,33)],weight,wood,12)
  t.tube([points[0],Vector((0,.025,0)),points[-1]],[.0012]*3,weight,grip,6)
  t.tube([Vector((0,-.13,-.065)),Vector((0,-.13,.065))],[.019]*2,weight,grip,12)
  reference=bow_pose;transform=rig.data.bones[bone].matrix_local@reference[bone].inverted();anchor=reference[bone].translation+Vector((0,-.025,0))
  t.vertices=[transform@(anchor+p) for p in t.vertices]
  return object_from_tailor(key,True)
 if pole:
  bottom=-.42;top={'lance':1.40,'pike':1.30,'scythe':1.10,'fishing_pole':1.25}.get(d,1.05)
  points=[(0,0,bottom),(0,0,top)]
  if d=='wild_staff':points=[(.025*math.sin(i*.65),.015*math.sin(i*.9),bottom+(top-bottom)*i/24) for i in range(25)]
  tube(points,[.019]*len(points),wood)
  tube([(0,0,-.075),(0,0,.075)],[.024,.024],grip)
  if d in ['pike','lance','bladed_staff','double_staff']:
   blade([(-.025,top-.10),(-.035,top+.10),(0,top+.35),(.035,top+.10),(.025,top-.10)],0,.018,iron)
   if d=='double_staff':blade([(-.025,bottom+.05),(-.04,bottom-.12),(0,bottom-.35),(.04,bottom-.12),(.025,bottom+.05)],0,.018,iron)
  elif d=='scythe':blade([(0,top-.09),(.08,top+.05),(.55,top+.04),(.68,top-.08),(.35,top-.02),(.08,top-.04)],0,.016,iron)
  elif d=='tetsubo':
   tube([(0,0,.55),(0,0,1.03)],[.05,.04],wood,8)
   for z in [.61,.72,.83,.94]:
    for a in [i*math.tau/6 for i in range(6)]:tube([(.04*math.sin(a),.04*math.cos(a),z),(.059*math.sin(a),.059*math.cos(a),z)],[.009,.004],iron,6)
  elif d=='fishing_pole':
   tube([(0,0,top),(0,-.05,top+.08),(.03,-.10,.20)],[.001]*3,grip,6)
  elif d=='wild_staff':
   for side in [-1,1]:tube([(0,0,.8),(side*.09,0,1.03),(side*.07,0,1.18)],[.018,.012,.003],wood)
 else:
  length={'katana_long':1.02,'katana_short':.48,'greatsword':.9,'spike':.33,'leafblade':.44,'scimitar':.73,'cleaver':.42,'bokuto':.70,'daisho':.80}.get(d,.60)
  tube([(0,0,-.13),(0,0,.08)],[.017,.017],grip)
  tube([(0,0,-.15),(0,0,-.13)],[.022,.022],gold)
  if d in ['axe','club','diamond_mace']:
   tube([(0,0,.05),(0,0,.57)],[.018,.014],wood)
   if d=='axe':
    for side in [-1,1]:blade([(0,.38),(side*.17,.33),(side*.22,.45),(side*.17,.63),(0,.57)],0,.028,iron)
   elif d=='diamond_mace':tube([(0,0,.39),(0,0,.49),(0,0,.64)],[.025,.085,.009],iron,8)
   else:tube([(0,0,.18),(.01,0,.48),(0,0,.65)],[.024,.06,.04],wood,10)
  elif d in ['kama','scythe_short']:
   tube([(0,0,-.13),(0,0,.40)],[.018,.014],wood)
   blade([(0,.35),(.06,.46),(.31,.44),(.40,.34),(.14,.38),(0,.31)],0,.015,iron)
  elif d=='nunchaku':
   tube([(0,0,-.13),(0,0,.17)],[.02,.02],wood)
   for j in range(7):tube([(.012*math.sin(i*math.tau/12),-.015-j*.014+.010*math.cos(i*math.tau/12),.185) for i in range(13)],[.002]*13,iron,6)
   tube([(0,-.11,.16),(0,-.11,-.14)],[.02,.02],wood)
  elif d=='fan':
   for a in [(-.8+i*.1) for i in range(17)]:tube([(0,0,.05),(.27*math.sin(a),0,.05+.27*math.cos(a))],[.004,.004],iron,6)
   blade([(0,.06)]+[(.27*math.sin(-.8+i*.1),.05+.27*math.cos(-.8+i*.1)) for i in range(17)],0,.008,cloth)
  elif d=='fukiya':tube([(0,0,-.10),(0,0,.62)],[.012,.012],wood)
  elif d=='claw':
   tube([(-.04,0,.08),(.04,0,.08)],[.012,.012],iron)
   for x in [-.032,0,.032]:blade([(x-.005,.07),(x-.006,.27),(x+.025,.36),(x+.006,.23),(x+.005,.07)],0,.01,iron)
  else:
   tube([(-.07,0,.095),(.07,0,.095)],[.009,.009],gold)
   if d=='sai':
    for side in [-1,1]:tube([(0,0,.095),(side*.05,0,.12),(side*.06,0,.26)],[.007,.007,.002],iron)
   if d in ['katana_long','katana_short','daisho','scimitar','bokuto']:
    profile=[(-.017,.11),(-.015,length*.65),(.025,length),(.045,length+.04),(.02,length*.62),(.017,.11)]
   elif d=='leafblade':profile=[(-.014,.11),(-.05,length*.65),(0,length),(.05,length*.65),(.014,.11)]
   elif d=='cleaver':profile=[(-.015,.11),(-.025,length),(.08,length),(.08,.18),(.02,.11)]
   else:profile=[(-.018,.11),(-.023,length-.08),(0,length),(.023,length-.08),(.018,.11)]
   blade(profile,0,.014,wood if d=='bokuto' else iron)
   if key in ['rune_blade','elven_spellblade']:
    for z in [.26,.34,.42]:tube([(-.010,-.010,z),(.01,-.010,z+.02)],[.002,.002],gold,6)
 # Same calibrated closed right palm as the existing weapons, in bind space.
 transform=rig.data.bones[bone].matrix_local@held[bone].inverted();anchor=held[bone].translation+Vector((0,-.025,0))
 t.vertices=[transform@(anchor+p) for p in t.vertices]
 return object_from_tailor(key,True)

if __name__=='__main__':
 evidence=json.loads((OUT/'provenance.json').read_text())
 for row in ROWS:
  ob=derivative(row) if row['base'] else (hat(row) if row['slot']=='head' else weapon(row))
  ob.name='Extra_'+row['key'];ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
  for mod in list(ob.modifiers):
   if mod.type=='ARMATURE':ob.modifiers.remove(mod)
  mod=ob.modifiers.new('Shared named human skeleton','ARMATURE');mod.object=rig
  bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
  path=OUT/(row['key']+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
  evidence['parts'][row['key']]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'kind':'expansion35','base':row['base'],'design':row['design'],'vertices':len(ob.data.vertices),'polygons':len(ob.data.polygons),'source':'Original parametric topology or material variant of exact pinned fitted CC0 input','licence':PINS['licence'],'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'inputs_sha256':hashlib.sha256((ROOT/'scripts/human-frontier-inputs.json').read_bytes()).hexdigest(),'fidelity':'Category replacement; exact item ornament, silhouette and per-weapon combat choreography remain separately reviewable.'}
  bpy.data.objects.remove(ob,do_unlink=True);print('FRONTIER READY',FEMALE,row['key'],flush=True)
 (OUT/'provenance.json').write_text(json.dumps(evidence,indent=2))
 print('FRONTIER COMPLETE',FEMALE,len(ROWS),flush=True)
