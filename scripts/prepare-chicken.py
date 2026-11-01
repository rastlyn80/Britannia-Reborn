"""Pinned independent hen inputs and evidence-gated native/public installation."""
import argparse,hashlib,json,re,shutil,subprocess,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];LOCAL=ROOT/'Viewer/local-art/chicken';OUT=ROOT/'outputs/creatures/chicken-trial';PUBLIC=ROOT/'Viewer/Art/Creatures/Chicken';WORK=ROOT/'work/creatures/chicken';PINS=ROOT/'scripts/chicken-inputs.json'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
def resource(p):
 assert p.startswith('res://');result=(ROOT/'Viewer'/p[6:]).resolve();assert result.is_relative_to(ROOT/'Viewer');return result
def inputs(verify=False):
 pins=read(PINS);archive=WORK/'source/chicken_0.zip'
 if not archive.exists():
  assert not verify,'Pinned independent hen archive missing';archive.parent.mkdir(parents=True,exist_ok=True)
  with urllib.request.urlopen(pins['download'],timeout=60) as response:raw=response.read(pins['bytes']+1)
  assert len(raw)==pins['bytes'] and hashlib.sha256(raw).hexdigest()==pins['sha256'];archive.write_bytes(raw)
 assert archive.stat().st_size==pins['bytes'] and sha(archive)==pins['sha256']
 destination=(WORK/'source/extracted').resolve()
 with zipfile.ZipFile(archive) as z:
  for member in pins['members']:
   path=(destination/member['path']).resolve();assert path.is_relative_to(destination);raw=z.read(member['path']);assert len(raw)==member['bytes'] and hashlib.sha256(raw).hexdigest()==member['sha256']
   if not path.exists():assert not verify,'Pinned extracted input missing';path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
   assert sha(path)==member['sha256']
 return pins
def configure(path):
 if not path.exists():return
 text=path.read_text();text=re.sub(r'^animation/fps=\d+','animation/fps=240',text,flags=re.M);text=text.replace('meshes/force_disable_compression=false','meshes/force_disable_compression=true');options='_subresources={\n"nodes": {\n"PATH:AnimationPlayer": {\n"compression/enabled": false,\n"optimizer/enabled": false\n}\n}\n}'
 if '_subresources={}' in text:text=text.replace('_subresources={}',options)
 else:assert '"compression/enabled": false' in text and '"optimizer/enabled": false' in text
 if path.read_text()!=text:path.write_text(text)
def motion():
 inputs(True);prep=read(LOCAL/'preparation.json');meta=read(LOCAL/'chicken-modern.actions.json');proof=read(OUT/'motion.json');gait=read(OUT/'source-gait.json')
 assert prep['source_pin_sha256']==sha(PINS) and prep['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-chicken.py') and prep['bbone_recipe_sha256']==sha(ROOT/'scripts/chicken-bbone.py')
 assert meta['recipe_sha256']==sha(ROOT/'scripts/creature-chicken-actions.py') and meta['source_preparation_sha256']==sha(LOCAL/'preparation.json') and meta['gait_sha256']==sha(OUT/'source-gait.json')
 assert gait['test_sha256']==sha(ROOT/'Viewer/Presentation/ChickenSourceGait.gd') and gait['asset_sha256']==sha(LOCAL/'chicken-source.glb') and gait['import_sha256']==sha(LOCAL/'chicken-source.glb.import')
 assert proof['failures']==0 and proof['checks']>=1685 and proof['source_samples']==187 and proof['complete_skins']==627 and proof['airborne_run_cases']>=8 and proof['max_source_relative_skin_error_m']<.00005
 assert proof['test_sha256']==sha(ROOT/'Viewer/Presentation/ChickenMotionTests.gd') and proof['metadata_sha256']==sha(LOCAL/'chicken-modern.actions.json')
 for label,key in [('source','source_asset_sha256'),('modern','asset_sha256')]:assert proof[key]==sha(LOCAL/('chicken-'+label+'.glb'))
 assert proof['source_import_sha256']==sha(LOCAL/'chicken-source.glb.import') and proof['import_sha256']==sha(LOCAL/'chicken-modern.glb.import') and meta['asset_sha256']==proof['asset_sha256'] and meta['source_asset_sha256']==proof['source_asset_sha256']
 return prep,meta,proof
