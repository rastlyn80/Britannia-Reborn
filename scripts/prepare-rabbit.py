"""Pinned independent rabbit input and evidence-gated native/public installation."""
import argparse,hashlib,json,os,re,shutil,subprocess,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];PINS=ROOT/'scripts/rabbit-inputs.json';WORK=ROOT/'work/creatures/rabbit';LOCAL=ROOT/'Viewer/local-art/rabbit';OUT=ROOT/'outputs/creatures/rabbit-trial';PUBLIC=ROOT/'Viewer/Art/Creatures/Rabbit'
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True);pending=path.with_suffix(path.suffix+'.pending');pending.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8');pending.replace(path)
def resource(path):
    assert path.startswith('res://');result=(ROOT/'Viewer'/path[6:]).resolve();assert result.is_relative_to(ROOT);return result
def inputs(verify_only):
    pins=read(PINS);WORK.mkdir(parents=True,exist_ok=True);source=WORK/'rabbit.blend'
    if not source.exists():
        assert not verify_only,'Pinned rabbit input missing'
        with urllib.request.urlopen(pins['download'],timeout=60) as response:raw=response.read(pins['bytes']+1)
        assert len(raw)==pins['bytes'] and hashlib.sha256(raw).hexdigest()==pins['sha256'];source.write_bytes(raw)
    assert source.stat().st_size==pins['bytes'] and sha(source)==pins['sha256']
    return pins
def checked_motion():
    prep=read(LOCAL/'preparation.json');motion=read(OUT/'motion.json')
    assert prep['recipe_sha256']==motion['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-rabbit.py')
    assert prep['gait_recipe_sha256']==motion['gait_recipe_sha256']==sha(ROOT/'scripts/creature-rabbit-gaits.py')
    assert prep['source_pin_sha256']==sha(PINS) and motion['test_sha256']==sha(ROOT/'Viewer/Presentation/RabbitMotionTests.gd')
    assert motion['preparation_sha256']==sha(LOCAL/'preparation.json') and motion['failures']==0 and motion['checks']>=1700 and len(motion['samples'])==len(prep['clips'])*66 and motion['airborne_cases']>=20
    for treatment in ['source','modern']:
        path=LOCAL/('rabbit-'+treatment+'.glb')
        assert motion['assets'][treatment]['asset_sha256']==sha(path)==prep['treatments'][treatment]['asset_sha256']
        assert motion['assets'][treatment]['import_sha256']==sha(Path(str(path)+'.import'))
    for clip in ['Walk','Run']:
        gait=prep['treatments']['modern']['gait_reconciliation'][clip]
        assert abs(motion['gaits'][clip]['median_stance_speed_mps']*gait['runtime_reference_rate']-gait['target_stance_speed_mps'])<.15,'Actual imported stance speed needs calibration: '+clip
    return prep,motion
