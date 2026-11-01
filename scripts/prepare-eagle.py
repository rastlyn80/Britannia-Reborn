"""Verify independent eagle inputs and record a measured, uninstalled trial."""
import argparse,hashlib,json,os,re,shutil,subprocess,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work/creatures/animals-vol2';LOCAL=ROOT/'Viewer/local-art/eagle';OUT=ROOT/'outputs/creatures/eagle-trial'
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def inputs(verify_only):
    pins=read(ROOT/'scripts/eagle-inputs.json');archive=WORK/'animals-vol2.zip';WORK.mkdir(parents=True,exist_ok=True)
    if not archive.exists():
        assert not verify_only,'Pinned animal archive missing'
        with urllib.request.urlopen(pins['download'],timeout=60) as response:raw=response.read(pins['archive_bytes']+1)
        assert len(raw)==pins['archive_bytes'] and hashlib.sha256(raw).hexdigest()==pins['archive_sha256'];archive.write_bytes(raw)
    assert archive.stat().st_size==pins['archive_bytes'] and sha(archive)==pins['archive_sha256']
    target=(WORK/'source'/pins['member']).resolve();assert target.is_relative_to((WORK/'source').resolve())
    if not target.exists():
        assert not verify_only,'Pinned eagle source missing'
        with zipfile.ZipFile(archive) as z:raw=z.read(pins['member'])
        assert len(raw)==pins['member_bytes'] and hashlib.sha256(raw).hexdigest()==pins['member_sha256'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    assert target.stat().st_size==pins['member_bytes'] and sha(target)==pins['member_sha256']
    return pins
def candidate(pins):
    prep=read(LOCAL/'preparation.json');motion=read(OUT/'motion.json')
    assert motion['failures']==0 and motion['checks']>=3800 and len(motion['samples'])==1000
    assert motion['recipe_sha256']==prep['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-eagle.py')
    assert motion['test_sha256']==sha(ROOT/'Viewer/Presentation/EagleMotionTests.gd') and motion['preparation_sha256']==sha(LOCAL/'preparation.json')
    for path,digest in motion['runtime_sha256'].items():assert sha(ROOT/'Viewer'/path.removeprefix('res://'))==digest,'Stale eagle skin/material evidence: '+path
    for treatment in ['source','modern']:
        asset=LOCAL/('eagle-'+treatment+'.glb');assert sha(asset)==motion['assets'][treatment]['asset_sha256']==prep['treatments'][treatment]['asset_sha256']
        assert sha(Path(str(asset)+'.import'))==motion['assets'][treatment]['import_sha256']
    assert motion['standing_sole_max_m']<.004 and motion['feeding_beak_y']<.09 and motion['perched_width_m']<motion['flight_span_m']*.4
    native='Projects/UOContent/Mobiles/Animals/Birds/Eagle.cs';path=ROOT/'Server/ModernUO'/native
    text=path.read_text(encoding='utf-8-sig');match=re.search(r'\bBody\s*=\s*(0x[0-9a-fA-F]+|\d+)\s*;',text);assert match and int(match[1],0)==5
    body_table=ROOT/'Server/ModernUO/Distribution/Data/bodyTable.cfg';assert re.search(r'^5\s+Animal\s*$',body_table.read_text(),re.M)
    stats={'bones':24,'height_m':.4,'clips':prep['clips']}
    envelope=motion['envelope']
    record={'kind':'eagle','family':'eagles','profile':'animal','status':'candidate','movement_mode':'ground_plane','head_bone':'Bone.003',
        'assets':{'modern':'res://local-art/eagle/eagle-modern.glb','original':'res://local-art/eagle/eagle-source.glb'},
        'bodies':[{'body':5,'name':'Eagle','scale':[1,1,1],'native_profile':'animal','native_sources':[{'path':native,'sha256':sha(path)}]}],
        'source':pins['source'],'license':'CC0-1.0 independent donor; authored conversion/actions/shader GPL-3.0-or-later',
        'source_interpretation':'Quaternius independent eagle. Two evaluated donor airborne clips, explicitly authored perched/action/landing/airborne variations; not recovered UO geometry or choreography.',
        'partial_hue_interpretation':'Authored brown-feather region; white head/tail, yellow beak/feet and fixed eyes protected from partial dye. Not original UO mask recovery.',
        'stats':{'original':stats,'modern':stats},'authored_replacements':{name:info['origin'] for name,info in prep['clips'].items()},
        'camera_height':.5,'pick_bounds':{'position':[v-.01 for v in envelope['position']],'size':[v+.02 for v in envelope['size']]},
        'loop_categories':['Run'],'locomotion':{'run_threshold_mps':.4,'run_reference_mps':1.8,'walk_reference_mps':.3,'rate_min':.65,'rate_max':1.8},
        'native_gait_expectations':{'walk':'Run','run':'Run'},'presentation_transition':'TakeOff then Run; Land then Idle. Visual low flight inferred from movement; does not set native Flying.',
        'body_table_sha256':sha(body_table),'recipe_sha256':prep['recipe_sha256'],'source_pin_sha256':sha(ROOT/'scripts/eagle-inputs.json')}
    write(LOCAL/'candidate.json',record);print('EAGLE CANDIDATE: actual body5; no accepted/native route installed')
def verified_trial():
    record=read(LOCAL/'candidate.json');prep=read(LOCAL/'preparation.json');motion=read(OUT/'motion.json');presentation=read(OUT/'presentation.json')
    assert record['recipe_sha256']==prep['recipe_sha256']==motion['recipe_sha256']==sha(ROOT/'scripts/blender-prepare-eagle.py')
    assert record['source_pin_sha256']==sha(ROOT/'scripts/eagle-inputs.json')
    assert motion['failures']==0 and motion['checks']>=3800 and len(motion['samples'])==1000 and motion['test_sha256']==sha(ROOT/'Viewer/Presentation/EagleMotionTests.gd')
    assert motion['preparation_sha256']==sha(LOCAL/'preparation.json')
    assert presentation['failures']==0 and presentation['checks']>=129 and len(presentation['terrain'])==18 and presentation['renderer']=='forward_plus'
    assert presentation['candidate_sha256']==sha(LOCAL/'candidate.json')
    asset=LOCAL/'eagle-modern.glb';assert presentation['asset_sha256']==motion['assets']['modern']['asset_sha256']==prep['treatments']['modern']['asset_sha256']==sha(asset)
    assert presentation['import_sha256']==motion['assets']['modern']['import_sha256']==sha(Path(str(asset)+'.import'))
    for report in [motion,presentation]:
        for path,digest in report['runtime_sha256'].items():assert sha(ROOT/'Viewer'/path.removeprefix('res://'))==digest,'Stale eagle trial: '+path
    return record,presentation
def stage():
    record,_=verified_trial();record.update(status='validated',native_validation='Pending isolated native Eagle constructor checks')
    path=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(path);data['entries']=[r for r in data['entries'] if r['kind']!=record['kind']]+[record];write(path,data)
    print('EAGLE LOCAL STAGE: skin/material/terrain/transition proof passed; native validation pending')
def install():
    record,presentation=verified_trial();live_path=ROOT/'outputs/creatures/eagles/live.json';live=read(live_path)
    assert live['failures']==0 and live['checks']>=110 and len(live['records'])==2 and all(r['body']==5 and r['native_class']=='Eagle' for r in live['records'])
    assert {r['female'] for r in live['records']}=={False,True} and live_path.stat().st_mtime>(OUT/'presentation.json').stat().st_mtime
    public=ROOT/'Viewer/Art/Creatures/Eagle';public.mkdir(parents=True,exist_ok=True);shutil.copyfile(LOCAL/'eagle-modern.glb',public/'eagle.glb')
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(ROOT/'.godot-user');godot=next((ROOT/'.tools/godot').glob('*console.exe'))
    for label,args in [('public-import',['--editor','--import']),('public-precision',['--script','res://Presentation/ConfigureEagleImports.gd','--','--public']),('public-reimport',['--editor','--import'])]:
        result=subprocess.run([str(godot),'--headless','--path',str(ROOT/'Viewer'),*args],env=env,capture_output=True,text=True,timeout=180)
        output=result.stdout+result.stderr;(WORK/('eagle-'+label+'.log')).write_text(output,encoding='utf-8');assert result.returncode==0 and 'SCRIPT ERROR:' not in output,output
    record.update(status='validated',assets={'modern':'res://Art/Creatures/Eagle/eagle.glb'},native_validation='Passed actual disposable-server/two-client Eagle body5 checks; repeat installed public asset')
    index=ROOT/'Viewer/Art/Creatures/index.json';data=read(index);data['entries']=[r for r in data['entries'] if r['kind']!='eagle']+[record];write(index,data)
    path=ROOT/'Viewer/local-art/creatures/accepted-index.json';data=read(path);data['entries']=[r for r in data['entries'] if r['kind']!='eagle'];write(path,data)
    write(public/'provenance.json',{'source':read(ROOT/'scripts/eagle-inputs.json'),'asset_sha256':sha(public/'eagle.glb'),'preparation':read(LOCAL/'preparation.json'),'validation':{'motion_checks':read(OUT/'motion.json')['checks'],'skin_samples':1000,'presentation_checks':presentation['checks'],'native_checks':live['checks']},'scope':'Independent Quaternius CC0 donor cage/rig/two clips; GPL authored refinement/eyes/actions/conversion. No UO geometry, rig, texture or animation data.'})
    (public/'NOTICE.txt').write_text('Quaternius Animated Animals Vol.2 Eagle\nSource: https://opengameart.org/node/78596\nLicense: CC0-1.0 https://creativecommons.org/publicdomain/zero/1.0/\nExact archive/member SHA256 pins: provenance.json and scripts/eagle-inputs.json.\nAuthored eyes, refinement, wing/tail packing, additional actions and conversion: Britannia Reborn, GPL-3.0-or-later.\nOnly donor Idle/Flying are source animation; the former is an airborne idle. All other actions are declared authored adaptations. No original Ultima Online art is included.\n',encoding='utf-8')
    print('EAGLE INSTALLED: independent public asset; repeat installed public GPU/native/distribution before publication')
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['verify-only','candidate','stage','install']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    pins=inputs(args.verify_only)
    if args.candidate:candidate(pins)
    if args.stage:stage()
    if args.install:install()
if __name__=='__main__':main()
