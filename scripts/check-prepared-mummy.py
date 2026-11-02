"""Check a private Mummy source/flat-support trial, without accepting a route."""
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
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-source-mummy.py'),'--check-prepared'],check=True)
    preparation=ART/'mummies/preparation.json'
    prep=read(preparation); proof=read(ROOT/'work/creatures/mummies/source-poses.json')
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

if __name__=='__main__':
    main()
