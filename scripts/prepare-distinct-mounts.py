"""Private original ki-rin and llama imports with explicit source repairs.

Missing source maps are replaced by separately authored, saved UV atlases.
No game binary is run; no model data is committed.
"""
import copy
import argparse
import hashlib
import importlib.util
import json
import struct
from pathlib import Path
import zipfile
ROOT=Path(__file__).resolve().parents[1]
def module(name,file):
    s=importlib.util.spec_from_file_location(name,ROOT/'scripts'/file);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
audit=module('mount_audit','audit-creature-sources.py');td=audit.td
smooth=module('mount_smooth','third-dawn-subdivide.py')
def match_animation(animation,body):
    """Map spelling aliases, then omit only subtrees with no retained bones."""
    result=copy.deepcopy(animation);normal=lambda name:name.replace('_','')
    by_normal={normal(b['name']):b['name'] for b in body['bones']}
    td.require(len(by_normal)==len(body['bones']),'Ambiguous body spelling aliases')
    for b in result['bones']:b['name']=by_normal.get(normal(b['name']),b['name'])
    for t in result['tracks']:t['name']=by_normal.get(normal(t['name']),t['name'])
    keep={i for i,b in enumerate(result['bones']) if b['name'] in by_normal.values()}
    td.require(len(keep)==len({result['bones'][i]['name'] for i in keep}),'Ambiguous source spelling aliases')
    for i in keep:td.require(result['bones'][i]['parent'] in keep,'Cannot omit an intermediary above a retained bone')
    indices={old:new for new,old in enumerate(sorted(keep))}
    omitted=[b['name'] for i,b in enumerate(result['bones']) if i not in keep]
    result['bones']=[dict(b,parent=indices[b['parent']]) for i,b in enumerate(result['bones']) if i in keep]
    result['tracks']=[t for t in result['tracks'] if t['name'] in by_normal.values()]
    return result,omitted
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--templates-only',action='store_true');args=parser.parse_args()
    output=ROOT/'Viewer/local-art/mounts';output.mkdir(exist_ok=True)
    archive=ROOT/'work/third-dawn/uotdb.zip'
    with archive.open('rb') as f:td.require(hashlib.file_digest(f,'sha256').hexdigest()==audit.ARCHIVE_HASH,'Unexpected archive')
    with zipfile.ZipFile(archive) as z:
        names={n.lower():n for n in z.namelist()}
        for kind,stem,height in [('kirin','monsters/kirin',2.15),('llama','animals/llamas_llama',1.95),('llama_ethereal','animals/llamas_llama_ethereal',1.95)]:
            records=[]
            def read(suffix):
                use_stem='animals/llamas_llama' if kind=='llama_ethereal' and suffix!='lod2' else stem
                path=names['uotdb/uotd/models/'+use_stem+'_'+suffix+'.grn'];raw=z.read(path)
                records.append({'member':path,'sha256':hashlib.sha256(raw).hexdigest()});return raw
            raw=read('lod2');body,repair=audit.repair_invalid_normals(raw) if kind=='kirin' else (td.parse(raw),None)
            if args.templates_only:
                if kind=='llama_ethereal':continue
                polygons=[]
                for pi,polygon in enumerate(body['polygons']):
                    weights={}
                    for vertex in polygon[:3]:
                        for tie,weight in body['weights'][vertex]:
                            name=body['bones'][body['ties'][tie]]['name'];weights[name]=weights.get(name,0.)+weight
                    dominant=max(weights,key=weights.get)
                    colour='#a99060' if kind=='kirin' else '#c8bc9a'
                    if 'head' in dominant or 'neck' in dominant:colour='#bda573' if kind=='kirin' else '#c5b58f'
                    if 'tail' in dominant or 'ponytail' in dominant:colour='#785445' if kind=='kirin' else '#9b8868'
                    points=' '.join('%.2f,%.2f'%(body['uv_sets'][-1][i][0]*1024,body['uv_sets'][-1][i][1]*1024) for i in body['texture_polygons'][pi])
                    polygons.append('<polygon points="'+points+'" fill="'+colour+'" stroke="#544b37" stroke-width="1"/>')
                (output/(kind+'-uv-template.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><rect width="1024" height="1024" fill="#9e8d68"/>'+''.join(polygons)+'</svg>')
                continue
            clips={};omitted={}
            for label,suffix in [('Idle','idle'),('Walk','walk'),('Run','run'),('Attack','attack1'),('Hit','gethit'),('Death','die1'),('Fidget','fidget')]:
                clips[label],omitted[label]=match_animation(td.parse(read(suffix),animations_only=True),body)
            source_height=max(p[2] for p in body['points'])-min(p[2] for p in body['points']);scale=height/source_height
            strengths=[]
            for point,pairs in zip(body['points'],body['weights']):
                names_at_point=[body['bones'][body['ties'][tie]]['name'] for tie,w in pairs if w>.2]
                strengths.append(0. if any(any(part in name for part in [' foot',' hand','toe','finger']) for name in names_at_point) else .55 if any('head' in name for name in names_at_point) else 1.)
            refined,refinement=smooth.refine(body,levels=2,maximum=min(.05,.05/scale),strengths=strengths,weight_smoothing=.18)
            atlas=output/(('llama' if kind=='llama_ethereal' else kind)+'-albedo-v1.png');td.require(atlas.exists(),'Generate the saved UV atlas first')
            pixels=atlas.read_bytes();td.require(pixels[:8]==b'\x89PNG\r\n\x1a\n' and len(pixels)>=24,'Expected a PNG replacement atlas')
            width,depth=struct.unpack_from('>II',pixels,16);td.require(width==depth and 512<=width<=4096,'Replacement atlas must be square, 512..4096 pixels')
            stats=td.export_gltf(refined,clips,pixels,output/(kind+'-modern.gltf'),height)
            report={'archive_sha256':audit.ARCHIVE_HASH,'inputs':records,'source_repair':repair,'animation_aliases':'Underscore spelling only; unique mapping required','omitted_unreferenced_subtrees':omitted,'refinement':refinement,'stats':stats,'atlas_sha256':hashlib.sha256(atlas.read_bytes()).hexdigest(),'prompt':atlas.with_suffix('.prompt.txt').read_text(),'atlas_method':'Built-in imagegen from technical UV template; original source texture absent. Not a recovered original map.','licence':'Local proprietary-derived experiment; no distribution grant','recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
            (output/(kind+'-provenance.json')).write_text(json.dumps(report,indent=2))
            print(kind,stats,flush=True)
if __name__=='__main__':main()
