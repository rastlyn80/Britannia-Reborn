"""Original later-client SnowElemental; prepare private candidates, never accept.

Uses exact preserved source meshes/maps/table-declared Acid motions. No game
executable is run. Original and generated game-derived artwork stays ignored.
"""
import argparse,base64,copy,hashlib,importlib.util,json,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/third-dawn/late-source-research/uoaos-source'
CABINETS=ROOT/'work/third-dawn/late-source-research/uoaos-cabinets'
WORK=ROOT/'work/creatures/snow-elemental'
ART=ROOT/'Viewer/local-art/creatures'
KIND='elementals_snow_elemental'
FAMILY='snow_elementals'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,value):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def module(name,filename):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/filename);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
def inputs(extract=False):
    pins=read(ROOT/'scripts/source-elemental-inputs.json')
    for row in pins['cabinets']:
        path=CABINETS/Path(row['zip_member']).name
        assert path.is_file() and path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],'Changed/missing cabinet:'+path.name
    if extract:
        program=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for filename,folder,pattern in [('client7.cab','Models','models.txt'),('client11.cab','Models/Monsters','*.grn'),('client10.cab','Models/Maps','*.tga')]:
            target=SOURCE/folder;target.mkdir(parents=True,exist_ok=True);subprocess.run([program,'e','-y','-o'+str(target),str(CABINETS/filename),pattern],check=True,stdout=subprocess.DEVNULL)
    for row in pins['files']:
        path=(SOURCE/row['path']).resolve();assert path.is_relative_to(SOURCE.resolve()) and sha(path)==row['sha256'],'Changed source:'+row['path']
    return pins
def constant_run_floor(doc):
    """Retain the imported Run's vertical trajectory with one floor anchor.

    Every source joint channel/UV/skin remains unchanged. A per-frame floor
    correction cancels the running rise/fall. One maximum correction makes
    the complete clip nonpenetrating without cancelling its airborne phases.
    """
    animation=next(a for a in doc['animations'] if a['name']=='Run')
    channels=[c for c in animation['channels'] if c['target']=={'node':1,'path':'translation'}];assert len(channels)==1
    accessor=doc['accessors'][animation['samplers'][channels[0]['sampler']]['output']];assert accessor['type']=='VEC3' and accessor['componentType']==5126
    view=doc['bufferViews'][accessor['bufferView']];assert view['buffer']==0 and not view.get('byteStride')
    prefix='data:application/octet-stream;base64,';assert doc['buffers'][0]['uri'].startswith(prefix)
    data=bytearray(base64.b64decode(doc['buffers'][0]['uri'][len(prefix):],validate=True));offset=view.get('byteOffset',0)+accessor.get('byteOffset',0);count=accessor['count']
    values=[struct.unpack_from('<3f',data,offset+i*12) for i in range(count)];assert all(x==0. and y==0. for x,y,z in values)
    anchor=max(v[2] for v in values)
    for i in range(count):struct.pack_into('<3f',data,offset+i*12,0.,0.,anchor)
    accessor['min']=accessor['max']=[0.,0.,anchor];doc['buffers'][0]['uri']=prefix+base64.b64encode(data).decode()
    return {'source_correction_range':[min(v[2] for v in values),anchor],'constant_source_z':anchor,'samples':count,'method':'One nonpenetrating per-clip anchor; original imported joint channels and vertical trajectory retained. Not per-frame flattening or recovered original-client root simulation.'}
