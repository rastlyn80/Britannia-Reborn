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
        gpu_inputs=[ROOT/'Viewer/Presentation'/name for name in ['CreatureAppearanceTests.gd','CreatureVisual.gd','OstardVisual.gd','OstardSurface.gdshader','CreatureCutoutSurface.gdshader','CreatureDustSurface.gdshader','CreatureFlashSurface.gdshader','HumanHue.gd']]
        assert all(path.stat().st_mtime<=gpu_path.stat().st_mtime for path in gpu_inputs),'Runtime/shader changed after GPU validation'
        assert tests['failures']==0 and gpu['failures']==0 and gpu['renderer']!='gl_compatibility'
        tested={row['kind']:row for row in tests['models']}
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
        if family=='gazers':
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
