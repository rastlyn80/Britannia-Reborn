"""Exact original eight-influence Solen source preparation; no route acceptance."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main(runtime=False,terrain=False):
    spec=importlib.util.spec_from_file_location('warrior_preparation',ROOT/'scripts/prepare-source-solen-warriors.py');preparer=importlib.util.module_from_spec(spec);spec.loader.exec_module(preparer);pins=preparer.inputs()
    path=ART/'solen_warriors/preparation.json';prep=read(path);proof=read(ROOT/'work/creatures/solen-warriors/source-poses.json')
    assert prep['input_manifest_sha256']==sha(ROOT/'scripts/source-solen-warrior-inputs.json')
    for name,digest in prep['source_tools_sha256'].items():assert sha(ROOT/'scripts'/name)==digest,name
    for name,digest in prep['assets_sha256'].items():assert Path(name).name==name and sha(ART/name)==digest,name
    assert proof['checks']==765275 and proof['failures']==0 and proof['poses']==1380 and len(proof['records'])==1380
    assert proof['preparation_sha256']==sha(path) and proof['maximum_relative_joint_error_m']<.00001 and proof['maximum_basis_error']<.00001 and proof['maximum_floor_error_m']<.008
    for name,digest in proof['runtime_sha256'].items():assert sha(ROOT/'Viewer/Presentation'/name)==digest,name
    for path,digest in proof['assets_sha256'].items():assert sha(ROOT/'Viewer'/path.removeprefix('res://'))==digest,path
    assert {r['kind'] for r in prep['models']}=={'fire_ant_warrior','black_ant_warrior'}
    clips={'Idle','Walk','Run','Attack','Attack2','Attack3','Hit','Death','Fidget','Fidget2'}
    for row in prep['models']:
        kind=row['kind'];black=kind.startswith('black');identity=row['bodies'][0]
        assert row['family']=='solen_warriors' and row['max_influences']==8 and row['pending_render_feature']
        assert identity['body']==(806 if black else 782) and identity['animation_body']==(782 if black else 0)
        assert identity['native_class']==('BlackSolenWarrior' if black else 'RedSolenWarrior')
        assert identity['scale']==[1.3]*3
        assert row['stats']['original']['source_points']==816 and row['stats']['original']['bones']==44 and row['stats']['original']['triangles']==1566 and row['stats']['rounded']['triangles']==6264
        assert set(row['clip_sources'])==clips and not row['rejected_source_clips']
        repair=row['authored_normal_repair'];assert repair['permitted_bytes']==72 and [r['normal_index'] for r in repair['replacements']]==pins['normal_repair_indices']
        assert all(r['coherence']>.6 for r in repair['replacements'])
        curve_path=ART/(kind+'-ground.json');curve=read(curve_path)
        assert proof['ground_measurement_sha256']['res://local-art/creatures/'+curve_path.name]==sha(curve_path)
        assert curve['sample_rate']==960 and curve['preparation_sha256']==sha(ART/'solen_warriors/preparation.json')
        assert curve['recipe_sha256']==sha(ROOT/'Viewer/Presentation/BakeSolenWarriorGround.gd') and curve['geometry_sha256']==sha(ROOT/'Viewer/Presentation/SourceGroundLookup.gd')
        assert set(curve['treatments'])=={'original','rounded','modern'}
        for treatment,data in curve['treatments'].items():
            assert set(data['clips'])==clips and data['asset_sha256']==sha(ART/(kind+'-'+treatment+'.gltf'))
    assert all(r['body_floor_m']>-.008 and (r['clip'] in ['Walk','Run'] or abs(r['body_floor_m'])<.008) for r in proof['records'])
    assert len(proof['gait_floor_ranges_m'])==12 and all(b-a>.05 for a,b in proof['gait_floor_ranges_m'].values())
    for row in prep['models']:
        for treatment in ['original','rounded']:
            for gait in ['Walk','Run']:
                stats=row['stats'][treatment]['clips'][gait]
                assert stats['floor_policy']=='source_vertical' and stats['floor_offset_range'][0]==stats['floor_offset_range'][1]
    if runtime:
        p=read(ROOT/'work/creatures/solen-warriors/runtime-tests.json')
        assert p['failures']==0 and p['poses']==600 and len(p['samples'])==600 and len(p['requests'])==120 and p['checks']>=31000
        assert p['preparation_sha256']==sha(ART/'solen_warriors/preparation.json') and p['maximum_floor_error_m']<.008 and p['maximum_local_position_error_m']<.00001
        for name,digest in p['runtime_sha256'].items():assert sha(ROOT/'Viewer/Presentation'/name)==digest,name
        for name,digest in p['assets_sha256'].items():assert sha(ROOT/'Viewer'/name.removeprefix('res://'))==digest,name
        for name,digest in p['ground_measurement_sha256'].items():assert sha(ROOT/'Viewer'/name.removeprefix('res://'))==digest,name
        assert sha(ROOT/'Viewer/hues.local.json')==p['hues_sha256'] and sha(ROOT/'Viewer/Network/Artwork.gd')==p['artwork_script_sha256']
        assert {(int(r['body']),int(r['hue'])) for r in p['corpses']}=={(body,hue) for body in [782,806] for hue in [0,53,0x8035,0x453]}
        assert len(p['unsupported_classic_groups'])==16 and {r['group'] for r in p['unsupported_classic_groups']}=={7,8,9,11,12,14,19,20}
        assert all(r['gap_m']>-.008 and (r['clip'] in ['Walk','Run'] or abs(r['gap_m'])<.008) for r in p['samples'])
        print('SOLEN WARRIOR RUNTIME:actual candidate avatar,120 timing requests/600 poses/eight raw-hue static corpses; exact source and import pins. No terrain/native/render acceptance.')
    if terrain:
        p=read(ROOT/'work/creatures/solen-warriors/terrain-tests.json')
        assert p['checks']==232685 and p['failures']==0 and p['poses']==2880 and len(p['cases'])==96 and not p['misses']
        assert p['maximum_skin_error_m']<.008 and p['maximum_foot_error_m']<.008
        assert p['preparation_sha256']==sha(ART/'solen_warriors/preparation.json')
        for name,digest in p['runtime_sha256'].items():assert sha(ROOT/'Viewer/Presentation'/name)==digest,name
        for name,digest in p['ground_measurement_sha256'].items():assert sha(ROOT/'Viewer'/name.removeprefix('res://'))==digest,name
        assert {r['kind'] for r in p['cases']}=={'fire_ant_warrior','black_ant_warrior'}
        assert {r['plane'] for r in p['cases']}=={'flat','forward','cross'}
        assert {(r['fps'],r['rate'],r['phase']) for r in p['cases']}=={(30,.65,.31),(90,1.65,.74)}
        assert {tuple(r['pair']) for r in p['cases']}=={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Run','Attack2'),('Run','Attack3'),('Run','Fidget2'),('Run','Death')}
        print('SOLEN WARRIOR TERRAIN:232685checks/2880skins/96finite-plane cases; independent six-foot source flight/stance and complete skin clearance. Two declared rate/fps/phase combinations; no universal terrain/native/render acceptance.')
    print('SOLEN WARRIOR SOURCE:765275checks/1380eight-slot skins; exact44-joint originals, authored six-normal repair, retained five-influence vertices, source gait bounce and measured action residuals. No native/render/terrain/runtime acceptance.')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime',action='store_true');parser.add_argument('--terrain',action='store_true');args=parser.parse_args();main(args.runtime or args.terrain,args.terrain)
