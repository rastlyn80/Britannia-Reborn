"""Independent source/ID/rig/backing audit of the human frontier exports."""
import json, hashlib, importlib.util, re, math
from pathlib import Path
from collections import Counter

ROOT=Path(__file__).resolve().parents[1]
sp=importlib.util.spec_from_file_location('glb',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(sp);sp.loader.exec_module(g)
pins=json.loads((ROOT/'scripts/human-frontier-inputs.json').read_text())
rows=[r for r in json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets'] if r['kind']=='expansion35']
for name,digest in pins['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
native=ROOT/'Server/ModernUO'
dependency=json.loads((ROOT/'Server/dependencies.json').read_text())
assert pins['native_reference']['revision'] in json.dumps(dependency)
catalog={r['id']:r for r in json.loads((ROOT/'outputs/human-catalogue/human-port-catalogue.json').read_text())['wearables']}
# Read-only ancestry check, including intermediate weapon/hat base classes.
classes={}
for file in (native/'Projects/UOContent').rglob('*.cs'):
 text=file.read_text(encoding='utf-8-sig')
 for m in re.finditer(r'public\s+(?:(?:abstract|partial|sealed)\s+)*class\s+(\w+)(?:\s*:\s*([\w.]+))?[^\{]*\{',text):
  depth=1;i=m.end()
  while i<len(text) and depth:depth+=(text[i]=='{')-(text[i]=='}');i+=1
  block=text[m.end():i-1];parent=m.group(2)
  restricted=bool(re.search(r'RequiredRace[s]?\s*=>\s*Race\.(?:Elf|Gargoyle|AllowElvesOnly|AllowGargoylesOnly)\b',block))
  record=classes.setdefault(m.group(1),{'parent':parent,'restricted':False})
  record['restricted']|=restricted
  if parent:record['parent']=parent
def human_ancestry(name):
 seen=set()
 while name in classes and name not in seen:
  seen.add(name);c=classes[name]
  if c['restricted']:return False
  name=c['parent']
 return True
ids=set()
for row in rows:
 for graphic in row['graphics']:
  assert graphic not in ids;ids.add(graphic);assert graphic in catalog
  references=pins['native_graphics'][str(graphic)];valid=False
  for ref in references:
   file=native/ref['file'];assert hashlib.sha256(file.read_bytes()).hexdigest()==ref['sha256']
   if not human_ancestry(ref['class']):continue
   if graphic in ref['ids']:valid=True
   elif ref['alias_basis'].startswith('client tile counterpart of '):
    canonical=int(ref['alias_basis'].split(':')[0].split()[-1],16)
    a,b=catalog[graphic],catalog[canonical]
    assert canonical in ref['ids'] and a['name']==b['name'] and a['source_animation_reference']==b['source_animation_reference'] and a['source_animation_reference']>0
    valid=True
  assert valid,('no human-compatible native source',row['key'],hex(graphic))

sp=importlib.util.spec_from_file_location('equipment_audit',ROOT/'scripts/human-equipment-audit.py');audit=importlib.util.module_from_spec(sp);sp.loader.exec_module(audit)
triangles=audit.triangles;unchanged=audit.unchanged

assets=[]
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 foundation,raw=g.read(art/'equipment-base.glb');skin=foundation['skins'][0]
 inverse={foundation['nodes'][i]['name']:matrix for i,matrix in zip(skin['joints'],g.values(foundation,raw,skin['inverseBindMatrices']))}
 provenance=json.loads((art/'coverage/provenance.json').read_text())
 for row in rows:
  path=art/'coverage'/(row['key']+'.glb')
  source=None
  if row['base']:source,_=triangles(art/(row['base']+'.glb'))
  output,d=triangles(path)
  record_source=provenance['parts'][row['key']]
  assert record_source['sha256']==hashlib.sha256(path.read_bytes()).hexdigest()
  assert record_source['recipe_sha256']==hashlib.sha256((ROOT/'scripts/prepare-human-frontier.py').read_bytes()).hexdigest()
  _,raw=g.read(path);skin=d['skins'][0]
  names=[d['nodes'][i]['name'] for i in skin['joints']];assert set(names)==set(inverse) and len(names)==61
  for name,matrix in zip(names,g.values(d,raw,skin['inverseBindMatrices'])):assert max(abs(a-b) for a,b in zip(matrix,inverse[name]))<1e-5
  for mesh in d['meshes']:
   for primitive in mesh['primitives']:
    assert all(math.isfinite(v) for co in g.values(d,raw,primitive['attributes']['NORMAL']) for v in co)
  record={'female':female,'asset':row['key'],'triangles':len(output),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
  if row['base']:
   error=unchanged(source,output)
   record['exact_source_triangles_and_named_weights']=True
   record['max_export_position_error_metres']=error
  for mat in d.get('materials',[]):
   pbr=mat.get('pbrMetallicRoughness',{})
   assert mat.get('alphaMode','OPAQUE')=='OPAQUE',('unexpected transparent equipment',row['key'])
   if mat.get('name','').startswith('Armour_Lining'):
    assert pbr.get('metallicFactor',1)<.01 and pbr.get('roughnessFactor',1)>.8
   if 'frontier_dragon' in mat.get('name','') or 'frontier_lamellar_plate' in mat.get('name',''):
    assert pbr.get('metallicFactor',1)>.8 and pbr.get('roughnessFactor',1)>=.5
  assets.append(record)
out=ROOT/'outputs/human-frontier';out.mkdir(exist_ok=True)
(out/'asset-validation.json').write_text(json.dumps({'native_graphics':len(ids),'models_per_body':len(rows),'exports':assets,'failures':[],'scope':'Hash-pinned original/CC0 inputs and generator provenance; pinned ModernUO source hashes, class ancestry and explicit client direction aliases. All 61 named inverse binds match the body. Derivatives preserve every triangle and named weight within float32 roundtrip tolerances (positions <2 micrometres, weights <2e-5); armour backing remains opaque/neutral. New parametric geometry has separate finite pose/GPU evidence. Exact ornaments and per-item choreography are not certified.'},indent=2))
print('HUMAN FRONTIER:',len(ids),'native graphics,',len(assets),'exports,',sum('exact_source_triangles_and_named_weights' in a for a in assets),'exact fitted derivatives; no failures')
