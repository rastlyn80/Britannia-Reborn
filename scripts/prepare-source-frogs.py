"""Prepare private original BullFrog/GiantToad meshes; never accept a route."""
import argparse,base64,copy,hashlib,importlib.util,json,math,shutil,struct,subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/third-dawn/late-source-research/uoaos-source'
CABINETS=SOURCE.parent/'uoaos-cabinets'
WORK=ROOT/'work/creatures/frogs/source-preparation'
ART=ROOT/'Viewer/local-art/creatures'
KINDS=('frogs_frog_giant','frogs_bullfrog')

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def inputs(extract=False):
    pins=read(ROOT/'scripts/source-frog-inputs.json')
    for row in pins['cabinets']:
        path=CABINETS/Path(row['zip_member']).name
        assert path.is_file() and path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],'Changed cabinet: '+path.name
    if extract:
        program=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for filename,folder,pattern in [('client7.cab','Models','models.txt'),('client8.cab','Models/Animals','frogs_bullfrog_*.grn'),('client11.cab','Models/Monsters','frogs_frog_giant_*.grn'),('client10.cab','Models/Maps','frogs_frog_giant_v01.tga')]:
            target=SOURCE/folder;target.mkdir(parents=True,exist_ok=True)
            subprocess.run([program,'e','-y','-o'+str(target),str(CABINETS/filename),pattern],check=True,stdout=subprocess.DEVNULL)
    for row in pins['files']:
        path=(SOURCE/row['path']).resolve()
        assert path.is_relative_to(SOURCE.resolve()) and path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],'Changed frog input: '+row['path']
    return pins

def constant_floor(doc,label):
    """Keep the complete imported hop with one nonpenetrating clip anchor."""
    animation=next(a for a in doc['animations'] if a['name']==label)
    channels=[c for c in animation['channels'] if c['target']=={'node':1,'path':'translation'}];assert len(channels)==1
    accessor=doc['accessors'][animation['samplers'][channels[0]['sampler']]['output']]
    view=doc['bufferViews'][accessor['bufferView']]
    assert accessor['type']=='VEC3' and accessor['componentType']==5126 and view['buffer']==0 and not view.get('byteStride')
    prefix='data:application/octet-stream;base64,';assert doc['buffers'][0]['uri'].startswith(prefix)
    data=bytearray(base64.b64decode(doc['buffers'][0]['uri'][len(prefix):],validate=True));offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
    values=[struct.unpack_from('<3f',data,offset+i*12) for i in range(accessor['count'])];assert all(x==0. and y==0. for x,y,z in values)
    anchor=max(v[2] for v in values)
    for i in range(accessor['count']):struct.pack_into('<3f',data,offset+i*12,0.,0.,anchor)
    accessor['min']=accessor['max']=[0.,0.,anchor];doc['buffers'][0]['uri']=prefix+base64.b64encode(data).decode()
    return {'source_correction_range':[min(v[2] for v in values),anchor],'constant_source_z':anchor,'samples':len(values),'method':'One maximum floor correction for the whole source clip; original local joint channels and vertical trajectory retained, not per-frame flattening or original-client root simulation.'}

