"""Private desert-ostard A/B/C import; original game inputs stay untouched.

Uses the existing bounded Granny reader and UV/skin-preserving refinement.
Generated albedo is supplied separately; no game executable or DLL is run.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import zipfile

ROOT=Path(__file__).resolve().parents[1]
ARCHIVE_SHA256='d872d59a4d3f92c82672bbadb98ae44772e42b44dacb4a28a1fdf39cf121dc0e'

def module(name,file):
    spec=importlib.util.spec_from_file_location(name,Path(__file__).with_name(file))
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

granny=module('ostard_granny','import-third-dawn.py')
smooth=module('ostard_refinement','third-dawn-subdivide.py')

def region_strengths(model):
    result=[]
    for point,pairs in zip(model['points'],model['weights']):
        amount=0.
        for tie,weight in pairs:
            name=model['bones'][model['ties'][tie]]['name']
            strength=1.
            if 'toe' in name or (' foot' in name and point[2]<.08):strength=0.
            elif ' foot' in name:strength=.45
            elif 'horselink' in name:strength=.6
            elif 'calf' in name:strength=.85
            elif 'head' in name:strength=.35 if point[1]<-.57 else 1.
            elif 'ponytail' in name:strength=.22  # keratin mouth/wattle corners
            elif 'tail' in name:strength=.45
            amount+=strength*weight
        # Keep the distinctive crest and toe tips while rounding its broad cage.
        if point[2]>1.90:amount=min(amount,.7)
        result.append(min(1.,max(0.,amount)))
    return result

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive',type=Path,default=ROOT/'work/third-dawn/uotdb.zip')
    parser.add_argument('--modern-albedo',type=Path,default=ROOT/'Viewer/local-art/ostards/desert-modern-albedo-v1.png')
    args=parser.parse_args()
    with args.archive.open('rb') as source:archive_hash=hashlib.file_digest(source,'sha256').hexdigest()
    granny.require(archive_hash==ARCHIVE_SHA256,'Unexpected source archive; inspect and pin it before importing')
    output=ROOT/'Viewer/local-art/ostards';output.mkdir(parents=True,exist_ok=True)
    report={'archive_sha256':archive_hash,'source':'Preserved Third Dawn 2.0.4 Alpha Build 35; see THIRD_DAWN_IMPORT.md',
            'licence':'Proprietary-derived local experiment; no redistribution grant','inputs':[],
            'recipes':{name:digest(Path(__file__).with_name(name)) for name in ['prepare-third-dawn-ostard.py','import-third-dawn.py','third-dawn-subdivide.py']},
            'source_height_display_m':2.2,'variants':{}}
    with zipfile.ZipFile(args.archive) as archive:
        names={name.lower():name for name in archive.namelist()}
        def read(path,parse=True):
            name=names[path.lower()];raw=archive.read(name)
            report['inputs'].append({'path':name,'sha256':hashlib.sha256(raw).hexdigest()})
            return granny.parse(raw) if parse else raw
        stem='uotdb/uotd/models/animals/ostards_ostard_desert'
        body=read(stem+'_lod2.grn')
        clips={label:read(stem+'_'+suffix+'.grn') for label,suffix in [
            ('Idle','idle'),('Walk','walk'),('Run','run'),('Attack','attack1'),('Hit','gethit'),('Death','die1'),('Fidget','fidget')]}
        texture=next(name for name in names if name.rsplit('/',1)[-1]==body['textures'][0].lower())
        original_png=granny.png_from_tga(read(texture,False))
    (output/'desert-original-albedo.png').write_bytes(original_png)
    granny.require(args.modern_albedo.exists(),'Supply the separately generated UV-preserving modern albedo first')
    modern_png=args.modern_albedo.read_bytes()
    granny.require(modern_png[:8]==b'\x89PNG\r\n\x1a\n','Modern albedo must be PNG')
    width,height=struct.unpack_from('>II',modern_png,16)
    granny.require(width==height and 512<=width<=4096,'Modern albedo must be a square 512..4096 atlas')
    report['modern_albedo']={'path':args.modern_albedo.name,'sha256':digest(args.modern_albedo),'size':[width,height],
                            'method':'Built-in imagegen edit of the source UV atlas; registration is a generation constraint and requires on-mesh visual review',
                            'generation':'exec-40457264-1095-4c2d-b5e8-0c91dfbaa86a.png'}
    prompt=args.modern_albedo.with_suffix('.prompt.txt')
    if prompt.exists():report['modern_albedo']['prompt']=prompt.read_text();report['modern_albedo']['prompt_sha256']=digest(prompt)
    source_span=max(p[2] for p in body['points'])-min(p[2] for p in body['points'])
    scale=2.2/source_span
    mask=region_strengths(body)
    refined,refinement=smooth.refine(body,levels=2,maximum=.055/scale,strengths=mask,weight_smoothing=.22)
    assert refined['bones']==body['bones']
    assert all(math.dist(point,refined['points'][i])<1e-12 for i,point in enumerate(body['points']) if mask[i]==0.)
    report['refinement']=dict(refinement,world_movement_cap_m=.055,weight_smoothing=.22,
                              protected_source_vertices=sum(w==0. for w in mask))
    for label,model,albedo in [('original',body,original_png),('rounded',refined,original_png),('modern',refined,modern_png)]:
        path=output/('desert-'+label+'.gltf')
        stats=granny.export_gltf(model,clips,albedo,path,2.2)
        data=json.loads(path.read_text())
        # All variants retain one common rig calibration, independent of any
        # small change to the refined silhouette's extrema.
        data['nodes'][0]['scale']=[scale]*3
        path.write_text(json.dumps(data,separators=(',',':')))
        report['variants'][label]=dict(stats,scale=scale,sha256=digest(path))
        print('OSTARD',label,stats['source_points'],'vertices /',stats['triangles'],'triangles /',stats['bones'],'bones /',len(stats['clips']),'clips',flush=True)
    (output/'provenance.json').write_text(json.dumps(report,indent=2))

if __name__=='__main__':main()
