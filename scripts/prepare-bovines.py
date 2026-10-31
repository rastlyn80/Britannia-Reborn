"""Private source-first bovine batch; no proprietary art is distributed.

Retains per-species native source clips, UVs and bounded four-influence skins.
Saved imagegen atlases are optional until the explicit modern-atlas pass.
"""
import argparse,hashlib,importlib.util,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/file)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
helper=module('bovine_helpers','prepare-distinct-mounts.py')
td=helper.td;smooth=helper.smooth
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--modern-atlases',action='store_true');args=parser.parse_args()
    output=ROOT/'Viewer/local-art/animals';output.mkdir(exist_ok=True)
    archive=ROOT/'work/third-dawn/uotdb.zip'
    with archive.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==helper.audit.ARCHIVE_HASH
    with zipfile.ZipFile(archive) as z:
        names={n.lower():n for n in z.namelist()}
        for species in ['cow','bull']:
            for coat in ['brown','spotted']:
                kind=f'bovine_{species}_{coat}';stem=f'bovines_{species}_{coat}';inputs=[]
                def read(name):
                    key=names[name.lower()];raw=z.read(key);inputs.append({'member':key,'sha256':hashlib.sha256(raw).hexdigest()});return raw
                body=td.parse(read(f'uotdb/uotd/models/animals/{stem}_lod2.grn'))
                clips={};omitted={}
                for label,suffix in [('Idle','idle'),('Walk','walk'),('Run','run'),('Attack','attack1'),('Hit','gethit'),('Death','die1'),('Eat','eat'),('Fidget','fidget')]:
                    animation_stem=f'bovines_{species}_brown'
                    if label=='Fidget' and species=='bull':animation_stem='bovines_cow_brown'
                    clip=td.parse(read(f'uotdb/uotd/models/animals/{animation_stem}_{suffix}.grn'),animations_only=True)
                    clips[label],omitted[label]=helper.match_animation(clip,body)
                texture=next(n for n in names if n.endswith('/'+body['textures'][0].lower()))
                original=td.png_from_tga(read(texture));(output/(kind+'-original-albedo.png')).write_bytes(original)
                height=1.48 if species=='cow' else 1.62
                scale=height/(max(p[2] for p in body['points'])-min(p[2] for p in body['points']))
                strengths=[]
                for pairs in body['weights']:
                    labels=[body['bones'][body['ties'][tie]]['name'] for tie,w in pairs if w>.2]
                    strengths.append(.05 if any(' foot' in n or ' hand' in n for n in labels) else .25 if any('head' in n or 'ponytail' in n for n in labels) else .8)
                refined,refinement=smooth.refine(body,levels=2,maximum=min(.05,.04/scale),strengths=strengths,weight_smoothing=.14)
                # Native cows are black/white and brown/white. The cow cages
                # share identical UVs; use the spotted atlas for both modern cows.
                atlas_coat='spotted' if species=='cow' else coat
                atlas=output/f'bovine-{atlas_coat}-albedo-v1.png'
                modern=atlas.read_bytes() if args.modern_atlases else original
                if args.modern_atlases:assert modern[:8]==b'\x89PNG\r\n\x1a\n'
                stats={}
                for treatment,mesh,png in [('original',body,original),('rounded',refined,original),('modern',refined,modern)]:
                    stats[treatment]=td.export_gltf(mesh,clips,png,output/(kind+'-'+treatment+'.gltf'),height)
                report={'archive_sha256':helper.audit.ARCHIVE_HASH,'inputs':inputs,'stats':stats,'refinement':refinement,'omitted_unreferenced_animation_bones':omitted,
                        'modern_atlas':str(atlas.relative_to(ROOT)) if args.modern_atlases else 'source texture; pending authored atlas',
                        'modern_atlas_sha256':hashlib.sha256(modern).hexdigest(),'source_clips':list(clips),'fidget_note':'Bull shares compatible cow fidget; per-species other clips',
                        'licence':'Proprietary-derived local experiment; no redistribution grant','recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
                (output/(kind+'-provenance.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
                print(kind,stats['modern'],flush=True)
if __name__=='__main__':main()
