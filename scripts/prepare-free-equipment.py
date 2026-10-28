"""Build five CC0 clothing substitutions on the fixed free human base in Blender."""
import bpy,bmesh,json,hashlib,sys,math
from pathlib import Path
from collections import defaultdict
from mathutils import Vector,Matrix
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'))
from mhclo_inspect import parse_obj,parse_proxy
FEMALE='--female' in sys.argv
SRC=ROOT/'work/free-equipment';OUT=ROOT/('Viewer/local-art/free-equipment-female' if FEMALE else 'Viewer/local-art/free-equipment');OUT.mkdir(parents=True,exist_ok=True)
BASE=ROOT/('Viewer/local-art/free-human-female/free-human.glb' if FEMALE else 'Viewer/local-art/free-human/free-human.glb')
if not (OUT/'equipment-previous.glb').exists():(OUT/'equipment-previous.glb').write_bytes(BASE.read_bytes())
PIN=json.loads((SRC/'download-manifest.json').read_text())
EVIDENCE=dict(source_pack=PIN,base_sha256=hashlib.sha256(BASE.read_bytes()).hexdigest(),base_obj_sha256=hashlib.sha256((SRC/'base.obj').read_bytes()).hexdigest(),licence='CC0-1.0 for all selected inputs',assets={})
EVIDENCE['sex']='female' if FEMALE else 'male'
bpy.context.preferences.filepaths.file_preview_type='NONE'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(BASE))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH' and o.name=='Body')
meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.vertex_groups]
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks:tr.mute=True
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
raw=parse_obj(SRC/'base.obj');uv_map=defaultdict(set)
for face,uvs in zip(raw['faces'],raw['face_uv']):
 for vi,ti in zip(face,uvs):
  if vi in raw['body_ids']:uv_map[tuple(round(x,5) for x in raw['uv'][ti])].add(vi)
keys=list(uv_map);uv_tree=KDTree(len(keys))
for i,uv in enumerate(keys):uv_tree.insert((uv[0],uv[1],0),i)
uv_tree.balance();orig_to_target={};target_to_orig={};max_uv_error=0.
local=rig.matrix_world.inverted()@body.matrix_world
for poly in body.data.polygons:
 for li in poly.loop_indices:
  uv=body.data.uv_layers.active.data[li].uv;_,index,error=uv_tree.find((uv.x,uv.y,0));max_uv_error=max(max_uv_error,error)
  if error>1e-5:raise RuntimeError('Base UV topology differs from hm08')
  choices=uv_map[keys[index]]
  if len(choices)!=1:raise RuntimeError('Ambiguous base UV identity')
  original=next(iter(choices));vi=body.data.loops[li].vertex_index;orig_to_target[original]=vi;target_to_orig[vi]=original
print('CORE MAPPING',len(orig_to_target),len(target_to_orig),'UV residual',max_uv_error)
def oldco(p):return Vector((p[0]*.1,-p[2]*.1,p[1]*.1))
oldtree=KDTree(len(orig_to_target));ids=list(orig_to_target)
for i,original in enumerate(ids):oldtree.insert(oldco(raw['points'][original]),i)
oldtree.balance()
full=[];weights=[]
group_names={g.index:g.name for g in body.vertex_groups}
def vertex_weights(vi):return {group_names[g.group]:g.weight for g in body.data.vertices[vi].groups if g.weight>1e-7}
for i,p in enumerate(raw['points']):
 if i in orig_to_target:
  vi=orig_to_target[i];full.append(local@body.data.vertices[vi].co);weights.append(vertex_weights(vi))
 else:
  old=oldco(p);near=oldtree.find_n(old,3);factors=[1/max(d,.0001)**2 for co,idx,d in near];total=sum(factors)
  point=old.copy();w={}
  for (co,index,d),factor in zip(near,factors):
   original=ids[index];vi=orig_to_target[original];k=factor/total;point+=(local@body.data.vertices[vi].co-co)*k
   for name,value in vertex_weights(vi).items():w[name]=w.get(name,0.)+value*k
  full.append(point);weights.append(w)