def tongue_colours(doc):
    """A semantic scalar on the existing skin, not guessed atlas coordinates."""
    prefix='data:application/octet-stream;base64,';assert len(doc['buffers'])==1 and doc['buffers'][0]['uri'].startswith(prefix)
    data=bytearray(base64.b64decode(doc['buffers'][0]['uri'][len(prefix):],validate=True))
    def accessor(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];assert v['buffer']==0 and not a.get('sparse')
        n={'VEC4':4}[a['type']];code={5126:'f',5123:'H',5121:'B'}[a['componentType']];size=struct.calcsize('<'+code*n)
        offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size)
        return [struct.unpack_from('<'+code*n,data,offset+i*stride) for i in range(a['count'])]
    names=[doc['nodes'][j]['name'] for j in doc['skins'][0]['joints']];selected={'bip01 ponytail12','bip01 ponytail13'};assert selected<=set(names)
    total=0;coloured=0;highest=0.
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attributes=primitive['attributes'];assert 'COLOR_0' not in attributes
            bindings=accessor(attributes['JOINTS_0']);weights=accessor(attributes['WEIGHTS_0']);assert len(bindings)==len(weights)
            values=[max(0.,min(1.,sum(w for j,w in zip(indices,ratios) if names[j] in selected))) for indices,ratios in zip(bindings,weights)]
            total+=len(values);coloured+=sum(v>.01 for v in values);highest=max(highest,max(values))
            while len(data)%4:data.append(0)
            offset=len(data)
            for value in values:data.extend(struct.pack('<4f',value,0.,0.,1.))
            view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(values)*16,'target':34962})
            index=len(doc['accessors']);doc['accessors'].append({'bufferView':view,'componentType':5126,'count':len(values),'type':'VEC4','min':[min(values),0.,0.,1.],'max':[max(values),0.,0.,1.]});attributes['COLOR_0']=index
    assert 0<coloured<total and highest>.9
    doc['buffers'][0].update(uri=prefix+base64.b64encode(data).decode(),byteLength=len(data))
    return {'source_bones':sorted(selected),'coloured_vertices':coloured,'total_vertices':total,'maximum_mask':highest,'method':'Sum of retained terminal appendage-chain skin weights in COLOR.r, authored moist pink tongue treatment. Original UVs/positions/weights/joints unchanged; no recovered original material or dye mask.'}

def alert_clip(body,idle,h):
    """A bounded head-up scan on the original idle rig, not a recovered clip."""
    baseline=h.Pose(body,idle);up=[0.,0.,1.]
    left=h.unit(h.sub(baseline.world('bip01 l clavicle')[1],baseline.world('bip01 r clavicle')[1]))
    probe=h.Pose(body,idle);probe.turn('bip01 neck',left,.14)
    sign=1. if probe.world('bip01 head')[1][2]>=baseline.world('bip01 head')[1][2] else -1.
    result=copy.deepcopy(idle);source={b['name']:b for b in idle['bones']}
    result['bones']=[dict(b,translation=source.get(b['name'],b)['translation'],rotation=source.get(b['name'],b)['rotation']) for b in body['bones']]
    result['tracks']=[{'name':b['name'],'translation':{'times':[],'values':[]},'rotation':{'times':[],'values':[]}} for b in body['bones']]
    for frame in range(73):
        u=frame/72.;amount=h.smooth(u/.22)*(1.-h.smooth((u-.72)/.28));pose=h.Pose(body,idle)
        pose.turn('bip01 neck',left,.14*sign*amount);pose.turn('bip01 head',up,.14*math.sin(math.tau*u)*amount)
        for i,track in enumerate(result['tracks']):
            for channel,value in [('translation',pose.positions[i]),('rotation',pose.rotations[i])]:
                track[channel]['times'].append(1.2*u);track[channel]['values'].append(list(value))
    return result

