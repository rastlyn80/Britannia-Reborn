"""Require current original amorphous source, deformation and actual-avatar proof."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures'
OUT=ROOT/'outputs/creatures/amorphous'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def native():
    ordinary=read(OUT/'live.json');owned=read(ROOT/'outputs/creatures/plague_spawn/live.json')
    assert ordinary['failures']==0 and ordinary['checks']>=576 and len(ordinary['records'])==10
    expected={(body,name,sex) for body,names in [(775,['PlagueBeast','PlagueBeastLord']),(51,['Slime','CorrosiveSlime','Jwilson'])] for name in names for sex in [False,True]}
    assert {(r['body'],r['native_class'],r['female']) for r in ordinary['records']}==expected
    assert all(not r['corpse_suppressed'] and not r['native_death_refused'] for r in ordinary['records'])
    assert owned['failures']==0 and owned['checks']>=303 and owned['renderer']=='forward_plus'
    assert owned['fixture_sha256']==digest(ROOT/'Server/HorseIntegrationFixtures/PlagueLifecycleFixtures.cs')
    assert owned['test_sha256']==digest(ROOT/'Viewer/Network/PlagueLifecycleLive.gd')
    assert len(owned['records'])==14 and {(r['body'],r['female']) for r in owned['records']}=={(body,sex) for body in [14,31,400,401,29,21,51] for sex in [False,True]}
    assert all(r['native_class']=='PlagueSpawn' and r['owner_serial']!=r['serial'] and 17<=r['hue']<=31 and 58000<=r['native_lifetime_ms']<=60000 and r['constructor_attempts']>0 for r in owned['records'])
    cases=owned['lifecycle'];assert len(cases)==8
    assert {(r['client'],r['condition']) for r in cases}=={(client,condition) for client in [0,1] for condition in ['range','map','delete','native one-minute expiry']}
    assert all(r['two_client_removal'] for r in cases)
    assert all(r['elapsed_ms']>=58000 and 58000<=r['initial_native_lifetime_ms']<=60000 if r['condition']=='native one-minute expiry' else r['native_deleted'] for r in cases)
    print('ORIGINAL AMORPHOUS NATIVE: five classes/two owners; seven actual owned random forms/eight native AI lifecycle cases passed')
def main():
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-source-amorphous.py'),'--check-inputs'],check=True)
    prep=read(ART/'amorphous/preparation.json');actions=read(OUT/'actions.json');tests=read(OUT/'validation.json')
    tested={r['kind']:r for r in tests['models']}
    kinds={'plague_beast':775,'slimes_slime':51}
    assert set(tested)==set(kinds) and tests['failures']==0
    assert prep['recipe_sha256']==digest(ROOT/'scripts/prepare-source-amorphous.py')
    assert prep['source_pipeline_sha256']==digest(ROOT/'scripts/prepare-creatures.py')
    assert prep['floor_helper_sha256']==digest(ROOT/'scripts/prepare-source-frogs.py')
    assert prep['input_manifest_sha256']==digest(ROOT/'scripts/source-amorphous-inputs.json')
    assert actions['failures']==0 and actions['checks']>=13770
    assert len(actions['samples'])==2886 and len(actions['paired_poses'])==962
    categories={'Idle','Walk','Run','Attack','Attack2','Attack3','Hit','Death','Death2','Fidget','Eat','Pillage','LieDown'}
    assert {s['clip'] for s in actions['samples']}==categories
    assert actions['maximum_relative_joint_error_m']<.00001 and actions['maximum_grounded_floor_error_m']<.008
    assert len(actions['native_timing'])==48 and {r['preceding_rate'] for r in actions['native_timing']}=={.25,1.,3.2}
    assert all(abs(r['position']-r['length']*.5)<.001 for r in actions['native_timing'])
    subdivision=read(OUT/'subdivision.json');gpu=read(OUT/'subdivision-gpu.json')
    assert subdivision['checks']>=917 and subdivision['failures']==0 and subdivision['poses']==61
    assert subdivision['conventional_interpolated_skin_error_m']>.5 and subdivision['maximum_source_barycentric_error_m']<.00003
    assert gpu['checks']>=98 and gpu['failures']==0 and gpu['renderer']=='forward_plus' and len(gpu['samples'])==49
    assert gpu['source_bones']==29 and gpu['refinement']['source_triangles']==46 and gpu['refinement']['triangles']==736
    assert gpu['refinement']['maximum_influences']==7 and gpu['refinement']['normal_offset_source_units']==0.
    assert gpu['asset_sha256']==tested['slimes_slime']['asset_sha256']['original'] and gpu['import_sha256']==tested['slimes_slime']['import_sha256']['original']
    for proof,name in [(subdivision,'SourcePoseSubdivisionTests.gd'),(gpu,'SourcePoseSubdivisionGpuTests.gd')]:
        assert proof['recipe_sha256']==digest(ROOT/'Viewer/Presentation/SourcePoseSubdivision.gd')
        assert proof['test_sha256']==digest(ROOT/'Viewer/Presentation'/name)
    proofs=[actions];appearances=[]
    for row in prep['models']:
        kind=row['kind'];body=kinds[kind];detail=next(r for r in actions['models'] if r['kind']==kind)
        appearance=read(OUT/f'{kind}-presentation/validation.json');transition=read(OUT/f'{kind}-transitions.json')
        assert row['preparation_recipe']['sha256']==prep['recipe_sha256'] and row['bodies'][0]['body']==body
        assert row['bodies'][0]['scale']==[1.3]*3 and row['source_alpha_scope']=='fine_edges'
        assert len(row['clip_sources'])==(9 if body==775 else 7)
        if body==51:
            assert row['pose_subdivision']['recipe_sha256']==gpu['recipe_sha256'] and row['pose_subdivision']['normal_offset_source_units']==.0015
            assert row['category_aliases']['Attack2'].startswith('Attack:') and row['category_aliases']['Attack3'].startswith('Attack:')
        for alias,clip in [('Death2','Death'),('Eat','Fidget'),('Pillage','Fidget')]:assert row['category_aliases'][alias].startswith(clip+':')
        assert appearance['kind']==kind and appearance['body']==body and appearance['failures']==0 and appearance['checks']>=4900 and appearance['renderer']=='forward_plus'
        assert len(appearance['terrain'])==702 and {s['clip'] for s in appearance['terrain']}==categories
        assert appearance['maximum_planted_gap_m']<.008 and appearance['maximum_lift_error_m']<.009 and appearance['airborne_gait_cases']>=30
        hues={53,0x8035,0x901}|(set(range(2201,2225))|set(range(17,32)) if body==51 else set())
        assert {r['hue'] for r in appearance['hues']}==hues and all(r['changed_pixels']>100 for r in appearance['hues'])
        assert appearance['source_nonopaque_texels']>100 and appearance['source_cutout_pixels']>100
        assert appearance['partial_full_difference_pixels']>100 and appearance['modern_texture_pixels']>100 and appearance['relief_pixels']>10
        assert {r['hue'] for r in appearance['cadavers']}==({0,53,0x8035,2201,2224,17,31} if body==51 else {0,53,0x8035})
        assert transition['kind']==kind and transition['body']==body and transition['failures']==0 and transition['checks']>=1765 and transition['renderer']=='forward_plus'
        pairs={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Run','Hit'),('Run','Fidget'),('Run','Death')}
        assert len(transition['samples'])==252 and {(s['source'],s['target']) for s in transition['samples']}==pairs
        assert {s['slope'] for s in transition['samples']}=={0.,.08} and {s['frame'] for s in transition['samples']}==set(range(18))
        assert transition['minimum_plane_gap_m']>-.008 and transition['maximum_plane_gap_m']<row['stats']['original']['height_m']*2 and transition['positive_rise_cases']>=20
        assert all(s['fresh_modified_skin'] and s['actual_picker_contains'] and s['relative_source_joint_error_m']<.00001 for s in transition['samples'])
        if body==51:assert max(abs(s['gap_m']-s['original_gap_m']) for s in transition['samples'])<.008,'Refinement must retain the actual source mixed surface, not merely joint centres'
        for treatment,pin in detail['assets'].items():
            assert pin['asset_sha256']==tested[kind]['asset_sha256'][treatment] and pin['import_sha256']==tested[kind]['import_sha256'][treatment]
            for clip in ['Walk','Run']:assert abs(detail['anchors'][treatment][clip][1]-detail['anchors'][treatment][clip][0])<.000001
            rise=detail['source_vertical_ranges'][treatment]['Run'];assert rise[1]-rise[0]>(.1 if body==775 else .2)
        for proof in [appearance,transition]:
            assert proof['asset_sha256']==tested[kind]['asset_sha256']['modern'] and proof['import_sha256']==tested[kind]['import_sha256']['modern']
        required={'SourceAmorphousVisual.gd','SourceAmorphousMaterial.gd','SourceAmorphousSurface.gdshader','SourcePoseSubdivision.gd','CreatureRegistry.gd','HumanAvatar.gd','SkinGeometry.gd','CorpseModels.gd'}
        assert {'res://Presentation/'+name for name in required}<=set(appearance['runtime_sha256'])
        appearances.append(appearance);proofs.extend([appearance,transition])
    for proof in proofs:
        assert proof['preparation_sha256']==digest(ART/'amorphous/preparation.json')
        for path,sha in proof['runtime_sha256'].items():
            assert digest(ROOT/'Viewer'/path[6:] if path.startswith('res://') else ROOT/'Viewer/Presentation'/path)==sha,'Amorphous runtime changed after proof: '+path
    aggregate={'checks':sum(p['checks'] for p in appearances),'failures':0,'renderer':'forward_plus','preparation_sha256':digest(ART/'amorphous/preparation.json'),'runtime_sha256':appearances[0]['runtime_sha256'],'models':appearances,'scope':'Two exact current actual-avatar amorphous reports, validated separately. Native constructor/owned lifecycle evidence is separate.'}
    folder=OUT/'presentation';folder.mkdir(parents=True,exist_ok=True);(folder/'validation.json').write_text(json.dumps(aggregate),encoding='utf-8')
    print('ORIGINAL AMORPHOUS: exact source/action/subdivision/GPU/terrain/blend/corpse evidence passed')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--native',action='store_true');args=parser.parse_args()
    main()
    if args.native:native()