EVIDENCE['topology_mapping']=dict(core_vertices=len(orig_to_target),exported_vertices=len(target_to_orig),max_uv_error=max_uv_error,helper_method='nearest-three body displacement and weights')
body.data.calc_loop_triangles();bvh=BVHTree.FromPolygons([local@v.co for v in body.data.vertices],[tuple(t.vertices) for t in body.data.loop_triangles],all_triangles=True)
ITEMS={'tunic':'rehmanpolanski_viking_tunic','pants':'rehmanpolanski_viking_pants','boots':'rehmanpolanski_viking_boots','robe':'donitz_monk_robe','hood':'donitz_monk_robe_hood'}
assets={};masks={}
def make_material(folder,filename):
 fields={}
 for rawline in (folder/filename).read_text(encoding='utf-8',errors='replace').splitlines():
  s=rawline.split()
  if s and not s[0].startswith(('#','//')):fields[s[0]]=' '.join(s[1:])
 mat=bpy.data.materials.new('Free_'+folder.name);mat.use_nodes=True;tree=mat.node_tree;p=tree.nodes.get('Principled BSDF')
 p.inputs['Roughness'].default_value=.78 if 'boots' in folder.name else .88
 p.inputs['Specular IOR Level'].default_value=.25
 for key,role in [('diffuseTexture','Base Color'),('normalmapTexture','Normal')]:
  if key not in fields:continue
  path=folder/fields[key]
  if not path.exists():raise RuntimeError('Missing map '+str(path))
  tex=tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True)
  if role=='Normal':
   tex.image.colorspace_settings.name='Non-Color';normal=tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.6;tree.links.new(tex.outputs['Color'],normal.inputs['Color']);tree.links.new(normal.outputs['Normal'],p.inputs['Normal'])
  else:tree.links.new(tex.outputs['Color'],p.inputs[role])
 return mat
for slot,foldername in ITEMS.items():
 folder=SRC/'assets/clothes'/foldername;proxy=parse_proxy(folder/(foldername+'.mhclo'));obj=parse_obj(folder/proxy['fields']['obj_file'])
 if len(obj['points'])!=len(proxy['rows']):raise RuntimeError('OBJ/proxy vertex count mismatch')
 scale={}
 for axis,component in [('x',0),('y',2),('z',1)]:
  a,b,d=proxy['fields'][axis+'_scale'];scale[axis]=abs(full[a][component]-full[b][component])/d
 coords=[];skin=[];corrected=0;max_push=0.
 for refs,ws,offset in proxy['rows']:
  if max(refs)>=len(full):raise RuntimeError('Proxy points outside base mesh')
  co=sum((full[i]*w for i,w in zip(refs,ws)),Vector())+Vector((offset[0]*scale['x'],-offset[2]*scale['z'],offset[1]*scale['y']))
  p,n,face,dist=bvh.find_nearest(co)
  if p is not None and dist<.055 and (co-p).dot(n)<.004:
   delta=(.004-(co-p).dot(n))*n;co+=delta;corrected+=1;max_push=max(max_push,delta.length)
  if slot=='robe' and co.z<.95:co.z=.95-(.95-max(co.z,.085))*.91
  w={}
  for i,amount in zip(refs,ws):
   for name,value in weights[i].items():w[name]=w.get(name,0.)+amount*value
  ordered=sorted(((n,v) for n,v in w.items() if v>1e-7),key=lambda p:-p[1])[:4];total=sum(v for n,v in ordered)
  if total<=0:raise RuntimeError('Unweighted fitted clothing vertex')
  coords.append(co);skin.append([(n,v/total) for n,v in ordered])
 mesh=bpy.data.meshes.new('Free_'+slot);mesh.from_pydata(coords,[],obj['faces']);mesh.update();ob=bpy.data.objects.new('Free_'+slot,mesh);bpy.context.collection.objects.link(ob)
 uv=mesh.uv_layers.new(name='UVMap')
 for poly,uvs in zip(mesh.polygons,obj['face_uv']):
  for li,ti in zip(poly.loop_indices,uvs):uv.data[li].uv=obj['uv'][ti]
 for name in sorted({n for w in skin for n,v in w}):ob.vertex_groups.new(name=name)
 for i,w in enumerate(skin):
  for n,v in w:ob.vertex_groups[n].add([i],v,'REPLACE')
 ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
 mod=ob.modifiers.new('Shared human rig','ARMATURE');mod.object=rig
 mesh.materials.append(make_material(folder,proxy['fields']['material']))
 for poly in mesh.polygons:poly.use_smooth=True
 assets[slot]=ob;masks[slot]=proxy['deleted']
 EVIDENCE['assets'][slot]=dict(source=foldername,author='Donitz' if slot in ['robe','hood'] else 'RehmanPolanski',licence='CC0',vertices=len(coords),triangles=sum(len(f)-2 for f in obj['faces']),corrected_vertices=corrected,max_surface_push=max_push,mask_vertices=len(proxy['deleted']),helper_references=sum(i not in orig_to_target for refs,ws,off in proxy['rows'] for i in refs))