def candidate(pins):
    prep,motion=checked_motion();sources=[]
    pin=read(ROOT/'Server/dependencies.json')['modernuo']['revision']
    assert subprocess.check_output(['git','-C',str(ROOT/'Server/ModernUO'),'rev-parse','HEAD'],text=True).strip()==pin,'Native source must match the authoritative server pin'
    for name in ['JackRabbit','Rabbit']:
        native='Projects/UOContent/Mobiles/Animals/Rodents/'+name+'.cs';path=ROOT/'Server/ModernUO'/native;match=re.search(r'\bBody\s*=\s*(0x[0-9a-fA-F]+|\d+)\s*;',path.read_text(encoding='utf-8-sig'));assert match and int(match[1],0)==205
        sources.append({'path':native,'sha256':sha(path)})
    clips=prep['treatments']['modern']['clips'];stats={'bones':37,'height_m':.45,'bind_diagonal_m':.95,'clips':clips};bounds=motion['envelope']
    record={'kind':'rabbit','family':'rabbits','profile':'animal','status':'candidate','surface_kind':'rabbit_pbr','contact_kind':'rabbit_paws','head_bone':'Head',
        'assets':{'modern':'res://local-art/rabbit/rabbit-modern.glb','original':'res://local-art/rabbit/rabbit-source.glb'},
        'bodies':[{'body':205,'name':'Rabbit / JackRabbit','scale':[1,1,1],'native_profile':'animal','native_sources':sources}],
        'source':pins['source'],'license':'CC0-1.0 donor geometry/rig/maps/five evaluated motions; GPL-3.0-or-later authored conversion, refinement, additional categories, common-root gait adaptation and shaders',
        'source_interpretation':'Original CDmir rabbit pose/rig and two source skins with actual alpha fur/normal map. Explicit source timing/root adaptations and authored Attack/Hit/Eat/Fidget; no recovered UO choreography.',
        'partial_hue_interpretation':'Authored fur tint with dark-eye/pink-feature protection; original source alpha and normal maps retained. No recovered UO partial mask.',
        'stats':{'original':stats,'modern':stats},'authored_replacements':{label:info['origin'] for label,info in clips.items()},
        'loop_categories':[label for label,info in clips.items() if info['loop']],
        'camera_height':.4,'pick_bounds':{'position':[v-.01 for v in bounds['position']],'size':[v+.02 for v in bounds['size']]},
        'nameplate_tips':prep['nameplate_tips'],
        'locomotion':{'run_threshold_mps':3.6,'walk_reference_mps':prep['treatments']['modern']['gait_reconciliation']['Walk']['reference_stance_speed_mps'],'run_reference_mps':prep['treatments']['modern']['gait_reconciliation']['Run']['reference_stance_speed_mps'],'rate_min':.15,'rate_max':4.0},
        'native_gait_expectations':{'walk':'Walk','run':'Run'},'recipe_sha256':prep['recipe_sha256'],'gait_recipe_sha256':prep['gait_recipe_sha256'],'source_pin_sha256':sha(PINS)}
    write(LOCAL/'candidate.json',record);print('RABBIT CANDIDATE: real native205, complete skins and calibrated hops; no route installed')
