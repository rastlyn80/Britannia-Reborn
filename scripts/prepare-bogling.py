"""Pinned CC0 treant conversion and evidence-gated native Bogling installation."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];LOCAL=ROOT/'Viewer/local-art/bogling';OUT=ROOT/'outputs/creatures/bogling-trial';PUBLIC=ROOT/'Viewer/Art/Creatures/Bogling';PINS=ROOT/'scripts/bogling-inputs.json'
NATIVE='Projects/UOContent/Mobiles/Monsters/Plant/Melee/Bogling.cs'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):
 p.parent.mkdir(parents=True,exist_ok=True);pending=p.with_suffix(p.suffix+'.pending');pending.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8');pending.replace(p)
def resource(p):
 assert p.startswith('res://');path=(ROOT/'Viewer'/p[6:]).resolve();assert path.is_relative_to(ROOT/'Viewer');return path
def inputs():
 pins=read(PINS)
 for item in pins['inputs']:
  path=ROOT/item['path'];assert path.is_relative_to(ROOT/'work') and path.stat().st_size==item['bytes'] and sha(path)==item['sha256'],'Changed CC0 input: '+item['path']
 return pins
def preparation():
 pins=inputs();prep=read(LOCAL/'preparation.json')
 assert prep['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-bogling.py') and prep['kinematics_sha256']==sha(ROOT/'scripts/creature-humanoid-actions.py')
 assert prep['bones']==33 and prep['triangles']==7340 and prep['fps']==240 and len(prep['clips'])==15
 assert prep['max_source_bake_position_error_m']<.00001 and prep['max_all_bake_position_error_m']<.001
 assert all(row['fitted_max_error_m']<.000001 for row in prep['skin_fit'])
 assert all(sha(ROOT/path.replace('\\','/'))==digest for path,digest in prep['inputs'].items())
 assert sha(LOCAL/'bogling-candidate.glb')==prep['asset_sha256']
 return pins,prep
def candidate():
 pins,prep=preparation();pin=read(ROOT/'Server/dependencies.json')['modernuo']['revision']
 assert subprocess.check_output(['git','-C',str(ROOT/'Server/ModernUO'),'rev-parse','HEAD'],text=True).strip()==pin
 native=ROOT/'Server/ModernUO'/NATIVE;match=re.search(r'\bBody\s*=\s*(\d+)\s*;',native.read_text(encoding='utf-8-sig'));assert match and int(match[1])==779
 stats={'bones':33,'height_m':1.15,'clips':prep['clips']}
 record={'kind':'bogling','family':'boglings','status':'candidate','profile':'monster','contact_kind':'measured_limbs','limb_support':'tree_biped','surface_kind':'bark_pbr',
  'assets':{'modern':'res://local-art/bogling/bogling-candidate.glb'},'bodies':[{'body':779,'scale':[1,1,1],'name':'Bogling','native_profile':'monster','native_sources':[{'path':NATIVE,'sha256':sha(native)}]}],
  'stats':{'original':stats,'modern':stats},'source':pins['source'],'license':'CC0-1.0 Tennessippi Tree02 mesh/rig/albedo/normal/ten source actions; GPL-3.0-or-later project conversion, gaits, gestures and shaders',
  'source_interpretation':'Independent CC0 tree-creature substitute, not recovered UO art. Original means independent donor source, not Ultima Online. Every donor action retained; separate physical Walk/Run and authored Cast/Pillage/Hit.',
  'partial_hue_interpretation':'Authored brown-bark colour selection, protecting green ivy; not recovered original UO partial-hue regions.',
  'loop_categories':['Idle','Walk','Run','SourceRun'],'camera_height':.9,'pick_bounds':{'position':[-1,-.1,-1],'size':[2,2,2]},
  'locomotion':{'walk_reference_mps':1.8,'run_reference_mps':5.5,'run_threshold_mps':3.6,'rate_min':.25,'rate_max':2.},'new_action_categories':{'2':'Hit','5':'Fidget','14':'Pillage'},
  'recipe_sha256':prep['recipe_sha256'],'asset_sha256':prep['asset_sha256']}
 write(LOCAL/'candidate.json',record);OUT.mkdir(parents=True,exist_ok=True);print('BOGLING CANDIDATE: no accepted route installed')
def configure(path):
 assert path.is_relative_to(ROOT/'Viewer') and path.suffix=='.import'
 if not path.exists():return
 text=path.read_text();previous=text;text=re.sub(r'^animation/fps=\d+', 'animation/fps=240',text,flags=re.M);text=re.sub(r'^meshes/force_disable_compression=\w+', 'meshes/force_disable_compression=true',text,flags=re.M)
 options='_subresources={\n"nodes": {\n"PATH:AnimationPlayer": {\n"compression/enabled": false,\n"optimizer/enabled": false\n}\n}\n}'
 if '_subresources={}' in text:text=text.replace('_subresources={}',options)
 else:assert '"optimizer/enabled": false' in text and '"compression/enabled": false' in text,'Unexpected import options; preserve existing settings'
 if text!=previous:path.write_text(text)
def proofs(public=False):
 pins,prep=preparation();record=next(r for r in read(PUBLIC.parent/'index.json')['entries'] if r['kind']=='bogling') if public else read(LOCAL/'candidate.json')
 asset=resource(record['assets']['modern']);assert sha(asset)==prep['asset_sha256']
 for filename,test,minimum in [('motion.json','BoglingMotionTests.gd',38226),('source.json','BoglingSourceTests.gd',341),('validation.json','BoglingPresentationTests.gd',2295)]:
  proof=read(OUT/filename);assert proof['failures']==0 and proof['checks']>=minimum,filename
  assert proof['asset_sha256']==sha(asset) and proof['import_sha256']==sha(Path(str(asset)+'.import')),'Stale asset import: '+filename
  assert proof['test_sha256']==sha(ROOT/'Viewer/Presentation'/test),'Stale test: '+filename
  assert proof['preparation_sha256']==sha(LOCAL/'preparation.json') and proof['candidate_sha256']==sha(PUBLIC.parent/'index.json' if public else LOCAL/'candidate.json')
 source=read(OUT/'source.json');assert len(source['samples'])==170 and source['maximum_surface_error_m']<.0005
 assert source['reference_sha256']==sha(ROOT/'work/creatures/bogling/source-reference/reference.json')
 reference=read(ROOT/'work/creatures/bogling/source-reference/reference.json')
 assert reference['recipe_sha256']==sha(ROOT/'scripts/blender-reference-bogling.py')
 assert reference['binary_sha256']==sha(ROOT/'work/creatures/bogling/source-reference/skins.bin')
 assert reference['source_sha256']==next(row['sha256'] for row in pins['inputs'] if row['path'].lower().endswith('.fbx'))
 motion=read(OUT/'motion.json');assert {r['category'] for r in motion['gaits']}=={'Walk','Run'} and all(r['max_speed_error_mps']<.15 for r in motion['gaits'])
 gpu=read(OUT/'validation.json');assert gpu['renderer']=='forward_plus' and len(gpu['terrain'])==156 and len(gpu['action_skins'])==289
 assert gpu['normal_pixels']>100
 colours={r['hue']:r['changed_pixels'] for r in gpu['hues']};assert colours[53]>100 and colours[0x8035]>100 and abs(colours[53]-colours[0x8035])>100,'Full/partial bark hue regions must both be visibly distinct'
 if public:
  # Godot's extract-textures import exposes the embedded maps as image inputs.
  # Their bytes must remain the pinned originals, with no later import change.
  for item in pins['inputs']:
   if not item['path'].endswith('.png'):continue
   image=PUBLIC/('bogling_'+Path(item['path']).name);assert sha(image)==item['sha256'],'Changed extracted artist map'
   assert Path(str(image)+'.import').stat().st_mtime<=(OUT/'validation.json').stat().st_mtime,'Artist image import changed after the actual GPU proof'
 for path,digest in gpu['runtime_sha256'].items():assert sha(resource(path))==digest,'Changed runtime: '+path
 return record,gpu
def stage():
 record,_=proofs();record.update(status='validated',native_validation='Candidate local staging only; native constructor proof pending')
 p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p)
 assert all(int(b['body'])!=779 for row in read(PUBLIC.parent/'index.json')['entries'] for b in row['bodies'])
 data['entries']=[r for r in data['entries'] if r['kind']!='bogling']+[record];write(p,data);print('BOGLING STAGED: real native tests still required')
def live():
 p=ROOT/'outputs/creatures/boglings/live.json';proof=read(p);assert proof['failures']==0 and proof['checks']>=90
 assert {(r['body'],r['native_class'],r['female']) for r in proof['records']}=={(779,'Bogling',sex) for sex in [False,True]}
 assert p.stat().st_mtime>(OUT/'validation.json').stat().st_mtime
 return proof
def install():
 record,gpu=proofs();live();PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(resource(record['assets']['modern']),PUBLIC/'bogling.glb')
 record.update(status='validated',assets={'modern':'res://Art/Creatures/Bogling/bogling.glb'},native_validation='Real Bogling constructor on both owners; repeat native/avatar checks on installed public route')
 p=PUBLIC.parent/'index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='bogling']+[record];write(p,data)
 p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='bogling'];write(p,data)
 write(PUBLIC/'provenance.json',{'source':read(PINS),'preparation':read(LOCAL/'preparation.json'),'asset_sha256':sha(PUBLIC/'bogling.glb'),'candidate_runtime_sha256':gpu['runtime_sha256'],'independence':'No Ultima Online mesh, texture, skeleton or animation. Native identity/behaviour stays authoritative on ModernUO; this is independent substitute art.'})
 (PUBLIC/'NOTICE.txt').write_text('Bogling independent substitute: Tennessippi Studios Treant Pack, Tree02, CC0-1.0.\nhttps://tennessippistudios.itch.io/treant-pack\nSource mesh, rig, albedo, normal map and ten source motions are CC0.\nAuthored Britannia Reborn conversion, physical Walk/Run, Cast/Pillage/Hit and shaders: GPL-3.0-or-later; root LICENSE.\nNo Ultima Online mesh, texture, rig or animation is included.\nExact archive/input hashes, recipe and motion origins: provenance.json and scripts/bogling-inputs.json.\n')
 print('BOGLING PUBLIC INSTALLED: repeat installed avatar/native and clean distribution before publishing')
def verify_public():
 proofs(True);live();assert sha(PUBLIC/'bogling.glb')==read(PUBLIC/'provenance.json')['asset_sha256']
 distribution=read(OUT/'distribution.json');assert distribution['failures']==0 and distribution['checks']>=470 and distribution['complete_skins']==153 and distribution['asset_sha256']==sha(PUBLIC/'bogling.glb')
 assert distribution['index_sha256']==sha(PUBLIC.parent/'index.json') and distribution['runner_sha256']==sha(ROOT/'scripts/test-bogling-distribution.py')
 for path,digest in distribution['runtime_sha256'].items():assert sha(ROOT/'Viewer'/path)==digest,'Stale standalone runtime: '+path
 print('BOGLING PUBLIC VERIFIED: exact source/rig/skins/current runtime/native and clean-distribution evidence')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['verify-inputs','candidate','configure-imports','stage','install','verify-public']:p.add_argument('--'+name,action='store_true')
 a=p.parse_args()
 if a.verify_inputs:inputs()
 if a.candidate:candidate()
 if a.configure_imports:
  for path in [LOCAL/'bogling-candidate.glb.import',PUBLIC/'bogling.glb.import']:configure(path)
 if a.stage:stage()
 if a.install:install()
 if a.verify_public:verify_public()
