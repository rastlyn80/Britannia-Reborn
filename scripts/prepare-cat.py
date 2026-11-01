"""Pinned CC0 cat input and a measured candidate; acceptance remains separate."""
import argparse,hashlib,json,os,re,shutil,subprocess,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];PINS=ROOT/'scripts/cat-inputs.json';WORK=ROOT/'work/creatures/animals-vol2';LOCAL=ROOT/'Viewer/local-art/cat';OUT=ROOT/'outputs/creatures/cat-trial'
PUBLIC=ROOT/'Viewer/Art/Creatures/Cat'
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def resource(path):
    assert path.startswith('res://');target=(ROOT/'Viewer'/path[6:]).resolve();assert target.is_relative_to(ROOT);return target
def inputs(verify_only):
    pins=read(PINS);WORK.mkdir(parents=True,exist_ok=True);archive=WORK/'animals-vol2.zip'
    if not archive.exists():
        assert not verify_only,'Pinned cat archive missing'
        with urllib.request.urlopen(pins['download'],timeout=60) as response:raw=response.read(pins['archive_bytes']+1)
        assert len(raw)==pins['archive_bytes'] and hashlib.sha256(raw).hexdigest()==pins['archive_sha256'];archive.write_bytes(raw)
    assert archive.stat().st_size==pins['archive_bytes'] and sha(archive)==pins['archive_sha256']
    target=(WORK/'source'/pins['member']).resolve();assert target.is_relative_to((WORK/'source').resolve())
    if not target.exists():
        assert not verify_only
        with zipfile.ZipFile(archive) as z:raw=z.read(pins['member'])
        assert len(raw)==pins['member_bytes'] and hashlib.sha256(raw).hexdigest()==pins['member_sha256'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    assert target.stat().st_size==pins['member_bytes'] and sha(target)==pins['member_sha256']
    return pins
def candidate(pins):
    prep=read(LOCAL/'preparation.json');motion=read(OUT/'motion.json')
    assert motion['failures']==0 and len(motion['samples'])==438 and motion['checks']>=1400
    assert motion['recipe_sha256']==prep['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-cat.py') and motion['test_sha256']==sha(ROOT/'Viewer/Presentation/CatMotionTests.gd')
    assert motion['preparation_sha256']==sha(LOCAL/'preparation.json')
    for treatment in ['source','modern']:
        asset=LOCAL/('cat-'+treatment+'.glb');assert motion['assets'][treatment]['asset_sha256']==prep['treatments'][treatment]['asset_sha256']==sha(asset)
        assert motion['assets'][treatment]['import_sha256']==sha(Path(str(asset)+'.import'))
    assert abs(motion['run_stance_speed_mps']-1.8)<.08 and abs(motion['gallop_stance_speed_mps']-6.8)<.12
    native='Projects/UOContent/Mobiles/Animals/Town Critters/Cat.cs';path=ROOT/'Server/ModernUO'/native
    match=re.search(r'\bBody\s*=\s*(0x[0-9a-fA-F]+|\d+)\s*;',path.read_text(encoding='utf-8-sig'));assert match and int(match[1],0)==201
    clips=prep['clips'];stats={'bones':24,'height_m':.45,'bind_diagonal_m':.75,'clips':clips};envelope=motion['envelope']
    record={'kind':'cat_domestic','family':'cats','profile':'animal','status':'candidate','surface_kind':'cat_fur_pbr','contact_kind':'cat_paws','head_bone':'bip01 head',
        'assets':{'modern':'res://local-art/cat/cat-modern.glb','original':'res://local-art/cat/cat-source.glb'},
        'bodies':[{'body':201,'scale':[1,1,1],'name':'Cat','native_profile':'animal','native_sources':[{'path':native,'sha256':sha(path)}]}],
        'source':pins['source'],'license':'Quaternius CC0-1.0 source mesh/rig/two clips; GPL-3.0-or-later authored conversion, details, motions and shaders',
        'source_interpretation':'Independent domestic cat with baked source Idle/Walking and nine declared authored categories, including distinct1.8/6.8m/s bounds. Original UO choreography not recovered.',
        'partial_hue_interpretation':'Authored material-region mask: partial dyes preserve white paws/chest and pink features; eyes fixed for full/partial hues. Not original UO dye-mask recovery.',
        'stats':{'original':stats,'modern':stats},'authored_replacements':{name:info['origin'] for name,info in clips.items()},
        'camera_height':.3,'pick_bounds':{'position':[v-.01 for v in envelope['position']],'size':[v+.02 for v in envelope['size']]},
        'locomotion':{'run_threshold_mps':.4,'gallop_threshold_mps':3.6,'walk_reference_mps':.192,'run_reference_mps':1.8,'gallop_reference_mps':6.8,'rate_min':.15,'rate_max':2.0},
        'native_gait_expectations':{'walk':'Run','run':'Gallop'},'recipe_sha256':prep['recipe_sha256'],'source_pin_sha256':sha(PINS)}
    record['loop_categories']=['Gallop']
    write(LOCAL/'candidate.json',record);print('CAT CANDIDATE: actual201; measured complete skins and two speeds; no route installed')
def verified_trial():
    record=read(LOCAL/'candidate.json');prep=read(LOCAL/'preparation.json');motion=read(OUT/'motion.json');presentation=read(OUT/'presentation.json');asset=resource(record['assets']['modern'])
    assert record['source_pin_sha256']==sha(PINS) and record['recipe_sha256']==prep['recipe_sha256']==motion['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-cat.py')
    assert motion['failures']==0 and motion['checks']>=1900 and len(motion['samples'])==438 and motion['test_sha256']==sha(ROOT/'Viewer/Presentation/CatMotionTests.gd')
    assert motion['preparation_sha256']==sha(LOCAL/'preparation.json') and motion['assets']['modern']['asset_sha256']==sha(asset)==prep['treatments']['modern']['asset_sha256']
    assert motion['assets']['modern']['import_sha256']==sha(Path(str(asset)+'.import'))
    assert abs(motion['run_stance_speed_mps']-1.8)<.08 and abs(motion['gallop_stance_speed_mps']-6.8)<.12
    assert presentation['failures']==0 and presentation['checks']>=300 and len(presentation['terrain'])==30 and presentation['lifted_paw_cases']>=12 and presentation['renderer']=='forward_plus'
    assert presentation['asset_sha256']==sha(asset) and presentation['import_sha256']==sha(Path(str(asset)+'.import')) and presentation['candidate_sha256']==sha(LOCAL/'candidate.json')
    assert [(row['speed'],row['clip'],row['rate']) for row in presentation['gaits']]==[(.192,'Walk',1.),(1.8,'Run',1.),(6.8,'Gallop',1.)]
    for path,digest in presentation['runtime_sha256'].items():assert sha(resource(path))==digest,'Stale cat presentation: '+path
    return record,presentation
def stage():
    record,_=verified_trial();record.update(status='validated',native_validation='Pending isolated native Cat constructor checks')
    path=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(path);data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']]+[record];write(path,data)
    print('CAT LOCAL STAGE: actual skin/material/paw/physical gait evidence passed; native validation pending')
def install():
    record,presentation=verified_trial();path=ROOT/'outputs/creatures/cats/live.json';live=read(path)
    assert live['failures']==0 and live['checks']>=100 and len(live['records'])==2 and all(row['body']==201 and row['native_class']=='Cat' for row in live['records'])
    assert {row['female'] for row in live['records']}=={False,True} and path.stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
    PUBLIC.mkdir(parents=True,exist_ok=True);shutil.copyfile(resource(record['assets']['modern']),PUBLIC/'cat.glb')
    # Configure the public import before moving its route from private to
    # public: default key reduction loses the short gallop stance trajectory.
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
    for label,args in [('public-import',['--editor','--import']),('public-precision',['--script','res://Presentation/ConfigureCatImports.gd','--','--public']),('public-reimport',['--editor','--import'])]:
        result=subprocess.run([str(godot),'--headless','--path',str(ROOT/'Viewer'),*args],env=env,capture_output=True,text=True,timeout=180)
        output=result.stdout+result.stderr;(WORK/(label+'.log')).write_text(output,encoding='utf-8')
        assert result.returncode==0 and 'SCRIPT ERROR:' not in output,output[-4000:]
    record.update(status='validated',assets={'modern':'res://Art/Creatures/Cat/cat.glb'},native_validation='Actual isolated two-client Cat constructor, physical-speed gaits, hues, hurt/actions/death and static corpse')
    index=PUBLIC.parent/'index.json';data=read(index);data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']]+[record];write(index,data)
    private=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(private);data['entries']=[row for row in data['entries'] if row['kind']!=record['kind']];write(private,data)
    write(PUBLIC/'provenance.json',{'sources':read(PINS),'preparation':read(LOCAL/'preparation.json'),'asset_sha256':sha(PUBLIC/'cat.glb'),'runtime_sha256':presentation['runtime_sha256']})
    (PUBLIC/'NOTICE.txt').write_text('Domestic cat source mesh, rig, colours and Idle/Walking motions: Quaternius, CC0-1.0.\nSource: https://opengameart.org/node/78596\nLicense: https://creativecommons.org/publicdomain/zero/1.0/\nExact archive/member hashes: scripts/cat-inputs.json and provenance.json.\nBritannia Reborn conversion, eye/paw details, nine additional motions and procedural coat: GPL-3.0-or-later; root LICENSE.\nNo Ultima Online mesh, map, rig or motion is included; no photographic fur texture or hair simulation is claimed.\n',encoding='utf-8')
    print('CAT INSTALLED: independent public bundle; repeat public presentation/native/distribution checks before publication')
def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['verify-only','candidate','stage','install']:p.add_argument('--'+name,action='store_true')
    a=p.parse_args();pins=inputs(a.verify_only)
    if a.candidate:candidate(pins)
    if a.stage:stage()
    if a.install:install()
if __name__=='__main__':main()
