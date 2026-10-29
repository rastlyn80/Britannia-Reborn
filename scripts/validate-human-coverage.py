"""Independent exported-asset, bone/weight, licence and coverage validation."""
import json,importlib.util,hashlib,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sp=importlib.util.spec_from_file_location('glb',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(sp);sp.loader.exec_module(g)
recipes=json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets']+[{'key':'armour_undercoat'},{'key':'armour_boots'}]
pins=json.loads((ROOT/'scripts/human-coverage-inputs.json').read_text())
for record in pins['gear'].values():
 assert record['license']=='CC-BY-4.0' and record['page'] and record['author']
 for name,digest in record['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest
rows=[]
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 foundation,raw=g.read(art/'equipment-base.glb')
 bones={foundation['nodes'][i]['name'] for i in foundation['skins'][0]['joints']}
 evidence=json.loads((art/'coverage/provenance.json').read_text())
 for row in recipes:
  path=art/'coverage'/(row['key']+'.glb');d,raw=g.read(path)
  assert evidence['parts'][row['key']]['sha256']==hashlib.sha256(path.read_bytes()).hexdigest()
  skin=d['skins'][0];assert {d['nodes'][i]['name'] for i in skin['joints']}==bones
  meshes=[n for n in d['nodes'] if n.get('name','').startswith('Extra_') and 'mesh' in n];assert len(meshes)==1
  count=0
  for p in d['meshes'][meshes[0]['mesh']]['primitives']:
   attrs=p['attributes'];positions=g.values(d,raw,attrs['POSITION']);weights=g.values(d,raw,attrs['WEIGHTS_0']);joints=g.values(d,raw,attrs['JOINTS_0'])
   assert all(math.isfinite(v) for co in positions for v in co)
   assert all(abs(sum(w)-1)<2e-5 and min(w)>=0 for w in weights)
   assert all(0<=i<len(skin['joints']) for js in joints for i in js)
   assert len(g.values(d,raw,p['indices']))>=12
   assert max(max(abs(v) for v in co) for co in positions)<3,('unbounded fitted mesh',row['key'])
   count+=len(positions)
  rows.append({'female':female,'asset':row['key'],'vertices':count,'sha256':evidence['parts'][row['key']]['sha256']})
out=ROOT/'outputs/human-coverage-session';out.mkdir(exist_ok=True)
(out/'asset-validation.json').write_text(json.dumps({'assets':rows,'failures':[],'scope':'Exported topology, finite bounds, normalized weights, 61 compatible joint identities, source licences/hashes. Pose and visual QA are separate.'},indent=2))
print('HUMAN COVERAGE ASSETS:',len(rows),'validated exports, no failures')
