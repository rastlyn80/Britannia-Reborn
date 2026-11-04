"""Independent flame/ash actor, gated by saved skins, actual avatar and native state."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
from elemental_classic_metadata import preserve_gestures
ROOT=Path(__file__).resolve().parents[1];LOCAL=ROOT/'Viewer/local-art/fire';OUT=ROOT/'outputs/creatures/fire-trial';PUBLIC=ROOT/'Viewer/Art/Creatures/Fire'
CARRIER_SHA='6b0856ae574b5571cbd79cb2682a0904ce1cb59a54da24f51b9e4d29b7e49bd8'
NATIVE=['Projects/UOContent/Mobiles/Monsters/Elemental/Magic/FireElemental.cs','Projects/UOContent/Mobiles/Monsters/Summons/SummonedFireElemental.cs'];CLASSES=['FireElemental','SummonedFireElemental']
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True);pending=p.with_suffix(p.suffix+'.pending');pending.write_text(json.dumps(v,indent=2)+'\n');pending.replace(p)
def resource(p):
 assert p.startswith('res://');path=(ROOT/'Viewer'/p[6:]).resolve();assert path.is_relative_to(ROOT/'Viewer');return path
def motion():
 prep=read(LOCAL/'preparation.json');proof=read(OUT/'motion.json')
 assert prep['carrier_sha256']==sha(ROOT/'Viewer/Art/Creatures/Water/water-elemental.scn')==CARRIER_SHA
 assert prep['bones']==65 and prep['vertices']==1836 and prep['triangles']==1632 and len(prep['clips'])==15
 assert proof['failures']==0 and proof['checks']>=14623 and len(proof['samples'])==255 and proof['source_position_error']<.00001
 for key,name in [('recipe_sha256','PrepareFireElemental.gd'),('geometry_sha256','FireFlameGeometry.gd'),('shader_sha256','FireElementalSurface.gdshader')]:assert prep[key]==sha(ROOT/'Viewer/Presentation'/name),'Changed flame input:'+name
 assert proof['test_sha256']==sha(ROOT/'Viewer/Presentation/FireElementalMotionTests.gd') and proof['preparation_sha256']==sha(LOCAL/'preparation.json')
 assert proof['asset_sha256']==prep['asset_sha256']==sha(LOCAL/'fire-modern.scn')
 return prep,proof
def candidate():
 prep,proof=motion();pin=read(ROOT/'Server/dependencies.json')['modernuo']['revision'];assert subprocess.check_output(['git','-C',str(ROOT/'Server/ModernUO'),'rev-parse','HEAD'],text=True).strip()==pin
 sources=[]
 for name in NATIVE:
  p=ROOT/'Server/ModernUO'/name;match=re.search(r'\bBody\s*=\s*(\d+)\s*;',p.read_text(encoding='utf-8-sig'));assert match and int(match[1])==15;sources.append({'path':name,'sha256':sha(p)})
 lo=[min(s['bounds_position'][i] for s in proof['samples'])-.08 for i in range(3)];hi=[max(s['bounds_position'][i]+s['bounds_size'][i] for s in proof['samples'])+.08 for i in range(3)];stats={'bones':65,'height_m':2.2,'clips':prep['clips']}
 record={'kind':'fire_elemental','family':'fire','status':'candidate','profile':'monster','movement_mode':'source_hover','surface_kind':'flame_pbr','assets':{'modern':'res://local-art/fire/fire-modern.scn'},'bodies':[{'body':15,'name':'FireElemental / SummonedFireElemental','scale':[1,1,1],'native_profile':'monster','native_sources':sources}],
  'source':'https://github.com/rastlyn80/Britannia-Reborn','license':'Original GPL-3.0-or-later flame ribbons/procedural shader/ash and conversion; retained Quaternius CC0 rig/UAL1 motions from pinned independent Water carrier.',
  'source_interpretation':'Independent authored flame actor; no recovered Third Dawn Fire actor/particle binding or original UO choreography. Original stats describe retained independent donor rig plus new geometry, not game art.',
  'partial_hue_interpretation':'Authored smooth hot-core and inner-ash colour regions; no recovered original UO partial mask.',
  'stats':{'original':stats,'modern':stats},'authored_replacements':{k:v['origin'] for k,v in prep['clips'].items()},'loop_categories':[k for k,v in prep['clips'].items() if v['loop']],'camera_height':1.7,'pick_bounds':{'position':lo,'size':[hi[i]-lo[i] for i in range(3)]},'new_action_categories':{'2':'Hit','5':'Fidget','14':'Pillage'},'recipe_sha256':prep['recipe_sha256'],'asset_sha256':prep['asset_sha256']}
 write(LOCAL/'candidate.json',record);print('FIRE CANDIDATE: no route installed')
def gated(public=False):
 if public:
  provenance=read(PUBLIC/'provenance.json');prep=provenance['preparation'];assert provenance['carrier_sha256']==prep['carrier_sha256']==CARRIER_SHA
  record=next(r for r in read(PUBLIC.parent/'index.json')['entries'] if r['kind']=='fire_elemental')
  assert record['status']=='validated' and record['assets']['modern']=='res://Art/Creatures/Fire/fire-elemental.scn'
 else:
  prep,_=motion();record=read(LOCAL/'candidate.json')
 proof=read(OUT/'presentation.json')
 assert record['recipe_sha256']==prep['recipe_sha256'] and record['asset_sha256']==prep['asset_sha256']
 runtime_gestures=2 if record.get('classic_action_categories',{}).get('7')=='ElementalOverhead' else 0
 assert proof['failures']==0 and proof['checks']>=1416 and len(proof['complete_action_skins'])==17*(17+runtime_gestures) and len(proof['terrain'])==72 and proof['renderer']=='forward_plus'
 assert proof['candidate_sha256']==sha(PUBLIC.parent/'index.json' if public else LOCAL/'candidate.json') and proof['asset_sha256']==sha(resource(record['assets']['modern']))
 assert proof['shader_envelope_pixels']>1500 and proof['shader_envelope_outside_pixels']<5
 for path,digest in proof['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale runtime:'+path
 return record,proof
def stage():
 record,_=gated();record.update(status='validated',native_validation='Local candidate staging only; native constructor/summon proof pending')
 p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p);assert all(int(b['body'])!=15 for row in read(PUBLIC.parent/'index.json')['entries'] for b in row['bodies']);data['entries']=[r for r in data['entries'] if r['kind']!='fire_elemental']+[record];write(p,data);print('FIRE STAGED: real native tests pending')
def live():
 p=ROOT/'outputs/creatures/fire/live.json';proof=read(p);assert proof['failures']==0 and proof['checks']>=200
 assert {(r['body'],r['native_class'],r['female']) for r in proof['records']}=={(15,name,sex) for name in CLASSES for sex in [False,True]}
 for row in proof['records']:
  summoned=row['native_class']=='SummonedFireElemental';assert row['native_state']==('summoned' if summoned else 'constructor') and row['corpse_suppressed']==summoned and not row['native_death_refused'] and not row['native_water']
 assert p.stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
 return proof
def install():
 record,proof=gated();live();PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(resource(record['assets']['modern']),PUBLIC/'fire-elemental.scn');record.update(status='validated',assets={'modern':'res://Art/Creatures/Fire/fire-elemental.scn'},native_validation='Actual native FireElemental constructor and SummonedFireElemental via real Summon API on both owners; repeat on public route')
 p=PUBLIC.parent/'index.json';data=read(p);preserve_gestures(record,data['entries']);data['entries']=[r for r in data['entries'] if r['kind']!='fire_elemental']+[record];write(p,data);p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='fire_elemental'];write(p,data)
 write(PUBLIC/'provenance.json',{'license':record['license'],'carrier_sha256':CARRIER_SHA,'preparation':read(LOCAL/'preparation.json'),'asset_sha256':sha(PUBLIC/'fire-elemental.scn'),'candidate_runtime_sha256':proof['runtime_sha256'],'independent_carrier_sources':read(PUBLIC.parent/'Water/provenance.json')['sources'],'independence':'Own flame ribbons and shader replace the carrier body entirely; only the project-authored radial footprint, CC0 rig and selected UAL1 motion remain. No game mesh, atlas, rig, animation or recovered particle definition.'})
 (PUBLIC/'NOTICE.txt').write_text('FireElemental flame ribbons, shader, ash footprint, conversion and authored death: original Britannia Reborn project work, GPL-3.0-or-later; root LICENSE.\nRetained rig and selected UAL1 actions: Quaternius, CC0-1.0, through the pinned public Water carrier. No original human or Water body mesh is retained.\nhttps://quaternius.itch.io/universal-base-characters\nhttps://quaternius.itch.io/universal-animation-library\nExact input hashes/source history: provenance.json and Art/Creatures/Water/NOTICE.txt. No Ultima Online mesh, texture, rig, clip or particle definition is included.\n')
 print('FIRE PUBLIC INSTALLED: repeat actual public avatar/native and clean distribution before publication')
def verify_public():
 gated(True);live();assert sha(PUBLIC/'fire-elemental.scn')==read(PUBLIC/'provenance.json')['asset_sha256']
 distribution=read(OUT/'distribution.json');assert distribution['failures']==0 and distribution['checks']>=291 and distribution['component_skin_samples']==152 and distribution['transient_death_trials']==4
 assert distribution['asset_sha256']==sha(PUBLIC/'fire-elemental.scn') and distribution['index_sha256']==sha(PUBLIC.parent/'index.json') and distribution['runner_sha256']==sha(ROOT/'scripts/test-fire-distribution.py')
 for path,digest in distribution['runtime_sha256'].items():assert sha(ROOT/'Viewer'/path)==digest,'Stale clean-distribution runtime:'+path
 print('FIRE PUBLIC VERIFIED: current source/skins/avatar/native constructors, real summon and clean distribution with death cleanup')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['candidate','stage','install','verify-public']:p.add_argument('--'+name,action='store_true')
 a=p.parse_args()
 if a.candidate:candidate()
 if a.stage:stage()
 if a.install:install()
 if a.verify_public:verify_public()
