"""Prepare private original red/black Solen workers; never accept a route."""
import argparse,base64,copy,hashlib,importlib.util,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/third-dawn/late-source-research/uoaos-source'
CABINETS=SOURCE.parent/'uoaos-cabinets'
WORK=ROOT/'work/creatures/solen/source-preparation'
ART=ROOT/'Viewer/local-art/creatures'
KINDS={'fire_ant_worker':('fire',781),'black_ant_worker':('black',805)}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def module(name,filename):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/filename);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
def inputs(extract=False):
    pins=read(ROOT/'scripts/source-solen-inputs.json')
    for row in pins['cabinets']:
        path=CABINETS/Path(row['zip_member']).name
        assert path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],'Changed original cabinet:'+path.name
    if extract:
        program=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for filename,folder,patterns in [('client7.cab','Models',['models.txt']),('client11.cab','Models/Monsters',['fire_ant_worker_*.grn','black_ant_worker_lod2.grn']),('client10.cab','Models/Maps',['fire_ant_worker_256.tga','black_ant_worker_256.tga'])]:
            target=SOURCE/folder;target.mkdir(parents=True,exist_ok=True);subprocess.run([program,'e','-y','-o'+str(target),str(CABINETS/filename),*patterns],check=True,stdout=subprocess.DEVNULL)
    for row in pins['files']:
        path=(SOURCE/row['path']).resolve();assert path.is_relative_to(SOURCE.resolve()) and path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],'Changed source:'+row['path']
    for layer in pins['generated_albedos']:
        assert sha(ROOT/layer['default_path'])==layer['sha256'] and sha(ROOT/layer['prompt_path'])==layer['prompt_sha256']
        assert read(ROOT/layer['provenance_path'])['output_sha256']==layer['sha256']
    return pins
