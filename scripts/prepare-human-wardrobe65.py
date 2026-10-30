"""Historical human equipment variants and original small wearable accessories.

Source topology and named weights are retained. Composite outer garments use
declared millimetre depth offsets and a matching fitted inner lining.
Only pinned licensed inputs are read; proprietary client artwork is not exported.
"""
import bpy, json, hashlib, importlib.util, math
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('equipment_context',ROOT/'scripts/prepare-human-frontier.py')
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
t=c.t;rig=c.rig;ART=c.ART;OUT=c.OUT;FEMALE=c.FEMALE
PINS=json.loads((ROOT/'scripts/human-wardrobe65-inputs.json').read_text())
ROWS=[r for r in json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets'] if r['kind']=='expansion65']
for name,digest in PINS['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name

def derivative(base,row):
 objects=c.load(ART/(base+'.glb'))
 ob=next(o for o in objects if o.type=='MESH' and o.name.startswith(('Extra_','Free_')))
 source_rig=next(o for o in objects if o.type=='ARMATURE')
 transform=source_rig.matrix_world.inverted()@ob.matrix_world
 assert all(abs(transform[i][j]-(i==j))<1e-5 for i in range(4) for j in range(4))
 for extra in objects:
  if extra!=ob:bpy.data.objects.remove(extra,do_unlink=True)
 if row.get('integrated_lining'):
  for vertex in ob.data.vertices:
   offset=row['outer_depth_offset'] if vertex.co.y>=0 else row.get('front_depth_offset',row['outer_depth_offset'])
   vertex.co.y+=(1 if vertex.co.y>=0 else -1)*offset/ob.matrix_world.to_scale().y
  lining=derivative('coverage/armour_undercoat',{})
  cloth=next(m for m in ob.data.materials if m and not m.name.startswith('Armour_Lining'))
  for i in range(len(lining.data.materials)):lining.data.materials[i]=cloth
  for vertex in lining.data.vertices:
   vertex.co.y+=(1 if vertex.co.y>=0 else -1)*row['lining_depth_offset']/lining.matrix_world.to_scale().y
  bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);lining.select_set(True);bpy.context.view_layer.objects.active=ob
  bpy.ops.object.join()
 return ob

def tube(points,radii,material,bone='head',sides=12):
 t.tube([Vector(p) for p in points],radii,lambda p:{bone:1.},material,sides)

def authored(row):
 t.reset();d=row['design'];r=t.ratio;h=t.head
 if d=='headband':
  # A shallow fabric band leaves scalp and all rear hair physically unobstructed.
  t.grid(4,80,lambda u,v:h+Vector((.109*r*math.sin(u*math.tau),.130*r*math.cos(u*math.tau),(.055+.025*v)*r)),lambda p,u,v:{'head':1.},c.cloth,True)
  for side in [-1,1]:tube([h+Vector((side*.03*r,.132*r,.06*r)),h+Vector((side*.055*r,.14*r,-.005*r))],[.006*r,.003*r],c.cloth)
  return c.object_from_tailor(row['key'],True,.001*r)
 if d in ['medallion','octopus']:
  bone='spine_02';centre=Vector((0,-.145*r,1.34*r))
  # A chain drops over the shirt front; the pendant uses solid geometry.
  points=[Vector((.105*r*math.sin(a),-.01*r+.10*r*math.cos(a),(1.43-.09*max(0,-math.cos(a)))*r)) for a in [i*math.tau/64 for i in range(65)]]
  tube(points,[.0025*r]*len(points),c.gold,bone)
  if d=='medallion':
   tube([centre+Vector((0,.004*r,-.035*r)),centre+Vector((0,.004*r,.035*r))],[.024*r,.024*r],c.gold,bone,20)
   tube([centre+Vector((-.018*r,-.025*r,0)),centre+Vector((.018*r,-.025*r,0))],[.003*r]*2,c.iron,bone)
  else:
   tube([centre+Vector((0,0,.012*r)),centre+Vector((0,0,.045*r)),centre+Vector((0,0,.060*r))],[.019*r,.025*r,.004*r],c.gold,bone,16)
   for j in range(8):
    angle=j*math.tau/8;points=[centre+Vector(((j-3.5)*.006*r+math.sin(angle)*.024*r*q,-.008*r-abs(math.sin(angle))*.006*r,(-.055*q+.012*math.sin(q*math.tau))*r)) for q in [i/12 for i in range(13)]]
    tube(points,[(.004*(1-i/15))*r for i in range(13)],c.gold,bone,8)
  return c.object_from_tailor(row['key'],True)
 bone='hand_r'
 if d=='crook':
  points=[Vector((0,0,-.45)),Vector((0,0,.85))]
  points += [Vector((.085-.085*math.cos(i*math.pi/20),0,.85+.085*math.sin(i*math.pi/20))) for i in range(1,21)]
  tube(points,[.017]*len(points),c.wood,bone)
 elif d.startswith('whip_'):
  tube([(0,0,-.12),(0,0,.12)],[.015,.013],c.grip,bone)
  # Coiled carry silhouette. Lash attacks still use the shared action family;
  # dynamic lash simulation and individual attack choreography remain pending.
  points=[Vector((.12*math.sin(q*math.tau*1.5),.02*q,.12+.24*q-.10*math.sin(q*math.pi))) for q in [i/80 for i in range(81)]]
  tube(points,[.010*(1-i/110) for i in range(81)],c.grip,bone,10)
  for i in range(8,80,8):
   p=points[i];side=-1 if i%16 else 1
   tube([p,p+Vector((side*.028,0,.014))],[.008,.001],c.iron,bone,6)
 else:raise ValueError(d)
 transform=rig.data.bones[bone].matrix_local@c.held[bone].inverted()
 anchor=c.held[bone].translation+Vector((0,-.025,0))
 t.vertices=[transform@(anchor+p) for p in t.vertices]
 return c.object_from_tailor(row['key'],True)

evidence=json.loads((OUT/'provenance.json').read_text())
for row in ROWS:
 variants=[('',row.get('base'))]
 if row.get('riding_base'):variants.append(('_riding',row['riding_base']))
 for suffix,base in variants:
  ob=derivative(base,row) if base else authored(row)
  ob.name='Extra_'+row['key'];ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
  for mod in list(ob.modifiers):
   if mod.type=='ARMATURE':ob.modifiers.remove(mod)
  mod=ob.modifiers.new('Shared named human skeleton','ARMATURE');mod.object=rig
  bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
  name=row['key']+suffix;path=OUT/(name+'.glb')
  bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_tangents=True)
  evidence['parts'][name]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'kind':'expansion65','base':base,'design':row['design'],'source':PINS['construction'],'licence':PINS['licence'],'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'inputs_sha256':hashlib.sha256((ROOT/'scripts/human-wardrobe65-inputs.json').read_bytes()).hexdigest(),'recipe_row_sha256':hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest(),'builder_dependencies':{file:hashlib.sha256((ROOT/file).read_bytes()).hexdigest() for file in ['scripts/prepare-human-frontier.py','scripts/human-tailoring.py']},'fidelity':'Fitted human category replacement with shared silhouettes. Exact native ornament, server eligibility and per-item choreography are separate.'}
  bpy.data.objects.remove(ob,do_unlink=True);print('WARDROBE65 READY',FEMALE,name,flush=True)
(OUT/'provenance.json').write_text(json.dumps(evidence,indent=2));print('WARDROBE65 COMPLETE',FEMALE,len(ROWS),flush=True)
