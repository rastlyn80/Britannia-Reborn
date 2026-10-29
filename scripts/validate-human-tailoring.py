"""Verify every new accessory variant, source pins and unmodified native bind data."""
import json,hashlib,math,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('glb',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
pins=json.loads((ROOT/'scripts/human-tailoring-inputs.json').read_text(encoding='utf-8'))
for name,digest in pins['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
recipes=[r for r in json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets'] if r['kind']=='tailoring']
rows=[];hair_rows=[]
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment');foundation,_=g.read(art/'equipment-base.glb');names={foundation['nodes'][i]['name'] for i in foundation['skins'][0]['joints']}
 report=json.loads((art/'coverage/provenance.json').read_text())
 for recipe in recipes:
  variants=[recipe['key']]
  if recipe['key']=='lantern':variants.append('lantern_lit')
  for name in variants:
   path=art/'coverage'/(name+'.glb');d,raw=g.read(path);digest=hashlib.sha256(path.read_bytes()).hexdigest();evidence=report['parts'][name]
   assert digest==evidence['sha256'],name
   assert evidence['recipe_sha256']==hashlib.sha256((ROOT/'scripts/human-tailoring.py').read_bytes()).hexdigest(),name
   assert {d['nodes'][i]['name'] for i in d['skins'][0]['joints']}==names and len(names)==61
   vertices=0
   for mesh in d['meshes']:
    for primitive in mesh['primitives']:
     a=primitive['attributes'];points=g.values(d,raw,a['POSITION']);weights=g.values(d,raw,a['WEIGHTS_0'])
     assert all(math.isfinite(x) and abs(x)<3 for p in points for x in p),name
     assert all(abs(sum(w)-1)<2e-5 and min(w)>=0 for w in weights),name
     assert all(math.isfinite(x) for p in g.values(d,raw,a['NORMAL']) for x in p),name
     vertices+=len(points)
   rows.append({'female':female,'asset':name,'vertices':vertices,'sha256':digest})
 hair_report=json.loads((art/'expansion/provenance.json').read_text())
 for style in ['long','ponytail']:
  for variant in ['covered','covered_cloak']:
   name='hair_'+style+'_'+variant+'_coif';evidence=hair_report['parts'][name];source=art/'expansion'/('hair_'+style+'_'+variant+'.glb');path=art/'expansion'/(name+'.glb');d,raw=g.read(path)
   assert evidence['sha256']==hashlib.sha256(path.read_bytes()).hexdigest()
   assert evidence['source_sha256']==hashlib.sha256(source.read_bytes()).hexdigest()
   assert evidence['recipe_sha256']==hashlib.sha256((ROOT/'scripts/prepare-coif-hair.py').read_bytes()).hexdigest()
   assert {d['nodes'][i]['name'] for i in d['skins'][0]['joints']}==names
   hair_rows.append({'female':female,'asset':name,'sha256':evidence['sha256'],'source_sha256':evidence['source_sha256']})
out=ROOT/'outputs/human-tailoring';out.mkdir(exist_ok=True)
(out/'asset-validation.json').write_text(json.dumps({'exports':rows,'hair_exports':hair_rows,'failures':[],'scope':'All headwear/book/lantern variants and coif hair derivatives, source hashes, compatible 61 named joints, finite normalized weighted geometry and generator provenance. GPU occlusion quality is checked separately.'},indent=2))
print('HUMAN TAILORING ASSETS:',len(rows),'accessories +',len(hair_rows),'hair exports validated')
