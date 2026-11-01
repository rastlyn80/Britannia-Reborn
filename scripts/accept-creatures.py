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
        for row in preparation['models']:
            if row['status']!='prepared':continue
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
