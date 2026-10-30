"""Independent native/source, complete topology and bind audit for this batch."""
import json, hashlib, importlib.util, re, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('equipment_audit',ROOT/'scripts/human-equipment-audit.py');audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit);g=audit.g
pins=json.loads((ROOT/'scripts/human-wardrobe50-inputs.json').read_text())
rows=[r for r in json.loads((ROOT/'scripts/human-coverage-recipes.json').read_text())['assets'] if r['kind']=='expansion50']
for name,digest in pins['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
data=Path(json.loads((ROOT/'Server/runtime/Configuration/modernuo.json').read_text())['dataDirectories'][0])
for name,digest in pins['client_files'].items():assert hashlib.sha256((data/name).read_bytes()).hexdigest()==digest,name
types=set()
for line in (data/'mobtypes.txt').read_text().splitlines():
 parts=line.split('#')[0].split()
 if len(parts)>1 and parts[1]=='EQUIPMENT':types.add(int(parts[0]))
catalog={r['id']:r for r in json.loads((ROOT/'outputs/human-catalogue/human-port-catalogue.json').read_text())['wearables']}
native=ROOT/'Server/ModernUO';classes={}
assert pins['native_reference']['revision'] in (ROOT/'Server/dependencies.json').read_text()
for file in (native/'Projects/UOContent').rglob('*.cs'):
 text=file.read_text(encoding='utf-8-sig')
 for m in re.finditer(r'public\s+(?:(?:abstract|partial|sealed)\s+)*class\s+(\w+)(?:\s*:\s*([\w.]+))?[^\{]*\{',text):
  depth=1;i=m.end()
  while i<len(text) and depth:depth+=(text[i]=='{')-(text[i]=='}');i+=1
  restricted=bool(re.search(r'RequiredRace[s]?\s*=>\s*Race\.(?:Elf|Gargoyle|AllowElvesOnly|AllowGargoylesOnly)\b',text[m.end():i-1]))
  c=classes.setdefault(m.group(1),{'parent':m.group(2),'restricted':False});c['restricted']|=restricted
  if m.group(2):c['parent']=m.group(2)
def allowed(name):
 seen=set()
 while name in classes and name not in seen:
  seen.add(name);c=classes[name]
  if c['restricted']:return False
  name=c['parent']
 return True
native_count=0;client_count=0;ids=set()
for row in rows:
 for graphic in row['graphics']:
  assert graphic not in ids;ids.add(graphic);assert graphic in catalog
  proof=pins['native_graphics'][str(graphic)]
  if proof.get('classes'):
   accepted=False
   for ref in proof['classes']:
    file=native/ref['file'];assert hashlib.sha256(file.read_bytes()).hexdigest()==ref['sha256']
    if not allowed(ref['class']):continue
    if graphic in ref['ids']:
     assert graphic in {int(x,16) for x in re.findall(r'0x[\da-fA-F]+',file.read_text(encoding='utf-8-sig'))};accepted=True
    elif proof['basis'].startswith('counterpart of '):
     canonical=int(proof['basis'].split()[-1],16);a,b=catalog[graphic],catalog[canonical]
     assert canonical in ref['ids'] and a['name']==b['name'] and a['source_animation_reference']==b['source_animation_reference'] and a['source_animation_reference']>0;accepted=True
   assert accepted,('no human-compatible native class',row['key']);native_count+=1
  else:
   assert proof['animation_reference']==catalog[graphic]['source_animation_reference'] and proof['animation_reference'] in types
   assert not any(word in catalog[graphic]['name'].lower() for word in ['gargoyle','gargish','elven'])
   client_count+=1
exports=[]
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 foundation,raw=g.read(art/'equipment-base.glb');skin=foundation['skins'][0];inverse={foundation['nodes'][i]['name']:v for i,v in zip(skin['joints'],g.values(foundation,raw,skin['inverseBindMatrices']))}
 provenance=json.loads((art/'coverage/provenance.json').read_text())
 for row in rows:
  variants=[('',row.get('base'))]
  if row.get('riding_base'):variants.append(('_riding',row['riding_base']))
  for suffix,base in variants:
   key=row['key']+suffix;path=art/'coverage'/(key+'.glb');triangles,d=audit.triangles(path);_,raw=g.read(path);digest=hashlib.sha256(path.read_bytes()).hexdigest()
   proof=provenance['parts'][key];assert proof['sha256']==digest and proof['recipe_sha256']==hashlib.sha256((ROOT/'scripts/prepare-human-wardrobe50.py').read_bytes()).hexdigest()
   assert proof['inputs_sha256']==hashlib.sha256((ROOT/'scripts/human-wardrobe50-inputs.json').read_bytes()).hexdigest()
   assert proof['recipe_row_sha256']==hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest()
   for file,digest in proof['builder_dependencies'].items():assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==digest
   skin=d['skins'][0];names=[d['nodes'][i]['name'] for i in skin['joints']];assert set(names)==set(inverse) and len(names)==61
   for name,matrix in zip(names,g.values(d,raw,skin['inverseBindMatrices'])):assert max(abs(a-b) for a,b in zip(matrix,inverse[name]))<1e-5
   for mesh in d['meshes']:
    for primitive in mesh['primitives']:
     a=primitive['attributes']
     assert all(math.isfinite(v) for p in g.values(d,raw,a['NORMAL']) for v in p)
     assert all(math.isfinite(v) and abs(v)<3 for p in g.values(d,raw,a['POSITION']) for v in p)
     assert all(min(w)>=0 and abs(sum(w)-1)<2e-5 for w in g.values(d,raw,a['WEIGHTS_0']))
   result={'female':female,'asset':key,'sha256':digest,'triangles':len(triangles),'base':base}
   if base:
    source,_=audit.triangles(art/(base+'.glb'))
    result['max_export_error']=audit.unchanged(source,triangles)
    result['preserved_complete_topology_and_named_weights']=True
   for mat in d.get('materials',[]):
    pbr=mat.get('pbrMetallicRoughness',{});assert mat.get('alphaMode','OPAQUE')=='OPAQUE'
    if mat.get('name','').startswith('Armour_Lining'):assert pbr.get('metallicFactor',1)<.01 and pbr.get('roughnessFactor',1)>.8
   exports.append(result)
out=ROOT/'outputs/human-wardrobe50';out.mkdir(exist_ok=True)
(out/'asset-validation.json').write_text(json.dumps({'native_class_or_counterpart_graphics':native_count,'curated_client_equipment_graphics':client_count,'total_graphics':len(ids),'models_per_body':len(rows),'exports':exports,'failures':[],'scope':'Exact hashes/licences and 61 inverse binds, finite geometry/weights, complete derivative triangle/weight preservation with <2-micrometre float32 tolerance. Class-backed and curated client EQUIPMENT references are distinct; client references do not certify active server classes or racial/gameplay eligibility. Physical pose, opacity, hair and final art quality are separate checks.'},indent=2))
print('HUMAN WARDROBE50:',len(ids),'IDs (',native_count,'native /',client_count,'client),',len(exports),'exports; no failures')
