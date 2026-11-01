"""Prepare the retained Third Dawn IceSerpent89 in a separate local family.

No game-derived art is distributed and no accepted route is installed here.
The original source attack remains available beside an authored jaw limit.
"""
import argparse,base64,copy,hashlib,importlib.util,json,math,shutil,struct,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work/creatures/ice-serpent'
ART=ROOT/'Viewer/local-art/creatures'
KIND='serpents_snake_giant_ice'
FAMILY='ice_serpents'
ATLAS_SHA='6ca71957364122b3926cfd01e2d45d1846360f811da9d2c87bdfd9fde46d810a'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def jaw_limit(doc,degrees):
 """Limit only the source lower-jaw angular excursion; retain SourceAttack."""
 source=copy.deepcopy(next(a for a in doc['animations'] if a['name']=='Attack'))
 source['name']='SourceAttack';doc['animations'].append(source)
 if degrees is None:return {'policy':'Retained source Attack, also saved as SourceAttack'}
 jaw=next(i for i,n in enumerate(doc['nodes']) if n.get('name')=='bip01 ponytail1')
 def output(animation):
  channel=next(c for c in animation['channels'] if c['target']=={'node':jaw,'path':'rotation'});return animation['samplers'][channel['sampler']]
 def values(index):
  a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];raw=base64.b64decode(doc['buffers'][v['buffer']]['uri'].split(',',1)[1]);offset=v.get('byteOffset',0)+a.get('byteOffset',0)
  assert a['componentType']==5126 and a['type']=='VEC4'
  return [struct.unpack_from('<4f',raw,offset+i*v.get('byteStride',16)) for i in range(a['count'])]
 def unit(q):
  length=math.sqrt(sum(v*v for v in q));assert length>.99;return [v/length for v in q]
 idle=next(a for a in doc['animations'] if a['name']=='Idle');reference=unit(values(output(idle)['output'])[0]);attack=next(a for a in doc['animations'] if a['name']=='Attack');sampler=output(attack);rows=[];maximum=0.
 for q in values(sampler['output']):
  q=unit(q);dot=sum(x*y for x,y in zip(reference,q))
  if dot<0:q=[-v for v in q];dot=-dot
  theta=math.acos(min(1.,dot));maximum=max(maximum,math.degrees(theta*2));fraction=min(1.,math.radians(degrees)/max(1e-12,theta*2))
  rows.append(q if theta<1e-6 else unit([(math.sin((1-fraction)*theta)*a+math.sin(fraction*theta)*b)/math.sin(theta) for a,b in zip(reference,q)]))
 payload=struct.pack('<'+'f'*(len(rows)*4),*(v for r in rows for v in r));bi=len(doc['buffers']);doc['buffers'].append({'byteLength':len(payload),'uri':'data:application/octet-stream;base64,'+base64.b64encode(payload).decode()});vi=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':bi,'byteLength':len(payload)});ai=len(doc['accessors']);doc['accessors'].append({'bufferView':vi,'componentType':5126,'count':len(rows),'type':'VEC4'});sampler['output']=ai
 return {'bone':'bip01 ponytail1','maximum_source_excursion_degrees':maximum,'maximum_authored_excursion_degrees':degrees,'policy':'Authored shorter gape relative to source Idle; original SourceAttack and all other joint channels retained. No recovered original choreography claimed.'}

