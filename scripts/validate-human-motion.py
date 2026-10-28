"""Independently inspect exported motion, fixed body geometry and skin binds."""
import importlib.util,json,hashlib,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('glb',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
rows=[]
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 source,sraw=g.read(art/'equipment-base.glb');data,raw=g.read(art/'motion/human-motion.glb')
 metadata=json.loads((art/'motion/motion.json').read_text())
 def nodes(d):return {d['nodes'][i]['name']:d['nodes'][i] for i in d['skins'][0]['joints']}
 a=nodes(source);b=nodes(data);assert a.keys()==b.keys() and len(a)==61
 for name,bone in b.items():
  for key,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]:
   assert max(abs(x-y) for x,y in zip(a[name].get(key,default),bone.get(key,default)))<1e-5,(female,name,key)
 def positions(d,raw):
  node=next(n for n in d['nodes'] if n.get('name','')=='Body');p=d['meshes'][node['mesh']]['primitives'][0]
  return g.values(d,raw,p['attributes']['POSITION'])
 p=positions(source,sraw);q=positions(data,raw)
 assert len(p)==len(q)
 error=max(abs(x-y) for a,b in zip(p,q) for x,y in zip(a,b));assert error<2e-6
 def attributes(d):
  node=next(n for n in d['nodes'] if n.get('name','')=='Body');return d['meshes'][node['mesh']]['primitives'][0]['attributes']
 aa=attributes(source);bb=attributes(data)
 for key in ['TEXCOORD_0','WEIGHTS_0']:
  assert max(abs(x-y) for p,q in zip(g.values(source,sraw,aa[key]),g.values(data,raw,bb[key])) for x,y in zip(p,q))<2e-6,('Changed body attribute',female,key)
 def inverse_binds(d,raw):return {d['nodes'][joint]['name']:matrix for joint,matrix in zip(d['skins'][0]['joints'],g.values(d,raw,d['skins'][0]['inverseBindMatrices']))}
 old=inverse_binds(source,sraw);new=inverse_binds(data,raw)
 assert max(abs(x-y) for name in old for x,y in zip(old[name],new[name]))<1e-5,'Changed inverse bind matrices'
 assert {a['name'] for a in data['animations']}==set(metadata['clips']) and len(metadata['clips'])==45
 for animation in data['animations']:
  controls=set()
  for channel in animation['channels']:
   sampler=animation['samplers'][channel['sampler']];values=g.values(data,raw,sampler['output']);times=g.values(data,raw,sampler['input'])
   assert all(math.isfinite(v) for value in values for v in value)
   name=data['nodes'][channel['target']['node']]['name'];assert name in b
   if name.startswith('robe_'):controls.add(name)
   if name.lower()=='root':assert max(max(abs(x-y) for x,y in zip(values[0],v)) for v in values)<1e-6,'Animated authoritative root'
   if channel['target']['path']=='rotation':assert all(abs(sum(x*x for x in v)-1)<1e-4 for v in values)
  assert len(controls)==8,(animation['name'],'missing rebaked garment controls')
  rows.append({'female':female,'clip':animation['name'],'channels':len(animation['channels']),'duration':max(float(v[0]) for v in times),'controls':len(controls)})
 print('HUMAN MOTION:',female,len(metadata['clips']),'clips, 61 unchanged joints, body max error',error)
(ROOT/'outputs/third-dawn/human-motion-validation.json').write_text(json.dumps({'clips':rows,'failures':[],'scope':'Exported fixed-body/rig, root, quaternion and garment-track checks; separate pose and visual checks required.'},indent=2))
