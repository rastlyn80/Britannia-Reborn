"""Activate only exact local assets with passing skin and actual GPU evidence."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('families',nargs='+');args=parser.parse_args()
    accepted=ART/'accepted-index.json'
    report=json.loads(accepted.read_text()) if accepted.exists() else {'entries':[]}
    for family in args.families:
        if family=='mages':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-source-mages.py'),'--native'],check=True)
        if family=='juka':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-prepared-juka.py'),'--native'],check=True)
        subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-creature-evidence.py'),family],check=True)
        preparation=json.loads((ART/family/'preparation.json').read_text())
        tests=json.loads((ROOT/f'outputs/creatures/{family}/validation.json').read_text())
        gpu=json.loads((ROOT/f'outputs/creatures/{family}/appearance.json').read_text())
        gpu_path=ROOT/f'outputs/creatures/{family}/appearance.json'
        gpu_inputs=[ROOT/'Viewer/Presentation'/name for name in ['CreatureAppearanceTests.gd','CreatureVisual.gd','OstardVisual.gd','OstardSurface.gdshader','CreatureCutoutSurface.gdshader','CreatureDustSurface.gdshader','CreatureFlashSurface.gdshader','CreatureMineralMaterial.gd','CreatureMineralSurface.gdshader','HumanHue.gd']]
        assert all(path.stat().st_mtime<=gpu_path.stat().st_mtime for path in gpu_inputs),'Runtime/shader changed after GPU validation'
        assert tests['failures']==0 and gpu['failures']==0 and gpu['renderer']!='gl_compatibility'
        tested={row['kind']:row for row in tests['models']}
        aquatic=[row for row in preparation['models'] if row.get('movement_mode')=='native_waterline' and row['status']=='prepared']
        if aquatic:
            result=json.loads((ROOT/f'outputs/creatures/{family}/aquatic/validation.json').read_text(encoding='utf-8'))
            assert result['checks']>=40*len(aquatic) and result['failures']==0 and result['renderer']=='forward_plus','Aquatic actors require actual water-anchor/material/corpse evidence'
            assert set(result['assets'])=={row['kind'] for row in aquatic},'Missing aquatic form'
            assert all(digest(ROOT/'Viewer/Presentation'/name)==sha for name,sha in result['runtime_sha256'].items()),'Aquatic runtime changed after validation'
            assert result['preparation_sha256']==digest(ART/family/'preparation.json'),'Aquatic preparation changed'
            for row in aquatic:
                assert result['assets'][row['kind']]['asset_sha256']==tested[row['kind']]['asset_sha256']['modern']
                assert result['assets'][row['kind']]['import_sha256']==tested[row['kind']]['import_sha256']['modern']
                if row.get('authored_mesh_recipe'):
                    assert digest(ROOT/row['authored_mesh_recipe']['path'])==row['authored_mesh_recipe']['sha256'],'Authored tentacle recipe changed'
        if family=='krakens':
            gesture=json.loads((ROOT/'outputs/creatures/krakens/gestures/validation.json').read_text(encoding='utf-8'))
            assert gesture['checks']>=150 and gesture['failures']==0 and gesture['renderer']=='forward_plus','Kraken attacks/casting require measured actual tentacle paths'
            assert gesture['recipe_sha256']==digest(ROOT/'scripts/creature-cephalopod.py')
            assert all(digest(ROOT/'Viewer/Presentation'/name)==sha for name,sha in gesture['runtime_sha256'].items()),'Tentacle action runtime changed'
            assert gesture['asset_sha256']==tested['krakens_kraken']['asset_sha256']['modern'] and gesture['import_sha256']==tested['krakens_kraken']['import_sha256']['modern']
            assert all(len([s for s in gesture['samples'] if s['clip']==clip])==17 for clip in ['Attack','Attack2','Attack3','Cast'])
        if family=='deer' and any(row.get('authored_cervid_recipe') for row in preparation['models']):
            gesture=json.loads((ROOT/'outputs/creatures/deer/gestures/validation.json').read_text(encoding='utf-8'))
            assert gesture['checks']>400 and gesture['failures']==0 and gesture['renderer']=='forward_plus','Cervid actions need actual rendered muzzle/hoof/terrain proof'
            assert gesture['preparation_sha256']==digest(ART/family/'preparation.json')
            assert set(gesture['assets'])==set(tested) and len(gesture['terrain_samples'])==len(tested)*18
            assert all(digest(ROOT/'Viewer/Presentation'/name)==sha for name,sha in gesture['runtime_sha256'].items())
            assert all(digest(ROOT/'scripts'/name)==sha for name,sha in gesture['recipe_sha256'].items())
            for row in preparation['models']:
                if row['status']!='prepared':continue
                kind=row['kind'];asset=gesture['assets'][kind];recipe=row['authored_cervid_recipe']
                assert digest(ROOT/recipe['path'])==recipe['sha256'] and digest(ROOT/recipe['support_path'])==recipe['support_sha256']
                assert asset['asset_sha256']==tested[kind]['asset_sha256']['modern'] and asset['import_sha256']==tested[kind]['import_sha256']['modern']
                for clip in ['Attack2','Eat']:assert len([s for s in gesture['samples'] if s['kind']==kind and s['clip']==clip])==13
        contact_kinds={row['kind'] for row in preparation['models'] if row['status']=='prepared' and row['kind'] in ['dragons_dragon_asian','dragons_wyvern']}
        contact=None
        if contact_kinds:
            contact_path=ROOT/f'outputs/creatures/{family}/contact-motion.json'
            contact=json.loads(contact_path.read_text())
            assert contact['checks']>0 and contact['failures']==0,'Animated contact solver checks failed'
            assert {row['kind'] for row in contact['models']}==contact_kinds,'Missing animated contact model'
            assert all(digest(ROOT/'Viewer/Presentation'/name)==sha for name,sha in contact['runtime_sha256'].items()),'Contact runtime changed after its motion checks'
            assert set(contact['runtime_sha256'])=={'CreatureContactTests.gd','CreatureVisual.gd','SourceMountContact.gd','FootContact.gd'},'Incomplete contact test inputs'
            for model in contact['models']:
                assert model['asset_sha256']==tested[model['kind']]['asset_sha256']['modern'],'Animated contact used different geometry'
                assert model['import_sha256']==tested[model['kind']]['import_sha256']['modern'],'Animated contact used different import precision'
        for row in preparation['models']:
            if row.get('status')!='prepared' or row.get('contact_kind')!='measured_limbs':continue
            if family in ['mages','juka']:continue # Stricter per-form/mixed/native gates above.
            path=ROOT/'outputs/creatures'/family/(row['kind']+'-presentation/validation.json')
            measured=json.loads(path.read_text(encoding='utf-8'))
            assert measured['failures']==0 and measured['checks']>=1000 and measured['renderer']=='forward_plus','Measured source limbs require actual avatar/skin/terrain evidence'
            assert measured['kind']==row['kind'] and measured['body']==int(row['bodies'][0]['body'])
            categories=set(row['stats']['original']['clips'])|{'Eat','LieDown'}
            assert {s['clip'] for s in measured['action_skins']}==categories and len(measured['action_skins'])==17*len(categories),'Every saved and compatibility category needs complete skin sampling'
            supported={'Idle','Walk','Run'}|({'Attack','Cast','Pillage','Stomp'}&categories)
            assert len(measured['terrain'])==6*(17+3*(len(supported)-3)) and {s['clip'] for s in measured['terrain']}==supported,'Missing actual gait/combat terrain cases'
            limbs=4 if row.get('limb_support')=='quadruped' else 2
            assert all(len(s['feet'])==limbs for s in measured['terrain']) and measured['lifted_foot_cases']>=20 and measured['planted_foot_cases']>=20,'Missing measured stance/swing limbs'
            required={'MeasuredCreaturePresentationTests.gd','MeasuredCreatureVisual.gd','MeasuredCreatureSupport.gd','CreatureRegistry.gd','SkinGeometry.gd','HumanAvatar.gd','CorpseModels.gd'}
            assert {'res://Presentation/'+name for name in required}<=set(measured['runtime_sha256'])
            assert all(digest(ROOT/'Viewer'/name.removeprefix('res://'))==sha for name,sha in measured['runtime_sha256'].items()),'Measured source runtime changed after validation'
            assert measured['preparation_sha256']==digest(ART/family/'preparation.json')
            assert measured['asset_sha256']==tested[row['kind']]['asset_sha256']['modern'] and measured['import_sha256']==tested[row['kind']]['import_sha256']['modern'],'Measured source skin/import changed'
            if row.get('authored_action_recipe'):
                recipe=row['authored_action_recipe'];assert digest(ROOT/recipe['path'])==recipe['sha256'],'Authored measured-source gesture recipe changed'
        rows=[]
        if family in ['orcs','ettins'] and any(row.get('authored_action_recipe') for row in preparation['models']):
            gesture_path=ROOT/f'outputs/creatures/{family}/gestures/validation.json'
            gesture=json.loads(gesture_path.read_text())
            assert gesture['checks']>100 and gesture['failures']==0 and gesture['renderer']=='forward_plus','Orc gestures require passing actual GPU/stance checks'
            assert set(gesture['assets'])==set(tested),'Missing measured orc gesture model'
            assert len(gesture['terrain_samples'])==len(tested)*36,'Missing actual gesture collision-plane samples'
            assert gesture['recipe_sha256']==digest(ROOT/'scripts/creature-humanoid-actions.py'),'Gesture recipe changed after measured stance checks'
            assert set(gesture['runtime_sha256'])=={'CreatureGestureTests.gd','CreatureVisual.gd','OstardVisual.gd','SkinGeometry.gd','HumanActions.gd','SourceMountContact.gd','AnimalPoseLibrary.gd','HumanHue.gd','OstardSurface.gdshader','FootContact.gd'},'Incomplete gesture runtime evidence'
            assert all(digest(ROOT/'Viewer/Presentation'/name)==sha for name,sha in gesture['runtime_sha256'].items()),'Gesture runtime changed after checks'
            for kind,asset in gesture['assets'].items():
                assert asset['asset_sha256']==tested[kind]['asset_sha256']['modern'] and asset['import_sha256']==tested[kind]['import_sha256']['modern'],'Gesture checks used different geometry/import'
                for clip in ['Cast','Pillage','Attack2','Attack3']:
                    assert len([s for s in gesture['samples'] if s['kind']==kind and s['clip']==clip])==21,'Missing gesture phase sweep'
            for row in preparation['models']:
                assert row['authored_action_recipe']['sha256']==gesture['recipe_sha256'],'Prepared orc uses a different gesture recipe'
        if family=='elementals':
            mineral_path=ROOT/f'outputs/creatures/{family}/mineral-response.json'
            mineral=json.loads(mineral_path.read_text())
            assert mineral['checks']>0 and mineral['failures']==0 and mineral['renderer']=='forward_plus','Mineral PBR response needs actual passing GPU evidence'
            assert set(mineral['assets'])==set(tested),'Missing mineral material response model'
            assert set(mineral['runtime_sha256'])=={'MineralAppearanceTests.gd','CreatureVisual.gd','CreatureMineralMaterial.gd','CreatureMineralSurface.gdshader','HumanHue.gd'},'Incomplete mineral runtime inputs'
            assert all(digest(ROOT/'Viewer/Presentation'/name)==sha for name,sha in mineral['runtime_sha256'].items()),'Mineral material changed after response checks'
            for kind,asset in mineral['assets'].items():
                assert asset['asset_sha256']==tested[kind]['asset_sha256']['modern'],'Mineral response used different art'
                assert asset['import_sha256']==tested[kind]['import_sha256']['modern'],'Mineral response used different import settings'
                assert asset['surface_parameters']==next(row['mineral_surface'] for row in preparation['models'] if row['kind']==kind),'Mineral surface parameters changed after response checks'
        if family in ['gazers','genies']:
            hover_path=ROOT/f'outputs/creatures/{family}/hover-contact.json'
            hover=json.loads(hover_path.read_text())
            hover_bodies={int(identity['body']) for row in preparation['models'] if row['status']=='prepared' for identity in row['bodies']}
            assert hover['checks']>0 and hover['failures']==0 and len(hover['records'])==len(hover_bodies)*6,'Missing measured gazer hover support'
            assert {int(row['body']) for row in hover['records']}==hover_bodies,'Missing gazer body hover support'
            assert set(hover['runtime_sha256'])=={'FloatingCreatureTests.gd','HumanAvatar.gd','LegacyAvatar.gd','CreatureVisual.gd','SourceMountContact.gd','SkinGeometry.gd','FootContact.gd','MountVisual.gd','CreatureRegistry.gd'},'Incomplete floating avatar inputs'
            assert all(digest(ROOT/'Viewer/Presentation'/name)==sha for name,sha in hover['runtime_sha256'].items()),'Floating avatar support runtime changed'
            for kind,asset in hover['assets'].items():
                assert asset['asset_sha256']==tested[kind]['asset_sha256']['modern'],'Hover support used different geometry'
                assert asset['import_sha256']==tested[kind]['import_sha256']['modern'],'Hover support used a different import'
            assert set(hover['assets'])==set(tested),'Missing floating model support case'
        if preparation.get('selection_recipe_sha256'):
            assert preparation['selection_recipe_sha256']==digest(ROOT/'scripts/prepare-creature-kind.py'),'Selected-kind recipe changed after preparation'
            assert set(preparation['selected_kinds'])=={row['kind'] for row in preparation['models']},'Selected-kind preparation contains unrelated forms'
        if any(row.get('kind')=='walking_dead_zombie' and row.get('status')=='prepared' for row in preparation['models']):
            zombie_path=ROOT/'outputs/creatures/walking/zombie-presentation/validation.json'
            zombie=json.loads(zombie_path.read_text(encoding='utf-8'))
            assert zombie['failures']==0 and zombie['checks']>=830 and zombie['renderer']=='forward_plus','Zombie needs actual registered-avatar/render-stage support proof'
            assert len(zombie['terrain'])==102 and zombie['lifted_foot_cases']>=40 and zombie['planted_foot_cases']>=100,'Zombie support must include complete lifted and planted foot cases'
            required={'ZombiePresentationTests.gd','SourceBipedVisual.gd','SourceBipedSupport.gd','CreatureRegistry.gd','SourceMountContact.gd','SkinGeometry.gd','HumanAvatar.gd'}
            assert {'res://Presentation/'+name for name in required}<=set(zombie['runtime_sha256']),'Incomplete render-stage zombie support inputs'
            assert zombie['preparation_sha256']==digest(ART/family/'preparation.json'),'Zombie preparation changed after measured avatar proof'
            assert all(digest(ROOT/'Viewer'/path.removeprefix('res://'))==sha for path,sha in zombie['runtime_sha256'].items()),'Zombie support/avatar runtime changed after proof'
            assert zombie['asset_sha256']==tested['walking_dead_zombie']['asset_sha256']['modern'] and zombie['import_sha256']==tested['walking_dead_zombie']['import_sha256']['modern'],'Zombie avatar used a different source skin/import'
        if any(row.get('kind')=='serpents_snake_giant' and row.get('status')=='prepared' for row in preparation['models']):
            serpent=json.loads((ROOT/'outputs/creatures/serpents/presentation/validation.json').read_text(encoding='utf-8'))
            assert serpent['failures']==0 and serpent['checks']>=2600 and serpent['renderer']=='forward_plus','Serpent requires actual weighted-skin support, hue, selection and final corpse proof'
            assert len(serpent['terrain'])==432 and {s['clip'] for s in serpent['terrain']}=={'Idle','Walk','Run','Attack','Hit','Death','Fidget','Eat'},'Incomplete source action/terrain sweep'
            assert all(abs(s['lowest_plane_gap'])<.008 for s in serpent['terrain']),'Legless source skin must remain grounded across the measured action phases'
            required={'SerpentPresentationTests.gd','CreatureRegistry.gd','CreatureVisual.gd','BirdGroundSupport.gd','SourceMountContact.gd','SkinGeometry.gd','HumanAvatar.gd','CorpseModels.gd'}
            assert {'res://Presentation/'+name for name in required}<=set(serpent['runtime_sha256']),'Incomplete source serpent avatar inputs'
            assert serpent['preparation_sha256']==digest(ART/family/'preparation.json'),'Serpent preparation changed after actual avatar proof'
            assert all(digest(ROOT/'Viewer'/path.removeprefix('res://'))==sha for path,sha in serpent['runtime_sha256'].items()),'Serpent avatar runtime changed after proof'
            assert serpent['asset_sha256']==tested['serpents_snake_giant']['asset_sha256']['modern'] and serpent['import_sha256']==tested['serpents_snake_giant']['import_sha256']['modern'],'Serpent avatar used a different source skin/import'
        if family=='silver_serpents':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-source-silver-serpent.py')],check=True)
        if family=='fluid_elementals':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-source-fluid-elementals.py')],check=True)
        if family=='solen_workers':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-source-solen.py')],check=True)
        if family=='amorphous':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/check-source-amorphous.py')],check=True)
        if family=='frogs':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-source-frogs.py'),'--check-inputs'],check=True)
            actions=json.loads((ROOT/'outputs/creatures/frogs/actions.json').read_text())
            kinds={'frogs_bullfrog':81,'frogs_frog_giant':80}
            assert set(tested)==set(kinds) and actions['failures']==0 and actions['checks']>=19718 and len(actions['samples'])==2664 and len(actions['paired_poses'])==888
            assert actions['maximum_relative_joint_error_m']<.00001 and actions['maximum_grounded_floor_error_m']<.008
            assert len(actions['hit_holdouts'])==6 and sum(r['poses'] for r in actions['hit_holdouts'])>=7000 and all(r['maximum_floor_error_m']<.008 for r in actions['hit_holdouts'])
            assert len(actions['native_timing'])==36 and {r['preceding_rate'] for r in actions['native_timing']}=={.25,1.,3.2} and all(r['seconds']==.8 and abs(r['position']-r['length']*.5)<.001 for r in actions['native_timing'])
            assert preparation['recipe_sha256']==digest(ROOT/'scripts/prepare-source-frogs.py') and preparation['source_pipeline_sha256']==digest(ROOT/'scripts/prepare-creatures.py') and preparation['input_manifest_sha256']==digest(ROOT/'scripts/source-frog-inputs.json')
            measurement=preparation['ground_measurement'];assert digest(ROOT/measurement['path'])==measurement['sha256'] and measurement['recipe_sha256']==digest(ROOT/'Viewer/Presentation/BakeSourceFrogGround.gd') and measurement['geometry_sha256']==digest(ROOT/'Viewer/Presentation/SourceGroundLookup.gd')
            proofs=[actions];appearances=[];categories={'Idle','Walk','Run','Attack','Attack2','Hit','Death','Death2','Fidget','Eat','Alert','LieDown'}
            assert {s['clip'] for s in actions['samples']}==categories
            for row in preparation['models']:
                kind=row['kind'];body=kinds[kind];detail=next(m for m in actions['models'] if m['kind']==kind)
                appearance=json.loads((ROOT/f'outputs/creatures/frogs/{kind}-presentation/validation.json').read_text())
                transition=json.loads((ROOT/f'outputs/creatures/frogs/{kind}-transitions.json').read_text())
                assert appearance['kind']==kind and appearance['body']==body and appearance['checks']>=9101 and appearance['failures']==0 and appearance['renderer']=='forward_plus' and len(appearance['terrain'])==648
                assert {r['clip'] for r in appearance['terrain']}==categories and appearance['maximum_planted_gap_m']<.008 and appearance['maximum_lift_error_m']<.009 and appearance['airborne_run_cases']>=12
                hues={53,0x8035,0x901}|({0x5ac,0x5a3,0x59a,0x591,0x588,0x57f} if body==81 else set())
                assert {h['hue'] for h in appearance['hues']}==hues and all(h['changed_pixels']>100 for h in appearance['hues'])
                assert not appearance['original_atlas_opaque'] and appearance['source_cutout_pixels']>10 and appearance['tongue_material_pixels']>10 and appearance['partial_full_difference_pixels']>100 and appearance['modern_texture_pixels']>100 and appearance['relief_pixels']>10
                assert {r['hue'] for r in appearance['cadavers']}=={0,53,0x8035}
                assert transition['kind']==kind and transition['body']==body and transition['checks']>=1513 and transition['failures']==0 and transition['renderer']=='forward_plus' and len(transition['samples'])==252
                pairs={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Run','Hit'),('Run','Eat' if body==81 else 'Fidget'),('Run','Death')}
                assert {(s['source'],s['target']) for s in transition['samples']}==pairs and {s['slope'] for s in transition['samples']}=={0.,.08} and {s['frame'] for s in transition['samples']}==set(range(18))
                assert transition['minimum_plane_gap_m']>-.008 and transition['maximum_plane_gap_m']<row['stats']['original']['height_m']*2 and transition['positive_rise_cases']>=20
                assert all(s['fresh_modified_skin'] and s['actual_picker_contains'] and s['gap_m']>-.008 for s in transition['samples'])
                ground=ART/Path(row['ground_lookup']).name
                assert digest(ground)==row['ground_lookup_sha256']==detail['ground_lookup_sha256']==appearance['ground_lookup_sha256']==transition['ground_lookup_sha256']
                assert row['action_support_sha256']==digest(ROOT/'scripts/creature-humanoid-actions.py') and row['source_alpha_scope']=='fine_edges'
                assert row['category_aliases']['Eat'].startswith('Fidget:') and row['category_aliases']['Attack2'].startswith('Attack:') and row['category_aliases']['Death2'].startswith('Death:') and 'Alert' in row['authored_replacements']
                assert row['bodies'][0]['body']==body and row['bodies'][0]['scale']==([.8]*3 if body==81 else [1.3]*3) and row['bodies'][0]['native_profile']==('animal' if body==81 else 'monster')
                for treatment,pin in detail['assets'].items():
                    assert pin['asset_sha256']==tested[kind]['asset_sha256'][treatment] and pin['import_sha256']==tested[kind]['import_sha256'][treatment]
                    for clip in ['Walk','Run']:
                        anchor=detail['anchors'][treatment][clip];assert abs(anchor[1]-anchor[0])<.000001
                    rise=detail['source_vertical_ranges'][treatment]['Run'];assert rise[1]-rise[0]>.5
                for proof in [appearance,transition]:
                    assert proof['asset_sha256']==tested[kind]['asset_sha256']['modern'] and proof['import_sha256']==tested[kind]['import_sha256']['modern']
                required={'SourceFrogVisual.gd','SourceFrogMaterial.gd','SourceFrogSurface.gdshader','SourcePlaneSoleSupport.gd','SourceGroundLookup.gd','CreatureRegistry.gd','CreatureVisual.gd','HumanAvatar.gd','SkinGeometry.gd','CorpseModels.gd'}
                assert {'res://Presentation/'+name for name in required}<=set(appearance['runtime_sha256'])
                appearances.append(appearance);proofs.extend([appearance,transition])
            for proof in proofs:
                assert proof['preparation_sha256']==digest(ART/'frogs/preparation.json')
                for path,sha in proof['runtime_sha256'].items():assert digest(ROOT/'Viewer'/path[6:] if path.startswith('res://') else ROOT/'Viewer/Presentation'/path)==sha,'Original frog runtime changed after its proof'
            aggregate={'checks':sum(p['checks'] for p in appearances),'failures':0,'renderer':'forward_plus','preparation_sha256':digest(ART/'frogs/preparation.json'),'runtime_sha256':appearances[0]['runtime_sha256'],'models':appearances,'scope':'Aggregate of two exact current actual-avatar frog reports, validated separately above. Native server evidence is separate.'}
            folder=ROOT/'outputs/creatures/frogs/presentation';folder.mkdir(parents=True,exist_ok=True);(folder/'validation.json').write_text(json.dumps(aggregate),encoding='utf-8')
        if family=='snow_elementals':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-source-elementals.py'),'--check-inputs'],check=True)
            actions=json.loads((ROOT/'outputs/creatures/snow_elementals/actions.json').read_text())
            appearance=json.loads((ROOT/'outputs/creatures/snow_elementals/presentation/validation.json').read_text())
            transitions=json.loads((ROOT/'outputs/creatures/snow_elementals/transitions.json').read_text())
            kind='elementals_snow_elemental';categories={'Idle','Walk','Run','Attack','Attack2','Attack3','Hit','Death','Death2','Fidget','Cast2','Stomp','Pillage','LieDown'}
            assert set(tested)=={kind} and actions['checks']>=59000 and actions['failures']==0 and len(actions['samples'])==1554 and len(actions['paired_poses'])==518
            assert {s['clip'] for s in actions['samples']}==categories and actions['maximum_relative_joint_error_m']<.00001 and actions['maximum_grounded_floor_error_m']<.008
            assert .15<actions['maximum_run_rise_m']<.3 and all(abs(r[1]-r[0])<.000001 for r in actions['run_anchor_ranges']),'Preserve actual imported Run vertical motion with one constant floor anchor'
            assert len(actions['native_timing'])==12 and {r['preceding_rate'] for r in actions['native_timing']}=={.25,1.,3.2} and all(abs(r['position']-r['length']*.5)<.001 for r in actions['native_timing']),'Real action timing and repeated native casts must restart'
            assert appearance['checks']>=8000 and appearance['failures']==0 and appearance['renderer']=='forward_plus' and len(appearance['terrain'])==756
            assert {r['clip'] for r in appearance['terrain']}==categories and appearance['maximum_planted_gap_m']<.008 and appearance['maximum_lift_error_m']<.009 and appearance['airborne_run_cases']>=12
            assert appearance['lifted_foot_cases']>20 and appearance['planted_foot_cases']>20 and {r['hue'] for r in appearance['hues']}=={53,0x8035,0x901}
            assert all(r['changed_pixels']>100 for r in appearance['hues']) and appearance['partial_full_difference_pixels']>100 and appearance['modern_texture_pixels']>100 and appearance['relief_pixels']>10 and appearance['original_atlas_opaque']
            assert {r['hue'] for r in appearance['cadavers']}=={0,53,0x8035}
            assert transitions['failures']==0 and transitions['checks']>=1297 and transitions['renderer']=='forward_plus' and len(transitions['samples'])==216,'Require actual mixed render-stage skins and picking'
            assert {(s['source'],s['target']) for s in transitions['samples']}=={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Run','Cast2'),('Run','Death')}
            assert {s['slope'] for s in transitions['samples']}=={0.,.08} and {s['frame'] for s in transitions['samples']}==set(range(18))
            assert transitions['minimum_plane_gap_m']>-.008 and transitions['maximum_plane_gap_m']<.35 and transitions['positive_rise_cases']>=20
            assert all(s['fresh_modified_skin'] and s['actual_picker_contains'] and -.008<s['gap_m']<.35 for s in transitions['samples'])
            required={'SourceElementalVisual.gd','SourceElementalMaterial.gd','SourceElementalSurface.gdshader','SourcePlaneSoleSupport.gd','SourceGroundLookup.gd','CreatureRegistry.gd','CreatureVisual.gd','MeasuredCreatureSupport.gd','HumanAvatar.gd','SkinGeometry.gd','CorpseModels.gd'}
            assert {'res://Presentation/'+n for n in required}<=set(appearance['runtime_sha256'])
            assert {'SourceElementalTransitionTests.gd','SourcePlaneSoleSupport.gd','SourceGroundLookup.gd','SourceElementalVisual.gd'}<=set(transitions['runtime_sha256'])
            for proof in [actions,appearance,transitions]:
                assert proof['preparation_sha256']==digest(ART/family/'preparation.json')
                for path,sha in proof['runtime_sha256'].items():assert digest(ROOT/'Viewer'/path[6:] if path.startswith('res://') else ROOT/'Viewer/Presentation'/path)==sha,'Source elemental runtime changed after proof'
            for treatment,pin in actions['assets'].items():assert pin['asset_sha256']==tested[kind]['asset_sha256'][treatment] and pin['import_sha256']==tested[kind]['import_sha256'][treatment]
            assert appearance['asset_sha256']==tested[kind]['asset_sha256']['modern'] and appearance['import_sha256']==tested[kind]['import_sha256']['modern']
            assert transitions['asset_sha256']==tested[kind]['asset_sha256']['modern'] and transitions['import_sha256']==tested[kind]['import_sha256']['modern']
            assert preparation['recipe_sha256']==digest(ROOT/'scripts/prepare-source-elementals.py') and preparation['source_pipeline_sha256']==digest(ROOT/'scripts/prepare-creatures.py') and preparation['input_manifest_sha256']==digest(ROOT/'scripts/source-elemental-inputs.json')
            row=preparation['models'][0];assert row['preparation_recipe']['sha256']==preparation['recipe_sha256'] and int(row['bodies'][0]['body'])==163 and int(row['bodies'][0]['animation_body'])==158
            assert len(row['clip_sources'])==12 and row['category_aliases']['Pillage'].startswith('Stomp:')
            assert row['classic_action_categories']=={'12':'Cast2','14':'Cast2'} and row['new_action_categories']['11']=='Cast2' and row['new_action_categories']['14']=='Pillage'
            for treatment in ['original','rounded']:assert row['stats'][treatment]['clips']['Run']['floor_policy']=='source_vertical' and row['stats'][treatment]['clips']['Run']['floor_offset_range'][0]==row['stats'][treatment]['clips']['Run']['floor_offset_range'][1]
        if family=='liches':
            subprocess.run([sys.executable,'-B',str(ROOT/'scripts/prepare-liches.py'),'--check-inputs'],check=True)
            actions=json.loads((ROOT/'outputs/creatures/liches/actions.json').read_text())
            appearance=json.loads((ROOT/'outputs/creatures/liches/presentation/validation.json').read_text())
            kinds={'liche_liche_retro','liche_liche_lord_retro'}
            categories={'Idle','Walk','Run','Attack','Attack2','Attack3','Hit','Death','Fidget','Cast','Pillage','LieDown'}
            assert set(tested)==kinds and {r['kind'] for r in actions['models']}==kinds and {r['kind'] for r in appearance['models']}==kinds
            assert actions['checks']>=20000 and actions['failures']==0 and len(actions['samples'])==1512 and len(actions['pairs'])==504,'Liches require all source/refined/modern skins and unamended-joint comparisons'
            assert actions['maximum_body_floor_error_m']<.008 and actions['maximum_unamended_joint_error_m']<.00001
            assert actions['maximum_wrist_support_rotation_degrees']<1. and actions['maximum_hand_support_source_m']<.001,'Flat source actions must retain the measured held arm'
            assert appearance['checks']>=8400 and appearance['failures']==0 and appearance['renderer']=='forward_plus','Liches require actual rendered avatar/material/terrain/picking/corpse evidence'
            assert len(appearance['terrain'])==720 and appearance['maximum_planted_gap_m']<.008 and appearance['lifted_foot_cases']>20 and appearance['planted_foot_cases']>20
            for kind in kinds:
                assert {s['clip'] for s in actions['samples'] if s['kind']==kind}==categories
                assert len([s for s in appearance['terrain'] if s['kind']==kind])==360 and {s['clip'] for s in appearance['terrain'] if s['kind']==kind}==categories
                measured=next(r for r in appearance['models'] if r['kind']==kind)
                assert measured['staff_visible_pixels']>25 and measured['source_cutout_pixels']>25 and measured['modern_texture_pixels']>100 and measured['partial_full_difference_pixels']>100,'Original pole/cutouts and authored RGB/dyes must be visible'
                assert {r['hue'] for r in measured['hues']}=={53,0x8035,0x901} and all(r['changed_pixels']>100 for r in measured['hues'])
                if kind=='liche_liche_lord_retro':assert measured['lord_accent_pixels']>25
                assert measured['asset_sha256']==tested[kind]['asset_sha256']['modern'] and measured['import_sha256']==tested[kind]['import_sha256']['modern']
            assert {(int(c['body']),c['hue']) for c in appearance['cadavers']}=={(body,hue) for body in [24,78,79,82] for hue in [0,53,0x8035]},'Every Lich source/compatibility route needs all three static corpse hues'
            required={'LichVisual.gd','LichGrip.gd','LichMaterial.gd','LichSurface.gdshader','MeasuredCreatureSupport.gd','CreatureRegistry.gd','HumanAvatar.gd','SkinGeometry.gd','CorpseModels.gd'}
            assert {'res://Presentation/'+name for name in required}<=set(appearance['runtime_sha256'])
            for proof in [actions,appearance]:
                assert proof['preparation_sha256']==digest(ART/family/'preparation.json')
                for path,sha in proof['runtime_sha256'].items():assert digest(ROOT/'Viewer'/path[6:] if path.startswith('res://') else ROOT/'Viewer/Presentation'/path)==sha,'Lich runtime changed after proof'
            assert preparation['recipe_sha256']==digest(ROOT/'scripts/prepare-liches.py') and preparation['source_pipeline_sha256']==digest(ROOT/'scripts/prepare-creatures.py') and preparation['input_manifest_sha256']==digest(ROOT/'scripts/lich-inputs.json')
            for row in preparation['models']:
                assert row['preparation_recipe']['sha256']==preparation['recipe_sha256'] and row['authored_lich_action_recipe']['sha256']==digest(ROOT/'scripts/creature-lich-actions.py')
                proof=next(r for r in actions['models'] if r['kind']==row['kind'])
                for treatment,pin in proof['assets'].items():assert pin['sha256']==tested[row['kind']]['asset_sha256'][treatment] and pin['import_sha256']==tested[row['kind']]['import_sha256'][treatment]
                staff=ROOT/'Viewer'/row['staff_asset'].removeprefix('res://')
                assert digest(staff)==row['staff']['asset_sha256']==proof['staff_asset_sha256'] and digest(Path(str(staff)+'.import'))==proof['staff_import_sha256']
                assert row['staff']['relative_scale']==.8
        if family=='ice_serpents':
            actions=json.loads((ROOT/'outputs/creatures/ice_serpents/actions.json').read_text())
            appearance=json.loads((ROOT/'outputs/creatures/ice_serpents/presentation/validation.json').read_text())
            transitions=json.loads((ROOT/'outputs/creatures/ice_serpents/transitions.json').read_text())
            assert transitions['failures']==0 and transitions['checks']>=24500 and len(transitions['flat_samples'])==7600 and len(transitions['terrain_samples'])==864,'Ice serpent requires actual mixed skins at slow/native/fast playback and measured finite planes'
            assert all(abs(s['floor_m'])<.008 for s in transitions['flat_samples']) and all(abs(s['gap_m'])<.008 for s in transitions['terrain_samples'])
            assert {s['fps'] for s in transitions['flat_samples']}=={30,60} and len({s['rate'] for s in transitions['flat_samples']})==5
            assert {(s['source'],s['target']) for s in transitions['flat_samples']}=={('Idle','Walk'),('Walk','Run'),('Run','Walk'),('Run','Attack'),('Attack','Idle'),('Hit','Walk'),('Fidget','Walk'),('Eat','Walk')}
            assert {s['preceding_rate'] for s in transitions['native_timing']}=={.25,1.,3.2} and all(s['requested_seconds']==.8 and abs(s['midpoint_position']-s['authored_length']*.5)<.001 for s in transitions['native_timing'])
            assert {'IceSerpentTransitionTests.gd','IceSerpentVisual.gd','SourceGroundLookup.gd','SmallSnakeVisual.gd','CreatureVisual.gd','SkinGeometry.gd','HumanActions.gd'}==set(transitions['runtime_sha256'])
            assert actions['failures']==0 and actions['checks']>=1300 and len(actions['samples'])==230,'Ice serpent requires paired imported source/modern skins and actual action routing'
            assert actions['maximum_retained_relative_skin_error_m']<.00001 and 20<actions['maximum_active_jaw_degrees']<32.01 and actions['maximum_source_jaw_degrees']>45,'Preserve source motions beside the explicitly shorter active jaw gape'
            assert appearance['failures']==0 and appearance['checks']>3900 and appearance['renderer']=='forward_plus','Ice serpent requires actual source avatar/PBR/hue/terrain/picking/corpse evidence'
            assert appearance['partial_full_difference_pixels']>100 and appearance['source_cutout_pixels']>0 and appearance['registered_head_pixels']>100,'Actual partial/full colour separation, original alpha and authored eye registration must remain visible'
            expected={'Idle','Walk','Run','Attack','SourceAttack','Hit','Death','Fidget','Eat','LieDown'}
            assert len(appearance['terrain'])==660 and {s['clip'] for s in appearance['terrain']}==expected and all(abs(s['lowest_plane_gap'])<.008 for s in appearance['terrain']),'Missing complete finite-plane/off-grid grounded action sweep'
            assert {s['clip'] for s in actions['samples']}==expected
            required={'IceSerpentVisual.gd','IceSerpentMaterial.gd','IceSerpentSurface.gdshader','SourceGroundLookup.gd','SmallSnakeVisual.gd','CreatureRegistry.gd','HumanAvatar.gd','SkinGeometry.gd','CorpseModels.gd'}
            assert {'res://Presentation/'+name for name in required}<=set(appearance['runtime_sha256'])
            for proof in [actions,appearance,transitions]:
                assert proof['preparation_sha256']==digest(ART/family/'preparation.json')
                for path,sha in proof['runtime_sha256'].items():assert digest(ROOT/'Viewer'/path[6:] if path.startswith('res://') else ROOT/'Viewer/Presentation'/path)==sha,'Ice serpent runtime changed after proof'
                assert proof['asset_sha256']==tested['serpents_snake_giant_ice']['asset_sha256']['modern'] and proof['import_sha256']==tested['serpents_snake_giant_ice']['import_sha256']['modern']
            row=preparation['models'][0];recipe=row['preparation_recipe'];assert digest(ROOT/recipe['path'])==recipe['sha256']==preparation['recipe_sha256']
            assert preparation['source_pipeline_sha256']==digest(ROOT/'scripts/prepare-creatures.py')
            ground=ART/'serpents_snake_giant_ice-ground.json';assert digest(ground)==row['ground_lookup_sha256']==actions['ground_lookup_sha256']==appearance['ground_lookup_sha256']==transitions['ground_lookup_sha256']
            baked=json.loads(ground.read_text());assert baked['sample_rate']==960 and baked['recipe_sha256']==digest(ROOT/'Viewer/Presentation/BakeIceSerpentGround.gd') and baked['geometry_sha256']==digest(ROOT/'Viewer/Presentation/SkinGeometry.gd')
            for treatment,proof in baked['treatments'].items():
                assert proof['asset_sha256']==tested[row['kind']]['asset_sha256'][treatment] and proof['import_sha256']==tested[row['kind']]['import_sha256'][treatment]
            assert actions['reference_sha256']==tested[row['kind']]['asset_sha256']['rounded'] and actions['reference_import_sha256']==tested[row['kind']]['import_sha256']['rounded']
        if family=='small_snakes':
            actions=json.loads((ROOT/'outputs/creatures/small_snakes/actions.json').read_text())
            assert actions['failures']==0 and actions['checks']>=516 and len(actions['samples'])==170
            assert actions['test_sha256']==digest(ROOT/'Viewer/Presentation/SmallSnakeActionTests.gd') and actions['preparation_sha256']==digest(ART/family/'preparation.json')
            assert all(digest(ROOT/'Viewer/Presentation'/path)==sha for path,sha in actions['runtime_sha256'].items()),'Small snake action runtime changed'
            assert actions['asset_sha256']==tested['small_snakes']['asset_sha256']['modern'] and actions['import_sha256']==tested['small_snakes']['import_sha256']['modern']
            small=json.loads((ROOT/'outputs/creatures/small_snakes/presentation/validation.json').read_text())
            assert small['failures']==0 and small['checks']>=2600 and small['renderer']=='forward_plus'
            assert len(small['terrain'])==432 and all(abs(s['lowest_plane_gap'])<.008 for s in small['terrain']),'Small snakes need complete action/terrain support'
            assert small['preparation_sha256']==digest(ART/family/'preparation.json')
            assert all(digest(ROOT/'Viewer'/path.removeprefix('res://'))==sha for path,sha in small['runtime_sha256'].items()),'Small snake runtime changed'
            assert small['asset_sha256']==tested['small_snakes']['asset_sha256']['modern'] and small['import_sha256']==tested['small_snakes']['import_sha256']['modern']
            for row in preparation['models']:
                if row['status']!='prepared':continue
                recipe=row['scale_recipe'];assert recipe['uniform_scale']==.18 and digest(ROOT/recipe['path'])==recipe['sha256']
                for treatment,sha in recipe['source_assets'].items():assert digest(ART/('serpents_snake_giant-'+treatment+'.gltf'))==sha,'Shared source donor changed'
        for row in preparation['models']:
            if row['status']!='prepared':continue
            if row.get('presentation_script'):
                resource=row['presentation_script'];name=resource.rsplit('/',1)[-1]
                assert resource=='res://Presentation/'+name and name.endswith('.gd'),'Renderer must be an owned direct presentation script'
                assert digest(ROOT/'Viewer/Presentation'/name)==row['presentation_script_sha256'],'Owned renderer changed after preparation'
                focused=json.loads((ROOT/'outputs/creatures'/family/(row['kind']+'-presentation/validation.json' if family in ['mages','juka'] else 'presentation/validation.json')).read_text())
                assert focused['failures']==0 and focused['renderer']=='forward_plus' and focused['preparation_sha256']==digest(ART/family/'preparation.json')
                assert focused['runtime_sha256'][resource]==row['presentation_script_sha256'],'Owned renderer lacks actual current avatar evidence'
            if family=='juka':
                assert row.get('pending_render_feature')=='Original Juka source-pose, actual terrain/material/corpse and native action/behaviour acceptance pending.'
            else:
                assert not row.get('pending_render_feature'),row.get('pending_render_feature')
            assert row['kind'] in tested and tested[row['kind']]['passed']
            for treatment,sha in tested[row['kind']]['asset_sha256'].items():
                assert digest(ART/(row['kind']+'-'+treatment+'.gltf'))==sha,'Asset changed after pose validation'
                assert digest(ART/(row['kind']+'-'+treatment+'.gltf.import'))==tested[row['kind']]['import_sha256'][treatment],'Import settings changed after pose validation'
            samples=[sample for sample in gpu['samples'] if sample['kind']==row['kind']]
            dependencies=row.get('art_dependency_sha256',{})
            assert all((ART/name).resolve().is_relative_to(ART.resolve()) and digest(ART/name)==sha for name,sha in dependencies.items()),'Auxiliary art changed after preparation'
            assert all(sample.get('art_dependency_sha256',{})==dependencies for sample in samples),'Auxiliary art changed after rendering'
            assert len(samples)==6
            if row.get('death_effect'):
                effect_path=ROOT/f'outputs/creatures/{family}/death-effect.json'
                effect=json.loads(effect_path.read_text())
                assert effect['failures']==0 and effect['checks']>0 and effect['renderer']=='forward_plus','Death effect needs actual passing GPU evidence'
                assert effect['asset_sha256']==tested[row['kind']]['asset_sha256']['modern'],'Death effect used different geometry'
                assert effect['import_sha256']==tested[row['kind']]['import_sha256']['modern'],'Death effect used different animation import'
                assert set(effect['runtime_sha256'])=={'CreatureFlashTests.gd','CreatureVisual.gd','CreatureFlashSurface.gdshader'},'Incomplete death effect runtime evidence'
                assert all(digest(ROOT/'Viewer/Presentation'/name)==sha for name,sha in effect['runtime_sha256'].items()),'Death effect runtime changed after validation'
            assert all(sample['asset_sha256']==tested[row['kind']]['asset_sha256']['modern'] for sample in samples),'Atlas changed after GPU validation'
            assert all(sample['import_sha256']==tested[row['kind']]['import_sha256']['modern'] for sample in samples),'GPU and pose samples used different import settings'
            row=dict(row,status='validated',validation_sha256=digest(ROOT/f'outputs/creatures/{family}/validation.json'),
                     gpu_sha256=digest(gpu_path),gpu_runtime_sha256={path.name:digest(path) for path in gpu_inputs},asset_sha256=tested[row['kind']]['asset_sha256'],import_sha256=tested[row['kind']]['import_sha256'])
            if family=='juka':
                # This exact integration marker is discharged by the strict
                # source/skin/terrain/native gates; preparation/proofs stay intact.
                row.pop('pending_render_feature')
                row['remaining_fidelity']='Original256-square atlas/procedural surface; exact original per-category choreography, final art and autonomous gameplay remain unproved. Native Lord766 graphics/bow adaptation is a separate missing route.'
            if row['kind'] in contact_kinds:row['contact_sha256']=digest(contact_path)
            rows.append(row)
        # Test actual frozen cadavers before publishing any new runtime route.
        # This Godot process injects prepared candidates only in its own memory.
        godot=os.environ.get('GODOT_BIN') or next((ROOT/'.tools/godot').glob('*console.exe'),None) or shutil.which('godot') or shutil.which('godot4')
        if not godot:raise RuntimeError('Set GODOT_BIN to validate candidate cadavers before acceptance')
        subprocess.run([str(godot),'--headless','--path',str(ROOT/'Viewer'),'--script',
                        'res://Presentation/CorpseCatalogue.gd','--','--candidate='+family],check=True)
        report['entries']=[row for row in report['entries'] if row['family']!=family]+rows
        print('ACCEPTED LOCAL PRESENTATION:',family,len(rows),'source forms;',sum(len(row['bodies']) for row in rows),'body routes; native live evidence separate')
    report['scope']='Exact prepared art with passing finite pose/skin and GPU dye checks. Not universal animation fidelity, native gameplay certification or redistributable assets.'
    # A running client may load this index while a batch is being published.
    # Replace the completed document rather than exposing a partially written one.
    pending=accepted.with_suffix('.json.pending')
    pending.write_text(json.dumps(report,indent=2),encoding='utf-8')
    pending.replace(accepted)
if __name__=='__main__':main()
