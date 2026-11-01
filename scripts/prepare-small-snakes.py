"""Author-reuse the retained giant-serpent source for native small snakes."""
import base64,copy,hashlib,json,math,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'Viewer/local-art/creatures';SCALE=.18;KIND='small_snakes';FAMILY='small_snakes'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2)+'\n')
def main():
 pin=json.loads((ROOT/'Server/dependencies.json').read_text())['modernuo']['revision'];assert subprocess.check_output(['git','-C',str(ROOT/'Server/ModernUO'),'rev-parse','HEAD'],text=True).strip()==pin
 source=next(r for r in json.loads((ART/'accepted-index.json').read_text())['entries'] if r['kind']=='serpents_snake_giant');row=copy.deepcopy(source)
 for key in ['validation_sha256','gpu_sha256','gpu_runtime_sha256','asset_sha256','import_sha256']:row.pop(key,None)
 row.update(kind=KIND,family=FAMILY,status='prepared',profile='animal',camera_height=.081,bounds_mode='weighted_skin')
 native=[]
 for name in ['IceSnake','Snake','LavaSnake']:
  path='Projects/UOContent/Mobiles/Animals/Reptiles/'+name+'.cs';p=ROOT/'Server/ModernUO'/path;assert 'Body = 52;' in p.read_text(encoding='utf-8-sig');native.append({'path':path,'sha256':sha(p)})
 row['bodies']=[{'body':52,'scale':[1,1,1],'native_profile':'animal','native_sources':native,'source_assignment':'Authored18% source reuse; not a recovered body52 model-table row'}]
 row['authored_source_reuse']['native_body_interpretation']='Authored reuse of giant-serpent mesh/rig/UV/maps/source motions for native52 Snake/IceSnake/LavaSnake; no original intended small-snake assignment claimed.'
 row['motion_bound_diagonal_m']*=SCALE
 row['locomotion']={'walk_reference_mps':1.8*math.sqrt(SCALE),'run_reference_mps':5.5*math.sqrt(SCALE),'run_threshold_mps':3.6,'rate_min':.25,'rate_max':3.2}
 row['locomotion_interpretation']='Authored square-root size-based cadence scaling; Run reuses the active Walk with60% duration, original coiled SourceRun retained separately. Not recovered UO speed or a no-slip guarantee.'
 for stats in row['stats'].values():
  for key in ['height_m','bind_diagonal_m','scale']:
   if key in stats:stats[key]*=SCALE
  for clip in stats['clips'].values():
   for key in ['measured_max_pose_diagonal_m']:
    if key in clip:clip[key]*=SCALE
   if 'floor_offset_range' in clip:clip['floor_offset_range']=[v*SCALE for v in clip['floor_offset_range']]
  stats['clips']['SourceRun']=copy.deepcopy(stats['clips']['Run']);stats['clips']['Run']=copy.deepcopy(stats['clips']['Walk'])
  for clip in stats['clips'].values():clip['floor_sample_rate']=240
 row['clip_sources']['SourceRun']=row['clip_sources']['Run'];row['clip_sources']['Run']=row['clip_sources']['Walk']
 row['authored_replacements']['Run']='Authored60%-duration reuse of measured active Walk; original Run retained as SourceRun. No new recovered choreography claimed.'
 row['pick_bounds']={'position':[-.7,-.03,-.8],'size':[1.2,.5,1.4]};row['pick_bounds_scope']='Initial envelope only; actual runtime uses weighted-skin boxes at each animation pose.'
 row['scale_recipe']={'path':'scripts/prepare-small-snakes.py','sha256':sha(Path(__file__)),'uniform_scale':SCALE,'source_assets':{}}
 for treatment in ['original','rounded','modern']:
  p=ART/('serpents_snake_giant-'+treatment+'.gltf');raw=json.loads(p.read_text());original=copy.deepcopy(raw);roots=raw['scenes'][raw.get('scene',0)]['nodes'];index=len(raw['nodes']);raw['nodes'].append({'name':'AuthoredSmallSnakeScale','scale':[SCALE]*3,'children':roots});raw['scenes'][raw.get('scene',0)]['nodes']=[index]
  assert raw['meshes']==original['meshes'] and raw.get('animations')==original.get('animations') and raw['skins']==original['skins'] and raw['buffers']==original['buffers'] and raw['accessors']==original['accessors']
  run=next(a for a in raw['animations'] if a['name']=='Run');run['name']='SourceRun';fast=copy.deepcopy(next(a for a in raw['animations'] if a['name']=='Walk'));fast['name']='Run';changed={}
  for sampler in fast['samplers']:
   source_id=sampler['input']
   if source_id not in changed:
    accessor=raw['accessors'][source_id];assert accessor['componentType']==5126 and accessor['type']=='SCALAR';view=raw['bufferViews'][accessor['bufferView']];buffer=raw['buffers'][view['buffer']];assert buffer['uri'].startswith('data:');data=base64.b64decode(buffer['uri'].split(',',1)[1]);offset=view.get('byteOffset',0)+accessor.get('byteOffset',0);stride=view.get('byteStride',4);times=[struct.unpack_from('<f',data,offset+i*stride)[0]*.6 for i in range(accessor['count'])];payload=struct.pack('<'+'f'*len(times),*times);buffer_id=len(raw['buffers']);raw['buffers'].append({'byteLength':len(payload),'uri':'data:application/octet-stream;base64,'+base64.b64encode(payload).decode()});view_id=len(raw['bufferViews']);raw['bufferViews'].append({'buffer':buffer_id,'byteOffset':0,'byteLength':len(payload)});changed[source_id]=len(raw['accessors']);raw['accessors'].append({'bufferView':view_id,'componentType':5126,'count':len(times),'type':'SCALAR','min':[min(times)],'max':[max(times)]})
   sampler['input']=changed[source_id]
  raw['animations'].append(fast)
  assert raw['meshes']==original['meshes'] and raw['skins']==original['skins'] and raw['buffers'][:len(original['buffers'])]==original['buffers']
  write(ART/(KIND+'-'+treatment+'.gltf'),raw);row['scale_recipe']['source_assets'][treatment]=sha(p)
 archive=json.loads((ART/'serpents/preparation.json').read_text())['archive_sha256'];write(ART/FAMILY/'preparation.json',{'family':FAMILY,'models':[row],'archive_sha256':archive,'recipe_sha256':sha(Path(__file__)),'scope':'Private authored scale reuse of recovered source; no native or redistribution acceptance.'})
 print('SMALL SNAKES PREPARED: three unchanged source payloads with18% common ancestors; native52 acceptance pending')
if __name__=='__main__':main()
