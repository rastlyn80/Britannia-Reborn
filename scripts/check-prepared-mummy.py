"""Check a private Mummy source/flat-support trial, without accepting a route."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'Viewer/local-art/creatures'
KIND = 'walking_dead_mummy'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime',action='store_true');args=parser.parse_args()
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-source-mummy.py'),'--check-prepared'],check=True)
    preparation=ART/'mummies/preparation.json'
    prep=read(preparation); proof=read(ROOT/'work/creatures/mummies/source-poses.json')
    row=prep['models'][0]
    assert row['presentation_script']=='res://Presentation/SourceMummyVisual.gd'
    assert row['presentation_script_sha256']==sha(ROOT/'Viewer/Presentation/SourceMummyVisual.gd')
    assert row['ground_lookup']=='res://local-art/creatures/'+KIND+'-ground.json'
    assert row['new_action_categories']=={'1':'Hit','2':'Hit','5':'Fidget'}
    assert prep['runtime_sha256']
    for name,digest in prep['runtime_sha256'].items():
        assert sha(ROOT/'Viewer/Presentation'/name)==digest,name
    measurement=read(ART/(KIND+'-ground.json'))
    assert proof['checks']==2346 and proof['failures']==0 and len(proof['samples'])==777 and proof['paired_poses']==518
    assert proof['maximum_joint_error_m']<.00001 and proof['maximum_basis_error']<.00001
    assert proof['maximum_floor_error_m']<.008
    assert proof['preparation_sha256']==measurement['preparation_sha256']==sha(preparation)
    assert proof['ground_measurement_sha256']==sha(ART/(KIND+'-ground.json'))
    assert measurement['sample_rate']==960
    assert measurement['recipe_sha256']==sha(ROOT/'Viewer/Presentation/BakeSourceMummyGround.gd')
    assert measurement['geometry_sha256']==sha(ROOT/'Viewer/Presentation/SourceGroundLookup.gd')
    for name,digest in proof['runtime_sha256'].items():
        assert sha(ROOT/'Viewer/Presentation'/name)==digest,name
    clips={'Idle','Walk','Run','Attack','Hit','Death','Fidget'}
    assert set(proof['assets'])==set(measurement['treatments'])=={'original','rounded','modern'}
    for treatment,pin in proof['assets'].items():
        asset=ART/(KIND+'-'+treatment+'.gltf')
        assert sha(asset)==pin['asset_sha256']==measurement['treatments'][treatment]['asset_sha256']
        assert sha(Path(str(asset)+'.import'))==pin['import_sha256']==measurement['treatments'][treatment]['import_sha256']
        assert set(measurement['treatments'][treatment]['clips'])==clips
    assert {r['clip'] for r in proof['samples']}==clips
    assert {(r['clip'],r['treatment']) for r in proof['samples']}=={(clip,treatment) for clip in clips for treatment in range(3)}
    assert all(abs(r['body_floor_m'])<.008 for r in proof['samples'])
    for clip,omitted in prep['models'][0]['omitted_animation_bones'].items():
        assert clip in clips and set(omitted)=={'bip01 l finger11','bip01 r finger11'}
    print('MUMMY SOURCE TRIAL:2346checks/777skins/518pairs; exact cabinet/source/rig/curve/asset pins; no accepted route or native/render/terrain coverage.')
    if args.runtime:
        runtime=read(ROOT/'work/creatures/mummies/runtime-tests.json')
        terrain=read(ROOT/'work/creatures/mummies/terrain-tests.json')
        death=read(ROOT/'work/creatures/mummies/death-tests.json')
        for report in [runtime,terrain,death]:
            assert report['failures']==0
            assert report['preparation_sha256']==sha(preparation)
            assert report['ground_measurement_sha256']==sha(ART/(KIND+'-ground.json'))
            assert report['runtime_sha256']
            for name,digest in report['runtime_sha256'].items():
                assert sha(ROOT/'Viewer/Presentation'/name)==digest,name
        assert runtime['checks']==12419 and runtime['poses']==300 and len(runtime['requests'])==60
        categories={0:'Walk',1:'Idle',2:'Death',3:'Death',4:'Attack',5:'Attack',6:'Attack',10:'Hit',13:'Hit',15:'Hit',16:'Hit',17:'Fidget',18:'Fidget',21:'Death'}
        assert {(r['request']['protocol'],r['request'].get('action',r['request'].get('type')),r['prior_rate']) for r in runtime['requests']}=={
            (protocol,group,rate) for protocol,groups in [('classic',categories),('new',[0,1,2,3,4,5])] for group in groups for rate in [.65,1.,1.65]}
        for record in runtime['requests']:
            request=record['request']
            assert request['body']==154
            assert record['clip']==(categories[request['action']] if request['protocol']=='classic' else {0:'Attack',1:'Hit',2:'Hit',3:'Death',4:'Hit',5:'Fidget'}[request['type']])
        assert runtime['unsupported_classic_groups']==[7,8,9,11,12,14,19,20]
        assert runtime['maximum_floor_error_m']<.008 and runtime['maximum_local_position_error_m']<.00001
        assert len(runtime['corpses'])==4 and {r['hue'] for r in runtime['corpses']}=={0,53,0x8035,0x515}
        assert runtime['hues_sha256']==sha(ROOT/'Viewer/hues.local.json')
        assert runtime['artwork_script_sha256']==sha(ROOT/'Viewer/Network/Artwork.gd')
        assert terrain['checks']==522357 and terrain['poses']==8064 and len(terrain['cases'])==192 and not terrain['misses']
        pairs={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Attack','Idle'),('Run','Hit'),('Run','Fidget'),('Run','Death')}
        assert {(r['plane'],tuple(r['pair']),r['phase'],r['rate'],r['fps']) for r in terrain['cases']}=={
            (plane,pair,phase,rate,fps) for plane in ['flat','forward','cross'] for pair in pairs for phase in [.31,.74] for rate in [.65,1.65] for fps in [30,90]}
        assert terrain['maximum_skin_error_m']<.008 and terrain['maximum_foot_error_m']<.008
        assert all(r['maximum_body_gap_m']<.008 and r['maximum_foot_error_m']<.008 for r in terrain['cases'])
        assert death['checks']==2277 and len(death['cases'])==24
        assert {(r['from'],r['hue'],r['direction'],r['with_corpse']) for r in death['cases']}=={
            (origin,hue,direction,corpse) for origin in ['Walk','Run','Attack'] for hue in [53,0x8035] for direction in [0,5] for corpse in [False,True]}
        assert all(r['maximum_body_error_m']<.008 and r['entry_s']==.08 for r in death['cases'])
        print('MUMMY CANDIDATE RUNTIME:12419avatar/522357finite-terrain/2277decoded-death checks. Source, native roots, actual picking, hue flags and static corpses retained; no server/GPU or family acceptance.')

if __name__=='__main__':
    main()
