"""Original Ice161 source candidate, own mesh/map and explicit Acid158 motions.

Preparation stays under work until explicitly staged; never accepts a route.
No source executable is run and no original/derived artwork is publishable.
"""
import argparse
import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/third-dawn/late-source-research/uoaos-source'
WORK=ROOT/'work/creatures/ice-elemental'
MANIFEST=ROOT/'scripts/source-ice-elemental-inputs.json'
KIND='elementals_ice_elemental'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):return json.loads(path.read_text(encoding='utf-8'))

def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/file);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value

def inputs(cabinet_members=False):
    pins=read(MANIFEST);cabs=SOURCE.parent/'uoaos-cabinets'
    for row in pins['cabinets']:
        path=cabs/Path(row['zip_member']).name
        assert path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],path.name
    for row in pins['files']:
        path=(SOURCE/row['path']).resolve()
        assert path.is_relative_to(SOURCE.resolve()) and path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],row['path']
    native=ROOT/'Server/ModernUO'/pins['native_source']['path']
    assert sha(native)==pins['native_source']['sha256']
    if cabinet_members:
        seven=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        target=WORK/'cabinet-members'
        for folder,cab in [('Models','client7.cab'),('Models/Monsters','client11.cab'),('Models/Maps','client10.cab')]:
            rows=[r for r in pins['files'] if Path(r['path']).parent.as_posix()==folder]
            out=(target/folder).resolve();assert out.is_relative_to(WORK.resolve());out.mkdir(parents=True,exist_ok=True)
            subprocess.run([seven,'e','-y','-o'+str(out),str(cabs/cab),*[Path(r['path']).name for r in rows]],check=True,stdout=subprocess.DEVNULL)
            for row in rows:assert sha(out/Path(row['path']).name)==row['sha256'],row['path']
    return pins

def prepare(cabinet_members=False,stage_art=False):
    pins=inputs(cabinet_members);p=module('original_ice_pipeline','prepare-creatures.py');floor=module('original_ice_floor','prepare-source-elementals.py')
    output=WORK/'prepared';output.mkdir(parents=True,exist_ok=True);p.OUTPUT=output
    assert not (output/(KIND+'-albedo-v1.png')).exists(),'Source-only trial cannot consume an unpinned generated atlas'
    class InstalledData:
        def __init__(self):self.paths={'uoaos/UOTD/'+r['path']:SOURCE/r['path'] for r in pins['files']}
        def read(self,name):return self.paths[name].read_bytes()
    source=InstalledData();names={name.casefold():name for name in source.paths};table=p.table_rows((SOURCE/'Models/models.txt').read_bytes());server_pin,native=p.native_bodies()
    def model(kind):
        raw=(SOURCE/'Models/Monsters'/(kind+'_lod2.grn')).read_bytes();value=p.td.parse(raw,scene_root_names=True);value,_=p.normalise_bind(raw,value);value,_=p.visible_vertices(value);return value
    contract=p.reuse.assert_exact_contract(model(KIND),model('elementals_acid_elemental'))
    def aliases(body,clips,authored,labels,stem):
        assert stem==KIND and 'Stomp' in clips and 'Cast2' in clips
        clips['Pillage']=copy.deepcopy(clips['Stomp']);labels['Pillage']='Stomp: explicit source ground-slap reuse, not recovered pillaging choreography';return False
    p.humanoid_actions.install=aliases;p.reuse.RECIPES[KIND]={'floor_sample_rate':240,'measure_motion_bounds':True}
    rows=p.prepare('elementals',source,names,table,native,selected_kinds=[KIND]);assert len(rows)==1 and rows[0]['status']=='prepared',rows
    row=rows[0];assert len(row['clip_sources'])==12 and not row['rejected_source_clips']
    identity=row['bodies'][0];assert identity['body']==161 and identity['animation_body']==158 and identity['scale']==[1.3]*3
    original=output/(KIND+'-original-albedo.png');gaits={}
    for treatment in ['original','rounded','modern']:
        doc=read(output/(KIND+'-'+treatment+'.gltf'));gaits[treatment]=floor.constant_run_floor(doc)
        doc['images'][0]['uri']='data:image/png;base64,'+base64.b64encode(original.read_bytes()).decode()
        for material in doc['materials']:material['pbrMetallicRoughness'].update(metallicFactor=0.,roughnessFactor=.3)
        (output/(KIND+'-'+treatment+'.gltf')).write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
        if treatment!='modern':row['stats'][treatment]['clips']['Run'].update(floor_policy='source_vertical',floor_offset_range=[gaits[treatment]['constant_source_z']]*2)
    row.update(source_family=row['family'],family='ice_elementals',source_atlas_texture=original.name,
               modern_atlas=str(original.relative_to(ROOT)),atlas_sha256=sha(original),
               source_motion_contract=contract,vertical_gait_policy=gaits,
               source_motion_assignment='Own Ice161 mesh/UV/34-joint rig and opaque128RGBA map; table explicitly selects original Acid158 motions at1.3scale.',
               classic_action_categories={'12':'Cast2','14':'Cast2'},new_action_categories={'1':'Hit','2':'Hit','5':'Fidget','11':'Cast2','14':'Pillage'},
               mask_scope=pins['mask_scope'],surface_scope='Retained original RGB/UV/opaque diffuse. Mask meaning, dedicated authored ice PBR, source/cache precision and actual rendering remain unproved.',
               pending_features='Source/weighted-skin/cache fidelity, grounded and airborne transitions, actual avatar/hue/picking/corpse/death routing, ice material and separate native behaviour/render acceptance remain.')
    row['authored_source_reuse']['method']='Authored refinement/review-floor sampling policy; own mesh and animation158 assignment are explicitly declared by the source table. No recovered shader or original-client floor algorithm claimed.'
    assets={name:sha(output/name) for name in [KIND+'-'+t+'.gltf' for t in ['original','rounded','modern']]+[original.name]}
    tools=['prepare-source-ice-elemental.py','prepare-creatures.py','prepare-source-elementals.py','import-third-dawn.py','third-dawn-subdivide.py','creature-source-reuse.py']
    report={'models':rows,'family':'ice_elementals','server_pin':server_pin,'input_manifest_sha256':sha(MANIFEST),
            'source_tools_sha256':{name:sha(ROOT/'scripts'/name) for name in tools},'assets_sha256':assets,
            'source_url':pins['source_url'],'source_cabinets':pins['cabinets'],'scope':'Private original Ice161 source preparation only; twelve named original motion files include two identical original collapse files. Explicit Pillage reuse, no renderer/native/GPU/terrain/family acceptance or artwork redistribution.'}
    (output/'preparation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    if stage_art:
        art=ROOT/'Viewer/local-art/creatures';folder=art/'ice_elementals';folder.mkdir(parents=True,exist_ok=True)
        for name in assets:shutil.copyfile(output/name,art/name)
        shutil.copyfile(output/'preparation.json',folder/'preparation.json')
    print('ORIGINAL ICE SOURCE PREPARED: own34-joint mesh/atlas,12named source motions, constant Run anchor; no accepted route')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ['check-inputs','cabinet-members','prepare','stage-art']:parser.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    if args.stage_art and not args.prepare:parser.error('--stage-art requires --prepare so the staged source is regenerated and verified')
    if args.prepare:prepare(args.cabinet_members,args.stage_art)
    else:inputs(args.cabinet_members);print('ICE INPUTS:3cabinets/17exact source members/native constructor pins verified')