def prepare():
 pipeline=module('ice_serpent_pipeline',ROOT/'scripts/prepare-creatures.py');staging=WORK/'prepared';staging.mkdir(parents=True,exist_ok=True);pipeline.OUTPUT=staging
 pipeline.reuse.RECIPES[KIND]={'clip_stem':'serpents_snake_giant_silver','motion_contract_stem':'serpents_snake_giant_silver','unbound_label_aliases':[[KIND,'serpents_snake_giant_silver']],'serpentine_feeding':True,'floor_sample_rate':240,'measure_motion_bounds':True}
 atlas=WORK/'ice-serpent-albedo-v2.png';assert sha(atlas)==ATLAS_SHA,'Requires the exact separately generated private atlas'
 shutil.copyfile(atlas,staging/(KIND+'-albedo-v1.png'))
 prompts='\n\n'.join((WORK/n).read_text(encoding='utf-8') for n in ['texture-v1-prompt.txt','texture-v2-prompt.txt']);(staging/(KIND+'-albedo-v1.prompt.txt')).write_text(prompts,encoding='utf-8')
 archive=ROOT/'work/third-dawn/uotdb.zip';assert sha(archive)==pipeline.helper.audit.ARCHIVE_HASH
 _,native=pipeline.native_bodies()
 with zipfile.ZipFile(archive) as z:
  names={n.lower():n for n in z.namelist()};table=pipeline.table_rows(z.read(names['uotdb/uotd/models/models.txt']));rows=pipeline.prepare('serpents',z,names,table,native,selected_kinds={KIND})
 assert len(rows)==1 and rows[0]['status']=='prepared';row=rows[0];assert [b['body'] for b in row['bodies']]==[89] and row['profile']=='monster'
 report=json.loads((staging/'serpents/preparation.json').read_text());original_alpha=staging/(KIND+'-original-albedo.png');ART.mkdir(parents=True,exist_ok=True)
 for treatment in ['original','rounded','modern']:
  source=staging/(KIND+'-'+treatment+'.gltf');doc=json.loads(source.read_text());before=copy.deepcopy(doc);authored=jaw_limit(doc,32. if treatment=='modern' else None)
  for material in doc['materials']:material.update(alphaMode='MASK',alphaCutoff=.12)
  assert doc['meshes']==before['meshes'] and doc['skins']==before['skins'] and doc['nodes']==before['nodes']
  (ART/source.name).write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
  if treatment=='modern':row['authored_jaw_limit']=authored
 for path in [original_alpha,staging/(KIND+'-albedo-v1.png'),staging/(KIND+'-albedo-v1.prompt.txt')]:shutil.copyfile(path,ART/path.name)
 for stats in row['stats'].values():stats['clips']['SourceAttack']=copy.deepcopy(stats['clips']['Attack'])
 row.update(family=FAMILY,movement_mode='ground_plane',bounds_mode='weighted_skin',camera_height=.48,source_alpha_texture=original_alpha.name,source_alpha_scope='fine_edges',art_dependency_sha256={original_alpha.name:sha(original_alpha)},loop_categories=['Idle','Walk','Run','Fidget'],new_action_categories={'2':'Hit','5':'Fidget','14':'Eat'},locomotion={'walk_reference_mps':1.8,'run_reference_mps':5.5,'run_threshold_mps':3.6,'rate_min':.25,'rate_max':3.2},pick_bounds={'position':[-4.,-.05,-5.],'size':[8.,2.,10.]})
 row['appearance_pose_fit']=True
 row['motion_bound_diagonal_m']=max(c['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for c in stats['clips'].values())*1.1
 row['authored_replacements'].update(Attack=row['authored_jaw_limit']['policy']);row['clip_sources']['SourceAttack']=row['clip_sources']['Attack'];row['modern_atlas']=str((ART/(KIND+'-albedo-v1.png')).relative_to(ROOT));row['surface']='Generated private ice atlas, original source cutout alpha, authored head sampling registration/PBR; not original mask semantics'
 row['eye_registration']=[.762374,.001209,-.041576,-.034753];row['eye_registration_scope']='Explicit material sampling warp from source/generated eye landmarks; original mesh UVs retained, not a claim of exact generated raster UV alignment.'
 row['preparation_recipe']={'path':'scripts/prepare-ice-serpent.py','sha256':sha(Path(__file__)),'atlas_sha256':ATLAS_SHA};row['ground_lookup']='res://local-art/creatures/'+KIND+'-ground.json';row['ground_lookup_status']='Pending actual saved-scene full-skin bake; do not accept route yet'
 report.update(family=FAMILY,models=[row],recipe_sha256=sha(Path(__file__)),source_pipeline_sha256=sha(ROOT/'scripts/prepare-creatures.py'))
 write(ART/FAMILY/'preparation.json',report);print('ICE SERPENT PREPARED: original89/18joints/ownUV+alpha, retained SourceAttack and authored32degree gape; ground lookup/GPU/native/corpse acceptance pending')

def finalize():
 path=ART/FAMILY/'preparation.json';report=json.loads(path.read_text());row=report['models'][0];ground=ART/(KIND+'-ground.json');bake=json.loads(ground.read_text())
 assert bake['sample_rate']==960 and bake['recipe_sha256']==sha(ROOT/'Viewer/Presentation/BakeIceSerpentGround.gd') and bake['geometry_sha256']==sha(ROOT/'Viewer/Presentation/SkinGeometry.gd')
 for treatment in ['original','rounded','modern']:
  proof=bake['treatments'][treatment];asset=ART/(KIND+'-'+treatment+'.gltf');assert proof['asset_sha256']==sha(asset) and proof['import_sha256']==sha(Path(str(asset)+'.import'))
  assert set(proof['clips'])=={'Idle','Walk','Run','Attack','SourceAttack','Hit','Death','Fidget','Eat'}
  for samples in proof['clips'].values():assert len(samples)>100 and all(len(v)==2 and all(math.isfinite(x) for x in v) for v in samples) and all(b[0]>a[0] for a,b in zip(samples,samples[1:]))
 row.update(source_alpha_scope='fine_edges',appearance_pose_fit=True,ground_lookup_sha256=sha(ground),ground_lookup_status='Measured imported full-skin shared vertical corrections at960Hz; off-grid/avatar/terrain/native evidence still required')
 row['art_dependency_sha256'][ground.name]=sha(ground);row['preparation_recipe']['sha256']=sha(Path(__file__));report['recipe_sha256']=sha(Path(__file__));write(path,report);print('ICE GROUND INPUTS FINALIZED: exact three saved imports/curves; no accepted route')

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--prepare',action='store_true');parser.add_argument('--finalize',action='store_true');args=parser.parse_args()
 if args.prepare:prepare()
 if args.finalize:finalize()
