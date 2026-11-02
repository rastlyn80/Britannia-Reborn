"""Check exact prepared human-NPC action evidence, without accepting a family."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):
    return json.loads(path.read_text(encoding='utf-8'))
def current_runtime(report):
    assert report['runtime_sha256']
    for name,digest in report['runtime_sha256'].items():
        assert sha(ROOT/'Viewer/Presentation'/name)==digest,name
def main():
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-savage-dance.py'),'--check-inputs'],check=True)
    reference=ROOT/'work/creatures/savages/dance-reference'
    output=ROOT/'Viewer/local-art/human-npcs/savages/dance'
    original=read(reference/'preparation.json')
    prepared=read(output/'preparation.json')
    motion=read(ROOT/'work/creatures/savages/human-npc-motion-tests.json')
    actions=read(ROOT/'work/creatures/savages/action-integration-tests.json')
    ground=read(ROOT/'work/creatures/savages/ground-tests.json')
    death_folder=ROOT/'Viewer/local-art/human-npcs/shared'
    death_prepared=read(death_folder/'death-preparation.json')
    death_floor=read(ROOT/'work/creatures/savages/death-floor-tests.json')
    death=read(ROOT/'work/creatures/savages/death-tests.json')
    assert original['input_manifest_sha256']==sha(ROOT/'scripts/savage-dance-inputs.json')
    for name,digest in original['source_tool_sha256'].items():
        assert sha(ROOT/'scripts'/name)==digest,name
    assert prepared['reference_preparation_sha256']==sha(reference/'preparation.json')
    for report in [prepared,motion,actions,ground,death_prepared,death_floor,death]:current_runtime(report)
    assert death_floor['failures']==0 and death_floor['checks']>=500000
    assert death_floor['preparation_sha256']==sha(death_folder/'death-preparation.json')
    assert len(death_prepared['models'])==len(death_floor['cases'])==2
    for row in death_prepared['models']:
        proof=next(r for r in death_floor['cases'] if r['female']==row['female'])
        asset=ROOT/'Viewer'/row['asset'].removeprefix('res://')
        assert asset.resolve().is_relative_to(death_folder.resolve())
        assert sha(asset)==row['asset_sha256']==proof['asset_sha256']
        assert row['source_signature']==proof['source_signature']
        assert proof['poses']>2000 and proof['minimum_body_y_m']>=-.004
        assert proof['maximum_clearance_error_m']<.004
        assert abs(proof['maximum_correction_m']-row['maximum_floor_compensation_m'])<.004
    assert death['failures']==0 and death['checks']>2200 and len(death['cases'])==16
    assert {(r['body'],r['hue'],r['with_corpse']) for r in death['cases']}=={
        (body,hue,corpse) for body in [183,184,400,401] for hue in [53,0x8035] for corpse in [False,True]}
    assert all(r['minimum_sampled_body_y_m']>=-.004 for r in death['cases'])
    assert ground['checks']==166381 and ground['failures']==0 and ground['pose_cases']==3192
    assert ground['preparation_sha256']==sha(output/'preparation.json')
    assert len(ground['cases'])==48
    assert {(r['body'],r['plane'],r['from'],r['fps']) for r in ground['cases']}=={
        (body,plane,origin,fps) for body in [183,184] for plane in ['flat','raised_forward','cross_slope']
        for origin in ['Idle','Walk','Run','Sword_Walk'] for fps in [30,90]}
    for case in ground['cases']:
        assert case['minimum_gap_m']>=-.004 and case['maximum_reference_error_m']<.004
        assert case['maximum_support_shift_m']<=.2 and case['airborne_frames']>0
    assert motion['checks']==2468 and motion['failures']==0
    assert actions['checks']==1781 and actions['failures']==0
    assert {row['body'] for row in actions['models']}=={183,184}
    for source in original['models']:
        gender=source['gender'];female=gender=='female'
        assert sha(reference/source['output'])==source['sha256']
        assert source['omitted_animation_bones']==['bip01 footsteps']
        row=next(r for r in prepared['models'] if r['gender']==gender)
        assert row['status']=='prepared' and row['mapped_bones']==52 and row['target_bones']==61
        assert row['source_reference_sha256']==source['sha256']
        floor=source['floor_reference']
        assert floor['stats']['source_points']==(190 if female else 183)
        assert sha(reference/floor['output'])==floor['sha256']==row['floor_reference_sha256']
        assert all(abs(s['source_lift_m']-max(0,s['raw_source_body_clearance_m']))<.000001 for s in row['samples'])
        assert row['maximum_global_rotation_basis_error']<.00001
        assert row['maximum_nonpelvis_local_position_error_m']<.000001 and row['maximum_floor_reference_error_m']<.00001
        asset=(ROOT/'Viewer'/row['asset'].removeprefix('res://')).resolve()
        assert asset.is_relative_to(output.resolve()) and sha(asset)==row['asset_sha256']
        m=next(r for r in motion['models'] if r['female']==female)
        a=next(r for r in actions['models'] if r['female']==female)
        assert m['sha256']==a['asset_sha256']==row['asset_sha256']
        assert m['off_grid_phases']==5 and m['target_bones']==61
        assert a['settled_off_grid_poses']==6 and 0<=a['source_peak_pose']<=max(s['time'] for s in row['samples'])
        assert a['native_duration_s']==.8 and a['sampled_floor_error_m']<.004
        assert a['preserved_lift_m']>.02 and abs(a['preserved_lift_m']-row['source_lift_m'])<.004
    print('SAVAGE PREPARED ACTIONS: exact source retarget;2468 library/1781 avatar/166381 finite-ground checks and3192poses; dense human death-floor and decoded corpse lifecycle. No server/GPU/equipment or family acceptance.')
if __name__=='__main__':main()
