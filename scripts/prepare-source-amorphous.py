"""Private original PlagueBeast/Slime conversion; never accept a route."""
import argparse,base64,copy,hashlib,importlib.util,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/third-dawn/late-source-research/uoaos-source'
CABINETS=SOURCE.parent/'uoaos-cabinets'
WORK=ROOT/'work/creatures/plague-spawn/source-preparation'
ART=ROOT/'Viewer/local-art/creatures'
KINDS={'plague_beast':('plague',775),'slimes_slime':('slimes',51)}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def module(name,filename):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/filename);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
def inputs(extract=False):
    pins=read(ROOT/'scripts/source-amorphous-inputs.json')
    for row in pins['cabinets']:
        path=CABINETS/Path(row['zip_member']).name
        assert path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],'Changed original cabinet:'+path.name
    if extract:
        program=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for filename,folder,patterns in [('client7.cab','Models',['models.txt']),('client11.cab','Models/Monsters',['plague_beast_*.grn','slimes_slime_*.grn']),('client10.cab','Models/Maps',['plague_beast_256.tga','slimes_slime_v02.tga'])]:
            target=SOURCE/folder;target.mkdir(parents=True,exist_ok=True);subprocess.run([program,'e','-y','-o'+str(target),str(CABINETS/filename),*patterns],check=True,stdout=subprocess.DEVNULL)
    for row in pins['files']:
        path=(SOURCE/row['path']).resolve();assert path.is_relative_to(SOURCE.resolve()) and path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],'Changed source:'+row['path']
    return pins