def candidate():
 prep,meta,_=motion();pin=read(ROOT/'Server/dependencies.json')['modernuo']['revision'];assert subprocess.check_output(['git','-C',str(ROOT/'Server/ModernUO'),'rev-parse','HEAD'],text=True).strip()==pin
 native='Projects/UOContent/Mobiles/Animals/Birds/Chicken.cs';path=ROOT/'Server/ModernUO'/native;match=re.search(r'\bBody\s*=\s*(0x[0-9a-fA-F]+|\d+)\s*;',path.read_text(encoding='utf-8-sig'));assert match and int(match[1],0)==208
 clips=meta['clips'];stats={'bones':47,'height_m':.45,'clips':clips};record={'kind':'chicken','family':'chickens','profile':'animal','status':'candidate','movement_mode':'ground_plane','head_bone':'Head','assets':{'modern':'res://local-art/chicken/chicken-modern.glb'},'bodies':[{'body':208,'name':'Chicken','scale':[1,1,1],'native_profile':'animal','native_sources':[{'path':native,'sha256':sha(path)}]}],'source':read(PINS)['source'],'license':'CC0-1.0 original CDmir hen mesh/rig/maps/eleven motions; GPL-3.0-or-later project conversion, seven segment joints, authored categories/root motion and shaders','source_interpretation':'Independent natural hen substitute; no recovered UO body208 geometry/choreography. All eleven source motions retained; active Run/Attack/Hit and timing changes explicitly authored.','partial_hue_interpretation':'Authored textured-body region; comb differs under full/partial dyes and dark source eyes remain protected. Not a recovered native partial mask.','stats':{'original':stats,'modern':stats},'authored_replacements':{k:v['origin'] for k,v in clips.items()},'loop_categories':[k for k,v in clips.items() if v['loop']],'locomotion':meta['locomotion'],'camera_height':.32,'pick_bounds':{'position':[-.5,-.02,-.6],'size':[1,.8,1.2]},'new_action_categories':{'2':'Hit','5':'Fidget','14':'Eat'},'recipe_sha256':prep['recipe_sha256'],'action_recipe_sha256':meta['recipe_sha256'],'source_pin_sha256':sha(PINS)}
 write(LOCAL/'candidate.json',record);print('CHICKEN CANDIDATE: source/skin/categories proved; actual presentation/native pending')
def verified(public=False):
 prep,meta,_=motion();record=next(r for r in read(PUBLIC.parent/'index.json')['entries'] if r['kind']=='chicken') if public else read(LOCAL/'candidate.json');proof=read(OUT/'presentation.json');source=read(OUT/'source.json')
 assert source['failures']==0 and len(source['samples'])==187 and source['max_surface_difference_m']<.001 and source['max_relative_skin_difference_m']<.001
 assert source['asset_sha256']==sha(LOCAL/'chicken-modern.glb') and source['reference_recipe_sha256']==sha(ROOT/'scripts/blender-reference-chicken.py') and source['test_sha256']==sha(ROOT/'Viewer/Presentation/ChickenSourceTests.gd') and source['comparison_recipe_sha256']==sha(ROOT/'scripts/check-chicken-source.py')
 assert proof['failures']==0 and proof['renderer']=='forward_plus' and len(proof['terrain'])==192 and proof['checks']>1000 and proof['airborne_cases']>0
 asset=resource(record['assets']['modern']);assert proof['candidate_sha256']==sha(PUBLIC.parent/'index.json' if public else LOCAL/'candidate.json') and proof['asset_sha256']==sha(asset)==sha(LOCAL/'chicken-modern.glb') and proof['import_sha256']==sha(Path(str(asset)+'.import'))
 for path,digest in proof['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale Chicken runtime: '+path
 return record,proof
def stage():
 record,_=verified();record.update(status='validated',native_validation='Pending actual native Chicken constructor/movement/death on both disposable owners')
 p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p);assert all(r['kind']=='chicken' or all(int(b['body'])!=208 for b in r['bodies']) for r in data['entries']+read(PUBLIC.parent/'index.json')['entries']);data['entries']=[r for r in data['entries'] if r['kind']!='chicken']+[record];write(p,data);print('CHICKEN STAGED: actual native proof pending')
