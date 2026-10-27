"""Validate all actual CC0 clothing variants independently of the Blender builder."""
import importlib.util,json,hashlib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FEMALE='--female' in sys.argv
ART=ROOT/('Viewer/local-art/free-equipment-female' if FEMALE else 'Viewer/local-art/free-equipment')
BASE=ROOT/('Viewer/local-art/free-human-female/free-human.glb' if FEMALE else 'Viewer/local-art/free-human/free-human.glb')
spec=importlib.util.spec_from_file_location('free_validation',Path(__file__).with_name('validate-free-human.py'));v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
rows=[];rig=None;animations=None;max_rest_error=0.
def compare_rest(a,b):
 if isinstance(a,dict):
  assert a.keys()==b.keys()
  return max((compare_rest(a[k],b[k]) for k in a),default=0.)
 if isinstance(a,(list,tuple)):
  assert len(a)==len(b)
  return max((compare_rest(x,y) for x,y in zip(a,b)),default=0.)
 if isinstance(a,(int,float)) and isinstance(b,(int,float)):return abs(a-b)
 assert a==b
 return 0.
for name in ['base','tunic','pants','boots','robe','hood','viking','monk']:
 p=ART/('equipment-'+name+'.glb');row,current,clips=v.inspect(p,garment_prefix='Free_')
 if rig is None:rig,animations=current,clips
 error=compare_rest(current,rig);max_rest_error=max(max_rest_error,error)
 assert error<1e-6,'Variant changed the shared skeleton'
 assert clips==animations,'Variant changed the shared animation'
 assert (row['garment_vertices']>0)==(name!='base')
 rows.append(row)
# This pass must not silently sculpt a different body for the skin comparison.
def body_positions(path):
 d,raw=v.read(path);node=next(n for n in d['nodes'] if n.get('name','').startswith('Body'))
 p=d['meshes'][node['mesh']]['primitives'][0]
 return v.values(d,raw,p['attributes']['POSITION'])
a=body_positions(BASE);b=body_positions(ART/'equipment-base.glb')
assert len(a)==len(b),'Material pass changed vertex topology'
body_error=max(abs(x-y) for p,q in zip(a,b) for x,y in zip(p,q))
assert body_error<2e-6,'Material pass changed the underlying body geometry'
# Compare native tracks to the pre-existing base, not only between new variants.
_,native_rig,native_clips=v.inspect(BASE)
def canonical_rest(r):
 return {n:{k:x[k] if x[k] is not None else default for k,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]} for n,x in r.items()}
native_rest_error=compare_rest(canonical_rest(native_rig),canonical_rest({n:x for n,x in rig.items() if not n.startswith('robe_')}))
assert native_rest_error<2e-6
current_clips=sorted((n,[t for t in tracks if not t[0].startswith('robe_')]) for n,tracks in animations)
native_motion_error=0.
for (name,old),(newname,new) in zip(sorted(native_clips),current_clips):
 assert name==newname and len(old)==len(new)
 for a,b in zip(old,new):
  assert a[:2]==b[:2]
  native_motion_error=max(native_motion_error,compare_rest(a[2],b[2]))
  assert len(a[3])==len(b[3])
  for x,y in zip(a[3],b[3]):
   error=max(abs(i-j) for i,j in zip(x,y))
   if a[1]=='rotation':error=min(error,max(abs(i+j) for i,j in zip(x,y)))
   native_motion_error=max(native_motion_error,error)
assert native_motion_error<2e-5,'Skirt recipe altered native animation'

def body_data(path):
 d,raw=v.read(path);node=next(n for n in d['nodes'] if n.get('name','').startswith('Body'))
 p=d['meshes'][node['mesh']]['primitives'][0]
 return v.values(d,raw,p['attributes']['POSITION']),[i[0] for i in v.values(d,raw,p['indices'])]

