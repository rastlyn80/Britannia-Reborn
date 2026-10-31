"""Activate only exact local assets with passing skin and actual GPU evidence."""
import argparse,hashlib,json,subprocess,sys
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
        gpu_inputs=[ROOT/'Viewer/Presentation'/name for name in ['CreatureAppearanceTests.gd','CreatureVisual.gd','OstardVisual.gd','OstardSurface.gdshader','CreatureCutoutSurface.gdshader','CreatureDustSurface.gdshader','HumanHue.gd']]
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
            assert all(sample['asset_sha256']==tested[row['kind']]['asset_sha256']['modern'] for sample in samples),'Atlas changed after GPU validation'
            assert all(sample['import_sha256']==tested[row['kind']]['import_sha256']['modern'] for sample in samples),'GPU and pose samples used different import settings'
            row=dict(row,status='validated',validation_sha256=digest(ROOT/f'outputs/creatures/{family}/validation.json'),
                     gpu_sha256=digest(gpu_path),gpu_runtime_sha256={path.name:digest(path) for path in gpu_inputs},asset_sha256=tested[row['kind']]['asset_sha256'],import_sha256=tested[row['kind']]['import_sha256'])
            if row['kind'] in contact_kinds:row['contact_sha256']=digest(contact_path)
            rows.append(row)
        report['entries']=[row for row in report['entries'] if row['family']!=family]+rows
        print('ACCEPTED LOCAL PRESENTATION:',family,len(rows),'source forms;',sum(len(row['bodies']) for row in rows),'body routes; native live evidence separate')
    report['scope']='Exact prepared art with passing finite pose/skin and GPU dye checks. Not universal animation fidelity, native gameplay certification or redistributable assets.'
    accepted.write_text(json.dumps(report,indent=2),encoding='utf-8')
if __name__=='__main__':main()
