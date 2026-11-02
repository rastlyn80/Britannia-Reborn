"""Prepare pinned later-client original Liches; never install an accepted route.

Original and derived game inputs remain private. Cabinet/source hashes describe
the inspected preservation copy, not a full remote ZIP/authenticity guarantee.
"""
import argparse,base64,hashlib,importlib.util,json,shutil,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work/creatures/lich'
SOURCE=ROOT/'work/third-dawn/late-source-research/uoaos-source'
CABINETS=ROOT/'work/third-dawn/late-source-research/uoaos-cabinets'
ART=ROOT/'Viewer/local-art/creatures'
KINDS=['liche_liche_retro','liche_liche_lord_retro']
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path,value):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def module(name,filename):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/filename);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
def inputs(extract=False):
    pins=read(ROOT/'scripts/lich-inputs.json')
    for cabinet in pins['cabinets']:
        path=CABINETS/Path(cabinet['zip_member']).name
        assert path.is_file() and sha(path)==cabinet['sha256'],'Missing/changed pinned cabinet: '+path.name
    if extract:
        program=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for filename,folder,pattern in [('client7.cab','Models','models.txt'),('client11.cab','Models/Monsters','*.grn'),('client10.cab','Models/Maps','*.tga'),('client12.cab','Models/Others','*.grn')]:
            destination=SOURCE/folder;destination.mkdir(parents=True,exist_ok=True)
            subprocess.run([program,'e','-y','-o'+str(destination),str(CABINETS/filename),pattern],check=True,stdout=subprocess.DEVNULL)
    for item in pins['files']:
        path=(SOURCE/item['path']).resolve();assert path.is_relative_to(SOURCE.resolve()) and sha(path)==item['sha256'],'Changed original input: '+item['path']
    return pins