# The full leg topology, including connecting triangles, must remain under robes.
# Exported mesh positions use glTF's Y-up convention.
base_points,base_indices=body_data(ART/'equipment-base.glb')
def key(p):return tuple(round(x,3) for x in p)
expected={tuple(sorted(key(base_points[i]) for i in base_indices[k:k+3])) for k in range(0,len(base_indices),3) if all(base_points[i][1]<.88 for i in base_indices[k:k+3])}
retained={}
for name in ['robe','monk']:
 pts,idx=body_data(ART/f'equipment-{name}.glb')
 actual={tuple(sorted(key(pts[i]) for i in idx[k:k+3])) for k in range(0,len(idx),3)}
 missing=expected-actual
 assert not missing,f'{name}: {len(missing)} lower-body triangles were hidden'
 retained[name]=len(expected)
hair_rows=[]
for style in ([] if FEMALE else ['ponytail01']):
 path=ROOT/'Viewer/local-art/free-equipment'/f'hair_{style}.glb'
 if not path.exists():continue # Withheld exploratory style, not a batch input.
 d,raw=v.read(path)
 joints=d['skins'][0]['joints'];names=[d['nodes'][i]['name'] for i in joints]
 assert set(names)==set(native_rig),'Hair uses a different native rig'
 rest={n:{k:d['nodes'][i].get(k) for k in ['translation','rotation','scale']} for n,i in zip(names,joints)}
 error=compare_rest(canonical_rest(native_rig),canonical_rest(rest));assert error<2e-6
 count=0
 for node in d['nodes']:
  if 'mesh' not in node:continue
  for p in d['meshes'][node['mesh']]['primitives']:
   att=p['attributes'];points=v.values(d,raw,att['POSITION']);ws=v.values(d,raw,att['WEIGHTS_0']);js=v.values(d,raw,att['JOINTS_0'])
   assert len(points)==len(ws)==len(js)
   for weights,indices in zip(ws,js):
    assert abs(sum(weights)-1)<1e-4 and min(weights)>=0
    assert all(j<len(names) for j,w in zip(indices,weights) if w>0)
   count+=len(points)
 assert count>0,'Empty hair export'
 hair_rows.append(dict(style=style,vertices=count,native_rest_error=error,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
runtime=[]
for path in sorted((ART/'runtime').glob('*.glb')):
 d,raw=v.read(path);joints=d['skins'][0]['joints'];names=[d['nodes'][i]['name'] for i in joints]
 assert len(joints)==61 and len(set(names))==61
 rest={n:{k:d['nodes'][i].get(k) for k in ['translation','rotation','scale']} for n,i in zip(names,joints)}
 assert compare_rest(canonical_rest(rig),canonical_rest(rest))<2e-6
 count=0
 for node in d['nodes']:
  if 'mesh' not in node:continue
  for p in d['meshes'][node['mesh']]['primitives']:
   att=p['attributes'];assert {'POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'}<=att.keys()
   ws=v.values(d,raw,att['WEIGHTS_0']);js=v.values(d,raw,att['JOINTS_0'])
   for weights,indices in zip(ws,js):
    assert abs(sum(weights)-1)<1e-4 and min(weights)>=0
    assert all(j<61 for j,w in zip(indices,weights) if w>0)
   count+=len(ws)
 assert count>0
 runtime.append(dict(file=path.name,vertices=count,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
assert len(runtime)==37,'Expected five shared pieces and 32 body masks'
report=dict(sex='female' if FEMALE else 'male',models=rows,runtime=runtime,shared_rig_and_animation=True,max_rest_numeric_difference=max_rest_error,same_body_geometry=True,max_body_roundtrip_error=body_error,native_rest_error=native_rest_error,native_animation_error=native_motion_error,lower_body_triangles_retained=retained,hair=hair_rows,failures=[])
(ROOT/'outputs/third-dawn'/('female-equipment-asset-validation.json' if FEMALE else 'free-equipment-asset-validation.json')).write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
