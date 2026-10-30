"""Shared independent named-triangle audit for fitted equipment exports."""
import importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('glb',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
def triangles(path):
 d,raw=g.read(path);skin=d['skins'][0];names=[d['nodes'][i]['name'] for i in skin['joints']];out=[]
 for mesh in d['meshes']:
  for p in mesh['primitives']:
   a=p['attributes'];points=g.values(d,raw,a['POSITION']);weights=g.values(d,raw,a['WEIGHTS_0']);joints=g.values(d,raw,a['JOINTS_0']);indices=g.values(d,raw,p['indices'])
   vertices=[]
   for co,w,js in zip(points,weights,joints):
    bindings=tuple(sorted((names[j],v) for j,v in zip(js,w) if v>1e-6))
    vertices.append((tuple(co),bindings))
   for i in range(0,len(indices),3):out.append(tuple(vertices[int(index[0])] for index in indices[i:i+3]))
 return out,d

def unchanged(source,output):
 # Match complete triangles, including every vertex's named skin bindings.
 # A 2-micrometre tolerance only accommodates float32 import/export; it does
 # not permit changed fitting, remeshing, deleted plates or changed weights.
 from itertools import permutations,product
 assert len(source)==len(output)
 cells={}
 def cell(triangle):return tuple(round(sum(v[0][axis] for v in triangle)/3*10000) for axis in range(3))
 for i,tri in enumerate(source):cells.setdefault(cell(tri),set()).add(i)
 max_error=0.
 for triangle in output:
  c=cell(triangle);best=None;minimum=1.
  for offset in product([-1,0,1],repeat=3):
   key=tuple(a+b for a,b in zip(c,offset))
   for index in cells.get(key,[]):
    for candidate in permutations(source[index]):
     if any(len(a[1])!=len(b[1]) or any(n!=m or abs(x-y)>2e-5 for (n,x),(m,y) in zip(a[1],b[1])) for a,b in zip(triangle,candidate)):continue
     error=max(abs(x-y) for a,b in zip(triangle,candidate) for x,y in zip(a[0],b[0]))
     if error<minimum:minimum=error;best=(key,index)
  assert best is not None and minimum<2e-6,('changed fitted triangle/weights',triangle,minimum)
  cells[best[0]].remove(best[1]);max_error=max(max_error,minimum)
 return max_error
