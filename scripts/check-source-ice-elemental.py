"""Exact original Ice source preparation/skin trial, never family acceptance."""
import hashlib
import argparse
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'work/creatures/ice-elemental'
ART=WORK/'prepared'
KIND='elementals_ice_elemental'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def candidate():
    folder=ROOT/'Viewer/local-art/creatures';path=folder/'ice_elementals/candidate.json'
    staged=read(path);row=staged['models'][0]
    assert staged['source_preparation_sha256']==sha(ART/'preparation.json') and staged['stage_recipe_sha256']==sha(ROOT/'scripts/stage-ice-elemental-candidate.py')
    assert row['status']=='prepared' and row['presentation_script']=='res://Presentation/SourceIceElementalVisual.gd' and row['presentation_script_sha256']==sha(ROOT/'Viewer/Presentation/SourceIceElementalVisual.gd')
    for name,digest in staged['assets_sha256'].items():
        assert Path(name).name==name and sha(folder/name)==digest==sha(ART/name),name
    proof=read(WORK/'import-fidelity.json');runtime=read(WORK/'runtime-tests.json');death=read(WORK/'death-tests.json');terrain=read(WORK/'terrain-tests.json')
    for trial in [proof,runtime,death,terrain]:
        assert trial['failures']==0 and trial['preparation_sha256']==sha(path)
        for name,digest in trial['runtime_sha256'].items():assert digest and sha(ROOT/'Viewer/Presentation'/name)==digest,name
    assert len(proof['records'])==507 and len(proof['meshes'])==3
    assert proof['maximum_position_error_m']<.001 and proof['maximum_basis_error']<.001 and proof['maximum_scale_error']<.00001 and proof['maximum_skin_error_bound_m']<.001
    for mesh in proof['meshes']:
        assert mesh['missing_exact_corners']==0 and mesh['same_winding_topology'] and mesh['atlas']['width']==mesh['atlas']['height']==128
    for name,digest in proof['assets_sha256'].items():assert digest and sha(ROOT/'Viewer'/name.removeprefix('res://'))==digest,name
    assert runtime['poses']==375 and len(runtime['requests'])==75 and len(runtime['gait_records'])==34
    assert runtime['unsupported_classic_groups']==[7,8,9,19,20] and len(runtime['corpses'])==4
    assert runtime['maximum_floor_error_m']<.008 and runtime['maximum_local_position_error_m']<.00001
    assert runtime['hues_sha256']==sha(ROOT/'Viewer/hues.local.json') and runtime['artwork_script_sha256']==sha(ROOT/'Viewer/Network/Artwork.gd')
    assert runtime['ground_measurement_sha256']==sha(folder/(KIND+'-ground.json'))
    for name,digest in runtime['assets_sha256'].items():assert digest==staged['assets_sha256'][name]
    assert len(death['cases'])==36 and sum(r['altered_source'] for r in death['cases'])==1
    assert all(r['first_skin_error_m']<.00001 and r['minimum_body_gap_m']>-.008 and r['maximum_collapse_error_m']<.008 for r in death['cases'])
    assert death['hues_sha256']==sha(ROOT/'Viewer/hues.local.json')
    for name,digest in death['network_sha256'].items():assert digest and sha(ROOT/'Viewer'/name.removeprefix('res://'))==digest
    for name,digest in death['ground_measurement_sha256'].items():assert sha(ROOT/'Viewer'/name.removeprefix('res://'))==digest
    assert terrain['poses']==9072 and len(terrain['cases'])==216 and not terrain['misses']
    assert terrain['maximum_skin_error_m']<.008 and terrain['maximum_foot_error_m']<.008 and terrain['ground_measurement_sha256']==sha(folder/(KIND+'-ground.json'))
    print(f"ICE161 CANDIDATE:{proof['checks']}import/{runtime['checks']}avatar/{terrain['checks']}finite-terrain/{death['checks']}client-death checks;507 saved/source pairs,375 avatar poses,9072 timed finite-plane poses,36 death cases. No native server, rendered/material-pixel, mixed ledge/spawn or family acceptance.")

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--candidate',action='store_true');args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('ice_source_preparer',ROOT/'scripts/prepare-source-ice-elemental.py');p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p);pins=p.inputs()
    prep=read(ART/'preparation.json');proof=read(WORK/'source-poses.json');ground=read(ART/(KIND+'-ground.json'));row=prep['models'][0]
    assert len(pins['files'])==17 and len(pins['cabinets'])==3 and prep['input_manifest_sha256']==sha(ROOT/'scripts/source-ice-elemental-inputs.json')
    for name,digest in prep['source_tools_sha256'].items():assert sha(ROOT/'scripts'/name)==digest,name
    for name,digest in prep['assets_sha256'].items():assert Path(name).name==name and sha(ART/name)==digest,name
    assert row['kind']==KIND and row['family']=='ice_elementals' and row['status']=='prepared' and not row['rejected_source_clips'] and not row['authored_replacements']
    body=row['bodies'][0];assert body['body']==161 and body['animation_body']==158 and body['scale']==[1.3]*3
    assert len(row['clip_sources'])==12 and len(row['category_aliases'])==1 and row['category_aliases']['Pillage'].startswith('Stomp:')
    assert row['stats']['original']['source_points']==183 and row['stats']['original']['bones']==34 and row['stats']['original']['triangles']==362 and row['stats']['rounded']['triangles']==5792
    assert row['source_motion_contract']['fields']==['points','normals','polygons','texture_polygons','uv_sets','weights','ties','bones']
    assert row['atlas_sha256']==sha(ART/(KIND+'-original-albedo.png'))
    assert proof['checks']==37849 and proof['failures']==0 and proof['poses']==663 and len(proof['records'])==663
    assert proof['maximum_relative_joint_error_m']<.00001 and proof['maximum_basis_error']<.00001 and proof['maximum_grounded_error_m']<.008
    assert proof['preparation_sha256']==ground['preparation_sha256']==sha(ART/'preparation.json') and proof['ground_measurement_sha256']==sha(ART/(KIND+'-ground.json'))
    for name,digest in proof['runtime_sha256'].items():assert sha(ROOT/'Viewer/Presentation'/name)==digest,name
    for name,digest in proof['assets_sha256'].items():assert sha(ROOT/'Viewer'/name.removeprefix('res://'))==digest,name
    assert ground['sample_rate']==960 and ground['recipe_sha256']==sha(ROOT/'Viewer/Presentation/BakeIceElementalGround.gd') and ground['geometry_sha256']==sha(ROOT/'Viewer/Presentation/SourceGroundLookup.gd')
    assert set(ground['treatments'])=={'original','rounded','modern'}
    for treatment,data in ground['treatments'].items():
        assert data['asset_sha256']==sha(ART/(KIND+'-'+treatment+'.gltf')) and len(data['clips'])==13
        assert all(float(sample[1])==0. for sample in data['clips']['Run'])
        if treatment!='modern':
            stats=row['stats'][treatment]['clips']['Run'];assert stats['floor_policy']=='source_vertical' and stats['floor_offset_range'][0]==stats['floor_offset_range'][1]
    assert all(r['body_floor_m']>-.008 and (r['clip']=='Run' or abs(r['body_floor_m'])<.008) for r in proof['records'])
    assert all(hi-lo>.05 for lo,hi in proof['run_floor_ranges_m'].values())
    print('ORIGINAL ICE SOURCE:37849checks/663weighted skins; exact17source members/three cabinets/own34-joint mesh128RGBA and declared158motions. Model-only residuals, unchanged source Run rise. No saved-import/material/native/render/terrain/avatar/death/corpse/family acceptance.')
    if args.candidate:candidate()
if __name__=='__main__':main()
