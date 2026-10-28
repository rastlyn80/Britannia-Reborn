"""Inspect the actual exported meshes, weights and native rest bindings."""
import importlib.util,json,math,hashlib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('v',ROOT/'scripts/validate-free-human.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
rows=[];max_rest_error=0.
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 base,raw=v.read(art/'equipment-base.glb')
 def rig_data(d):return {d['nodes'][i]['name']:{k:d['nodes'][i].get(k,default) for k,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]} for i in d['skins'][0]['joints']}
 canonical=rig_data(base)
 for path in sorted((art/'expansion').glob('*.glb')):
  d,raw=v.read(path);rig=rig_data(d);assert rig.keys()==canonical.keys() and len(rig)==61
  for name,bone in rig.items():
   for key,values in bone.items():
    error=max(abs(x-y) for x,y in zip(values,canonical[name][key]));max_rest_error=max(max_rest_error,error)
    assert error<1e-5,(path,name,key,error) # second float32 import/export, <=10 ppm
  names=[d['nodes'][i]['name'] for i in d['skins'][0]['joints']];count=0;max_influences=0
  for mesh in d['meshes']:
   for primitive in mesh['primitives']:
    a=primitive['attributes'];assert {'POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'}<=a.keys()
    for point in v.values(d,raw,a['POSITION']):assert all(math.isfinite(x) and abs(x)<4 for x in point)
    for js,ws in zip(v.values(d,raw,a['JOINTS_0']),v.values(d,raw,a['WEIGHTS_0'])):
     assert abs(sum(ws)-1)<1e-4 and min(ws)>=0
     active=[names[j] for j,w in zip(js,ws) if w>1e-6];assert active
     if path.stem.startswith(('hair_','beard_')) or path.stem in ['helmet','closed_helmet']:assert active==['head'],(path,active)
     if path.stem in ['sword','hammer','staff']:assert active==['hand_r'],(path,active)
     max_influences=max(max_influences,len(active));count+=1
  assert count>0
  rows.append({'female':female,'file':path.name,'vertices':count,'bones':len(rig),'max_influences':max_influences,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 assert len([r for r in rows if r['female']==female])==48,'16 pieces + 32 glove masks expected'
report={'models':rows,'max_rest_numeric_error':max_rest_error,'failures':[],'scope':'Actual exported rest/UV/weight/joint checks. Does not establish visual quality or every animation collision.'}
(ROOT/'outputs/third-dawn/character-expansion-validation.json').write_text(json.dumps(report,indent=2));print('EXPANSION ASSETS:',len(rows),'models, zero failures')