def prepare():
    pins=inputs();atlas=ROOT/pins['generated_albedo']['default_path'];assert sha(atlas)==pins['generated_albedo']['sha256']
    assert sha(ROOT/pins['generated_albedo']['prompt_path'])==pins['generated_albedo']['prompt_sha256']
    assert read(ROOT/pins['generated_albedo']['provenance_path'])['output_sha256']==sha(atlas)
    spec=importlib.util.spec_from_file_location('original_frog_pipeline',ROOT/'scripts/prepare-creatures.py');pipeline=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipeline)
    staging=WORK/'prepared';staging.mkdir(parents=True,exist_ok=True);pipeline.OUTPUT=staging
    class InstalledData:
        def __init__(self):self.paths={'uoaos/UOTD/'+row['path']:SOURCE/row['path'] for row in pins['files']}
        def read(self,name):return self.paths[name].read_bytes()
    source=InstalledData();names={name.casefold():name for name in source.paths};table=pipeline.table_rows((SOURCE/'Models/models.txt').read_bytes());server_pin,native=pipeline.native_bodies()
    rows={r['body']:r for r in table if r['body'] in (80,81)}
    assert rows[80]['stem']==KINDS[0] and rows[81]['stem']==KINDS[1] and rows[81]['animation_body']==80
    assert rows[80]['scale']==[1.3]*3 and rows[81]['scale']==[.8]*3
    # The authoritative81->80 link crosses Animals/Monsters. Input aliases
    # resolve to actual original archive members in all reads and receipts.
    # No invented duplicate archive member or bind-rig equality is asserted.
    for kind in KINDS:pipeline.reuse.RECIPES[kind]={'floor_sample_rate':240,'measure_motion_bounds':True}
    pipeline.reuse.RECIPES[KINDS[1]]['clip_stem']='../monsters/frogs_frog_giant'
    for actual in source.paths:
        if '/Models/Monsters/frogs_frog_giant_' in actual and not actual.endswith('_lod2.grn'):
            names[('uoaos/UOTD/Models/Animals/../Monsters/'+actual.rsplit('/',1)[1]).casefold()]=actual
    def frog_actions(body,clips,authored,aliases,stem):
        assert stem in KINDS and 'Fidget' in clips and 'Attack' in clips
        for target,source,label in [('Eat','Fidget','Retained tongue-snap fidget used as a feeding category, not a recovered original Eat clip'),('Attack2','Attack','Retained source tongue strike reused for the second native attack category'),('Death2','Death','Retained source collapse reused for the alternate native death category')]:
            clips[target]=copy.deepcopy(clips[source]);aliases[target]=source+': '+label
        clips['Alert']=alert_clip(body,clips['Idle'],pipeline.humanoid_actions);authored['Alert']='Authored bounded head-up scan on the original idle pose, with fixed source limb/jaw channels; not recovered UO choreography'
        return False
    pipeline.humanoid_actions.install=frog_actions
    models=pipeline.prepare('frogs',source,names,table,native,selected_kinds=list(KINDS))
    assert len(models)==2 and all(row['status']=='prepared' and len(row['clip_sources'])==7 and not row['rejected_source_clips'] for row in models)
    ART.mkdir(parents=True,exist_ok=True)
    for row in models:
        kind=row['kind'];policies={}
        original=staging/(kind+'-original-albedo.png');shutil.copyfile(original,ART/original.name)
        for treatment in ['original','rounded','modern']:
            doc=read(staging/(kind+'-'+treatment+'.gltf'))
            policies[treatment]={clip:constant_floor(doc,clip) for clip in ['Walk','Run']}
            if treatment=='modern':
                doc['images'][0]['uri']='data:image/png;base64,'+base64.b64encode(atlas.read_bytes()).decode()
                row['tongue_material_mask']=tongue_colours(doc)
            for material in doc['materials']:material.update(alphaMode='MASK',alphaCutoff=.12)
            (ART/(kind+'-'+treatment+'.gltf')).write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
            if treatment!='modern':
                for clip in ['Walk','Run']:row['stats'][treatment]['clips'][clip].update(floor_policy='source_vertical',floor_offset_range=[policies[treatment][clip]['constant_source_z']]*2)
        script='res://Presentation/SourceFrogVisual.gd'
        row.update(vertical_gait_policy=policies,modern_atlas=str(atlas.relative_to(ROOT)),atlas_sha256=sha(atlas),source_atlas_texture=original.name,art_dependency_sha256={original.name:sha(original)},source_motion_assignment='Original table BullFrog81 explicitly selects GiantToad80 motions across Animals/Monsters; each original mesh and its distinct forelimb bind rig retained.',preparation_recipe={'path':'scripts/prepare-source-frogs.py','sha256':sha(Path(__file__))},gait_scope='Original imported Walk/Run trajectories retained; terrain/contact/physical cadence and no-slip not certified by preparation.',presentation_script=script,presentation_script_sha256=sha(ROOT/'Viewer/Presentation/SourceFrogVisual.gd'),contact_kind='source_frog',limb_support='quadruped',appearance_pose_fit=True)
        row['motion_bound_diagonal_m']=max(c['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for c in stats['clips'].values())*1.1
        row['action_support_sha256']=sha(ROOT/'scripts/creature-humanoid-actions.py')
        row.update(source_alpha_texture=original.name,source_alpha_scope='fine_edges',source_alpha_policy='Original64-square graded alpha retained with an authored0.12 cutout threshold; not an exact original-client blending reconstruction.')
    write(ART/'frogs/preparation.json',{'family':'frogs','models':models,'source_url':pins['source_url'],'source_cabinets':pins['cabinets'],'server_pin':server_pin,'input_manifest_sha256':sha(ROOT/'scripts/source-frog-inputs.json'),'recipe_sha256':sha(Path(__file__)),'source_pipeline_sha256':sha(ROOT/'scripts/prepare-creatures.py'),'scope':'Private actual original BullFrog81/GiantToad80, distinct source bind meshes/UVs/scales and seven original motions. Prepared only, no route/native/corpse/terrain/final-art acceptance. Original and derived game artwork excluded from publication.'})
    print('ORIGINAL FROGS PREPARED:2original meshes/27joints/7source motions,240Hz,retained Walk/Run rise; no accepted route')

def finalize_ground():
    """Attach measured small Hit corrections, leaving both hopping clips alone."""
    path=ART/'frogs/preparation.json';report=read(path);measurement=ROOT/'work/creatures/frogs/hit-calibration.json';bake=read(measurement)
    assert report['recipe_sha256']==sha(Path(__file__)) and bake['preparation_sha256']==sha(path)
    assert bake['sample_rate']==960 and bake['recipe_sha256']==sha(ROOT/'Viewer/Presentation/BakeSourceFrogGround.gd') and bake['geometry_sha256']==sha(ROOT/'Viewer/Presentation/SourceGroundLookup.gd')
    assert {(r['kind'],r['treatment']) for r in bake['records']}=={(kind,t) for kind in KINDS for t in ['original','rounded','modern']}
    for row in report['models']:
        treatments={}
        for record in [r for r in bake['records'] if r['kind']==row['kind']]:
            asset=ART/(row['kind']+'-'+record['treatment']+'.gltf')
            assert record['asset_sha256']==sha(asset) and record['import_sha256']==sha(Path(str(asset)+'.import'))
            assert record['clip']=='Hit' and len(record['samples'])>=1000 and max(abs(v[1]) for v in record['samples'])<.03
            treatments[record['treatment']]={'clips':{'Hit':[[time,-gap] for time,gap in record['samples']]}}
        ground=ART/(row['kind']+'-hit-ground.json')
        write(ground,{'sample_rate':960,'treatments':treatments,'measurement_sha256':sha(measurement),'scope':'Measured imported complete-skin residual floor correction for Hit only; source local joint channels unchanged. Walk/Run anchors and positive hops are untouched. Not original-client floor simulation.'})
        row.update(ground_lookup='res://local-art/creatures/'+ground.name,ground_lookup_sha256=sha(ground),ground_lookup_scope='Small residual imported Hit correction only, measured at960Hz; preserve all positive Walk/Run source rise')
    report['ground_measurement']={'path':str(measurement.relative_to(ROOT)),'sha256':sha(measurement),'recipe_sha256':bake['recipe_sha256'],'geometry_sha256':bake['geometry_sha256']};write(path,report)
    print('FROG HIT GROUND FINALIZED:actual960Hz residual curves, original Walk/Run untouched; acceptance still requires holdout/avatar/native proof')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs','extract','prepare','finalize-ground']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    if args.extract:inputs(True)
    if args.check_inputs:inputs();print('ORIGINAL FROG INPUTS:4cabinets/11original members verified')
    if args.prepare:prepare()
    if args.finalize_ground:finalize_ground()
