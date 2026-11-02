"""Prepare original later Silver Serpent source; acceptance remains separate."""
import argparse,hashlib,importlib.util,json,math,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/third-dawn/late-source-research/uoaos-source'
CABINETS=SOURCE.parent/'uoaos-cabinets'
WORK=ROOT/'work/creatures/silver-serpent'
ART=ROOT/'Viewer/local-art/creatures'
KIND='serpents_snake_giant_silver'
FAMILY='silver_serpents'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((json.dumps(data,indent=2)+'\n').encode())
def inputs(extract=False):
    pins=read(ROOT/'scripts/source-silver-serpent-inputs.json')
    for row in pins['cabinets']:
        p=CABINETS/Path(row['zip_member']).name;assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256']
    if extract:
        program=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for cabinet,folder,patterns in [('client7.cab','Models',['models.txt']),('client11.cab','Models/Monsters',['serpents_snake_giant_*.grn']),('client10.cab','Models/Maps',['serpents_snake_giant_v03.tga','serpents_snake_giant_silver_v02.tga'])]:
            target=SOURCE/folder;target.mkdir(parents=True,exist_ok=True);subprocess.run([program,'e','-y','-o'+str(target),str(CABINETS/cabinet),*patterns],check=True,stdout=subprocess.DEVNULL)
    for row in pins['files']:
        p=(SOURCE/row['path']).resolve();assert p.is_relative_to(SOURCE.resolve()) and p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],'Changed original source: '+row['path']
    atlas=pins['generated_atlas']
    for key,hashkey in [('path','sha256'),('prompt_path','prompt_sha256')]:assert sha(ROOT/atlas[key])==atlas[hashkey]
    return pins