def verified_trial():
    prep,motion=checked_motion();record=read(LOCAL/'candidate.json');presentation=read(OUT/'presentation.json');asset=resource(record['assets']['modern'])
    assert record['source_pin_sha256']==sha(PINS) and record['recipe_sha256']==prep['recipe_sha256'] and record['gait_recipe_sha256']==prep['gait_recipe_sha256']
    assert presentation['failures']==0 and presentation['checks']>=400 and len(presentation['terrain'])>=54 and presentation['renderer']=='forward_plus'
    assert presentation['airborne_paw_cases']>=12 and presentation['planted_paw_cases']>=12
    assert presentation['candidate_sha256']==sha(LOCAL/'candidate.json') and presentation['asset_sha256']==sha(asset) and presentation['import_sha256']==sha(Path(str(asset)+'.import'))
    required={'RabbitPresentationTests.gd','RabbitVisual.gd','RabbitGroundSupport.gd','RabbitMaterial.gd','RabbitSurface.gdshader','CreatureRegistry.gd','HumanAvatar.gd','CorpseModels.gd','SkinGeometry.gd'}
    assert {'res://Presentation/'+name for name in required}<=set(presentation['runtime_sha256'])
    for path,digest in presentation['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale rabbit avatar/material/support proof: '+path
    return record,presentation
def stage():
    record,_=verified_trial();record.update(status='validated',native_validation='Pending real isolated JackRabbit and Rabbit constructor checks')
    path=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(path)
    assert all(row['kind']=='rabbit' or all(int(body['body'])!=205 for body in row['bodies']) for row in data['entries']),'Another validated provider owns body205'
    data['entries']=[row for row in data['entries'] if row['kind']!='rabbit']+[record];write(path,data);print('RABBIT LOCAL STAGE: actual presentation proved; native identity tests pending')
def install():
    record,presentation=verified_trial();live_path=ROOT/'outputs/creatures/rabbits/live.json';live=read(live_path)
    assert live['failures']==0 and live['checks']>=180 and len(live['records'])==4
    assert {(row['native_class'],row['female']) for row in live['records']}=={(name,sex) for name in ['JackRabbit','Rabbit'] for sex in [False,True]}
    assert all(row['body']==205 for row in live['records']) and live_path.stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
    PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(resource(record['assets']['modern']),PUBLIC/'rabbit.glb')
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
    for label,args in [('public-import',['--editor','--import','--quit']),('public-precision',['--script','res://Presentation/ConfigureRabbitImports.gd','--','--public']),('public-reimport',['--editor','--import','--quit'])]:
        result=subprocess.run([str(godot),'--headless','--path',str(ROOT/'Viewer'),*args],env=env,capture_output=True,text=True,timeout=180)
        output=result.stdout+result.stderr;(WORK/(label+'.log')).write_text(output,encoding='utf-8');assert result.returncode==0 and 'SCRIPT ERROR:' not in output,output[-4000:]
    record.update(status='validated',assets={'modern':'res://Art/Creatures/Rabbit/rabbit.glb'},native_validation='Actual isolated two-client JackRabbit and Rabbit constructors, hues/movement/actions/hurt/death and static corpse; repeat on installed public route')
    path=PUBLIC.parent/'index.json';data=read(path);data['entries']=[row for row in data['entries'] if row['kind']!='rabbit']+[record];write(path,data)
    path=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(path);data['entries']=[row for row in data['entries'] if row['kind']!='rabbit'];write(path,data)
    dependencies={p.name:sha(p) for p in sorted(PUBLIC.glob('*.png'))}
    write(PUBLIC/'provenance.json',{'sources':read(PINS),'preparation':read(LOCAL/'preparation.json'),'asset_sha256':sha(PUBLIC/'rabbit.glb'),'extracted_map_sha256':dependencies,'runtime_sha256':presentation['runtime_sha256']})
    (PUBLIC/'NOTICE.txt').write_text('Rabbit mesh, rig, UVs, albedo/alpha fur, normal map and five original motions: Cestmir Dammer (CDmir), Kelgar, CC0-1.0. Listing collaborator TinyWorlds; ideas Rick Hoppmann and Keppu.\nSource: https://opengameart.org/content/rabbit-0\nLicense: https://creativecommons.org/publicdomain/zero/1.0/\nExact download/image hashes and embedded licence: scripts/rabbit-inputs.json and provenance.json.\nBritannia Reborn conversion, refinement, skin normalization, authored categories/common-root gait reconciliation and shaders: GPL-3.0-or-later; root LICENSE.\nNo Ultima Online mesh, map, rig or motion is included. Fur is the artist\'s texture/cards and normal map, not simulated hair.\n',encoding='utf-8')
    print('RABBIT PUBLIC BUNDLE INSTALLED: repeat public avatar/native/distribution proof before publication')
def verify_public():
    prep,motion=checked_motion();record=next(row for row in read(PUBLIC.parent/'index.json')['entries'] if row['kind']=='rabbit');presentation=read(OUT/'presentation.json');live=read(ROOT/'outputs/creatures/rabbits/live.json');provenance=read(PUBLIC/'provenance.json')
    assert record['status']=='validated' and record['assets']['modern']=='res://Art/Creatures/Rabbit/rabbit.glb'
    assert sha(PUBLIC/'rabbit.glb')==prep['treatments']['modern']['asset_sha256']==presentation['asset_sha256']==provenance['asset_sha256']
    assert presentation['candidate_sha256']==sha(PUBLIC.parent/'index.json') and presentation['failures']==0 and presentation['checks']>=3200 and len(presentation['terrain'])==162
    assert presentation['import_sha256']==sha(PUBLIC/'rabbit.glb.import') and presentation['alpha_gap_pixels']>100
    for path,digest in presentation['runtime_sha256'].items():assert sha(resource(path))==digest,'Public rabbit evidence is stale: '+path
    assert live['failures']==0 and live['checks']>=210 and {(row['native_class'],row['female']) for row in live['records']}=={(name,sex) for name in ['Rabbit','JackRabbit'] for sex in [False,True]}
    dependencies=provenance.get('extracted_map_sha256',{});assert len(dependencies)==3,'Record all three independently licensed extracted maps'
    for name,digest in dependencies.items():
        path=(PUBLIC/name).resolve();assert path.is_relative_to(PUBLIC.resolve()) and sha(path)==digest and path.stat().st_mtime<(OUT/'presentation.json').stat().st_mtime
    print('RABBIT PUBLIC VERIFIED: exact installed maps/model/import/runtime, complete skin/hop, actual avatar and both native classes')
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['verify-only','candidate','stage','install','verify-public']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args();pins=inputs(args.verify_only)
    if args.candidate:candidate(pins)
    if args.stage:stage()
    if args.install:install()
    if args.verify_public:verify_public()
if __name__=='__main__':main()