def live():
 proof=read(ROOT/'outputs/creatures/chickens/live.json');assert proof['failures']==0 and proof['checks']>=80 and {(r['body'],r['native_class'],r['female']) for r in proof['records']}=={(208,'Chicken',sex) for sex in [False,True]}
 assert all(not r['native_death_refused'] and not r['corpse_suppressed'] for r in proof['records']);return proof
def install():
 record,proof=verified();native=live();assert (ROOT/'outputs/creatures/chickens/live.json').stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
 PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(LOCAL/'chicken-modern.glb',PUBLIC/'chicken.glb');record.update(status='validated',assets={'modern':'res://Art/Creatures/Chicken/chicken.glb'},native_validation='Actual native Chicken208 constructor on both owners; repeat installed public route')
 p=PUBLIC.parent/'index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='chicken']+[record];write(p,data);p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='chicken'];write(p,data)
 write(PUBLIC/'provenance.json',{'source':read(PINS),'preparation':read(LOCAL/'preparation.json'),'actions':read(LOCAL/'chicken-modern.actions.json'),'asset_sha256':sha(PUBLIC/'chicken.glb'),'candidate_runtime_sha256':proof['runtime_sha256'],'native_checks':native['checks'],'independence':'No Ultima Online mesh, texture, skeleton, animation or palette. Body208/native behaviour stays authoritative on ModernUO.'})
 shutil.copyfile(WORK/'source/extracted/license.txt',PUBLIC/'SOURCE-LICENSE.txt')
 (PUBLIC/'NOTICE.txt').write_text('Original hen mesh, rig, two maps and eleven source motions: CDmir / Cestmir Dammer, CC0-1.0. Created for Kelgar; UV texture derived from Rick Hoppmann photos, per the included original CC0 notice.\nhttps://lpc.opengameart.org/content/chicken-animated\nhttps://lpc.opengameart.org/sites/default/files/chicken_0.zip\nExact original notice and archive/member pins: provenance.json and scripts/chicken-inputs.json.\nProject B-Bone conversion, authored Run/Attack/Hit/category timings, common-root motion, shaders and code: GPL-3.0-or-later. No Ultima Online artwork included.\n',encoding='utf-8');print('CHICKEN PUBLIC INSTALLED: repeat public GPU/native/clean distribution before publication')
def verify_public():
 verified(True);live();assert (ROOT/'outputs/creatures/chickens/live.json').stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
 pins=read(PINS);notice=next(m for m in pins['members'] if m['path']=='license.txt');assert sha(PUBLIC/'SOURCE-LICENSE.txt')==notice['sha256'] and read(PUBLIC/'provenance.json')['source']==pins
 proof=read(OUT/'distribution.json');assert proof['failures']==0 and proof['checks']>500 and proof['complete_skins']==171
 assert proof['asset_sha256']==sha(PUBLIC/'chicken.glb')==read(PUBLIC/'provenance.json')['asset_sha256'] and proof['index_sha256']==sha(PUBLIC.parent/'index.json') and proof['runner_sha256']==sha(ROOT/'scripts/test-chicken-distribution.py')
 for path,digest in proof['runtime_sha256'].items():assert sha(ROOT/'Viewer'/path)==digest,'Stale clean Chicken runtime: '+path
 print('CHICKEN PUBLIC VERIFIED: exact source/skin/gait/avatar/native constructor and clean distribution')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['inputs','verify-inputs','configure-imports','candidate','stage','install','verify-public']:p.add_argument('--'+name,action='store_true')
 a=p.parse_args()
 if a.inputs or a.verify_inputs:inputs(a.verify_inputs)
 if a.configure_imports:
  for path in [LOCAL/'chicken-source.glb.import',LOCAL/'chicken-modern.glb.import',PUBLIC/'chicken.glb.import']:configure(path)
 if a.candidate:candidate()
 if a.stage:stage()
 if a.install:install()
 if a.verify_public:verify_public()
