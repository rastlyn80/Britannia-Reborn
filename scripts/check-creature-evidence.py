"""Reuse exact, successful local pose evidence while inputs remain unchanged."""
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    family=sys.argv[1];folder=ROOT/f'outputs/creatures/{family}'
    report=folder/'validation.json';preparation=ROOT/f'Viewer/local-art/creatures/{family}/preparation.json'
    runtime=[ROOT/'Viewer/Presentation'/name for name in ['CreatureTests.gd','CreatureVisual.gd','OstardVisual.gd','AnimalPoseLibrary.gd','SourceMountContact.gd','SkinGeometry.gd']]
    try:
        tests=json.loads(report.read_text());prepared=json.loads(preparation.read_text())
        assert tests['failures']==0 and tests['models']
        assert preparation.stat().st_mtime<=report.stat().st_mtime
        assert all(path.stat().st_mtime<=report.stat().st_mtime for path in runtime)
        expected={row['kind'] for row in prepared['models'] if row['status']=='prepared'}
        assert expected=={row['kind'] for row in tests['models'] if row['passed']}
        for row in tests['models']:
            for treatment,sha in row['asset_sha256'].items():
                assert digest(ROOT/f"Viewer/local-art/creatures/{row['kind']}-{treatment}.gltf")==sha
        receipt={'validation_sha256':digest(report),'preparation_sha256':digest(preparation),
                 'runtime_sha256':{p.name:digest(p) for p in runtime}}
        path=folder/'pose-inputs.json'
        if path.exists():assert json.loads(path.read_text())==receipt
        else:path.write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    except (OSError,AssertionError,ValueError,KeyError):return 2
    print('CREATURE UNCHANGED POSES:',family,tests['checks'],'checks / zero failures')
    return 0
if __name__=='__main__':sys.exit(main())