# Bake garment-only controls while the complete, unmasked body is available.
import importlib.util
spec=importlib.util.spec_from_file_location('robe_motion',ROOT/'scripts/robe-motion.py');motion=importlib.util.module_from_spec(spec);spec.loader.exec_module(motion)
EVIDENCE['robe_silhouette']=motion.fit_silhouette(assets['robe'],body,rig)
EVIDENCE['robe_motion']=motion.bake(rig,body,assets['robe'])
EVIDENCE['robe_recipe_sha256']=hashlib.sha256((ROOT/'scripts/robe-motion.py').read_bytes()).hexdigest()
# Natural albedo candidates and original normal/spec maps retain source pixels.
exec(compile((ROOT/'scripts/prepare-natural-skin.py').read_text(),str(ROOT/'scripts/prepare-natural-skin.py'),'exec'),{'__file__':str(ROOT/'scripts/prepare-natural-skin.py')})
skin_folder=SRC/'assets/skins/mindfront_aksel_skin'
for name in ['Aksel_Skin_diffuse.png','Aksel_Skin_NRM.png','Aksel_Skin_SPEC.png']:(OUT/name).write_bytes((skin_folder/name).read_bytes())
for mat in body.data.materials:
 if mat.name.startswith('Skin'):
  tree=mat.node_tree;p=next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED');al=tree.nodes.new('ShaderNodeTexImage');al.image=bpy.data.images.load(str(ROOT/'Viewer/local-art/free-equipment'/('young_lightskinned_female_diffuse.png' if FEMALE else 'young_lightskinned_male_diffuse2.png')));tree.links.new(al.outputs['Color'],p.inputs['Base Color'])
  tex=tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(skin_folder/'Aksel_Skin_NRM.png'));tex.image.colorspace_settings.name='Non-Color';normal=tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.45;tree.links.new(tex.outputs['Color'],normal.inputs['Color']);tree.links.new(normal.outputs['Normal'],p.inputs['Normal']);p.inputs['Roughness'].default_value=.58