def prepare():
    pins=inputs();spec=importlib.util.spec_from_file_location('silver_pipeline',ROOT/'scripts/prepare-creatures.py');p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p);staging=WORK/'source-preparation';staging.mkdir(parents=True,exist_ok=True);p.OUTPUT=staging
    class OriginalInputs:
        def __init__(self):self.paths={'uoaos/UOTD/'+r['path']:SOURCE/r['path'] for r in pins['files']}
        def read(self,name):return self.paths[name].read_bytes()
    source=OriginalInputs();names={n.casefold():n for n in source.paths};table=p.table_rows((SOURCE/'Models/models.txt').read_bytes());server_pin,native=p.native_bodies()
    p.reuse.RECIPES[KIND]={'clip_stem':'serpents_snake_giant','motion_contract_stem':'serpents_snake_giant','unbound_label_aliases':[[KIND,'serpents_snake_giant']],'serpentine_feeding':True,'floor_sample_rate':240,'measure_motion_bounds':True}
    atlas=pins['generated_atlas'];shutil.copyfile(ROOT/atlas['path'],staging/(KIND+'-albedo-v1.png'));shutil.copyfile(ROOT/atlas['prompt_path'],staging/(KIND+'-albedo-v1.prompt.txt'))
    rows=p.prepare('serpents',source,names,table,native,selected_kinds={KIND});assert len(rows)==1 and rows[0]['status']=='prepared';row=rows[0]
    assert {b['body'] for b in row['bodies']}=={91,92,93} and len(row['clip_sources'])==8 and not row['rejected_source_clips']
    row['bodies'].sort(key=lambda b:(b['body']!=92,b['body']))
    for treatment in ['original','rounded','modern']:
        path=staging/(KIND+'-'+treatment+'.gltf');doc=read(path)
        for material in doc['materials']:material.update(alphaMode='MASK',alphaCutoff=.12)
        (ART/path.name).write_bytes(json.dumps(doc,separators=(',',':')).encode())
    for suffix in ['-original-albedo.png','-albedo-v1.png','-albedo-v1.prompt.txt']:shutil.copyfile(staging/(KIND+suffix),ART/(KIND+suffix))
    script='res://Presentation/SourceSilverSerpentVisual.gd'
    row.update(family=FAMILY,movement_mode='ground_plane',bounds_mode='weighted_skin',camera_height=.48,source_alpha_texture=KIND+'-original-albedo.png',source_alpha_scope='fine_edges',art_dependency_sha256={KIND+s:sha(ART/(KIND+s)) for s in ['-original-albedo.png','-albedo-v1.png']},loop_categories=['Idle','Walk','Run','Fidget'],new_action_categories={'2':'Hit','5':'Fidget','14':'Pillage'},locomotion={'walk_reference_mps':1.8,'run_reference_mps':5.5,'run_threshold_mps':3.6,'rate_min':.25,'rate_max':3.2},appearance_pose_fit=True,presentation_script=script,presentation_script_sha256=sha(ROOT/'Viewer/Presentation/SourceSilverSerpentVisual.gd'),ground_lookup='res://local-art/creatures/'+KIND+'-ground.json',ground_lookup_status='Pending current saved-import measurement; no acceptance',modern_atlas=str((ART/(KIND+'-albedo-v1.png')).relative_to(ROOT)),surface='Original later Silver UV/rig/opacity, private remastered scales and authored relief/charcoal-eye amendment; source-based partial hue, no recovered original normal map or exact generated feature registration claim',preparation_recipe={'path':'scripts/prepare-source-silver-serpent.py','sha256':sha(Path(__file__))},jaw_policy='All original Attack jaw channels retained; no inherited Ice gape limit',source_motion_assignment='Later table native92 and compatibility91/93 explicitly select GiantSerpent21 motions; own original mesh/UV/atlas retained')
    row['motion_bound_diagonal_m']=max(c['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for c in stats['clips'].values())*1.1
    report={'family':FAMILY,'models':[row],'server_pin':server_pin,'source_url':pins['source_url'],'source_cabinets':pins['cabinets'],'recipe_sha256':sha(Path(__file__)),'input_manifest_sha256':sha(ROOT/'scripts/source-silver-serpent-inputs.json'),'source_pipeline_sha256':sha(ROOT/'scripts/prepare-creatures.py'),'scope':'Private original later Silver source preparation only, no route/native/final art or gameplay acceptance. Original/generated artwork excluded from Git.'}
    write(ART/FAMILY/'preparation.json',report);print('SILVER PREPARED: own later source/18joints/8motions, native92+91/93compatibility; no accepted route')
def finalize():
    inputs();path=ART/FAMILY/'preparation.json';report=read(path);row=report['models'][0];ground=ART/(KIND+'-ground.json');bake=read(ground)
    assert bake['sample_rate']==960 and bake['recipe_sha256']==sha(ROOT/'Viewer/Presentation/BakeSourceSilverSerpentGround.gd') and bake['geometry_sha256']==sha(ROOT/'Viewer/Presentation/SourceGroundLookup.gd')
    categories={'Idle','Walk','Run','Attack','Hit','Death','Fidget','Pillage','Eat'}
    for treatment in ['original','rounded','modern']:
        asset=ART/(KIND+'-'+treatment+'.gltf');proof=bake['treatments'][treatment];assert proof['asset_sha256']==sha(asset) and proof['import_sha256']==sha(Path(str(asset)+'.import')) and set(proof['clips'])==categories
        for samples in proof['clips'].values():assert len(samples)>100 and all(len(r)==2 and all(math.isfinite(x) for x in r) for r in samples) and all(b[0]>a[0] for a,b in zip(samples,samples[1:]))
    row['ground_lookup_sha256']=sha(ground);row['art_dependency_sha256'][ground.name]=sha(ground);row['ground_lookup_status']='Current actual complete-skin curves at960Hz; terrain/transition/native proof separate';row['presentation_script_sha256']=sha(ROOT/'Viewer/Presentation/SourceSilverSerpentVisual.gd');row['preparation_recipe']['sha256']=sha(Path(__file__));report['recipe_sha256']=sha(Path(__file__));write(path,report);print('SILVER GROUND FINALIZED: exact current three imports, no acceptance')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs','extract','prepare','finalize-ground']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    if args.extract:inputs(True)
    if args.check_inputs:inputs();print('SILVER INPUTS:13exact original members/3cabinets/private atlas and prompt verified')
    if args.prepare:prepare()
    if args.finalize_ground:finalize()
