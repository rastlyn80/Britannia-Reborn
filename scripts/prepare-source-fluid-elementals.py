"""Prepare private original Acid/Poison Elementals, never accept a route."""
import argparse,copy,hashlib,importlib.util,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/third-dawn/late-source-research/uoaos-source'
CABINETS=SOURCE.parent/'uoaos-cabinets'
WORK=ROOT/'work/creatures/elemental-variants/acid-poison/source-preparation'
ART=ROOT/'Viewer/local-art/creatures'
FAMILY='fluid_elementals'
KINDS={'elementals_acid_elemental':158,'elementals_poison_elemental':162}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/file);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
def inputs(extract=False):
    pins=read(ROOT/'scripts/source-fluid-elemental-inputs.json')
    for row in pins['cabinets']:
        p=CABINETS/Path(row['zip_member']).name;assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],'Changed original cabinet:'+p.name
    if extract:
        program=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for filename,folder,patterns in [('client7.cab','Models',['models.txt']),('client11.cab','Models/Monsters',['elementals_acid_elemental*.grn','elementals_poison_elemental_lod2.grn']),('client10.cab','Models/Maps',['elementals_acid_elemental.tga','elementals_poison_elemental.tga'])]:
            target=SOURCE/folder;target.mkdir(parents=True,exist_ok=True);subprocess.run([program,'e','-y','-o'+str(target),str(CABINETS/filename),*patterns],check=True,stdout=subprocess.DEVNULL)
    for row in pins['files']:
        p=(SOURCE/row['path']).resolve();assert p.is_relative_to(SOURCE.resolve()) and p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],'Changed source:'+row['path']
    return pins
def prepare():
    pins=inputs();p=module('fluid_elemental_pipeline','prepare-creatures.py');floor=module('fluid_elemental_floor','prepare-source-elementals.py');staging=WORK/'prepared';staging.mkdir(parents=True,exist_ok=True);p.OUTPUT=staging
    class InstalledData:
        def __init__(self):self.paths={'uoaos/UOTD/'+row['path']:SOURCE/row['path'] for row in pins['files']}
        def read(self,name):return self.paths[name].read_bytes()
    source=InstalledData();names={n.casefold():n for n in source.paths};table=p.table_rows((SOURCE/'Models/models.txt').read_bytes());server_pin,native=p.native_bodies()
    def model(kind):
        raw=(SOURCE/'Models/Monsters'/(kind+'_lod2.grn')).read_bytes();value=p.td.parse(raw,scene_root_names=True);value,_=p.normalise_bind(raw,value);value,_=p.visible_vertices(value);return value
    contract=p.reuse.assert_exact_contract(model('elementals_poison_elemental'),model('elementals_acid_elemental'))
    def aliases(body,clips,authored,labels,stem):
        assert stem in KINDS and 'Cast2' in clips and 'Stomp' in clips
        clips['Pillage']=copy.deepcopy(clips['Stomp']);labels['Pillage']='Stomp: explicit source ground-slap reuse, not recovered pillaging choreography';return False
    p.humanoid_actions.install=aliases
    for kind in KINDS:p.reuse.RECIPES[kind]={'floor_sample_rate':240,'measure_motion_bounds':True}
    rows=p.prepare('elementals',source,names,table,native,selected_kinds=list(KINDS));assert len(rows)==2 and all(r['status']=='prepared' and len(r['clip_sources'])==12 and not r['rejected_source_clips'] for r in rows)
    for row in rows:
        kind=row['kind'];assert row['bodies'][0]['body']==KINDS[kind] and row['bodies'][0]['scale']==[1.3]*3
        original=staging/(kind+'-original-albedo.png');shutil.copyfile(original,ART/original.name);gaits={}
        for treatment in ['original','rounded','modern']:
            doc=read(staging/(kind+'-'+treatment+'.gltf'));gaits[treatment]=floor.constant_run_floor(doc)
            for material in doc['materials']:material['pbrMetallicRoughness'].update(metallicFactor=0.,roughnessFactor=.8)
            (ART/(kind+'-'+treatment+'.gltf')).write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
            if treatment!='modern':row['stats'][treatment]['clips']['Run'].update(floor_policy='source_vertical',floor_offset_range=[gaits[treatment]['constant_source_z']]*2)
        script='res://Presentation/SourceFluidElementalVisual.gd'
        row.update(family=FAMILY,contact_kind='source_fluid_elemental',presentation_script=script,presentation_script_sha256=sha(ROOT/'Viewer/Presentation/SourceFluidElementalVisual.gd'),source_atlas_texture=original.name,source_opacity_scope='Original128square RGBA/opaque input retained; no cutout recovery claimed',art_dependency_sha256={original.name:sha(original)},surface='Retained original RGB/UV/opacity plus authored procedural wet-gel grain, reflectance, faint emission and controlled fluid clock; no generated bitmap or recovered native shader',loop_categories=['Idle','Walk','Run','Fidget'],classic_action_categories={'12':'Cast2','14':'Cast2'},new_action_categories={'2':'Hit','5':'Fidget','11':'Cast2','14':'Pillage'},appearance_pose_fit=True,camera_height=1.45,source_motion_contract=contract,source_motion_assignment='Original Acid158 motions, explicitly selected by Poison162 model-table animation_body158; own original mesh/atlas retained',vertical_gait_policy=gaits,preparation_recipe={'path':'scripts/prepare-source-fluid-elementals.py','sha256':sha(Path(__file__))},gait_scope='Retained source joint channels and Run vertical rise with one whole-clip anchor; measured soles and mixed-skin death support inherited from accepted original elemental renderer. Native/terrain/final art require separate checks.')
        row['motion_bound_diagonal_m']=max(c['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for c in stats['clips'].values())*1.1
    report={'family':FAMILY,'models':rows,'source_url':pins['source_url'],'source_cabinets':pins['cabinets'],'server_pin':server_pin,'input_manifest_sha256':sha(ROOT/'scripts/source-fluid-elemental-inputs.json'),'recipe_sha256':sha(Path(__file__)),'floor_helper_sha256':sha(ROOT/'scripts/prepare-source-elementals.py'),'source_pipeline_sha256':sha(ROOT/'scripts/prepare-creatures.py'),'scope':'Private original Acid158/Poison162, own maps/meshes/34source joints and12source motions plus explicit Pillage reuse. Prepared only; no native/route/corpse/terrain/complete choreography/final art acceptance. All original/derived artwork excluded from publication.'}
    folder=ART/FAMILY;folder.mkdir(parents=True,exist_ok=True);(folder/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('ORIGINAL FLUID ELEMENTALS PREPARED:2source meshes/34joints/12motions; no accepted route')
def refresh_support():
    inputs();path=ART/FAMILY/'preparation.json';report=read(path)
    assert report['input_manifest_sha256']==sha(ROOT/'scripts/source-fluid-elemental-inputs.json') and report['source_pipeline_sha256']==sha(ROOT/'scripts/prepare-creatures.py') and report['floor_helper_sha256']==sha(ROOT/'scripts/prepare-source-elementals.py')
    report['recipe_sha256']=sha(Path(__file__))
    for row in report['models']:row['presentation_script_sha256']=sha(ROOT/'Viewer/Presentation/SourceFluidElementalVisual.gd');row['preparation_recipe']['sha256']=report['recipe_sha256']
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs','extract','prepare','refresh-support']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    if args.extract:inputs(True)
    if args.check_inputs:inputs();print('FLUID SOURCE INPUTS:3exact cabinets/original member pins verified')
    if args.prepare:prepare()
    if args.refresh_support:refresh_support()