def prepare():
    pins=inputs();atlas=ROOT/pins['generated_albedo']['default_path'];assert sha(atlas)==pins['generated_albedo']['sha256']
    pipeline=module('original_elemental_pipeline','prepare-creatures.py');staging=WORK/'prepared';staging.mkdir(parents=True,exist_ok=True);pipeline.OUTPUT=staging
    class InstalledData:
        def __init__(self):self.paths={'uoaos/UOTD/'+p.relative_to(SOURCE).as_posix():p for p in SOURCE.rglob('*') if p.is_file()}
        def read(self,name):return self.paths[name].read_bytes()
    source=InstalledData();names={n.casefold():n for n in source.paths};table=pipeline.table_rows((SOURCE/'Models/models.txt').read_bytes());pin,native=pipeline.native_bodies()
    def model(stem):
        raw=(SOURCE/'Models/Monsters'/(stem+'_lod2.grn')).read_bytes();value=pipeline.td.parse(raw,scene_root_names=True);value,_=pipeline.normalise_bind(raw,value);value,_=pipeline.visible_vertices(value);return value
    donor=model('elementals_acid_elemental');contracts={}
    for stem in ['elementals_snow_elemental','elementals_ice_elemental','elementals_poison_elemental']:contracts[stem]=pipeline.reuse.assert_exact_contract(model(stem),donor)
    def aliases_only(body,clips,authored,aliases,stem):
        assert stem==KIND and 'Cast2' in clips and 'Stomp' in clips
        clips['Pillage']=copy.deepcopy(clips['Stomp']);aliases['Pillage']='Stomp: explicit source ground-slap reuse, not recovered pillaging choreography'
        return False
    pipeline.humanoid_actions.install=aliases_only;pipeline.reuse.RECIPES[KIND]={'floor_sample_rate':240,'measure_motion_bounds':True}
    models=pipeline.prepare('elementals',source,names,table,native,selected_kinds=[KIND]);assert len(models)==1 and models[0]['status']=='prepared',models
    row=models[0];assert len(row['clip_sources'])==12 and not row['rejected_source_clips']
    original=staging/(KIND+'-original-albedo.png');ART.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,ART/original.name);gaits={}
    for treatment in ['original','rounded','modern']:
        doc=read(staging/(KIND+'-'+treatment+'.gltf'));gaits[treatment]=constant_run_floor(doc)
        if treatment=='modern':doc['images'][0]['uri']='data:image/png;base64,'+base64.b64encode(atlas.read_bytes()).decode()
        for material in doc['materials']:material['pbrMetallicRoughness'].update(metallicFactor=0.,roughnessFactor=.94)
        (ART/(KIND+'-'+treatment+'.gltf')).write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
        if treatment!='modern':row['stats'][treatment]['clips']['Run'].update(floor_policy='source_vertical',floor_offset_range=[gaits[treatment]['constant_source_z']]*2)
    script='res://Presentation/SourceElementalVisual.gd'
    row.update(family=FAMILY,contact_kind='source_elemental',presentation_script=script,presentation_script_sha256=sha(ROOT/'Viewer/Presentation/SourceElementalVisual.gd'),source_atlas_texture=original.name,source_opacity_scope='All128x128 original texels opaque; no cutout recovery claimed',art_dependency_sha256={original.name:sha(original)},modern_atlas=str(atlas.relative_to(ROOT)),atlas_sha256=sha(atlas),surface='Private granular compacted snow; authored diffuse frost/relief and partial body dye, original UV/rig',loop_categories=['Idle','Walk','Run','Fidget'],classic_action_categories={'12':'Cast2','14':'Cast2'},new_action_categories={'2':'Hit','5':'Fidget','11':'Cast2','14':'Pillage'},appearance_pose_fit=True,camera_height=1.45,source_motion_contract=contracts[KIND],source_variant_contracts=contracts,source_motion_assignment='Original model-table Snow163 animation_body158, Acid source motions; exact inspected source mesh/UV/rig contract',vertical_gait_policy=gaits,preparation_recipe={'path':'scripts/prepare-source-elementals.py','sha256':sha(Path(__file__))},gait_scope='Retained source Walk/Run, Run vertical trajectory preserved with a constant per-clip floor anchor; physical stance-speed/no-slip validation pending.')
    row['motion_bound_diagonal_m']=max(c['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for c in stats['clips'].values())*1.1
    row['terrain_sole_policy']='Lowest skinned point against each actual contacted plane; retain source flat foot lift and original limb lengths.'
    row['death_blend_support']='Temporary negative-only complete-skin model-root lift during the death crossfade; retained source local channels and positive Run rise. Uses cached unique skin points; steady poses keep imported support.'
    report={'family':FAMILY,'models':models,'source_url':pins['source_url'],'source_cabinets':pins['cabinets'],'input_manifest_sha256':sha(ROOT/'scripts/source-elemental-inputs.json'),'recipe_sha256':sha(Path(__file__)),'source_pipeline_sha256':sha(ROOT/'scripts/prepare-creatures.py'),'server_pin':pin,'scope':'Private actual later Snow source body/34joints/12table-declared Acid motions and explicitly aliased Pillage. Original/source-derived art not redistributable. Prepared only: no accepted/native/final-art/complete-original-client simulation claim.'}
    write(ART/FAMILY/'preparation.json',report);print('ORIGINAL SNOW PREPARED:240Hz,34joints,12source motions; Run rise retained; no accepted route')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs','extract','prepare']:p.add_argument('--'+name,action='store_true')
    args=p.parse_args()
    if args.extract:inputs(True)
    if args.check_inputs:inputs();print('ORIGINAL ELEMENTAL INPUTS:3cabinet/21originalmember pins verified')
    if args.prepare:prepare()
