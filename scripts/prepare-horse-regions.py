"""Blender Python: annotate the pinned horse mesh with coat/tack vertex regions.

No texture pixels, geometry, UVs, binds or source animations are changed. Local
derived GLB stays subject to the source's non-redistribution restriction.
"""
import bpy,numpy as np,json,struct,hashlib,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('g',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
path=ROOT/'Viewer/local-art/horses/warhorse.glb';pins=json.loads((ROOT/'scripts/horse-inputs.json').read_text())
assert hashlib.sha256(path.read_bytes()).hexdigest()==pins['files']['Warhorse_Lite/Warhorse_Lite.glb']
d,raw=g.read(path);raw=bytearray(raw);work=ROOT/'work/horse-polish';work.mkdir(parents=True,exist_ok=True)
images=[]
for number in [1,2]:
 image=d['images'][number];view=d['bufferViews'][image['bufferView']];suffix='.png' if image['mimeType']=='image/png' else '.jpg'
 target=work/('region-input-%d'%number+suffix);target.write_bytes(raw[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
 image=bpy.data.images.load(str(target),check_existing=False);image.colorspace_settings.name='Non-Color'
 pixels=np.empty(len(image.pixels),np.float32);image.pixels.foreach_get(pixels);images.append(pixels.reshape(image.size[1],image.size[0],4))
def sample(image,uv):
 h,w,_=image.shape;return image[min(h-1,max(0,int((1-uv[1])*h))),min(w-1,max(0,int(uv[0]*w))),:3]
records=[]
for mesh in d['meshes']:
 for primitive in mesh['primitives']:
  attrs=primitive['attributes'];uv=np.array(g.values(d,raw,attrs['TEXCOORD_0']));points=g.values(d,raw,attrs['POSITION']);indices=[i[0] for i in g.values(d,raw,primitive['indices'])]
  votes=np.zeros(len(uv));counts=np.zeros(len(uv));weights=g.values(d,raw,attrs['WEIGHTS_0']);joints=g.values(d,raw,attrs['JOINTS_0']);names=[d['nodes'][i]['name'] for i in d['skins'][0]['joints']]
  for face in np.array(indices).reshape(-1,3):
   samples=[uv[face].mean(axis=0)]+[uv[face[k]]*.6+uv[face[(k+1)%3]]*.2+uv[face[(k+2)%3]]*.2 for k in range(3)]
   albedo=np.mean([sample(images[0],p) for p in samples],axis=0);orm=np.mean([sample(images[1],p) for p in samples],axis=0)
   dark_hair=max(albedo)<.12 and (albedo[0]-albedo[2])/max(albedo[0],.0001)<.38
   coat=1. if orm[1]>.555 and orm[2]<.2 and not dark_hair else 0.
   for index in face:votes[index]+=coat;counts[index]+=1
  values=[]
  for i,point in enumerate(points):
   tail=sum(w for j,w in zip(joints[i],weights[i]) if names[j].startswith('tail_'))
   value=float(votes[i]/max(1,counts[i])) if tail<.2 else 0.
   values.extend([value,0.,0.,1.])
  while len(raw)%4:raw.append(0)
  offset=len(raw);raw.extend(struct.pack('<%df'%len(values),*values))
  view=len(d['bufferViews']);d['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(values)*4,'target':34962})
  accessor=len(d['accessors']);d['accessors'].append({'bufferView':view,'componentType':5126,'count':len(points),'type':'VEC4'});attrs['COLOR_0']=accessor
  records.append({'vertices':len(points),'triangles':len(indices)//3,'coat_vertices':sum(values[i]>.5 for i in range(0,len(values),4))})
d['buffers'][0]['byteLength']=len(raw);encoded=json.dumps(d,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
result=struct.pack('<4sII',b'glTF',2,12+8+len(encoded)+8+len(raw))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(raw),0x004e4942)+raw
destination=path.with_name('warhorse-regions.glb');destination.write_bytes(result)
destination.with_suffix('.provenance.json').write_text(json.dumps({'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'sha256':hashlib.sha256(result).hexdigest(),'method':'Source ORM/albedo triangle-region voting; tail bone exclusion; no texture/position/UV/bind/animation changes','license':pins['license'],'meshes':records},indent=2))
print('HORSE COAT REGIONS',records,flush=True)
