"""Pinned public inputs and receipt-gated installation for the authored water actor."""
import argparse, hashlib, json, runpy, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LOCAL=ROOT/'Viewer/local-art/water-elemental'
PUBLIC=ROOT/'Viewer/Art/Creatures/Water'
FIDGET_GROUPS = {
 17: ('WaterArmSettle', '6ba9c4d533e77ebadcfc83597fd5ae4d02f55a3a27ee21775cba284ff37d9cd5'),
 18: ('Fidget2', '76eb3c14da1eaa5cf545d1e17374262e12bab17d383362706e51a6befb21cc11'),
}
PINNED={
 'Viewer/Art/Quaternius/Character/Superhero_Male_FullBody.gltf':'96edb76572b387b38cdcbab746034d2534da74c1ba86bcef8d049fff1a40aec2',
 'Viewer/Art/Quaternius/Character/Superhero_Male_FullBody.bin':'459003f9745853ae562a85506a2b94dd56515c1f37728f9fa3d2ce1a3e4cd92f',
 'Viewer/Art/Quaternius/Animation/UAL1_Standard.glb':'69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997',
}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def inputs():
 for relative,digest in PINNED.items():assert sha(ROOT/relative)==digest,'Changed CC0 input: '+relative
 for name in ['universal-base-characters','universal-animation-library']:
  text=(ROOT/f'Viewer/Art/Quaternius/{name}-LICENSE.txt').read_text(encoding='utf-8')
  assert 'CC0' in text,'CC0 grant missing'
def candidate():
 inputs();report=read(LOCAL/'preparation.json')
 native='Projects/UOContent/Mobiles/Monsters/Elemental/Magic/WaterElemental.cs'
 clips=report['clips'];stats={'bones':report['bones'],'height_m':1.82,'clips':clips}
 record={'kind':'water_elemental','family':'water','status':'candidate','profile':'monster','movement_mode':'ground_plane','surface_kind':'water_pbr','head_bone':'Head',
 'assets':{'modern':'res://local-art/water-elemental/trial.scn'},'bodies':[{'body':16,'scale':[1,1,1],'name':'Water elemental','native_profile':'monster','native_sources':[{'path':native,'sha256':sha(ROOT/'Server/ModernUO'/native)}]}],
 'license':'GPL-3.0-or-later; underlying Quaternius base mesh, rig and UAL1 actions CC0-1.0',
 'source':'https://quaternius.itch.io/universal-base-characters',
 'source_interpretation':'Authored fluid-vortex replacement using the CC0 Quaternius male upper body/rig and retargeted CC0 UAL1 Standard actions. Not a recovered Third Dawn water elemental or original UO choreography.',
 'partial_hue_interpretation':'Authored moving foam zones; not a recovered original grey-pixel mask.',
 'classic_action_categories':{'7':'OverheadSurge','8':'WaterHold','17':'WaterArmSettle','18':'Fidget2'},
 'new_action_categories':{'2':'Hit','5':'Fidget','14':'Pillage'},'camera_height':1.7,
 'pick_bounds':report['envelope'],'stats':{'modern':stats,'original':stats},
 'authored_replacements':{clip:info['origin'] for clip,info in clips.items()},'category_aliases':{'Death2':'Death; same authored liquid collapse'}}
 write(LOCAL/'candidate.json',record)
 write(LOCAL/'inputs.json',{'inputs':PINNED,'recipe':sha(ROOT/'Viewer/Presentation/PrepareWaterElemental.gd'),'asset_sha256':sha(LOCAL/'trial.scn'),'preparation':report})
 print(f'WATER CANDIDATE: public pinned inputs, authored fluid seam and {len(clips)} mapped categories')
def stage():
 record=read(LOCAL/'candidate.json');report=read(ROOT/'outputs/creatures/water-trial/validation.json')
 assert report['failures']==0 and report['checks']>450
 assert report['asset_sha256']==sha(LOCAL/'trial.scn')
 assert report['candidate_sha256']==sha(LOCAL/'candidate.json')
 for relative,digest in report['runtime'].items():assert sha(ROOT/relative)==digest,relative+' changed after validation'
 record['status']='validated';record['native_validation']='pending isolated native fixture'
 index=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(index)
 data['entries']=[r for r in data['entries'] if r['kind']!=record['kind']]+[record];write(index,data)
 print('WATER LOCAL STAGE: presentation validated; native fixture pending; no public route installed')
def prepared_fidgets():
 record=read(LOCAL/'candidate.json')
 report=read(ROOT/'outputs/creatures/water-trial/validation.json')
 assert report['failures']==0 and report['asset_sha256']==sha(LOCAL/'trial.scn')
 assert report['candidate_sha256']==sha(LOCAL/'candidate.json')
 ledger=read(ROOT/'outputs/creatures/actions.json')
 reference=runpy.run_path(str(ROOT/'scripts/prepare-dragon-daemon-actions.py'))['reference']
 references={str(slot):reference(ledger,16,slot,('anim.mul',16,5,digest))
             for slot,(_,digest) in FIDGET_GROUPS.items()}
 assert all(record['classic_action_categories'][str(slot)]==clip for slot,(clip,_) in FIDGET_GROUPS.items())
 relative='local-art/creatures/water-fidgets/water-elemental.scn'
 target=ROOT/'Viewer'/relative
 target.parent.mkdir(parents=True,exist_ok=True)
 if not target.exists() or sha(target)!=report['asset_sha256']:
  shutil.copyfile(LOCAL/'trial.scn',target)
 treatments=('original','rounded','modern')
 prepared=dict(record,status='prepared',family='water_fidgets',
               assets=dict.fromkeys(treatments,'res://'+relative),
               authored_action_scene_sha256=dict.fromkeys(treatments,sha(target)),
               authored_action_reference=references['17'],classic_motion_references=references)
 return [prepared],{16:['WaterElemental']}
