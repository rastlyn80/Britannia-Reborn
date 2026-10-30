"""Fitted clothing and original accessories for the 50% human category batch.

Only hash-pinned local licensed inputs are read. Generated art stays ignored.
Long garments use the already accepted independent split riding topology.
"""
import bpy, json, hashlib, importlib.util, math, sys
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('equipment_context',ROOT/'scripts/prepare-human-frontier.py');c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
t=c.t;rig=c.rig;ART=c.ART;OUT=c.OUT;FEMALE=c.FEMALE
TMP=ROOT/'work/human-wardrobe50';TMP.mkdir(parents=True,exist_ok=True)
PINS=json.loads((ROOT/'scripts/human-wardrobe50-inputs.json').read_text())
ROWS=[r for r in json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets'] if r['kind']=='expansion50']
for name,digest in PINS['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
N=512;u,v=np.meshgrid(np.arange(N)/N,np.arange(N)/N)
linen=bpy.data.images.load(str(ROOT/'Viewer/Art/MedievalKit/textures/Linen_Color.jpg'),check_existing=True)
lw,lh=linen.size;pixels=np.array(linen.pixels[:],np.float32).reshape(lh,lw,4)
weave=pixels[((v*4*lh).astype(int)%lh),((u*4*lw).astype(int)%lw),:3].mean(2);weave=np.clip(weave/(weave.mean()+1e-6),.65,1.25)
materials={}

def image(name,rgb):
 rgba=np.ones((N,N,4),np.float32);rgba[:,:,:3]=np.clip(rgb,0,1)
 im=bpy.data.images.new('Authored '+name,N,N);im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(TMP/(name+'.png'));im.file_format='PNG';im.save();return im
def material(style,metal=False):
 key=style+('_metal' if metal else '')
 if key in materials:return materials[key]
 colours={'linen':(.44,.40,.31),'dark_linen':(.075,.09,.10),'formal':(.17,.20,.24),'wedding':(.76,.70,.56),'fur':(.24,.19,.13),'leather':(.17,.105,.055),'studded':(.20,.13,.075),'velvet':(.24,.045,.06),'holiday':(.38,.045,.04),'red':(.38,.055,.045),'blue':(.055,.12,.32),'green':(.055,.24,.11),'purple':(.20,.07,.26),'brass':(.42,.29,.105),'steel':(.32,.36,.40),'leaf':(.17,.23,.12)}
 base=np.array(colours.get(style,(.18,.22,.28)));rgb=weave[:,:,None]*base
 if style in ['heraldic','vice','virtue','pirate']:
  region=((u<.5)^(v<.5));rgb=np.where(region[:,:,None],np.array([.24,.055,.055]),np.array([.065,.12,.22]))*weave[:,:,None]
  crest=((u-.5)**2*1.2+(v-.50)**2<.052);cross=(abs(u-.5)<.028)|(abs(v-.5)<.028)
  rgb[crest & cross]=(.66,.53,.25)
 elif style in ['brocade','floral','gilded','kimono']:
  a=np.sin(u*math.tau*8)*np.cos(v*math.tau*8);b=np.cos(u*math.tau*4)*np.sin(v*math.tau*4)
  motif=(abs(a+b*.5)>.93)|(abs(np.sin((u+v)*math.tau*8))<.04)
  rgb[motif]=(.45,.34,.17) if style!='floral' else (.43,.22,.19)
 elif style in ['tiger','scale','brocade_metal']:
  if style=='tiger':motif=abs(np.sin((u*8+.45*np.sin(v*math.tau*4))*math.tau))>.7;rgb=weave[:,:,None]*np.array([.38,.25,.12]);rgb[motif]*=.35
  else:
   x=(u*10+np.floor(v*10)*.5)%1-.5;y=(v*10)%1;edge=abs(y-(.2+.65*np.sqrt(np.maximum(0,1-4*x*x))))<.055
   rgb=weave[:,:,None]*np.array([.27,.31,.29]);rgb[edge]*=.42
 elif style=='tartan':
  a=(u*8)%1;b=(v*8)%1;rgb=weave[:,:,None]*np.array([.10,.20,.14]);rgb[(a<.17)|(b<.17)]*=.35;rgb[(a>.62)&(a<.70)]=(.35,.09,.07);rgb[(b>.62)&(b<.70)]=(.35,.09,.07)
 elif style=='jester':rgb=np.where((u<.5)[:,:,None],np.array([.35,.055,.045]),np.array([.06,.16,.25]))*weave[:,:,None]
 elif style=='pleated':rgb*= (.72+.28*(.5+.5*np.sin(u*math.tau*28)))[:,:,None]
 elif style=='arcane':
  glyph=((abs((u*8)%1-.5)<.07)&((v*8)%1<.7))|((abs((v*8)%1-.5)<.05)&((u*8)%1<.7));rgb[glyph]=(.47,.38,.19)
 elif style=='fur':rgb*= (.76+.24*np.sin(u*173+np.sin(v*181))**2)[:,:,None]
 mat=t.material('Wardrobe50_'+key,tuple(base),.90 if metal else 0.,.56 if metal else .94)
 nodes=mat.node_tree.nodes;links=mat.node_tree.links;s=nodes.get('Principled BSDF');tex=nodes.new('ShaderNodeTexImage');tex.image=image(key,rgb);links.new(tex.outputs['Color'],s.inputs['Base Color']);materials[key]=mat;return mat

def source_object(path):
 objects=c.load(path);ob=next(o for o in objects if o.type=='MESH' and o.name.startswith(('Extra_','Free_')))
 source_rig=next(o for o in objects if o.type=='ARMATURE');transform=source_rig.matrix_world.inverted()@ob.matrix_world
 assert all(abs(transform[i][j]-(i==j))<1e-5 for i in range(4) for j in range(4))
 for extra in objects:
  if extra!=ob:bpy.data.objects.remove(extra,do_unlink=True)
 return ob

def derivative(row,base):
 ob=source_object(ART/(base+'.glb'))
 for i,old in enumerate(ob.data.materials):
  if old is None:continue
  if old.name.startswith('Armour_Lining'):continue
  shader=old.node_tree.nodes.get('Principled BSDF') if old.use_nodes else None
  if shader and shader.inputs['Emission Color'].default_value[:3]!=(0.,0.,0.) and shader.inputs['Emission Strength'].default_value>0:continue
  metal=base.startswith('coverage/plate_') or row['design'] in ['steel','brocade_metal']
  ob.data.materials[i]=material(row['design'],metal)
 return ob

def tube(points,radii,mat,bone='head',sides=12):
 assert isinstance(bone,str) and bone in rig.data.bones,bone
 t.tube([Vector(p) for p in points],radii,lambda p:{bone:1.},mat,sides)
def headwear(row):
 t.reset();key=row['key'];d=row['design'];h=t.head;r=t.ratio;head=lambda p:{'head':1.};gold=c.gold
 if d=='kabuto':return c.hat(dict(row,key='standard_kabuto'))
 if d.startswith('hood'):
  cloth=material('velvet' if d=='hood_mage' else 'dark_linen');t.materials['mail']=cloth;t.headwear('chain_coif');t.face_material=[cloth]*len(t.faces)
  t.vertices=[p+Vector((0,0,max(0.,p.z-h.z-.13)*1.3)) for p in t.vertices]
  return c.object_from_tailor(key,True,.0018*r)
 if d=='spectacles':
  for side in [-1,1]:
   points=[h+Vector(((side*.036+.028*math.sin(i*math.tau/40))*r,-.128*r,(.052+.020*math.cos(i*math.tau/40))*r)) for i in range(41)];tube(points,[.0022*r]*41,gold)
   tube([h+Vector((side*.064*r,-.128*r,.055*r)),h+Vector((side*.089*r,-.06*r,.055*r)),h+Vector((side*.090*r,.025*r,.045*r))],[.002*r]*3,gold)
  tube([h+Vector((-.008*r,-.13*r,.055*r)),h+Vector((.008*r,-.13*r,.055*r))],[.002*r]*2,gold)
  return c.object_from_tailor(key,True)
 cloth=material('wedding' if d=='chef' else 'holiday' if d=='holiday' else 'formal' if d in ['tophat','haunted_hat'] else 'leather' if d=='leather_cap' else 'scale' if d=='turtle_helm' else 'steel',d in ['winged','turtle_helm'])
 if d=='pumpkin':
  cloth=t.material('Wardrobe50_pumpkin',(.52,.21,.035),rough=.92)
  def dome(u,v):
   a=u*math.tau;theta=v*math.pi;f=1+.04*math.cos(10*a)
   return h+Vector((.123*f*r*math.sin(theta)*math.sin(a),.142*f*r*math.sin(theta)*math.cos(a),(.065+.16*math.cos(theta))*r))
  t.grid(30,64,dome,lambda p,u,v:head(p),cloth,True)
  keep=[]
  for i,f in enumerate(t.faces):
   p=sum((t.vertices[j] for j in f),Vector())/len(f)-h
   holes=p.y<-.06*r and ((abs(abs(p.x/r)-.042)<.027 and .04<p.z/r<.085) or (abs(p.x/r)<.06 and -.04<p.z/r<-.015))
   if not holes:keep.append(i)
  t.faces=[t.faces[i] for i in keep];t.face_material=[t.face_material[i] for i in keep]
  tube([h+Vector((0,0,.22*r)),h+Vector((.012*r,0,.28*r))],[.014*r,.008*r],c.wood)
 else:
  if d in ['tophat','haunted_hat']:rings=[(.109,.129,.05),(.105,.124,.29),(.005,.005,.30)]
  elif d=='chef':rings=[(.110,.130,.05),(.114,.134,.15),(.15,.16,.23),(.13,.14,.34),(.005,.005,.36)]
  elif d=='holiday':rings=[(.11,.13,.05),(.11,.125,.1),(.065,.075,.26),(.015,.02,.38)]
  else:rings=[(.107,.127,.045),(.10,.12,.105),(.075,.09,.165),(.004,.004,.19)]
  for a,b in zip(rings,rings[1:]):
   def crown(u,v,a=a,b=b):
    angle=u*math.tau;rx=a[0]*(1-v)+b[0]*v;ry=a[1]*(1-v)+b[1]*v;z=a[2]*(1-v)+b[2]*v
    gather=1+.035*math.sin(angle*16) if d=='chef' else 1.
    return h+Vector((rx*r*math.sin(angle)*gather,ry*r*math.cos(angle)*gather,z*r))
   t.grid(8,64,crown,lambda p,u,v:head(p),cloth,True)
  if d in ['tophat','haunted_hat']:
   def brim(u,v):
    a=u*math.tau;return h+Vector(((.105+.085*v)*r*math.sin(a),(.125+.065*v)*r*math.cos(a),(.052+.008*v*v)*r))
   t.grid(6,72,brim,lambda p,u,v:head(p),cloth,True)
  if d=='winged':
   for side in [-1,1]:
    for j in range(5):tube([h+Vector((side*.09*r,0,(.10-j*.013)*r)),h+Vector((side*(.19+j*.01)*r,.02*r,(.29-j*.035)*r))],[.015*r,.003*r],c.iron,sides=8)
  if d=='holiday':
   path=[h+Vector((.111*r*math.sin(i*math.tau/64),.131*r*math.cos(i*math.tau/64),.07*r)) for i in range(65)];tube(path,[.012*r]*65,material('wedding'))
 # Physical rear port preserves ponytail emergence with ordinary depth testing.
 keep=[i for i,f in enumerate(t.faces) if not all(t.vertices[j].y>h.y+.085*r for j in f) or not any(abs(t.vertices[j].x)<.047*r and t.vertices[j].z<h.z+.125*r for j in f)]
 t.faces=[t.faces[i] for i in keep];t.face_material=[t.face_material[i] for i in keep]
 return c.object_from_tailor(key,True,.002*r)

def accessory(row):
 t.reset();d=row['design'];r=t.ratio;h=t.head
 if d.startswith('mempo_'):
  mat=material(d[6:],d.endswith('steel'))
  t.grid(12,48,lambda u,v:h+Vector((.108*r*math.sin((u-.5)*2.6),-.125*r*math.cos((u-.5)*2.6),(-.015-.115*v)*r)),lambda p,u,v:{'head':1.},mat,True)
  return c.object_from_tailor(row['key'],True,.003*r)
 if d.startswith('belt_') or d=='talisman':
  bone='pelvis';z=rig.data.bones[bone].head_local.z+.14*r
  source=source_object(ART/'expansion/shirt.glb')
  candidates=[v for v in source.data.vertices if abs(v.co.z-z)<.04*r and abs(v.co.x)<.33*r and sum(g.weight for g in v.groups if source.vertex_groups[g.group].name.startswith(('spine','pelvis')))>.7]
  assert candidates
  rx=max(abs(v.co.x) for v in candidates)+.018*r;front=min(v.co.y for v in candidates)-.018*r;back=max(v.co.y for v in candidates)+.018*r;ry=(back-front)*.5;cy=(back+front)*.5
  mat=material(d[5:] if d.startswith('belt_') else 'leather')
  if d!='talisman':
   t.grid(4,80,lambda u,v:Vector((rx*math.sin(u*math.tau),cy+ry*math.cos(u*math.tau),z+(v-.5)*.052*r)),lambda p,u,v:{'pelvis':.6,'spine_01':.4},mat,True)
  t.box(Vector((0,front-.006*r,z)),Vector((.045*r,.015*r,.045*r)),bone,c.gold)
  if d in ['belt_sword','belt_dagger','belt_mace','belt_aid','belt_demon','talisman']:
   x=.13*r;length=.27*r if d=='belt_sword' else .16*r
   if d=='belt_aid':t.box(Vector((x,front-.03*r,z-.045*r)),Vector((.09*r,.06*r,.10*r)),bone,material('wedding'))
   else:
    tube([(x,front-.03*r,z-.04*r),(x+.035*r,front-.03*r,z-length)],[.019*r,.009*r],c.wood,bone)
    tube([(x-.025*r,front-.03*r,z-.055*r),(x+.025*r,front-.03*r,z-.055*r)],[.006*r]*2,c.gold,bone)
  for i,p in enumerate(t.vertices):
   vertex=min(candidates,key=lambda v:(v.co-p).length_squared);weights=sorted(((source.vertex_groups[g.group].name,g.weight) for g in vertex.groups),key=lambda v:-v[1])[:4];total=sum(w for _,w in weights);t.weights[i]={name:w/total for name,w in weights}
  bpy.data.objects.remove(source,do_unlink=True)
  return c.object_from_tailor(row['key'],True,.0018*r)
 if d=='quiver':
  bone='spine_02';bottom=Vector((-.23*r,.15*r,.94*r));top=Vector((-.25*r,.18*r,1.30*r));tube([bottom,top],[.065*r,.072*r],material('leather'),bone,20)
  for j in range(5):
   p=top+Vector(((j-2)*.017*r,0,.18*r));tube([p-Vector((0,0,.20*r)),p],[.003*r]*2,c.wood,bone,6);tube([p,p+Vector((0,0,.035*r))],[.010*r,.002*r],material('wedding'),bone,6)
  return c.object_from_tailor(row['key'],True)
 # Calibrated rigid hand props, in the same bind frame as existing equipment.
 bone='hand_l' if row['slot']=='shield' else 'hand_r';mat=c.iron
 if d in ['torch','candle']:
  if d=='torch':tube([(0,0,-.16),(0,0,.24)],[.016,.020],c.wood,bone);tube([(0,0,.20),(0,0,.30)],[.029,.027],material('leather'),bone)
  else:
   tube([(0,0,-.07),(0,0,-.04)],[.065,.065],c.gold,bone,20);tube([(0,0,-.04),(0,0,.15)],[.022,.022],material('wedding'),bone,20)
  if row.get('lit'):
   flame=t.material('Wardrobe50_flame',(1.,.30,.045),rough=1.);shader=flame.node_tree.nodes.get('Principled BSDF');shader.inputs['Emission Color'].default_value=(1.,.22,.025,1);shader.inputs['Emission Strength'].default_value=2.
   z=.30 if d=='torch' else .15;tube([(0,0,z),(0,0,z+.035),(.008,0,z+.095)],[.009,.028,.001],flame,bone,16)
 elif d in ['hatchet','cleaver','skull_sword','crescent']:
  tube([(0,0,-.13),(0,0,.11)],[.016]*2,c.grip,bone)
  if d=='hatchet':tube([(0,0,.05),(0,0,.43)],[.018]*2,c.wood,bone);c.blade([(0,.29),(.16,.26),(.19,.39),(.12,.49),(0,.43)],0,.025,mat)
  elif d=='crescent':
   tube([(0,0,.05),(0,0,.46)],[.016]*2,c.wood,bone)
   for side in [-1,1]:c.blade([(0,.3),(side*.18,.27),(side*.27,.46),(side*.18,.65),(0,.60),(side*.12,.50)],0,.018,mat)
  else:c.blade([(-.02,.11),(-.024,.65),(0,.78),(.026,.65),(.06,.17)],0,.016,mat)
 elif d in ['skull_staff','candy_staff','wand']:
  length=.5 if d=='wand' else 1.1;points=[Vector((0,0,-.3)),Vector((0,0,length))]
  if d=='candy_staff':points += [Vector((.09-.09*math.cos(i*math.pi/16),0,length+.09*math.sin(i*math.pi/16))) for i in range(1,17)]
  tube(points,[.017]*len(points),material(('green' if row['key']=='candy_staff_green' else 'holiday') if d=='candy_staff' else 'leather'),bone)
  if d=='skull_staff':tube([(0,0,length),(0,0,length+.1)],[.055,.045],material('wedding'),bone,12)
  if d=='wand':tube([(0,0,length),(0,0,length+.07)],[.03,.004],c.gold,bone,10)
 elif d=='bottle':tube([(0,0,-.15),(0,0,.08),(0,0,.12)],[.045,.045,.018],material('green'),bone,16)
 elif d=='orb':tube([(0,0,-.045),(0,0,.015),(0,0,.075)],[.005,.065,.005],material('blue',True),bone,24)
 transform=rig.data.bones[bone].matrix_local@c.held[bone].inverted();anchor=c.held[bone].translation+Vector((0,-.025,0))
 t.vertices=[transform@(anchor+p) for p in t.vertices]
 return c.object_from_tailor(row['key'],True)

evidence=json.loads((OUT/'provenance.json').read_text())
for row in ROWS:
 variants=[('',row.get('base'))]
 if row.get('riding_base'):variants.append(('_riding',row['riding_base']))
 for suffix,base in variants:
  ob=derivative(row,base) if base else (headwear(row) if row['slot']=='head' else accessory(row))
  ob.name='Extra_'+row['key'];ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
  for mod in list(ob.modifiers):
   if mod.type=='ARMATURE':ob.modifiers.remove(mod)
  mod=ob.modifiers.new('Shared named human skeleton','ARMATURE');mod.object=rig
  bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
  name=row['key']+suffix;path=OUT/(name+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
  evidence['parts'][name]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'kind':'expansion50','base':base,'design':row['design'],'source':PINS['construction'],'licence':PINS['licence'],'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'inputs_sha256':hashlib.sha256((ROOT/'scripts/human-wardrobe50-inputs.json').read_bytes()).hexdigest(),'fidelity':'Fitted category replacement; exact native cut, ornament, eligibility and per-item choreography remain separate.'}
  evidence['parts'][name]['recipe_row_sha256']=hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest()
  evidence['parts'][name]['builder_dependencies']={file:hashlib.sha256((ROOT/file).read_bytes()).hexdigest() for file in ['scripts/prepare-human-frontier.py','scripts/human-tailoring.py']}
  bpy.data.objects.remove(ob,do_unlink=True);print('WARDROBE50 READY',FEMALE,name,flush=True)
(OUT/'provenance.json').write_text(json.dumps(evidence,indent=2));print('WARDROBE50 COMPLETE',FEMALE,len(ROWS),flush=True)
