"""Bounded, explicitly authored repairs to indexed non-finite source normals."""
import hashlib
import math
import struct

def repair(raw,reader,expected_sha256,indices):
    reader.require(hashlib.sha256(raw).hexdigest()==expected_sha256,'Normal repair source hash mismatch')
    entries=list(reader.chunks(raw))
    points=[p for tag,p,_ in entries if tag==0xca5e0801]
    normals=[p for tag,p,_ in entries if tag==0xca5e0802]
    reader.require(len(points)==len(normals)==1,'Normal repair requires exactly one source mesh')
    payload=normals[0]
    reader.require(raw.count(payload)==1 and len(payload)%12==0 and len(points[0])%12==0,'Ambiguous or malformed normal/point buffer')
    vertices=list(struct.iter_unpack('<3f',points[0]));vectors=list(struct.iter_unpack('<3f',payload))
    reader.require(all(math.isfinite(v) for p in vertices for v in p),'Normal repair cannot change non-finite positions')
    bad=[i for i,n in enumerate(vectors) if not all(math.isfinite(v) for v in n)]
    reader.require(bad==list(indices),'Indexed non-finite normals differ from repair contract')
    faces=[face for tag,p,_ in entries if tag==0xca5e0901 for face in struct.iter_unpack('<6I',p)]
    reader.require(all(max(f[:3])<len(vertices) and max(f[3:])<len(vectors) for f in faces),'Normal repair triangle indices invalid')
    patched=bytearray(raw);offset=raw.index(payload);allowed=set();records=[]
    for index in bad:
        total=[0.,0.,0.];area=0.;positive=negative=0;incident=[]
        for face_index,face in enumerate(faces):
            if index not in face[3:]:continue
            a,b,c=[vertices[v] for v in face[:3]];u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
            normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            area+=math.sqrt(sum(x*x for x in normal));total=[total[i]+normal[i] for i in range(3)];incident.append(face_index)
            for other in face[3:]:
                if other in bad:continue
                dot=sum(normal[i]*vectors[other][i] for i in range(3));positive+=dot>0.;negative+=dot<0.
        length=math.sqrt(sum(x*x for x in total))
        reader.require(area>0. and length/area>.6 and positive>negative,'Normal neighbourhood is degenerate, ambiguous or oppositely wound')
        replacement=[x/length for x in total];struct.pack_into('<3f',patched,offset+index*12,*replacement)
        allowed.update(range(offset+index*12,offset+(index+1)*12))
        records.append(dict(normal_index=index,replacement=replacement,incident_triangles=incident,coherence=length/area))
    reader.require(len(raw)==len(patched) and all(a==b or i in allowed for i,(a,b) in enumerate(zip(raw,patched))),'Normal repair changed non-normal bytes')
    return bytes(patched),dict(source_sha256=expected_sha256,repaired_sha256=hashlib.sha256(patched).hexdigest(),
        replacements=records,permitted_bytes=len(allowed),method='Authored area-weighted normals from coherent incident source faces; not recovered original normals. Every other source byte is unchanged.')