# Exact author-provided coverage groups, using recovered original vertex identities.
def masked(slots):
 ob=body.copy();ob.data=body.data.copy();bpy.context.collection.objects.link(ob);deleted=set().union(*(masks[s] for s in slots))
 if 'robe' in slots:
  # The source delete group includes skin which becomes exposed in a stride.
  # Keep complete pelvis/legs below the waist, including all connecting faces.
  retained={target_to_orig[v.index] for v in body.data.vertices if v.index in target_to_orig and (local@v.co).z<.92}
  deleted.difference_update(retained)
 boot_top=max(v.co.z for v in assets['boots'].data.vertices)-.015 if 'boots' in slots else 0.
 # The Viking files have no delete group. Apply fixed-body anatomical masks
 # beneath their actual sleeves/waist/boot shafts, retaining exposed extremities.
 for v in body.data.vertices:
  co=local@v.co;ws=vertex_weights(v.index)
  def covered(prefixes):return sum(w for n,w in ws.items() if n.startswith(prefixes))>.5
  hide=False
  if 'tunic' in slots:
   hide=covered(('pelvis','spine','clavicle','upperarm','lowerarm')) or (co.z>.72 and covered(('thigh',)))
   if co.z>1.43 and abs(co.x)<.13:hide=False
  if 'pants' in slots:
   hide=hide or covered(('pelvis','thigh')) or (co.z>.45 and covered(('calf',)))
  if 'boots' in slots:
   hide=hide or (co.z<boot_top and covered(('calf','foot','ball')))
  if 'robe' in slots:
   hide=hide or (co.z>.94 and covered(('spine','clavicle','upperarm','lowerarm')))
   if co.z>1.43 and abs(co.x)<.13:hide=False
  if hide and v.index in target_to_orig:deleted.add(target_to_orig[v.index])
 bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table();bad=[f for f in bm.faces if any(target_to_orig.get(v.index,-1) in deleted for v in f.verts)]
 bmesh.ops.delete(bm,geom=bad,context='FACES');bm.to_mesh(ob.data);bm.free();return ob
variants={'base':[],'tunic':['tunic'],'pants':['pants'],'boots':['boots'],'robe':['robe'],'hood':['hood'],'viking':['tunic','pants','boots'],'monk':['robe','hood']}
base_location=rig.location.copy()
for variant,slots in variants.items():
 rig.location=base_location+Vector((0,0,.013 if 'boots' in slots else 0.))
 b=masked(slots) if slots else body
 chosen=[rig,b]+[o for o in meshes if o!=body and not ('hood' in slots and o.name.startswith('Hair_')) and not (any(s in slots for s in ['tunic','pants','robe']) and o.name.startswith('Cloth_briefs'))]+[assets[s] for s in slots]
 bpy.ops.object.select_all(action='DESELECT')
 for o in chosen:o.select_set(True)
 bpy.context.view_layer.objects.active=rig
 for tr in rig.animation_data.nla_tracks:tr.mute=False
 path=OUT/('equipment-'+variant+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_morph=False,export_yup=True,export_tangents=True,export_anim_slide_to_zero=True)
 for tr in rig.animation_data.nla_tracks:tr.mute=True
 if slots:bpy.data.objects.remove(b,do_unlink=True)
 EVIDENCE.setdefault('outputs',{})[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
# Runtime pieces share one live skeleton. Body-only masks carry no textures or
# animations; switching equipment does not replace the actor or restart its gait.
runtime=OUT/'runtime';runtime.mkdir(exist_ok=True)
rig.location=base_location
for p in rig.pose.bones:p.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
def export_part(path,ob,materials='EXPORT'):
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_morph=False,export_yup=True,export_tangents=True,export_texcoords=True,export_materials=materials)
 EVIDENCE.setdefault('runtime_outputs',{})[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
for slot,ob in assets.items():export_part(runtime/('part-'+slot+'.glb'),ob)
slot_order=list(ITEMS)
for bits in range(32):
 b=masked([s for i,s in enumerate(slot_order) if bits&(1<<i)])
 export_part(runtime/('body-mask-%02d.glb'%bits),b,'NONE');bpy.data.objects.remove(b,do_unlink=True)
EVIDENCE['runtime_slot_bits']={s:1<<i for i,s in enumerate(slot_order)}
EVIDENCE['recipe_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest();EVIDENCE['parser_sha256']=hashlib.sha256((ROOT/'scripts/mhclo_inspect.py').read_bytes()).hexdigest()
(OUT/'provenance.json').write_text(json.dumps(EVIDENCE,indent=2));print('FREE EQUIPMENT',json.dumps(EVIDENCE['assets']))
