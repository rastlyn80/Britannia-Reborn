"""Require exact original Silver source, whole skins, render and native proof."""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures'
OUT=ROOT/'outputs/creatures/silver_serpents'
KIND='serpents_snake_giant_silver'
CATEGORIES={'Idle','Walk','Run','Attack','Hit','Death','Fidget','Pillage','Eat','LieDown'}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def main():
    subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-source-silver-serpent.py'),'--check-inputs'],check=True)
    prep=read(ART/'silver_serpents/preparation.json');row=prep['models'][0];general=read(OUT/'validation.json');action=read(OUT/'actions.json');gpu=read(OUT/'presentation/validation.json');transition=read(OUT/'transitions.json')
    assert len(prep['models'])==1 and row['kind']==KIND and general['checks']>=718 and general['failures']==0 and len(general['models'])==1
    tested=general['models'][0];assert tested['kind']==KIND
    for field,name in [('recipe_sha256','prepare-source-silver-serpent.py'),('source_pipeline_sha256','prepare-creatures.py'),('input_manifest_sha256','source-silver-serpent-inputs.json')]:assert prep[field]==sha(ROOT/'scripts'/name)
    assert row['preparation_recipe']['sha256']==prep['recipe_sha256'] and row['presentation_script_sha256']==sha(ROOT/'Viewer/Presentation/SourceSilverSerpentVisual.gd')
    assert [b['body'] for b in row['bodies']]==[92,91,93] and all(b['animation_body']==21 and b['scale']==[1.3]*3 and b['native_profile']=='monster' for b in row['bodies'])
    assert len(row['bodies'][0]['native_sources'])==1 and all(not b['native_sources'] for b in row['bodies'][1:])
    assert row['stats']['original']['bones']==18 and row['stats']['original']['triangles']==237 and row['stats']['rounded']['triangles']==3792 and len(row['clip_sources'])==8 and not row['rejected_source_clips']
    assert row['source_motion_contract']['bone_count']==18 and row['source_motion_contract']['weighted_ancestor_count']==17 and row['authored_source_reuse']['clip_stem']=='serpents_snake_giant'
    assert row['new_action_categories']=={'2':'Hit','5':'Fidget','14':'Pillage'} and row['jaw_policy']=='All original Attack jaw channels retained; no inherited Ice gape limit'
    rounded=read(ART/(KIND+'-rounded.gltf'));modern=read(ART/(KIND+'-modern.gltf'))
    for field in ['nodes','meshes','skins','buffers','bufferViews','accessors','animations']:assert rounded[field]==modern[field],'Modern surface changed refined geometry or motion: '+field
    assert action['checks']>=5657 and action['failures']==0 and len(action['samples'])==1110 and len(action['paired_poses'])==740 and {r['clip'] for r in action['samples']}==CATEGORIES
    assert action['maximum_floor_error_m']<.008 and action['maximum_joint_error_m']<.00001 and action['maximum_segment_error_m']<.00001 and action['maximum_basis_error']<.00001
    assert 45<action['maximum_source_jaw_degrees']<60 and len(action['native_timing'])==24 and {r['action'] for r in action['native_timing']}=={4,10,11,17}
    assert {r['preceding_rate'] for r in action['native_timing']}=={.25,1.,3.2} and all(abs(r['position']-r['length']*.5)<.001 for r in action['native_timing'])
    assert gpu['checks']>=4784 and gpu['failures']==0 and gpu['renderer']=='forward_plus' and len(gpu['terrain'])==660 and {r['clip'] for r in gpu['terrain']}==CATEGORIES
    assert all(abs(r['lowest_plane_gap'])<.008 and r['actual_picker_contains'] for r in gpu['terrain'])
    assert gpu['source_nonopaque_texels']==318 and gpu['source_cutout_pixels']>0 and gpu['eye_colour_correction_pixels']>10 and gpu['modern_texture_pixels']>100 and gpu['relief_pixels']>10 and gpu['partial_full_difference_pixels']>100
    assert {r['hue'] for r in gpu['hues']}=={53,0x8035,0x901} and all(r['changed_pixels']>100 for r in gpu['hues'])
    assert {(r['body'],r['hue']) for r in gpu['cadavers']}=={(body,hue) for body in [91,92,93] for hue in [0,53,0x8035]}
    assert transition['checks']>=31400 and transition['failures']==0 and len(transition['flat_samples'])==9500 and len(transition['terrain_samples'])==1440 and len(transition['native_timing'])==3
    pairs={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Attack','Idle'),('Hit','Walk'),('Fidget','Walk'),('Eat','Walk'),('Run','Pillage'),('Run','Death')}
    assert {(r['source'],r['target']) for r in transition['flat_samples']}==pairs and all(abs(r['floor_m'])<.008 for r in transition['flat_samples'])
    assert {(r['source'],r['target']) for r in transition['terrain_samples']}=={('Walk','Run'),('Run','Attack'),('Attack','Idle'),('Run','Pillage'),('Run','Death')} and all(abs(r['gap_m'])<.008 for r in transition['terrain_samples'])
    assert transition['temporary_support_mean_us']<10000 and transition['unique_vertices']<transition['source_vertices']
    for treatment,pin in action['assets'].items():assert pin['asset_sha256']==tested['asset_sha256'][treatment] and pin['import_sha256']==tested['import_sha256'][treatment]
    for proof in [gpu,transition]:assert proof['asset_sha256']==tested['asset_sha256']['modern'] and proof['import_sha256']==tested['import_sha256']['modern']
    for proof in [action,gpu,transition]:
        assert proof['preparation_sha256']==sha(ART/'silver_serpents/preparation.json') and proof['ground_lookup_sha256']==row['ground_lookup_sha256']==sha(ART/(KIND+'-ground.json'))
        for path,digest in proof['runtime_sha256'].items():assert sha(ROOT/'Viewer'/path[6:] if path.startswith('res://') else ROOT/'Viewer/Presentation'/path)==digest,'Silver runtime changed after proof: '+path
    for path,digest in row['art_dependency_sha256'].items():assert sha(ART/path)==digest
    bake=read(ART/(KIND+'-ground.json'));assert bake['recipe_sha256']==sha(ROOT/'Viewer/Presentation/BakeSourceSilverSerpentGround.gd') and bake['geometry_sha256']==sha(ROOT/'Viewer/Presentation/SourceGroundLookup.gd') and bake['sample_rate']==960
    print('ORIGINAL SILVER: current exact source/rig/bases/whole skins/ground/mixed poses/hues/alpha/actual picker/three body corpses passed')
def native():
    live=read(OUT/'live.json');behaviour=read(OUT/'behaviour.json')
    assert live['failures']==0 and live['checks']>=140 and len(live['records'])==2 and {(r['body'],r['native_class'],r['female']) for r in live['records']}=={(92,'SilverSerpent',s) for s in [False,True]}
    assert live['test_sha256']==sha(ROOT/'Viewer/Network/CreatureLive.gd') and live['fixture_sha256']==sha(ROOT/'Server/HorseIntegrationFixtures/CreatureFixtures.cs') and live['preparation_sha256']==sha(ART/'silver_serpents/preparation.json')
    for row in live['records']:
        assert not row['corpse_suppressed'] and not row['native_death_refused'] and {r['requested'] for r in row['actions']}=={4,17,-1,11,-3,-4,-5}
        for action in row['actions']:
            assert action['owner_clip']==action['observer_clip']
            if action['requested'] in [11,-5]:assert action['owner_clip']=='Pillage'
    assert behaviour['failures']==0 and len(behaviour['records'])==2 and {r['client'] for r in behaviour['records']}=={0,1}
    for row in behaviour['records']:
        assert row['body']==92 and row['native_poison_level']==4 and 0<row['poison_callback_attempts']<=32
        assert all(row[k] for k in ['native_summon','actual_charm_packets','no_familiar_refused','invalid_item_refused','combatant_assigned','busy_charm_refused','lethal_immune','native_traits_passed'])
    assert behaviour['fixture_sha256']==sha(ROOT/'Server/HorseIntegrationFixtures/SilverSerpentBehaviourFixtures.cs') and behaviour['test_sha256']==sha(ROOT/'Viewer/Network/SilverSerpentBehaviourLive.gd')
    assert len(behaviour['native_source_sha256'])==6 and len(behaviour['runtime_sha256'])==3
    for path,digest in behaviour['native_source_sha256'].items():assert sha(ROOT/'Server/ModernUO'/path)==digest
    for path,digest in behaviour['runtime_sha256'].items():assert sha(ROOT/'Viewer/Network'/path)==digest
    print('SILVER NATIVE: both owners, real charm/refusal packets/native familiar/poison callback/immunity paths passed; not autonomous combat or full summoning/faction gameplay')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--native',action='store_true');args=parser.parse_args();main()
    if args.native:native()
