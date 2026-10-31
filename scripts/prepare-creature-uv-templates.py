"""Technical UV guides for absent source maps, not painted replacement art.

Run with a Python installation providing Pillow. All generated guides and
proprietary-derived anatomy metadata remain under ignored local-art/creatures.
"""
import argparse,collections,hashlib,importlib.util,json,zipfile
from pathlib import Path
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('creature_preparer',ROOT/'scripts/prepare-creatures.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kinds',nargs='+',default=['centaurs_centaur','fey_race_pixie','succubi_succubus'])
    args=parser.parse_args();archive=ROOT/'work/third-dawn/uotdb.zip'
    with archive.open('rb') as stream:assert hashlib.file_digest(stream,'sha256').hexdigest()==p.helper.audit.ARCHIVE_HASH
    with zipfile.ZipFile(archive) as z:
        names={name.lower():name for name in z.namelist()}
        for kind in args.kinds:
            member=next(name for name in names if name.endswith('/'+kind+'_lod2.grn'))
            raw=z.read(names[member])
            body=p.td.parse(raw,scene_root_names=True,skip_unskinned_helpers=kind=='centaurs_centaur')
            uv=body['uv_sets'][-1]
            assert all(-.2<=v[0]<=1.2 and -.2<=v[1]<=1.2 for v in uv),'Non-atlas UVs need a separately authored unwrap'
            image=Image.new('RGB',(1024,1024),'#4b4e50');draw=ImageDraw.Draw(image);labels=collections.defaultdict(list)
            zlow=min(v[2] for v in body['points']);height=max(v[2] for v in body['points'])-zlow
            for face,indices in zip(body['polygons'],body['texture_polygons']):
                scores=collections.defaultdict(float)
                for vertex in face[:3]:
                    for tie,weight in body['weights'][vertex]:scores[body['bones'][body['ties'][tie]]['name']]+=weight
                dominant=max(scores,key=scores.get)
                zmid=sum(body['points'][v][2] for v in face[:3])/3.
                colour='#b89a7a'
                if kind=='centaurs_centaur':
                    human=any(part in dominant for part in ['ponytail','neck1','neck2','neck3','head','right_thumb'])
                    colour='#bd9b78' if human else '#785038'
                    if dominant.startswith('bip01 tail'):colour='#3d2e25'
                    if 'foot' in dominant or 'toe' in dominant:colour='#413a32'
                elif kind=='fey_race_pixie':
                    colour='#497c45'
                    if any(word in dominant for word in ['head','neck','hand','finger']):colour='#cfaf8f'
                    if 'wing' in dominant:colour='#9caebf'
                    if 'tail' in dominant:colour='#5b4130'
                else:
                    colour='#572e3e'
                    if 'head' in dominant or 'neck' in dominant:colour='#aaa1a3'
                    if any(word in dominant for word in ['hand','finger','foot','toe']):colour='#4d4147'
                    if 'box' in dominant:colour='#735463'
                coordinates=[(uv[i][0]*1024,uv[i][1]*1024) for i in indices]
                for dx in [-1024,0,1024]:
                    for dy in [-1024,0,1024]:
                        shifted=[(x+dx,y+dy) for x,y in coordinates]
                        draw.polygon(shifted,fill=colour,outline='#d4d4cc')
                labels[dominant].append([sum(uv[i][axis] for i in indices)/3. for axis in range(2)])
            output=p.OUTPUT/(kind+'-uv-template.png');image.save(output)
            output.with_suffix('.json').write_text(json.dumps({'kind':kind,'member':names[member],
                'source_sha256':hashlib.sha256(raw).hexdigest(),'guide_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
                'bone_uv_centres':dict(labels),'scope':'Technical source UV guide; original texture absent. Colours identify approximate anatomy only; not a recovered map or redistribution grant.'},indent=2))
            print('TECHNICAL UV GUIDE:',output)

if __name__=='__main__':main()
