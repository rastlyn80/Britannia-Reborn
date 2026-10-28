"""Read static MakeHuman clothes/OBJ data; does not execute source directives."""
import math
from pathlib import Path

def parse_obj(path):
 points=[];uv=[];faces=[];face_uv=[];body_ids=set();group=''
 for raw in Path(path).read_text(encoding='utf-8',errors='replace').splitlines():
  s=raw.split()
  if not s or s[0].startswith('#'):continue
  if s[0]=='v':points.append(tuple(map(float,s[1:4])))
  elif s[0]=='vt':uv.append(tuple(map(float,s[1:3])))
  elif s[0]=='g':group=s[1]
  elif s[0]=='f':
   corners=[x.split('/') for x in s[1:]];face=tuple(int(v[0])-1 for v in corners)
   faces.append(face);face_uv.append(tuple(int(v[1])-1 for v in corners))
   if group=='body':body_ids.update(face)
 if not points or not faces or any(i<0 or i>=len(points) for f in faces for i in f):raise ValueError('Invalid OBJ topology')
 return dict(points=points,uv=uv,faces=faces,face_uv=face_uv,body_ids=body_ids)

def parse_proxy(path):
 fields={};rows=[];deleted=set();mode='header'
 for raw in Path(path).read_text(encoding='utf-8',errors='replace').splitlines():
  s=raw.split()
  if not s or s[0].startswith(('#','//')):continue
  if s[0]=='verts':mode='verts';continue
  if s[0]=='delete_verts':mode='delete';continue
  # Some official system hair places its material after the verts declaration.
  if s[0]=='material':fields['material']=' '.join(s[1:]);continue
  if mode=='verts':
   if len(s)==1:
    i=int(s[0]);row=((i,i,i),(1.,0.,0.),(0.,0.,0.))
   elif len(s)==9:row=(tuple(map(int,s[:3])),tuple(map(float,s[3:6])),tuple(map(float,s[6:9])))
   else:raise ValueError('Invalid proxy vertex row')
   if min(row[0])<0 or not all(math.isfinite(v) for v in row[1]+row[2]) or abs(sum(row[1])-1)>.002:raise ValueError('Invalid barycentric data')
   rows.append(row)
  elif mode=='delete':
   i=0
   while i<len(s):
    first=int(s[i]);i+=1;last=first
    if i<len(s) and s[i]=='-':last=int(s[i+1]);i+=2
    if first<0 or last<first:raise ValueError('Invalid delete range')
    deleted.update(range(first,last+1))
  else:fields[s[0]]=' '.join(s[1:])
 if fields.get('basemesh')!='hm08' or not rows:raise ValueError('Expected hm08 clothing data')
 mode=next((mode for mode in ['scale','shear','l_shear','r_shear'] if all((axis+'_scale' if mode=='scale' else mode+'_'+axis) in fields for axis in ['x','y','z'])),None)
 if mode is None:raise ValueError('Missing complete proxy offset transform')
 fields['offset_mode']=mode
 for axis in ['x','y','z']:
  key=axis+'_scale' if mode=='scale' else mode+'_'+axis
  values=fields[key].split();expected=3 if mode=='scale' else 4
  if len(values)!=expected:raise ValueError('Malformed offset transform')
  a,b=map(int,values[:2]);numbers=tuple(map(float,values[2:]))
  if min(a,b)<0 or not all(math.isfinite(v) for v in numbers):raise ValueError('Invalid offset transform')
  if (mode=='scale' and numbers[0]<=0) or (mode!='scale' and abs(numbers[0]-numbers[1])<1e-8):raise ValueError('Degenerate offset transform')
  fields[key]=(a,b,*numbers)
 return dict(fields=fields,rows=rows,deleted=deleted)

def offset_scales(fields,coordinates):
 """Axis-aligned reference-box offsets, converted to our metre/Z-up space.

 Scale headers give a distance; shear headers give signed source box limits.
 Only the offset is transformed: barycentric surface placement is separate.
 """
 mode=fields['offset_mode'];result={}
 for axis,component,sign in [('x',0,1),('y',2,1),('z',1,-1)]:
  key=axis+'_scale' if mode=='scale' else mode+'_'+axis
  a,b,*values=fields[key]
  if max(a,b)>=len(coordinates):raise ValueError('Reference box outside base mesh')
  distance=coordinates[a][component]-coordinates[b][component]
  result[axis]=abs(distance)/values[0] if mode=='scale' else sign*distance/(values[0]-values[1])
 return result