def verify_fidget_witnesses(live):
 assert {row['female'] for row in live['records']}=={False,True}
 for row in live['records']:
  for slot,(clip,_) in FIDGET_GROUPS.items():
   action,=(action for action in row['actions'] if action['requested']==slot)
   assert action['owner_clip']==action['observer_clip']==clip
def install(prepared=False):
 inputs();record=read(LOCAL/'candidate.json');report=read(ROOT/'outputs/creatures/water-trial/validation.json')
 live_path=ROOT/'outputs/creatures'/('water_fidgets' if prepared else 'water')/'live.json'
 live=read(live_path)
 assert report['failures']==0 and report['checks']>450 and live['failures']==0
 assert len(live['records'])==2 and all(r['body']==16 and r['native_class']=='WaterElemental' for r in live['records'])
 log=ROOT/'work/creatures'/('mul-motion-review/water-fidgets-native.log' if prepared else 'water-native-clean.log')
 assert log.exists() and 'ERROR:' not in log.read_text(encoding='utf-8-sig'),'Native run contains renderer errors'
 assert live_path.stat().st_mtime>(ROOT/'outputs/creatures/water-trial/validation.json').stat().st_mtime,'Repeat native checks after presentation validation'
 assert report['asset_sha256']==sha(LOCAL/'trial.scn') and report['candidate_sha256']==sha(LOCAL/'candidate.json')
 for relative,digest in report['runtime'].items():assert sha(ROOT/relative)==digest,relative+' changed after validation'
 verify_fidget_witnesses(live)
 if prepared:
  evidence=ROOT/'work/creatures/water_fidgets'
  runtime=json.loads((evidence/'native-runtime.json').read_text(encoding='utf-8-sig'))
  candidates=evidence/'candidates.json'
  assert live['prepared_trial'] and runtime['report_sha256']==sha(live_path)
  assert runtime['candidate_sha256']==live['candidate_sha256']==sha(candidates)
  assert live['test_sha256']==sha(ROOT/'Viewer/Network/CreatureLive.gd')
  assert live['prepared_wrapper_sha256']==sha(ROOT/'Viewer/Network/PreparedCreatureActionLive.gd')
  assert live['fixture_sha256']==sha(ROOT/'Server/HorseIntegrationFixtures/CreatureFixtures.cs')
  trial,=read(candidates)
  rows,_=prepared_fidgets()
  assert trial['presentation']==rows[0]
 PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(LOCAL/'trial.scn',PUBLIC/'water-elemental.scn')
 record.update(status='validated',assets={'modern':'res://Art/Creatures/Water/water-elemental.scn'})
 index=ROOT/'Viewer/Art/Creatures/index.json';data=read(index)
 position=next((i for i,row in enumerate(data['entries']) if row['kind']==record['kind']),len(data['entries']))
 data['entries'][position:position+1]=[record];write(index,data)
 private=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(private);data['entries']=[r for r in data['entries'] if r['kind']!=record['kind']];write(private,data)
 pack_names={'universal-base-characters','universal-animation-library'}
 packs=[p for p in read(ROOT/'Viewer/Art/Quaternius/manifest.json')['packs'] if p['pack'] in pack_names]
 grants={f'Viewer/Art/Quaternius/{p}-LICENSE.txt':sha(ROOT/f'Viewer/Art/Quaternius/{p}-LICENSE.txt') for p in sorted(pack_names)}
 write(PUBLIC/'provenance.json',{'sources':read(LOCAL/'inputs.json'),'source_packs':packs,'license_grants':grants,'presentation_files':report['runtime'],'asset_sha256':sha(PUBLIC/'water-elemental.scn'),'interpretation':record['source_interpretation']})
 (PUBLIC/'NOTICE.txt').write_text('Water elemental: authored fluid-vortex replacement by Britannia Reborn contributors, GPL-3.0-or-later. See root LICENSE.\nUnderlying upper-body mesh/65-bone rig: Quaternius Universal Base Characters Standard, CC0-1.0.\nThirteen retargeted action categories: Quaternius Universal Animation Library Standard, CC0-1.0.\nTwo death categories share one authored liquid collapse/puddle. Four poses follow visual inspection of Classic slots 7, 8, 17 and 18.\nSources: https://quaternius.itch.io/universal-base-characters and https://quaternius.itch.io/universal-animation-library\nExact input hashes, source pack pins and CC0 grants: provenance.json, scripts/prepare-water-elemental.py and Viewer/Art/Quaternius/manifest.json and *-LICENSE.txt.\nNo original game mesh, rig, texture or particle is included.\n',encoding='utf-8')
 print('WATER INSTALLED: independently licensed mesh/rig/actions, authored shader, measured/native route')
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('mode',choices=['inputs','candidate','stage','install','install-fidgets']);args=parser.parse_args()
 {'inputs':inputs,'candidate':candidate,'stage':stage,'install':install,'install-fidgets':lambda:install(prepared=True)}[args.mode]()
if __name__=='__main__':main()
