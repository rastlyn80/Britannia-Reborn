"""Require exact original Acid/Poison inputs, rendered support and native evidence."""
import argparse, hashlib, json, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures'
OUT=ROOT/'outputs/creatures/fluid_elementals'
KINDS={'elementals_acid_elemental':158,'elementals_poison_elemental':162}
CATEGORIES={'Idle','Walk','Run','Attack','Attack2','Attack3','Hit','Death','Death2','Fidget','Cast2','Stomp','Pillage','LieDown'}
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def main():
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-source-fluid-elementals.py'),'--check-inputs'],check=True)
    prep=read(ART/'fluid_elementals/preparation.json');general=read(OUT/'validation.json');tested={r['kind']:r for r in general['models']}
    assert set(tested)==set(KINDS) and general['failures']==0 and general['checks']>=2000
    for field,name in [('recipe_sha256','prepare-source-fluid-elementals.py'),('source_pipeline_sha256','prepare-creatures.py'),('floor_helper_sha256','prepare-source-elementals.py'),('input_manifest_sha256','source-fluid-elemental-inputs.json')]:assert prep[field]==digest(ROOT/'scripts'/name)
    assert {r['kind'] for r in prep['models']}==set(KINDS)
    proofs=[];appearances=[]
    for row in prep['models']:
        kind=row['kind'];body=KINDS[kind]
        actions=read(OUT/f'{kind}-actions.json');appearance=read(OUT/f'{kind}-presentation/validation.json');transitions=read(OUT/f'{kind}-transitions.json')
        assert actions['kind']==kind and actions['body']==body and actions['checks']>=59250 and actions['failures']==0 and len(actions['samples'])==1554 and len(actions['paired_poses'])==518
        assert {s['clip'] for s in actions['samples']}==CATEGORIES and actions['maximum_relative_joint_error_m']<.00001 and actions['maximum_grounded_floor_error_m']<.008
        assert .15<actions['maximum_run_rise_m']<.3 and len(actions['run_anchor_ranges'])==3 and all(abs(r[1]-r[0])<.000001 for r in actions['run_anchor_ranges'])
        assert len(actions['native_timing'])==12 and {r['preceding_rate'] for r in actions['native_timing']}=={.25,1.,3.2} and all(abs(r['position']-r['length']*.5)<.001 for r in actions['native_timing'])
        assert appearance['kind']==kind and appearance['body']==body and appearance['checks']>=8780 and appearance['failures']==0 and appearance['renderer']=='forward_plus'
        assert len(appearance['terrain'])==756 and {r['clip'] for r in appearance['terrain']}==CATEGORIES and all(len(r['feet'])==2 for r in appearance['terrain'])
        assert appearance['maximum_planted_gap_m']<.008 and appearance['maximum_lift_error_m']<.009 and appearance['minimum_skin_gap_m']>-.008 and appearance['airborne_run_cases']>=48
        assert appearance['lifted_foot_cases']>20 and appearance['planted_foot_cases']>20 and {r['hue'] for r in appearance['hues']}=={53,0x8035,0x901}
        assert all(r['changed_pixels']>100 for r in appearance['hues']) and appearance['partial_full_difference_pixels']>100 and appearance['modern_texture_pixels']>100 and appearance['relief_pixels']>10 and appearance['original_atlas_opaque']
        assert appearance['flow_pixels']>10 and {r['hue'] for r in appearance['cadavers']}=={0,53,0x8035} and all(r['render_drift_pixels']<=10 for r in appearance['cadavers'])
        assert transitions['kind']==kind and transitions['body']==body and transitions['failures']==0 and transitions['checks']>=1297 and transitions['renderer']=='forward_plus' and len(transitions['samples'])==216
        assert {(s['source'],s['target']) for s in transitions['samples']}=={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Run','Cast2'),('Run','Death')}
        assert {s['slope'] for s in transitions['samples']}=={0.,.08} and {s['frame'] for s in transitions['samples']}==set(range(18))
        assert transitions['minimum_plane_gap_m']>-.008 and transitions['maximum_plane_gap_m']<.35 and transitions['positive_rise_cases']>=20
        assert all(s['fresh_modified_skin'] and s['actual_picker_contains'] and -.008<s['gap_m']<.35 for s in transitions['samples'])
        required={'SourceFluidElementalVisual.gd','SourceFluidElementalMaterial.gd','SourceFluidElementalSurface.gdshader','SourceElementalVisual.gd','SourcePlaneSoleSupport.gd','SourceGroundLookup.gd','CreatureRegistry.gd','HumanAvatar.gd','SkinGeometry.gd','CorpseModels.gd'}
        assert {'res://Presentation/'+n for n in required}<=set(appearance['runtime_sha256'])
        assert {'SourceFluidElementalTransitionTests.gd','SourcePlaneSoleSupport.gd','SourceGroundLookup.gd','SourceElementalVisual.gd'}<=set(transitions['runtime_sha256'])
        for treatment,pin in actions['assets'].items():assert pin['asset_sha256']==tested[kind]['asset_sha256'][treatment] and pin['import_sha256']==tested[kind]['import_sha256'][treatment]
        for proof in [appearance,transitions]:assert proof['asset_sha256']==tested[kind]['asset_sha256']['modern'] and proof['import_sha256']==tested[kind]['import_sha256']['modern']
        assert row['preparation_recipe']['sha256']==prep['recipe_sha256'] and row['bodies'][0]['body']==body and row['bodies'][0]['animation_body']==(0 if body==158 else 158) and row['bodies'][0]['scale']==[1.3]*3
        assert row['stats']['original']['bones']==34 and row['stats']['original']['triangles']==362 and row['stats']['rounded']['triangles']==5792 and len(row['clip_sources'])==12
        assert row['category_aliases']['Pillage'].startswith('Stomp:') and row['classic_action_categories']=={'12':'Cast2','14':'Cast2'} and row['new_action_categories']=={'2':'Hit','5':'Fidget','11':'Cast2','14':'Pillage'}
        assert row['source_motion_contract']['fields']==['points','normals','polygons','texture_polygons','uv_sets','weights','ties','bones']
        for treatment in ['original','rounded']:assert row['stats'][treatment]['clips']['Run']['floor_policy']=='source_vertical' and row['stats'][treatment]['clips']['Run']['floor_offset_range'][0]==row['stats'][treatment]['clips']['Run']['floor_offset_range'][1]
        assert row['presentation_script_sha256']==digest(ROOT/'Viewer/Presentation/SourceFluidElementalVisual.gd')
        for path,sha in row['art_dependency_sha256'].items():assert digest(ART/path)==sha
        appearances.append(appearance);proofs.extend([actions,appearance,transitions])
    for proof in proofs:
        assert proof['preparation_sha256']==digest(ART/'fluid_elementals/preparation.json')
        for path,sha in proof['runtime_sha256'].items():assert digest(ROOT/'Viewer'/path[6:] if path.startswith('res://') else ROOT/'Viewer/Presentation'/path)==sha,'Fluid runtime changed after proof: '+path
    aggregate={'checks':sum(r['checks'] for r in appearances),'failures':0,'renderer':'forward_plus','preparation_sha256':digest(ART/'fluid_elementals/preparation.json'),'runtime_sha256':appearances[0]['runtime_sha256'],'models':appearances,'scope':'Two exact original Acid/Poison actual-avatar source/gel/support/clock/corpse reports. Native behaviour has separate evidence.'}
    folder=OUT/'presentation';folder.mkdir(parents=True,exist_ok=True);(folder/'validation.json').write_text(json.dumps(aggregate),encoding='utf-8')
    print('ORIGINAL FLUID ELEMENTALS: exact source/actions/Run lift/gel clock/terrain/hues/corpses/transitions passed')
def native():
    ordinary=read(OUT/'live.json');behaviour=read(OUT/'behaviour.json')
    assert ordinary['failures']==0 and ordinary['checks']>=200 and len(ordinary['records'])==4
    assert {(r['body'],r['native_class'],r['female']) for r in ordinary['records']}=={(b,n,s) for b,n in [(158,'AcidElemental'),(162,'PoisonElemental')] for s in [False,True]}
    assert all(not r['corpse_suppressed'] and not r['native_death_refused'] for r in ordinary['records'])
    assert ordinary['test_sha256']==digest(ROOT/'Viewer/Network/CreatureLive.gd') and ordinary['fixture_sha256']==digest(ROOT/'Server/HorseIntegrationFixtures/CreatureFixtures.cs') and ordinary['preparation_sha256']==digest(ART/'fluid_elementals/preparation.json')
    for row in ordinary['records']:
        assert {r['requested'] for r in row['actions']}=={4,5,6,11,12,14,17,-1,-2,-3,-4,-5}
        for action in row['actions']:
            assert action['owner_clip']==action['observer_clip']
            if action['requested'] in [12,14,-2]:
                assert action['owner_clip']=='Cast2'
                for packet in [action['owner_packet'],action['observer_packet']]:
                    if action['requested']==-2:assert packet['protocol']=='new' and packet['type']==11
                    else:assert packet['protocol']=='classic' and packet['action']==action['requested']
    assert behaviour['failures']==0 and len(behaviour['records'])==4 and {(r['client'],r['body']) for r in behaviour['records']}=={(c,b) for c in [0,1] for b in [158,162]}
    assert all(r['actual_spell_damage']>0 and r['target_poisoned'] and r['native_traits_passed'] for r in behaviour['records'])
    assert behaviour['fixture_sha256']==digest(ROOT/'Server/HorseIntegrationFixtures/FluidElementalBehaviourFixtures.cs') and behaviour['test_sha256']==digest(ROOT/'Viewer/Network/FluidElementalBehaviourLive.gd')
    for path,sha in behaviour['native_source_sha256'].items():assert digest(ROOT/'Server/ModernUO'/path)==sha
    print('FLUID NATIVE: both classes/owners, native Lightning.Cast/target/damage and lethal poison/immune traits passed; autonomous AI/automatic NPC cast packets are not certified')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--native',action='store_true');args=parser.parse_args();main()
    if args.native:native()
