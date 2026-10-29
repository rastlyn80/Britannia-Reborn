"""Static validation of the actual licensed horse, not catalogue declarations."""
import json,hashlib,importlib.util,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('glb',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
pins=json.loads((ROOT/'scripts/horse-inputs.json').read_text());art=ROOT/'Viewer/local-art/horses'
for source,name in [('Warhorse_Lite/Warhorse_Lite.glb','warhorse.glb'),('Warhorse_Lite/LICENSE.txt','LICENSE-Warhorse.txt'),('Warhorse_Lite/README.md','SOURCE-README.md')]:assert hashlib.sha256((art/name).read_bytes()).hexdigest()==pins['files'][source]
d,raw=g.read(art/'warhorse.glb');skin=d['skins'][0];bones={d['nodes'][i]['name'] for i in skin['joints']}
assert len(bones)==39 and {'saddle_socket','stirrup_L','stirrup_R','mouth_socket'}<=bones
clips={a['name']:a for a in d['animations']};assert set(clips)=={'idle_loop','walk_loop','canter_loop','rear'}
triangles=0;vertices=0
for mesh in d['meshes']:
 for primitive in mesh['primitives']:
  a=primitive['attributes'];positions=g.values(d,raw,a['POSITION']);weights=g.values(d,raw,a['WEIGHTS_0']);joints=g.values(d,raw,a['JOINTS_0'])
  assert all(math.isfinite(c) for p in positions for c in p)
  assert all(abs(sum(w)-1)<1e-4 and min(w)>=0 for w in weights)
  assert all(0<=j<len(skin['joints']) for row in joints for j in row)
  triangles+=len(g.values(d,raw,primitive['indices']))//3;vertices+=len(positions)
assert triangles==9916
derived=art/'warhorse-regions.glb'
if derived.exists():
 annotated,annotated_raw=g.read(derived)
 assert annotated_raw[:len(raw)]==raw,'Region preparation changed original source binary data'
 for key in ['nodes','skins','animations','images','materials']:assert annotated[key]==d[key],key
 for original_mesh,new_mesh in zip(d['meshes'],annotated['meshes']):
  for original,new in zip(original_mesh['primitives'],new_mesh['primitives']):
   for key,value in original['attributes'].items():assert new['attributes'][key]==value,key
   assert new['indices']==original['indices']
   assert all(0<=v<=1 for row in g.values(annotated,annotated_raw,new['attributes']['COLOR_0']) for v in row)
report={'source':pins,'triangles':triangles,'vertices':vertices,'bones':len(bones),'clips':list(clips),'failures':[],'scope':'Pinned archive members, genuine skinned geometry, finite coordinates, normalized weights, saddle/stirrups and four real source animations. Contact/playback tests are separate.'}
out=ROOT/'outputs/horse-session';out.mkdir(exist_ok=True);(out/'asset-validation.json').write_text(json.dumps(report,indent=2))
print('HORSE ASSET: 9916 measured triangles, 39 joints, 4 clips; pinned source/license pass (publisher page lists 9938 triangles)')
