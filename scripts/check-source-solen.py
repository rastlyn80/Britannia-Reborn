"""Require exact original Solen worker source, six-leg and native evidence."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures'
OUT=ROOT/'outputs/creatures/solen_workers'
KINDS={'fire_ant_worker':781,'black_ant_worker':805}
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def native():
    ordinary=read(OUT/'live.json');behaviour=read(OUT/'friendship.json')
    assert ordinary['failures']==0 and ordinary['checks']>=200 and len(ordinary['records'])==4
    assert {(r['body'],r['native_class'],r['female']) for r in ordinary['records']}=={(body,name,sex) for body,name in [(781,'RedSolenWorker'),(805,'BlackSolenWorker')] for sex in [False,True]}
    assert all(not r['corpse_suppressed'] and not r['native_death_refused'] for r in ordinary['records'])
    assert behaviour['failures']==0 and behaviour['checks']>=68 and len(behaviour['states'])==6 and len(behaviour['damage'])==8
    assert behaviour['fixture_sha256']==digest(ROOT/'Server/HorseIntegrationFixtures/SolenBehaviourFixtures.cs') and behaviour['test_sha256']==digest(ROOT/'Viewer/Network/SolenBehaviourLive.gd')
    assert {(r['client'],r['friendship']) for r in behaviour['states']}=={(client,state) for client in [0,1] for state in ['None','Red','Black']}
    for row in behaviour['states']:
        red=int(row['friendship']=='Red');black=int(row['friendship']=='Black')
        assert [int(v) for v in row['native_values']]==[red,black,1-red,1-black,red,black,1-red,1-black]
    assert {(r['client'],r['colour'],r['from']) for r in behaviour['damage']}=={(client,colour,attacker) for client in [0,1] for colour in ['red','black'] for attacker in ['direct','pet']}
    assert all(r['native_health_reduced'] and r['friendship_revoked'] and r['enmity_restored'] for r in behaviour['damage'])
    assert len(behaviour['native_source_sha256'])==3
    for path,sha in behaviour['native_source_sha256'].items():assert digest(ROOT/'Server/ModernUO'/path)==sha
    print('SOLEN NATIVE: two worker classes/both owners, second fidget, three friendship states/direct and actual controlled-pet damage passed')
def main():
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-source-solen.py'),'--check-inputs'],check=True)
    prep=read(ART/'solen_workers/preparation.json');actions=read(OUT/'actions.json');general=read(OUT/'validation.json');tested={r['kind']:r for r in general['models']}
    assert set(tested)==set(KINDS) and general['failures']==0 and general['checks']>=1891
    assert prep['recipe_sha256']==digest(ROOT/'scripts/prepare-source-solen.py') and prep['source_pipeline_sha256']==digest(ROOT/'scripts/prepare-creatures.py')
    assert prep['floor_helper_sha256']==digest(ROOT/'scripts/prepare-source-frogs.py') and prep['input_manifest_sha256']==digest(ROOT/'scripts/source-solen-inputs.json')
    measurement=prep['ground_measurement'];assert digest(ROOT/measurement['path'])==measurement['sha256']
    assert measurement['recipe_sha256']==digest(ROOT/'Viewer/Presentation/BakeSourceSolenGround.gd') and measurement['geometry_sha256']==digest(ROOT/'Viewer/Presentation/SourceGroundLookup.gd')
    assert actions['failures']==0 and actions['checks']>=20028 and len(actions['samples'])==3108 and len(actions['paired_poses'])==1036
    categories={'Idle','Walk','Run','Attack','Attack2','Attack3','Hit','Death','Death2','Fidget','Fidget2','Eat','Pillage','LieDown'}
    assert {s['clip'] for s in actions['samples']}==categories and actions['maximum_relative_joint_error_m']<.00001 and actions['maximum_grounded_floor_error_m']<.008
    assert len(actions['native_timing'])==54 and {r['preceding_rate'] for r in actions['native_timing']}=={.25,1.,3.2}
    assert all(abs(r['position']-r['length']*.5)<.001 for r in actions['native_timing'])
    assert len(actions['attack_holdouts'])==6 and sum(r['poses'] for r in actions['attack_holdouts'])>=5196 and all(r['maximum_floor_error_m']<.008 for r in actions['attack_holdouts'])
    proofs=[actions];appearances=[]
    for row in prep['models']:
        kind=row['kind'];body=KINDS[kind];detail=next(r for r in actions['models'] if r['kind']==kind)
        appearance=read(OUT/f'{kind}-presentation/validation.json');transition=read(OUT/f'{kind}-transitions.json')
        assert row['preparation_recipe']['sha256']==prep['recipe_sha256'] and row['bodies'][0]['body']==body and row['bodies'][0]['scale']==[1.3]*3
        assert row['bodies'][0]['animation_body']==(0 if body==781 else 781) and row['bodies'][0]['native_profile']=='monster'
        assert len(row['clip_sources'])==10 and row['clip_sources']['Fidget2'].endswith('fire_ant_worker_fidget2.grn')
        assert row['classic_action_categories']=={'18':'Fidget2'} and row['limb_support']=='six_original_legs'
        assert row['stats']['original']['bones']==42 and row['stats']['original']['triangles']==1322 and row['stats']['rounded']['triangles']==5288
        for alias,clip in [('Death2','Death'),('Eat','Fidget'),('Pillage','Fidget')]:assert row['category_aliases'][alias].startswith(clip+':')
        assert appearance['kind']==kind and appearance['body']==body and appearance['failures']==0 and appearance['checks']>=14932 and appearance['renderer']=='forward_plus'
        assert len(appearance['terrain'])==756 and {r['clip'] for r in appearance['terrain']}==categories and all(len(r['feet'])==6 for r in appearance['terrain'])
        assert appearance['maximum_planted_gap_m']<.008 and appearance['maximum_lift_error_m']<.009 and appearance['minimum_skin_gap_m']>-.008
        assert appearance['grounded_gait_cases']==108 and appearance['maximum_protected_joint_error_m']<.00001 and appearance['planted_foot_cases']>20 and appearance['lifted_foot_cases']>20
        hues={53,0x8035,0x901}|({0x453} if body==805 else set())
        assert {r['hue'] for r in appearance['hues']}==hues and all(r['changed_pixels']>100 for r in appearance['hues'])
        assert not appearance['original_atlas_opaque'] and appearance['source_cutout_pixels']>10 and appearance['partial_full_difference_pixels']>100 and appearance['modern_texture_pixels']>100 and appearance['relief_pixels']>10
        assert {r['hue'] for r in appearance['cadavers']}=={0,53,0x8035}
        assert transition['kind']==kind and transition['body']==body and transition['failures']==0 and transition['checks']>=2017 and transition['renderer']=='forward_plus'
        pairs={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Run','Attack2'),('Run','Hit'),('Run','Fidget2'),('Run','Death')}
        assert len(transition['samples'])==288 and {(s['source'],s['target']) for s in transition['samples']}==pairs
        assert {s['slope'] for s in transition['samples']}=={0.,.08} and {s['frame'] for s in transition['samples']}==set(range(18))
        assert transition['minimum_plane_gap_m']>-.008 and transition['maximum_plane_gap_m']<.35 and transition['grounded_gait_cases']==108
        assert all(s['fresh_modified_skin'] and s['actual_picker_contains'] and s['protected_source_joint_error_m']<.00001 for s in transition['samples'])
        for treatment,pin in detail['assets'].items():
            assert pin['asset_sha256']==tested[kind]['asset_sha256'][treatment] and pin['import_sha256']==tested[kind]['import_sha256'][treatment]
            for clip in ['Walk','Run']:assert abs(detail['anchors'][treatment][clip][1]-detail['anchors'][treatment][clip][0])<.000001
            rise=detail['source_vertical_ranges'][treatment]['Run'];assert rise[1]-rise[0]>.05
        assert appearance['ground_lookup_sha256']==row['ground_lookup_sha256']==digest(ART/Path(row['ground_lookup']).name)
        for proof in [appearance,transition]:assert proof['asset_sha256']==tested[kind]['asset_sha256']['modern'] and proof['import_sha256']==tested[kind]['import_sha256']['modern']
        required={'SourceSolenVisual.gd','SourceSolenSupport.gd','SourceSolenMaterial.gd','SourceSolenSurface.gdshader','SourceGroundLookup.gd','CreatureRegistry.gd','HumanAvatar.gd','SkinGeometry.gd','CorpseModels.gd'}
        assert {'res://Presentation/'+name for name in required}<=set(appearance['runtime_sha256'])
        appearances.append(appearance);proofs.extend([appearance,transition])
    for proof in proofs:
        assert proof['preparation_sha256']==digest(ART/'solen_workers/preparation.json')
        for path,sha in proof['runtime_sha256'].items():assert digest(ROOT/'Viewer'/path[6:] if path.startswith('res://') else ROOT/'Viewer/Presentation'/path)==sha,'Solen runtime changed after proof: '+path
    aggregate={'checks':sum(r['checks'] for r in appearances),'failures':0,'renderer':'forward_plus','preparation_sha256':digest(ART/'solen_workers/preparation.json'),'runtime_sha256':appearances[0]['runtime_sha256'],'models':appearances,'scope':'Two exact current actual-avatar original Solen worker reports, validated separately. Native classes/friendship/damage are separate.'}
    folder=OUT/'presentation';folder.mkdir(parents=True,exist_ok=True);(folder/'validation.json').write_text(json.dumps(aggregate),encoding='utf-8')
    print('ORIGINAL SOLEN WORKERS: current exact source/actions/six-leg/support/whole skin/UV/colour/corpse/mixed-poses passed')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--native',action='store_true');args=parser.parse_args();main()
    if args.native:native()
