"""Measure solid prop samples against clothing in final engine modifier poses.

Ordinary sleeve occlusion is not penetration. Test closest triangle interiors;
open cuff boundaries and the intentionally grasping hand are excluded.
"""
import json,importlib.util,math
from pathlib import Path
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('g',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
def load(path,prefix):
 d,raw=g.read(path);s=d['skins'][0];names=[d['nodes'][i]['name'] for i in s['joints']];inverse=np.array(g.values(d,raw,s['inverseBindMatrices'])).reshape(-1,4,4).transpose(0,2,1);parts=[]
 for node in d['nodes']:
  if 'mesh' not in node or not node.get('name','').startswith(prefix):continue
  for p in d['meshes'][node['mesh']]['primitives']:
   a=p['attributes'];parts.append((np.array(g.values(d,raw,a['POSITION'])),np.array(g.values(d,raw,a['WEIGHTS_0'])),np.array(g.values(d,raw,a['JOINTS_0']),int),np.array(g.values(d,raw,p['indices']),int).reshape(-1,3)))
 return names,inverse,parts
def posed(asset,pose):
 names,inverse,parts=asset;matrices=[]
 for name in names:
  m=np.eye(4);m[:3,:]=np.array(pose['bones'][name]).reshape(3,4);matrices.append(m)
 transforms=np.array(matrices)@inverse;points=[];faces=[]
 for p,w,j,triangles in parts:
  blend=np.sum(transforms[j]*w[:,:,None,None],axis=1);homogeneous=np.column_stack([p,np.ones(len(p))]);q=np.einsum('nij,nj->ni',blend,homogeneous)[:,:3];start=len(points);points.extend(Vector(row) for row in q);faces.extend(tuple(start+int(i) for i in row) for row in triangles)
 return points,faces
def interior(p,a,b,c):
 u=b-a;v=c-a;q=p-a;uu=u.dot(u);uv=u.dot(v);vv=v.dot(v);den=uu*vv-uv*uv
 if abs(den)<1e-14:return False
 beta=(vv*q.dot(u)-uv*q.dot(v))/den;gamma=(uu*q.dot(v)-uv*q.dot(u))/den
 return min(beta,gamma,1-beta-gamma)>.001
rows=[];failures=[]
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment');assets={key:load(art/path,prefix) for key,path,prefix in [('shirt','expansion/shirt.glb','Extra_'),('pants','runtime/part-pants.glb','Free_'),('spellbook','coverage/spellbook.glb','Extra_'),('lantern','coverage/lantern.glb','Extra_')]}
 for pose in json.loads((ROOT/'outputs/human-tailoring/prop-poses.json').read_text())['poses']:
  if pose['female']!=female:continue
  p,faces=posed(assets[pose['item']],pose);samples=list(p)
  for face in faces:
   a,b,c=[p[i] for i in face]
   samples.extend([(a+b+c)/3,(a+b)/2,(a+c)/2,(b+c)/2])
  worst=0.;contacts=0
  for garment in ['shirt','pants']:
   q,triangles=posed(assets[garment],pose);tree=BVHTree.FromPolygons(q,triangles,all_triangles=True)
   for point in samples:
    hit,normal,face,distance=tree.find_nearest(point)
    if hit is None or distance>.08 or not interior(hit,*[q[i] for i in triangles[face]]):continue
    signed=(point-hit).dot(normal)
    if signed<-.005:contacts+=1;worst=max(worst,-signed)
  row={k:v for k,v in pose.items() if k!='bones'};row.update(samples=len(samples),deep_contacts=contacts,max_penetration_m=worst,passed=contacts==0);rows.append(row)
  if not row['passed']:failures.append(row)
out=ROOT/'outputs/human-tailoring/prop-geometry.json';out.write_text(json.dumps({'samples':rows,'failures':failures,'scope':'Actual final Godot modifier poses; both bodies walking/running and horse riding at independent phases. Every rigid prop vertex, triangle centroid and edge midpoint tested against posed shirt/trousers. Closest triangle interiors only, ignoring open cuff boundaries; 5 mm tolerance. Hands intentionally grip objects. Finite surface samples, not universal collision proof.'},indent=2))
print('HELD ACCESSORY GEOMETRY:',len(rows),'poses,',len(failures),'failures; maximum penetration',max([r['max_penetration_m'] for r in rows]+[0.]))
if failures:raise RuntimeError(str(failures[:4]))
