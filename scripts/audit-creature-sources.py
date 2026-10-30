"""Read-only source queue for the complete preserved Animals/Monsters folders.

Outputs are local evidence, not a catalogue of implemented server body IDs.
The strict importer remains unchanged. Normal repair is an explicit diagnostic
copy: finite positions/UVs/bones/weights must still pass its existing checks.
"""
import collections
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import zipfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('creature_import',ROOT/'scripts/import-third-dawn.py')
td=importlib.util.module_from_spec(spec);spec.loader.exec_module(td)
ARCHIVE_HASH='d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e'


def repair_invalid_normals(raw):
    patched=bytearray(raw);invalid=[];normal_offset=None
    for tag,payload,_ in td.chunks(raw):
        if tag!=0xca5e0802:continue
        td.require(normal_offset is None and len(payload)%12==0,'Single bounded normal buffer required')
        td.require(raw.count(payload)==1,'Ambiguous normal payload')
        normal_offset=raw.index(payload)
        for index,normal in enumerate(struct.iter_unpack('<3f',payload)):
            if not all(math.isfinite(x) for x in normal):
                invalid.append(index);struct.pack_into('<3f',patched,normal_offset+index*12,0.,0.,1.)
    td.require(invalid,'No invalid normal vectors to repair')
    model=td.parse(bytes(patched));before=copy.deepcopy(model)
    sums={i:[0.,0.,0.] for i in invalid};score=0.
    dropped=[i for i,p in enumerate(model['polygons']) if len(set(p[:3]))<3]
    for pi,polygon in enumerate(model['polygons']):
        if pi in dropped:continue
        a,b,c=[model['points'][i] for i in polygon[:3]]
        u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
        cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
        for index in polygon[3:6]:
            if index in sums:sums[index]=[x+y for x,y in zip(sums[index],cross)]
            else:score+=sum(x*y for x,y in zip(model['normals'][index],cross))
    td.require(abs(score)>1e-12,'Cannot establish winding from finite source normals')
    unused=[]
    referenced={index for pi,polygon in enumerate(model['polygons']) if pi not in dropped for index in polygon[3:6]}
    for index,value in sums.items():
        length=math.sqrt(sum(x*x for x in value))
        if index not in referenced:
            unused.append(index);value=[0.,0.,1.]
        else:
            td.require(length>1e-12,'Referenced invalid normal has no usable incident surface')
            value=[x/length*(1 if score>0 else -1) for x in value]
        struct.pack_into('<3f',patched,normal_offset+index*12,*value)
    repaired=td.parse(bytes(patched))
    for key in before:
        if key!='normals':td.require(before[key]==repaired[key],'Normal repair altered '+key)
    repaired['polygons']=[p for i,p in enumerate(repaired['polygons']) if i not in dropped]
    repaired['texture_polygons']=[p for i,p in enumerate(repaired['texture_polygons']) if i not in dropped]
    return repaired,{'normal_indices':invalid,'unused_indices_after_pruning':unused,'dropped_repeated_vertex_faces':dropped,'count':len(invalid),'method':'Drop only faces with repeated vertex indices (zero area under every pose). Incident-face normals retain source winding. Unreferenced invalid normals get finite placeholders; not used by exported triangles. Positions, UV coordinates, bones, weights and all other parsed fields unchanged','patched_sha256':hashlib.sha256(patched).hexdigest()}


def main():
    archive=ROOT/'work/third-dawn/uotdb.zip'
    with archive.open('rb') as f:td.require(hashlib.file_digest(f,'sha256').hexdigest()==ARCHIVE_HASH,'Unpinned archive')
    rows=[]
    with zipfile.ZipFile(archive) as z:
        names={name.lower():name for name in z.namelist()}
        for lower,name in sorted(names.items()):
            if not lower.endswith('_lod2.grn') or not any('/models/'+folder+'/' in lower for folder in ['animals','monsters']):continue
            stem=Path(lower).name.removesuffix('_lod2.grn');family=stem.split('_')[0]
            raw=z.read(name);row={'member':name,'stem':stem,'family':family,'sha256':hashlib.sha256(raw).hexdigest(),'status':'source only'}
            try:
                try:model=td.parse(raw)
                except ValueError as error:
                    row['strict_error']=str(error)
                    model,repair=repair_invalid_normals(raw);row['diagnostic_normal_repair']=repair
                row.update(vertices=len(model['points']),triangles=len(model['polygons']),bones=len(model['bones']),textures=[])
                for reference in model['textures']:
                    matching=[n for n in names if n.rsplit('/',1)[-1]==reference.lower()]
                    row['textures'].append({'reference':reference,'members':[names[n] for n in matching]})
                row['missing_textures']=[entry['reference'] for entry in row['textures'] if not entry['members']]
                row['candidate_clips']=[names[n] for n in names if n.startswith(lower.rsplit('/',1)[0]+'/'+family+'_') and n.endswith('.grn') and '_lod' not in n]
                if family=='ostards':row['review_status']='local upgraded comparison available; rider/live pending'
                elif family=='equines':row['review_status']='accepted modern horse replacement retained; historical aliases separately deferred'
                else:row['review_status']='not modernised'
            except (ValueError,IndexError,KeyError,struct.error) as error:row['blocker']=str(error)
            rows.append(row)
    families=collections.Counter(row['family'] for row in rows)
    report={'archive_sha256':ARCHIVE_HASH,'scope':'Preserved archive mesh candidates, not all UO server creature identities or completed replacement coverage. Candidate clip names are not deformation evidence. No game binaries executed.','models':rows,'families':dict(families)}
    output=ROOT/'outputs/creature-sources';output.mkdir(parents=True,exist_ok=True)
    (output/'inventory.json').write_text(json.dumps(report,indent=2))
    print('CREATURE SOURCE QUEUE:',len(rows),'meshes /',len(families),'source families;',sum('blocker' in r for r in rows),'unparsed;',sum(bool(r.get('missing_textures')) for r in rows),'with missing textures')
    for row in rows:
        if row['family']=='kirin':print('KIRIN:',json.dumps(row))


if __name__=='__main__':main()