def prepare():
    pins=inputs();pipeline=module('solen_source_pipeline','prepare-creatures.py');floor=module('solen_floor_helper','prepare-source-frogs.py');staging=WORK/'prepared';staging.mkdir(parents=True,exist_ok=True);pipeline.OUTPUT=staging
    class InstalledData:
        def __init__(self):self.paths={'uoaos/UOTD/'+row['path']:SOURCE/row['path'] for row in pins['files']}
        def read(self,name):return self.paths[name].read_bytes()
    source=InstalledData();names={name.casefold():name for name in source.paths};table=pipeline.table_rows((SOURCE/'Models/models.txt').read_bytes());server_pin,native=pipeline.native_bodies()
    # Recover the second original fidget instead of substituting the first.
    pipeline.LABELS['fidget2']='Fidget2'
    def explicit_reuse(body,clips,authored,aliases,stem):
        assert stem in KINDS
        for target,original in [('Death2','Death'),('Eat','Fidget'),('Pillage','Fidget')]:
            assert target not in clips;clips[target]=copy.deepcopy(clips[original]);aliases[target]=original+': explicitly reused source category; not recovered '+target+' choreography'
        return False
    pipeline.humanoid_actions.install=explicit_reuse;models=[];ART.mkdir(parents=True,exist_ok=True)
    for kind,(family,body) in KINDS.items():
        pipeline.reuse.RECIPES[kind]={'floor_sample_rate':240,'measure_motion_bounds':True}
        rows=pipeline.prepare(family,source,names,table,native,selected_kinds=[kind]);assert len(rows)==1 and rows[0]['status']=='prepared';row=rows[0]
        assert len(row['clip_sources'])==10 and 'Fidget2' in row['clip_sources'] and not row['rejected_source_clips']
        assert len(row['bodies'])==1 and row['bodies'][0]['body']==body and row['bodies'][0]['scale']==[1.3]*3
        original=staging/(kind+'-original-albedo.png');shutil.copyfile(original,ART/original.name);layer=next(g for g in pins['generated_albedos'] if g['kind']==kind);atlas=ROOT/layer['default_path'];policies={}
        for treatment in ['original','rounded','modern']:
            doc=read(staging/(kind+'-'+treatment+'.gltf'));policies[treatment]={clip:floor.constant_floor(doc,clip) for clip in ['Walk','Run']}
            if treatment=='modern':doc['images'][0]['uri']='data:image/png;base64,'+base64.b64encode(atlas.read_bytes()).decode()
            for material in doc['materials']:material.update(alphaMode='MASK',alphaCutoff=.12)
            (ART/(kind+'-'+treatment+'.gltf')).write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
            if treatment!='modern':
                for clip in ['Walk','Run']:row['stats'][treatment]['clips'][clip].update(floor_policy='source_vertical',floor_offset_range=[policies[treatment][clip]['constant_source_z']]*2)
        script='res://Presentation/SourceSolenVisual.gd'
        row.update(family='solen_workers',movement_mode='ground_plane',contact_kind='source_solen',limb_support='six_original_legs',presentation_script=script,presentation_script_sha256=sha(ROOT/'Viewer/Presentation/SourceSolenVisual.gd'),source_atlas_texture=original.name,source_alpha_texture=original.name,source_alpha_scope='fine_edges',art_dependency_sha256={original.name:sha(original)},vertical_gait_policy=policies,appearance_pose_fit=True,classic_action_categories={'18':'Fidget2'},preparation_recipe={'path':'scripts/prepare-source-solen.py','sha256':sha(Path(__file__))},gait_scope='Original source Walk/Run joint and vertical channels retained with one whole-clip anchor; six actual distal-leg surfaces measured separately. Physical cadence/no-slip and terrain support require actual-avatar evidence.',surface='Private original-UV generated chitin detail, original source alpha and authored albedo relief/reflectance; no recovered native shader',modern_atlas=str(atlas.relative_to(ROOT)),atlas_sha256=sha(atlas),exact_prompt=(ROOT/layer['prompt_path']).read_text(),generation_mode='built-in imagegen original UV atlas edit')
        row['motion_bound_diagonal_m']=max(clip['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for clip in stats['clips'].values())*1.15;models.append(row)
    report={'family':'solen_workers','models':models,'source_url':pins['source_url'],'source_cabinets':pins['cabinets'],'server_pin':server_pin,'input_manifest_sha256':sha(ROOT/'scripts/source-solen-inputs.json'),'recipe_sha256':sha(Path(__file__)),'floor_helper_sha256':sha(ROOT/'scripts/prepare-source-frogs.py'),'source_pipeline_sha256':sha(ROOT/'scripts/prepare-creatures.py'),'scope':'Private original red/black Solen worker geometry/UV/42source joints/10original motions including second fidget; explicit alternate death/feed/pillage reuses. Prepared only; no route/native/corpse/terrain/final-art acceptance or coverage. Original/generated game artwork excluded from publication.'}
    folder=ART/'solen_workers';folder.mkdir(parents=True,exist_ok=True);(folder/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('ORIGINAL SOLEN WORKERS PREPARED:2meshes/42joints/10source motions, including Fidget2; no accepted route')
def refresh_support():
    inputs();path=ART/'solen_workers/preparation.json';report=read(path)
    assert report['input_manifest_sha256']==sha(ROOT/'scripts/source-solen-inputs.json') and report['source_pipeline_sha256']==sha(ROOT/'scripts/prepare-creatures.py') and report['floor_helper_sha256']==sha(ROOT/'scripts/prepare-source-frogs.py')
    report['recipe_sha256']=sha(Path(__file__))
    for row in report['models']:row['presentation_script_sha256']=sha(ROOT/'Viewer/Presentation/SourceSolenVisual.gd');row['preparation_recipe']['sha256']=report['recipe_sha256']
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('SOLEN WORKER OWNED SUPPORT REFRESHED:exact source/pipeline pins, current owned renderer')
def finalize_ground():
    path=ART/'solen_workers/preparation.json';report=read(path);measurement=ROOT/'work/creatures/solen/attack-calibration.json';bake=read(measurement)
    assert report['recipe_sha256']==sha(Path(__file__)) and bake['preparation_sha256']==sha(path)
    assert bake['sample_rate']==960 and bake['recipe_sha256']==sha(ROOT/'Viewer/Presentation/BakeSourceSolenGround.gd') and bake['geometry_sha256']==sha(ROOT/'Viewer/Presentation/SourceGroundLookup.gd')
    assert {(r['kind'],r['treatment']) for r in bake['records']}=={(kind,t) for kind in KINDS for t in ['original','rounded','modern']}
    for row in report['models']:
        treatments={}
        for record in [r for r in bake['records'] if r['kind']==row['kind']]:
            asset=ART/(row['kind']+'-'+record['treatment']+'.gltf')
            assert record['asset_sha256']==sha(asset) and record['import_sha256']==sha(Path(str(asset)+'.import'))
            treatments[record['treatment']]={'clips':{'Attack2':[[time,-gap] for time,gap in record['samples']]}}
        target=ART/(row['kind']+'-ground.json');target.write_text(json.dumps({'sample_rate':960,'treatments':treatments},separators=(',',':')),encoding='utf-8')
        row.update(ground_lookup='res://local-art/creatures/'+target.name,ground_lookup_sha256=sha(target));row['art_dependency_sha256'][target.name]=sha(target)
    report['ground_measurement']={'path':str(measurement.relative_to(ROOT)).replace('\\','/'),'sha256':sha(measurement),'recipe_sha256':bake['recipe_sha256'],'geometry_sha256':bake['geometry_sha256']}
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('SOLEN ATTACK CORRECTION FINALIZED:only imported Attack2 residual; original gait channels untouched')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs','extract','prepare','refresh-support','finalize-ground']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    if args.extract:inputs(True)
    if args.check_inputs:inputs();print('SOLEN SOURCE INPUTS:3cabinets/15source members/2private generated atlases verified')
    if args.prepare:prepare()
    if args.refresh_support:refresh_support()
    if args.finalize_ground:finalize_ground()
