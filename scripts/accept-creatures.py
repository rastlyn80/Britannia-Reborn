"""Activate only exact local assets with passing skin and actual GPU evidence."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Viewer/local-art/creatures'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('families',nargs='+');args=parser.parse_args()
    accepted=ART/'accepted-index.json'
    report=json.loads(accepted.read_text()) if accepted.exists() else {'entries':[]}
    for family in args.families:
        preparation=json.loads((ART/family/'preparation.json').read_text())
        tests=json.loads((ROOT/f'outputs/creatures/{family}/validation.json').read_text())
        gpu=json.loads((ROOT/f'outputs/creatures/{family}/appearance.json').read_text())
        assert tests['failures']==0 and gpu['failures']==0 and gpu['renderer']!='gl_compatibility'
        tested={row['kind']:row for row in tests['models']}
        rows=[]
        for row in preparation['models']:
            if row['status']!='prepared':continue
            assert row['kind'] in tested and tested[row['kind']]['passed']
            for treatment,sha in tested[row['kind']]['asset_sha256'].items():
                assert digest(ART/(row['kind']+'-'+treatment+'.gltf'))==sha,'Asset changed after pose validation'
            samples=[sample for sample in gpu['samples'] if sample['kind']==row['kind']]
            assert len(samples)==6
            assert all(sample['asset_sha256']==tested[row['kind']]['asset_sha256']['modern'] for sample in samples),'Atlas changed after GPU validation'
            row=dict(row,status='validated',validation_sha256=digest(ROOT/f'outputs/creatures/{family}/validation.json'),
                     gpu_sha256=digest(ROOT/f'outputs/creatures/{family}/appearance.json'),asset_sha256=tested[row['kind']]['asset_sha256'])
            rows.append(row)
        report['entries']=[row for row in report['entries'] if row['family']!=family]+rows
        print('ACCEPTED LOCAL PRESENTATION:',family,len(rows),'source forms;',sum(len(row['bodies']) for row in rows),'body routes; native live evidence separate')
    report['scope']='Exact prepared art with passing finite pose/skin and GPU dye checks. Not universal animation fidelity, native gameplay certification or redistributable assets.'
    accepted.write_text(json.dumps(report,indent=2),encoding='utf-8')
if __name__=='__main__':main()