def staff(pipeline):
    source=SOURCE/'Models/Others/weapon_liche_staff_lod2.grn';model,parts,proof=pipeline.rigid.read_rigid_parts(source.read_bytes(),pipeline.td,excluded_names=());assert len(parts)==1 and len(model['textures'])==1
    assert max(abs(v) for v in model['bones'][1]['translation'])<.000001 and abs(model['bones'][1]['rotation'][3])>.99999,'Unreviewed staff bind frame'
    texture=SOURCE/'Models/Maps'/model['textures'][0];png=pipeline.td.png_from_tga(texture.read_bytes());positions=[];normals=[];uv=[]
    for face,tex in zip(model['polygons'],model['texture_polygons'],strict=True):
        for corner in range(3):positions.append(model['points'][face[corner]]);normals.append(model['normals'][face[corner+3]]);uv.append(model['uv_sets'][-1][tex[corner]][:2])
    data=bytearray();views=[];accessors=[]
    def accessor(rows,width):
        offset=len(data);payload=struct.pack('<'+'f'*(len(rows)*width),*(v for row in rows for v in row));data.extend(payload);view=len(views);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(payload),'target':34962});index=len(accessors);accessors.append({'bufferView':view,'componentType':5126,'count':len(rows),'type':{2:'VEC2',3:'VEC3'}[width],'min':[min(row[i] for row in rows) for i in range(width)],'max':[max(row[i] for row in rows) for i in range(width)]});return index
    attributes={'POSITION':accessor(positions,3),'NORMAL':accessor(normals,3),'TEXCOORD_0':accessor(uv,2)}
    doc={'asset':{'version':'2.0','generator':'Britannia Reborn original rigid Liche staff'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':'OriginalLicheStaff','mesh':0}],'meshes':[{'name':'OriginalLicheStaff','primitives':[{'attributes':attributes,'material':0}]}],'materials':[{'name':'Original weapon atlas','doubleSided':True,'alphaMode':'MASK','alphaCutoff':.12,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0.,'roughnessFactor':.8}}],'images':[{'uri':'data:image/png;base64,'+base64.b64encode(png).decode()}],'samplers':[{}],'textures':[{'source':0,'sampler':0}],'bufferViews':views,'accessors':accessors,'buffers':[{'byteLength':len(data),'uri':'data:application/octet-stream;base64,'+base64.b64encode(data).decode()}]}
    path=ART/'liche-staff.gltf';path.write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
    return {'asset':'res://local-art/creatures/'+path.name,'asset_sha256':sha(path),'source_sha256':sha(source),'texture_source_sha256':sha(texture),'points':len(model['points']),'triangles':len(model['polygons']),'parts':proof,'relative_scale':.8,'authored_orientation':'Idle-up relative to source right grasp, ornament quarter-turn about staff axis','support':'Measured pole corner bounds; preserve wrist basis while raising reachable source arm only when the shaft intersects the model support plane','death':'Authored smooth release over normalized phases .05 to .75, source fingers restored and staff laid beside the final corpse at 3mm support clearance','interpretation':'Original later staff geometry/UVs/atlas, authored right-grasp body-art attachment/orientation and measured finger closure. Native Lich packs a GnarledStaff as loot; this is not a server-equipped or spawned item.'}
def prepare():
    pins=inputs();atlas=ROOT/pins['generated_albedo']['default_path'];assert sha(atlas)==pins['generated_albedo']['sha256'],'Missing/changed private generated Lich atlas'
    pipeline=module('liche_pipeline','prepare-creatures.py');gestures=module('liche_authored_actions','creature-lich-actions.py');staging=WORK/'prepared';staging.mkdir(parents=True,exist_ok=True);pipeline.OUTPUT=staging
    class InstalledData:
        def __init__(self):self.paths={'uoaos/UOTD/'+path.relative_to(SOURCE).as_posix():path for path in SOURCE.rglob('*') if path.is_file()}
        def read(self,name):return self.paths[name].read_bytes()
    source=InstalledData();names={name.casefold():name for name in source.paths};rows=pipeline.table_rows((SOURCE/'Models/models.txt').read_bytes());pin,native=pipeline.native_bodies()
    pipeline.humanoid_actions.install=lambda body,clips,authored,aliases,stem:gestures.install(body,clips,authored,aliases,stem,pipeline.humanoid_actions)
    for kind in KINDS:pipeline.reuse.RECIPES[kind]={'floor_sample_rate':120,'measure_motion_bounds':True}
    models=pipeline.prepare('liche',source,names,rows,native,selected_kinds=KINDS);assert len(models)==2 and all(row['status']=='prepared' for row in models),models
    ART.mkdir(parents=True,exist_ok=True);weapon=staff(pipeline)
    for row in models:
        kind=row['kind'];original=staging/(kind+'-original-albedo.png');shutil.copyfile(original,ART/original.name)
        for treatment in ['original','rounded','modern']:
            path=staging/(kind+'-'+treatment+'.gltf');doc=read(path)
            if treatment=='modern':doc['images'][0]['uri']='data:image/png;base64,'+base64.b64encode(atlas.read_bytes()).decode()
            for material in doc['materials']:material.update(alphaMode='MASK',alphaCutoff=.12)
            (ART/path.name).write_text(json.dumps(doc,separators=(',',':')),encoding='utf-8')
        row.update(family='liches',source_alpha_texture=original.name,source_alpha_scope='fine_edges',art_dependency_sha256={original.name:sha(original)},bounds_mode='weighted_skin',contact_kind='source_biped',staff_asset=weapon['asset'],staff=weapon,modern_atlas=str(atlas.relative_to(ROOT)),atlas_sha256=sha(atlas),surface='Private detailed woven cloth/desiccated skin, unchanged original cutouts; authored Lord accent tint and cloth partial dye region',loop_categories=['Idle','Walk','Run','Fidget'],classic_action_categories={'14':'Cast'},new_action_categories={'2':'Hit','5':'Fidget','14':'Pillage'},gait_scope='Retained source Walk/Run with inherited speed normalization; physical cadence/no-slip proof pending.',preparation_recipe={'path':'scripts/prepare-liches.py','sha256':sha(Path(__file__))})
        row['motion_bound_diagonal_m']=max(c['measured_max_pose_diagonal_m'] for stats in row['stats'].values() for c in stats['clips'].values())*1.1
        row['appearance_pose_fit']=True;row['authored_lich_action_recipe']={'path':'scripts/creature-lich-actions.py','sha256':sha(ROOT/'scripts/creature-lich-actions.py')}
    report={'family':'liches','models':models,'source_url':pins['source_url'],'source_cabinets':pins['cabinets'],'input_manifest_sha256':sha(ROOT/'scripts/lich-inputs.json'),'recipe_sha256':sha(Path(__file__)),'source_pipeline_sha256':sha(ROOT/'scripts/prepare-creatures.py'),'server_pin':pin,'scope':'Prepared original later Third Dawn Liches, not accepted/native coverage. Original seven motions plus explicitly authored four categories, original RGBA cutouts, modern private RGB and authored default staff/grip. No original particle simulation/full choreography/final art or redistribution claim.'}
    write(ART/'liches/preparation.json',report);print('LICHES PREPARED: exact original later bodies/36 joints/7 motions plus4 authored categories; actual avatar/material/action/terrain/corpse/native gates pending; no accepted route installed')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--extract',action='store_true');parser.add_argument('--prepare',action='store_true');parser.add_argument('--check-inputs',action='store_true');args=parser.parse_args()
    if args.extract:inputs(True)
    if args.check_inputs:inputs();print('LICH ORIGINAL INPUTS VERIFIED: exact4CAB/14source pins')
    if args.prepare:prepare()
