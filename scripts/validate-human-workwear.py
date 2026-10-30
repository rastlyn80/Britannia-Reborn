"""Export and actual-pose validation of matched source clothing topology.

Reconciles every exported vertex and weight with the exact source record, then
measures bounded offsets in final engine poses. Triangle orientation at folded
hems is diagnostic; visible occlusion is tested separately on the GPU. This does
not assert global cloth collision freedom. Generated art stays ignored.
"""
import json, hashlib, importlib.util, math
from pathlib import Path
import numpy as np
import bpy
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('g',ROOT/'scripts/validate-free-human.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
pins=json.loads((ROOT/'scripts/human-workwear-inputs.json').read_text())
for file,digest in pins['files'].items():assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==digest,file
posefile=ROOT/'outputs/human-workwear/poses.json';poses=json.loads(posefile.read_text())['poses'] if posefile.exists() else []
exports=[];rows=[];failures=[]
for female in [False,True]:
 art=ROOT/('Viewer/local-art/free-equipment-female' if female else 'Viewer/local-art/free-equipment')
 provenance=json.loads((art/'coverage/provenance.json').read_text());base,br=g.read(art/'equipment-base.glb');bs=base['skins'][0];expected={base['nodes'][i]['name']:matrix for i,matrix in zip(bs['joints'],g.values(base,br,bs['inverseBindMatrices']))}
 for key in ['body_sash']:
  for armoured in [False,True]:
   name=key+('_armour' if armoured else '');path=art/'coverage'/(name+'.glb');d,raw=g.read(path);skin=d['skins'][0];names=[d['nodes'][i]['name'] for i in skin['joints']];inverse=np.array(g.values(d,raw,skin['inverseBindMatrices'])).reshape(-1,4,4).transpose(0,2,1)
   assert set(names)==set(expected) and len(names)==61
   for n,m in zip(names,inverse):assert np.max(np.abs(m-np.array(expected[n]).reshape(4,4).T))<1e-5
   assert hashlib.sha256(path.read_bytes()).hexdigest()==provenance['parts'][name]['sha256']
   meta=json.loads((ROOT/'work/human-workwear'/(('female-' if female else 'male-')+name+'-topology.json')).read_text());convert=lambda p:np.array(p)[:,[0,2,1]]*np.array([1,1,-1])*meta['export_scale'];p=convert(meta['positions']);q=convert(meta['source_positions']);weights=np.zeros((len(p),len(names)))
   for i,w in enumerate(meta['weights']):
    for n,value in w.items():weights[i,names.index(n)]=value
   assert np.all(np.isfinite(p)) and np.max(np.abs(weights.sum(1)-1))<2e-5
   # Reconcile the exported skin vertices/weights with the construction record.
   exported=[]
   for mesh in d['meshes']:
    for primitive in mesh['primitives']:
     attrs=primitive['attributes'];pos=g.values(d,raw,attrs['POSITION']);ws=g.values(d,raw,attrs['WEIGHTS_0']);js=g.values(d,raw,attrs['JOINTS_0'])
     assert d['materials'][primitive['material']]['alphaMode']=='MASK'
     assert all(math.isfinite(v) for row in pos for v in row)
     for co,w,j in zip(pos,ws,js):
      full=np.zeros(len(names))
      for index,value in zip(j,w):full[index]+=value
      exported.append((np.array(co),full))
   lookup={}
   for i,co in enumerate(p):lookup.setdefault(tuple(np.round(co,5)),[]).append(i)
   for co,w in exported:
    candidates=lookup.get(tuple(np.round(co,5)),[])
    if not candidates:candidates=np.where(np.max(np.abs(p-co),axis=1)<2e-6)[0]
    assert any(np.max(np.abs(weights[i]-w))<2e-5 for i in candidates),('Export changed matched weights',name,co,[(int(i),float(np.max(np.abs(weights[i]-w)))) for i in candidates],float(np.min(np.linalg.norm(p-co,axis=1))))
   exports.append({'female':female,'asset':name,'sha256':provenance['parts'][name]['sha256'],'vertices':len(exported),'joints':len(names),'alpha_mode':'MASK'})
   faces=np.array(meta['faces'],int);mi=np.array(meta['material_indices']);uv=np.array(meta['uvs']);visible=np.zeros(len(faces),bool)
   for material_index,component in enumerate(['front','back']+(['lap'] if key!='body_sash' else [])):
    image=bpy.data.images.load(str(ROOT/'work/human-workwear'/((('female-' if female else 'male-')+key+'-'+component+'.png'))),check_existing=False);width,height=image.size;pixels=np.empty(len(image.pixels),np.float32);image.pixels.foreach_get(pixels);alpha=pixels.reshape(height,width,4)[:,:,3];sample=uv[faces].mean(1);ix=np.clip((sample[:,0]*width).astype(int),0,width-1);iy=np.clip((sample[:,1]*height).astype(int),0,height-1);visible|=(mi==material_index)&(alpha[iy,ix]>.5);bpy.data.images.remove(image)

   # Same authored outline as the exported binary mask, evaluated independently
   # at each triangle centroid. UV stencil and separation are distinct checks.

   for pose in poses:
    if pose['female']!=female or pose['plate']!=armoured or pose['item']!=key:continue
    matrices=[]
    for n in names:
     m=np.eye(4);m[:3,:]=np.array(pose['bones'][n]).reshape(3,4);matrices.append(m)
    transforms=np.array(matrices)@inverse;blend=np.einsum('vb,bjk->vjk',weights,transforms)
    deform=lambda a:np.einsum('vij,vj->vi',blend,np.column_stack([a,np.ones(len(a))]))[:,:3]
    a=deform(p)[faces];b=deform(q)[faces];normal=np.cross(b[:,1]-b[:,0],b[:,2]-b[:,0]);length=np.linalg.norm(normal,axis=1);valid=(length>1e-9)&visible;normal[valid]/=length[valid,None]
    distance=np.einsum('ij,ij->i',(a-b).mean(1),normal)
    # Alpha-hidden support triangles do not represent visible cloth.
    bad=(distance<-.005)&valid;maximum=float(np.max(np.linalg.norm((a-b).mean(1),axis=1)));row={k:v for k,v in pose.items() if k!='bones'};row.update(triangles=int(valid.sum()),opposite_orientation_triangles=int(bad.sum()),minimum_separation_m=float(distance[valid].min()),maximum_offset_m=maximum);rows.append(row)
    if maximum>.031:failures.append(row)
out=ROOT/'outputs/human-workwear/asset-validation.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps({'exports':exports,'poses':rows,'failures':failures,'scope':'Exact input/output hashes, 61 unchanged inverse binds, alpha MASK materials, exported original source weights, bounded matched-vertex offsets in final engine modifier poses (31 mm limit). Signed triangle orientation is diagnostic because original folded hems can invert their local face normal; GPU outer-face retention is a separate acceptance gate. Other garment combinations still require visual review.'},indent=2))
print('WORKWEAR VALIDATION',len(exports),'exports,',len(rows),'actual poses,',sum(r['triangles'] for r in rows),'triangles,',len(failures),'failures')
if failures:raise RuntimeError(str(failures[:4]))
