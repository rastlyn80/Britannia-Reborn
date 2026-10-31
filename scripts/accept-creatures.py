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
        gpu_inputs=[ROOT/'Viewer/Presentation'/name for name in ['CreatureAppearanceTests.gd','CreatureVisual.gd','OstardVisual.gd','OstardSurface.gdshader','HumanHue.gd']]
        assert all(path.stat().st_mtime<=gpu_path.stat().st_mtime for path in gpu_inputs),'Runtime/shader changed after GPU validation'
        assert tests['failures']==0 and gpu['failures']==0 and gpu['renderer']!='gl_compatibility'
        tested={row['kind']:row for row in tests['models']}
        rows=[]
        for row in preparation['models']:
            if row['status']!='prepared':continue
            assert row['kind'] in tested and tested[row['kind']]['passed']
            for treatment,sha in tested[row['kind']]['asset_sha256'].items():
                assert digest(ART/(row['kind']+'-'+treatment+'.gltf'))==sha,'Asset changed after pose validation'
                assert digest(ART/(row['kind']+'-'+treatment+'.gltf.import'))==tested[row['kind']]['import_sha256'][treatment],'Import settings changed after pose validation'
            samples=[sample for sample in gpu['samples'] if sample['kind']==row['kind']]
            assert len(samples)==6
            assert all(sample['asset_sha256']==tested[row['kind']]['asset_sha256']['modern'] for sample in samples),'Atlas changed after GPU validation'
            assert all(sample['import_sha256']==tested[row['kind']]['import_sha256']['modern'] for sample in samples),'GPU and pose samples used different import settings'
            row=dict(row,status='validated',validation_sha256=digest(ROOT/f'outputs/creatures/{family}/validation.json'),
                     gpu_sha256=digest(gpu_path),gpu_runtime_sha256={path.name:digest(path) for path in gpu_inputs},asset_sha256=tested[row['kind']]['asset_sha256'],import_sha256=tested[row['kind']]['import_sha256'])
            rows.append(row)
        report['entries']=[row for row in report['entries'] if row['family']!=family]+rows
        print('ACCEPTED LOCAL PRESENTATION:',family,len(rows),'source forms;',sum(len(row['bodies']) for row in rows),'body routes; native live evidence separate')
    report['scope']='Exact prepared art with passing finite pose/skin and GPU dye checks. Not universal animation fidelity, native gameplay certification or redistributable assets.'
    accepted.write_text(json.dumps(report,indent=2),encoding='utf-8')
if __name__=='__main__':main()
