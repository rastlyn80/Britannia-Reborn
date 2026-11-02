"""Private original Solen warrior conversion with every source influence retained."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work/creatures/solen-warriors'
SOURCE=WORK/'source'
ART=ROOT/'Viewer/local-art/creatures'
MANIFEST=ROOT/'scripts/source-solen-warrior-inputs.json'
KINDS={'fire_ant_warrior':('fire',782,'RedSolenWarrior'),'black_ant_warrior':('black',806,'BlackSolenWarrior')}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/file);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
def inputs(extract=False):
    pins=json.loads(MANIFEST.read_text(encoding='utf-8'));cabs=ROOT/'work/third-dawn/late-source-research/uoaos-cabinets'
    for row in pins['cabinets']:
        path=cabs/Path(row['zip_member']).name
        assert path.stat().st_size==row['bytes'] and sha(path)==row['sha256']
    if extract:
        seven=shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
        for folder,cab in [('Monsters','client11.cab'),('Maps','client10.cab')]:
            target=SOURCE/folder;target.mkdir(parents=True,exist_ok=True)
            names=[Path(r['path']).name for r in pins['files'] if Path(r['path']).parent.as_posix()==folder]
            subprocess.run([seven,'e','-y','-o'+str(target),str(cabs/cab),*names],check=True,stdout=subprocess.DEVNULL)
    for row in pins['files']:
        path=(SOURCE/row['path']).resolve()
        assert path.is_relative_to(SOURCE.resolve()) and path.stat().st_size==row['bytes'] and sha(path)==row['sha256'],row['path']
    assert sha(ROOT/pins['model_table']['path'])==pins['model_table']['sha256']
    for row in pins['native_sources']:assert sha(ROOT/'Server/ModernUO'/row['path'])==row['sha256']
    return pins
def prepare():
    pins=inputs();pipeline=module('warrior_pipeline','prepare-creatures.py');repair=module('warrior_normals','solen-warrior-normals.py')
    pipeline.OUTPUT=WORK/'prepared';pipeline.OUTPUT.mkdir(parents=True,exist_ok=True)
    paths={'uoaos/UOTD/Models/'+r['path']:SOURCE/r['path'] for r in pins['files']}
    class OriginalInputs:
        def read(self,name):return paths[name].read_bytes()
    mesh_pins={r['sha256']:r for r in pins['files'] if r['path'].endswith('_lod2.grn')}
    strict_parse=pipeline.td.parse;normal_reports=[]
    def parse(raw,**options):
        digest=hashlib.sha256(raw).hexdigest()
        if digest not in mesh_pins:return strict_parse(raw,**options)
        fixed,report=repair.repair(raw,pipeline.td,digest,pins['normal_repair_indices']);normal_reports.append(report)
        return strict_parse(fixed,max_influences=8,**options)
    pipeline.td.parse=parse
    refine=pipeline.smooth.refine
    def refine_eight(source,**options):
        # Existing source vertices keep their complete original influence set.
        # New edge vertices blend all supports; overflow raises, never truncates.
        options['weight_smoothing']=0.
        return refine(source,max_influences=8,**options)
    pipeline.smooth.refine=refine_eight
    export=pipeline.td.export_gltf
    def export_eight(*args,**options):
        # Preserve source torso/root bounce rather than flattening each gait
        # frame. The six actual legs receive terrain support separately.
        options['preserve_vertical_clips']=[*options.get('preserve_vertical_clips',()),'Walk','Run']
        return export(*args,max_influences=8,**options)
    pipeline.td.export_gltf=export_eight
    pipeline.LABELS['fidget2']='Fidget2'
    table=pipeline.table_rows((ROOT/pins['model_table']['path']).read_bytes());server_pin,native=pipeline.native_bodies();models=[]
    for kind,(family,body,name) in KINDS.items():
        pipeline.reuse.RECIPES[kind]={'floor_sample_rate':240,'measure_motion_bounds':True}
        rows=pipeline.prepare(family,OriginalInputs(),{k.casefold():k for k in paths},table,native,selected_kinds={kind})
        assert len(rows)==1 and rows[0]['status']=='prepared',rows
        row=rows[0];assert not row['rejected_source_clips'] and row['stats']['original']['bones']==44
        assert len(row['clip_sources'])==10 and {r['body'] for r in row['bodies']}=={body}
        row.update(source_family=row['family'],family='solen_warriors',max_influences=8,
                   presentation_script='res://Presentation/SourceSolenWarriorVisual.gd',
                   movement_mode='ground_plane',contact_kind='source_solen',
                   ground_lookup='res://local-art/creatures/'+kind+'-ground.json',
                   source_atlas_texture=kind+'-original-albedo.png',
                   classic_action_categories={'18':'Fidget2'},
                   new_action_categories={'1':'Hit','2':'Hit','5':'Fidget'},
                   gait_scope='Original Walk/Run vertical channels and one whole-clip anchor retained. Six source distal legs provide separate stance support; no physical no-slip/native terrain claim.',
                   authored_normal_repair=next(r for r in normal_reports if r['source_sha256']==next(p['sha256'] for p in pins['files'] if p['path'].endswith(kind+'_lod2.grn'))),
                   pending_render_feature='Original source/weighted-skin/import, six-leg terrain, materials/hues/picking/corpse and separate native behaviour acceptance remain.')
        row['bodies'][0]['native_class']=name
        models.append(row)
    assets={};ART.mkdir(parents=True,exist_ok=True)
    for kind in KINDS:
        for suffix in ['-original.gltf','-rounded.gltf','-modern.gltf','-original-albedo.png']:
            name=kind+suffix;shutil.copyfile(pipeline.OUTPUT/name,ART/name);assets[name]=sha(ART/name)
    tools=['prepare-source-solen-warriors.py','solen-warrior-normals.py','import-third-dawn.py','third-dawn-subdivide.py','prepare-creatures.py','prepare-distinct-mounts.py','creature-source-reuse.py','creature-humanoid-actions.py','creature-affine.py']
    report=dict(models=models,family='solen_warriors',server_pin=server_pin,input_manifest_sha256=sha(MANIFEST),
                source_tools_sha256={name:sha(ROOT/'scripts'/name) for name in tools},assets_sha256=assets,source_url=pins['source_url'],scope=pins['scope'])
    folder=ART/'solen_warriors';folder.mkdir(parents=True,exist_ok=True);(folder/'preparation.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
    print('SOLEN WARRIORS PREPARED:two original44-joint meshes/ten motions; exact eight-slot export, no dropped source influences. No acceptance.')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--extract',action='store_true');parser.add_argument('--prepare',action='store_true');args=parser.parse_args()
    if args.extract:inputs(True)
    if args.prepare:prepare()
    else:inputs();print('SOLEN WARRIOR INPUTS:14original members/3cabinets/two native source declarations checked')