def prepare():
    pins=inputs();layer=pins['generated_plague_layer'];atlas=ROOT/layer['default_path'];assert sha(atlas)==layer['sha256']
    assert all(sha(ROOT/prompt['path'])==prompt['sha256'] for prompt in layer['prompts'])
    assert read(ROOT/layer['provenance_path'])['output_sha256']==sha(atlas)
    pipeline=module('amorphous_source_pipeline','prepare-creatures.py');floor=module('amorphous_floor_support','prepare-source-frogs.py');staging=WORK/'prepared';staging.mkdir(parents=True,exist_ok=True);pipeline.OUTPUT=staging
    class InstalledData:
        def __init__(self):self.paths={'uoaos/UOTD/'+row['path']:SOURCE/row['path'] for row in pins['files']}
        def read(self,name):return self.paths[name].read_bytes()
    source=InstalledData();names={name.casefold():name for name in source.paths};table=pipeline.table_rows((SOURCE/'Models/models.txt').read_bytes());server_pin,native=pipeline.native_bodies()
    def explicit_reuse(body,clips,authored,aliases,stem):
        assert stem in KINDS
        for target,original in [('Attack2','Attack'),('Attack3','Attack'),('Death2','Death'),('Eat','Fidget'),('Pillage','Fidget')]:
            if target not in clips:clips[target]=copy.deepcopy(clips[original]);aliases[target]=original+': explicitly reused source category; not recovered '+target+' choreography'
        return False
    pipeline.humanoid_actions.install=explicit_reuse;models=[];ART.mkdir(parents=True,exist_ok=True)
    for kind,(family,body) in KINDS.items():
        pipeline.reuse.RECIPES[kind]={'floor_sample_rate':240,'measure_motion_bounds':True}
        rows=pipeline.prepare(family,source,names,table,native,selected_kinds=[kind]);assert len(rows)==1 and rows[0]['status']=='prepared';row=rows[0];assert len(row['clip_sources'])==(9 if body==775 else 7) and not row['rejected_source_clips']
        original=staging/(kind+'-original-albedo.png');shutil.copyfile(original,ART/original.name);policies={}
        if body==51:
            row['stats']['rounded']=copy.deepcopy(row['stats']['original'])
            row['stats']['rounded']['triangles']=736
            row['pose_subdivision']={'levels':2,'normal_offset_source_units':.0015,'method':'Runtime source-pose-preserving barycentric skin subdivision; original bone count and source-scale GLTF retained. Traditional weight smoothing rejected for large gait distortion.','recipe_sha256':sha(ROOT/'Viewer/Presentation/SourcePoseSubdivision.gd')}
            row['refinement']={'levels':2,'triangles_before':46,'triangles_after':736,'source_bones':29,'method':'Conditional per-bind source skin points; bounded1.5mm source-normal offset. No averaged incompatible skin bindings.'}
        for treatment in ['original','rounded','modern']:
            doc=read(staging/(kind+'-'+('original' if body==51 else treatment)+'.gltf'));policies[treatment]={clip:floor.constant_floor(doc,clip) for clip in ['Walk','Run']}
            if treatment=='modern' and body==775:doc['images'][0]['uri']='data:image/png;base64,'+base64.b64encode(atlas.read_bytes()).decode()
            for material in doc['materials']:material.update(alphaMode='MASK',alphaCutoff=.12)
            (ART/(kind+'-'+treatment+'.gltf')).write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
            if treatment!='modern':
                for clip in ['Walk','Run']:row['stats'][treatment]['clips'][clip].update(floor_policy='source_vertical',floor_offset_range=[policies[treatment][clip]['constant_source_z']]*2)
        script='res://Presentation/SourceAmorphousVisual.gd'
        row.update(family='amorphous',movement_mode='ground_plane',contact_kind='source_amorphous',presentation_script=script,presentation_script_sha256=sha(ROOT/'Viewer/Presentation/SourceAmorphousVisual.gd'),source_atlas_texture=original.name,source_alpha_texture=original.name,source_alpha_scope='fine_edges',art_dependency_sha256={original.name:sha(original)},amorphous_surface='plague' if body==775 else 'slime',vertical_gait_policy=policies,appearance_pose_fit=True,preparation_recipe={'path':'scripts/prepare-source-amorphous.py','sha256':sha(Path(__file__))},gait_scope='Original Walk/Run joint channels and vertical trajectories retained with one whole-clip anchor. Plane-only source support, not invented conventional foot IK. Physical cadence/no-slip not certified.')
        row['motion_bound_diagonal_m']=max(clip['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for clip in stats['clips'].values())*1.15
        if body==775:row.update(modern_atlas=str(atlas.relative_to(ROOT)),atlas_sha256=sha(atlas),surface='Private generated RGBA detail over retained originalRGB/alpha; authored albedo relief, source eyes/mouths pending exact registration')
        else:row.update(surface='Original source RGB/alpha with authored low-contrast moist gel shader/procedural grain; no recovered normal/material map')
        models.append(row)
    report={'family':'amorphous','models':models,'source_url':pins['source_url'],'source_cabinets':pins['cabinets'],'server_pin':server_pin,'input_manifest_sha256':sha(ROOT/'scripts/source-amorphous-inputs.json'),'recipe_sha256':sha(Path(__file__)),'floor_helper_sha256':sha(ROOT/'scripts/prepare-source-frogs.py'),'source_pipeline_sha256':sha(ROOT/'scripts/prepare-creatures.py'),'scope':'Private original PlagueBeast775/Slime51, source UVs/56+29joints/9+7motions plus explicit reused categories. Prepared only, no main route/native/lifecycle/corpse/final-art acceptance. All original and derived game artwork excluded from publication.'}
    folder=ART/'amorphous';folder.mkdir(parents=True,exist_ok=True);(folder/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('ORIGINAL AMORPHOUS PREPARED:2meshes,56/29joints,9/7source motions; Walk/Runrise retained; no accepted route')
def refresh_support():
    inputs();path=ART/'amorphous/preparation.json';report=read(path)
    assert report['input_manifest_sha256']==sha(ROOT/'scripts/source-amorphous-inputs.json') and report['source_pipeline_sha256']==sha(ROOT/'scripts/prepare-creatures.py') and report['floor_helper_sha256']==sha(ROOT/'scripts/prepare-source-frogs.py')
    report['recipe_sha256']=sha(Path(__file__))
    for row in report['models']:
        row['presentation_script_sha256']=sha(ROOT/'Viewer/Presentation/SourceAmorphousVisual.gd');row['preparation_recipe']['sha256']=report['recipe_sha256']
        if 'pose_subdivision' in row:row['pose_subdivision']['recipe_sha256']=sha(ROOT/'Viewer/Presentation/SourcePoseSubdivision.gd')
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('AMORPHOUS OWNED SUPPORT REFRESHED:exact source/pipeline pins; current owned renderer and conditional-bind subdivision')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs','extract','prepare','refresh-support']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    if args.extract:inputs(True)
    if args.check_inputs:inputs();print('AMORPHOUS SOURCE INPUTS:3cabinets/21original member pins verified')
    if args.prepare:prepare()
    if args.refresh_support:refresh_support()
