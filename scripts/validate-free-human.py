"""Inspect the actual private fitted GLBs, independent of Blender scene objects."""
import json,struct,hashlib,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(path):
 raw=path.read_bytes();magic,version,length=struct.unpack_from('<4sII',raw);assert magic==b'glTF' and version==2 and length==len(raw)
 n,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
 d=json.loads(raw[20:20+n]);off=20+n;size,kind=struct.unpack_from('<II',raw,off);assert kind==0x004e4942
 return d,raw[off+8:off+8+size]
def values(d,raw,index):
 a=d['accessors'][index];view=d['bufferViews'][a['bufferView']]
 fmt,step={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
 width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 stride=view.get('byteStride',width*step);offset=view.get('byteOffset',0)+a.get('byteOffset',0)
 return [struct.unpack_from('<'+fmt*width,raw,offset+i*stride) for i in range(a['count'])]
def inspect(path, garment_prefix='UO_'):
 d,raw=read(path);joint_nodes=d['skins'][0]['joints'];names=[d['nodes'][i]['name'] for i in joint_nodes]
 expected=61 if garment_prefix=='Free_' else 53
 assert len(names)==expected and len(set(names))==expected and not any('bip01' in n.lower() for n in names)
 if expected==61:assert {n for n in names if n.startswith('robe_')}=={f'robe_{side}_{i}' for side in ['front','back'] for i in range(4)}
 assert {a['name'] for a in d['animations']}=={'Idle','Walk','Run'}
 checked=0;garment_vertices=0;triangles=0
 for node in d['nodes']:
  if 'mesh' not in node:continue
  for p in d['meshes'][node['mesh']]['primitives']:
   att=p['attributes'];positions=values(d,raw,att['POSITION']);weights=values(d,raw,att['WEIGHTS_0']);joints=values(d,raw,att['JOINTS_0'])
   assert len(positions)==len(weights)==len(joints)
   for point,ws,js in zip(positions,weights,joints):
    assert all(math.isfinite(x) for x in point) and abs(sum(ws)-1)<1e-4 and min(ws)>=0
    assert all(j<len(names) for j,w in zip(js,ws) if w>0)
   checked+=len(positions)
   if node['name'].startswith(garment_prefix):garment_vertices+=len(positions)
   triangles+=d['accessors'][p['indices']]['count']//3
 rig={n:{k:d['nodes'][i].get(k) for k in ['translation','rotation','scale']} for i,n in zip(joint_nodes,names)}
 animation=[]
 for a in d['animations']:
  tracks=[]
  for c in a['channels']:
   sample=a['samplers'][c['sampler']];tracks.append((d['nodes'][c['target']['node']]['name'],c['target']['path'],values(d,raw,sample['input']),values(d,raw,sample['output'])))
  animation.append((a['name'],sorted(tracks)))
 return dict(file=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bones=len(names),clips=[a['name'] for a in d['animations']],checked_vertices=checked,garment_vertices=garment_vertices,triangles=triangles),rig,animation

def main():
 out=ROOT/'Viewer/local-art/free-human';rows=[];base_rig=None;base_animation=None
 for slot in ['base','shirt','robe']:
  path=out/('free-human'+('' if slot=='base' else '-'+slot)+'.glb');row,rig,animation=inspect(path)
  if base_rig is None:base_rig,base_animation=rig,animation
  assert rig==base_rig,'Variant changed target rig'
  assert animation==base_animation,'Variant changed animation tracks'
  assert (row['garment_vertices']>0)==(slot!='base')
  rows.append(row)
 result=dict(models=rows,shared_rig_and_animation=True,failures=[])
 (ROOT/'outputs/third-dawn/free-human-asset-validation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
