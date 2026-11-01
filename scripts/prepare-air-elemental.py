"""Pinned independent cloud actor and evidence-gated native/public installation."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];LOCAL=ROOT/'Viewer/local-art/air';OUT=ROOT/'outputs/creatures/air-trial';PUBLIC=ROOT/'Viewer/Art/Creatures/Air'
CARRIER_SHA='6b0856ae574b5571cbd79cb2682a0904ce1cb59a54da24f51b9e4d29b7e49bd8'
NATIVE=['Projects/UOContent/Mobiles/Monsters/Elemental/Magic/AirElemental.cs','Projects/UOContent/Mobiles/Monsters/Summons/SummonedAirElemental.cs','Projects/UOContent/Mobiles/Monsters/ML/Prism of Light/CrystalVortex.cs']
CLASSES=['AirElemental','SummonedAirElemental','CrystalVortex']
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True);pending=p.with_suffix(p.suffix+'.pending');pending.write_text(json.dumps(v,indent=2)+'\n');pending.replace(p)
def resource(p):
    assert p.startswith('res://');path=(ROOT/'Viewer'/p[6:]).resolve();assert path.is_relative_to(ROOT/'Viewer');return path
def motion():
    prep=read(LOCAL/'preparation.json');proof=read(OUT/'motion.json')
    assert sha(ROOT/'Viewer/Art/Creatures/Water/water-elemental.scn')==prep['carrier_sha256']==CARRIER_SHA
    notice=(ROOT/'Viewer/Art/Creatures/Water/NOTICE.txt').read_text();assert 'CC0' in notice and 'Quaternius' in notice
    assert prep['bones']==65 and prep['triangles']==14016 and prep['vertices']==7825 and len(prep['clips'])==15
    assert proof['failures']==0 and proof['checks']>=54004 and proof['complete_skins']==255 and proof['max_source_pose_delta']<.00001
    for key,name in [('recipe_sha256','PrepareAirElemental.gd'),('geometry_sha256','AirCloudGeometry.gd'),('shader_sha256','AirElementalSurface.gdshader')]:assert prep[key]==proof[key]==sha(ROOT/'Viewer/Presentation'/name),'Changed cloud input: '+name
    assert proof['test_sha256']==sha(ROOT/'Viewer/Presentation/AirElementalMotionTests.gd') and proof['preparation_sha256']==sha(LOCAL/'preparation.json')
    assert prep['asset_sha256']==proof['asset_sha256']==sha(LOCAL/'air-modern.scn')
    return prep,proof
def candidate():
    prep,proof=motion();pin=read(ROOT/'Server/dependencies.json')['modernuo']['revision']
    assert subprocess.check_output(['git','-C',str(ROOT/'Server/ModernUO'),'rev-parse','HEAD'],text=True).strip()==pin
    sources=[]
    for name in NATIVE:
        path=ROOT/'Server/ModernUO'/name;text=path.read_text(encoding='utf-8-sig');match=re.search(r'\bBody\s*=\s*(0x[\da-fA-F]+|\d+)\s*;',text);assert match and int(match[1],0)==13
        sources.append({'path':name,'sha256':sha(path)})
    lo=[min(s['position'][i] for s in proof['samples'])-.06 for i in range(3)];hi=[max(s['position'][i]+s['size'][i] for s in proof['samples'])+.06 for i in range(3)]
    stats={'bones':prep['bones'],'height_m':1.9,'clips':prep['clips']}
    record={'kind':'air_elemental','family':'air','status':'candidate','profile':'monster','movement_mode':'source_hover','surface_kind':'wind_pbr','assets':{'modern':'res://local-art/air/air-modern.scn'},'bodies':[{'body':13,'name':'AirElemental / SummonedAirElemental / CrystalVortex','scale':[1,1,1],'native_profile':'monster','native_sources':sources}],
        'source':'https://github.com/rastlyn80/Britannia-Reborn','license':'Original GPL-3.0-or-later cloud/vortex/dust geometry and shaders; retained Quaternius CC0 rig/UAL actions through the independently licensed Water carrier. Proprietary optional marker is separate local input, excluded from this scene.',
        'source_interpretation':'Authored analytic cloud actor with retained CC0 rig/motions; no recovered Third Dawn full actor or particle simulation. Original two-bone rigid death_mote/atlas preserved separately; explicit authored cue timing.',
        'partial_hue_interpretation':'Authored dense-cloud regions, not a recovered UO partial mask. Raw spectral/full/partial values preserved.',
        'stats':{'original':stats,'modern':stats},'authored_replacements':{k:v['origin'] for k,v in prep['clips'].items()},'loop_categories':[k for k,v in prep['clips'].items() if v['loop']],
        'camera_height':1.5,'pick_bounds':{'position':lo,'size':[hi[i]-lo[i] for i in range(3)]},'new_action_categories':{'2':'Hit','5':'Fidget','14':'Pillage'},'recipe_sha256':prep['recipe_sha256'],'asset_sha256':prep['asset_sha256']}
    write(LOCAL/'candidate.json',record);print('AIR CANDIDATE: source poses/independent cloud skins proved, no route installed')
def gated():
    prep,_=motion();record=read(LOCAL/'candidate.json');proof=read(OUT/'presentation.json')
    assert record['recipe_sha256']==prep['recipe_sha256'] and record['asset_sha256']==prep['asset_sha256']
    assert proof['failures']==0 and proof['checks']>=544 and len(proof['terrain'])==72 and proof['renderer']=='forward_plus'
    assert proof['candidate_sha256']==sha(LOCAL/'candidate.json') and proof['asset_sha256']==sha(resource(record['assets']['modern']))
    assert proof['shader_envelope_pixels']>1500 and proof['shader_envelope_outside_pixels']<5 and proof['original_marker_present']
    for path,digest in proof['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale cloud proof: '+path
    for source in record['bodies'][0]['native_sources']:assert sha(ROOT/'Server/ModernUO'/source['path'])==source['sha256']
    return record,proof
def stage():
    record,_=gated();record.update(status='validated',native_validation='Actual cloud avatar/hue/hover/corpse proved; three real native constructors pending')
    p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p);assert all(r['kind']=='air_elemental' or all(int(b['body'])!=13 for b in r['bodies']) for r in data['entries'])
    data['entries']=[r for r in data['entries'] if r['kind']!='air_elemental']+[record];write(p,data);print('AIR STAGED: native classes pending')
def live():
    proof=read(ROOT/'outputs/creatures/air/live.json');assert proof['failures']==0 and proof['checks']>=462
    assert {(r['body'],r['native_class'],r['female']) for r in proof['records']}=={(13,name,sex) for name in CLASSES for sex in [False,True]}
    for row in proof['records']:
        summoned=row['native_class']=='SummonedAirElemental'
        assert row['native_state']==('summoned' if summoned else 'constructor') and row['corpse_suppressed']==summoned
        assert not row['native_death_refused'] and not row['native_water']
    return proof
def install():
    record,proof=gated();live();assert (ROOT/'outputs/creatures/air/live.json').stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
    PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(resource(record['assets']['modern']),PUBLIC/'air-elemental.scn')
    record.update(status='validated',assets={'modern':'res://Art/Creatures/Air/air-elemental.scn'},native_validation='Actual three native constructors on two clients; repeat on installed public route')
    p=PUBLIC.parent/'index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='air_elemental']+[record];write(p,data)
    p=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(p);data['entries']=[r for r in data['entries'] if r['kind']!='air_elemental'];write(p,data)
    write(PUBLIC/'provenance.json',{'license':'GPL-3.0-or-later original cloud/vortex/dust geometry/shader with CC0 Quaternius rig/UAL motion exceptions','carrier_sha256':CARRIER_SHA,'geometry_origin':'Cloud body and tapered vortex authored in AirCloudGeometry.gd. Dry dust reuses the project-authored radial Puddle footprint from the independent Water carrier; its body mesh is replaced completely. Preparation clip metadata saying no water geometry refers to the removed body, not this retained footprint.','preparation':read(LOCAL/'preparation.json'),'asset_sha256':sha(PUBLIC/'air-elemental.scn'),'candidate_runtime_sha256':proof['runtime_sha256'],'optional_original_marker':'Private proprietary source mesh/atlas, not in this scene or public package; native particle-to-actor binding and timing not claimed'})
    provenance=read(PUBLIC/'provenance.json');carrier=read(PUBLIC.parent/'Water/provenance.json')['sources']
    provenance['independent_carrier_sources']={'inputs':carrier['inputs'],'recipe_sha256':carrier['recipe'],'rig_and_motion_license':'Quaternius CC0-1.0','urls':['https://quaternius.itch.io/universal-base-characters','https://quaternius.itch.io/universal-animation-library']}
    write(PUBLIC/'provenance.json',provenance)
    (PUBLIC/'NOTICE.txt').write_text('AirElemental analytic cloud/vortex/dust geometry, conversion and shader: original Britannia Reborn project work, GPL-3.0-or-later; root LICENSE.\nRetained rig and UAL1 motions: Quaternius, CC0-1.0, through the pinned public Water carrier. No original Quaternius human or Water body mesh is used. See Art/Creatures/Water/NOTICE.txt and provenance.json for exact source history/pins.\nhttps://quaternius.itch.io/universal-base-characters\nhttps://quaternius.itch.io/universal-animation-library\nNo Ultima Online mesh, texture, rig or animation is included. The original rigid death marker is optional separate local input.\n')
    print('AIR PUBLIC INSTALLED: repeat installed avatar/native and clean distribution before publication')
def verify_public():
    prep,_=motion();record=next(r for r in read(PUBLIC.parent/'index.json')['entries'] if r['kind']=='air_elemental');proof=read(OUT/'presentation.json');live()
    assert record['assets']['modern']=='res://Art/Creatures/Air/air-elemental.scn' and record['status']=='validated'
    assert sha(PUBLIC/'air-elemental.scn')==prep['asset_sha256']==proof['asset_sha256']
    assert proof['candidate_sha256']==sha(PUBLIC.parent/'index.json') and proof['failures']==0 and proof['checks']>=544
    for path,digest in proof['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale public cloud proof: '+path
    assert (ROOT/'outputs/creatures/air/live.json').stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
    print('AIR PUBLIC VERIFIED: independent cloud/current input hashes, actual avatar and all three native classes')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['candidate','stage','install','verify-public']:p.add_argument('--'+name,action='store_true')
    a=p.parse_args()
    if a.candidate:candidate()
    if a.stage:stage()
    if a.install:install()
    if a.verify_public:verify_public()
