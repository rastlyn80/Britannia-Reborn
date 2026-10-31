"""Pinned CC0 bird inputs and receipt-gated installation; never runs source scripts."""
import argparse, hashlib, json, shutil, urllib.request, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PINS=ROOT/'scripts/bird-inputs.json'
WORK=ROOT/'work/birds'
LOCAL=ROOT/'Viewer/local-art/birds'
PUBLIC=ROOT/'Viewer/Art/Creatures/Birds'

def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def resource(path):
    assert path.startswith('res://')
    result=(ROOT/'Viewer'/path[6:]).resolve()
    assert result.is_relative_to(ROOT)
    return result

def inputs(verify_only=False):
    pins=read(PINS);WORK.mkdir(parents=True,exist_ok=True)
    archive=WORK/'bird_yellow_billed_shrike.zip'
    if not archive.exists():
        assert not verify_only,'Pinned CC0 archive missing; run preparation without -VerifyOnly'
        with urllib.request.urlopen(pins['download_url'],timeout=60) as response:
            archive.write_bytes(response.read())
    assert sha(archive)==pins['archive_sha256'],'Bird archive hash mismatch'
    expected={entry['member']:entry for entry in pins['files']}
    with zipfile.ZipFile(archive) as bundle:
        assert {item.filename for item in bundle.infolist() if not item.is_dir()}==set(expected),'Unexpected archive members'
        for member,entry in expected.items():
            target=(WORK/'shrike'/member).resolve()
            assert target.is_relative_to((WORK/'shrike').resolve()),'Unsafe archive path'
            if not target.exists():
                assert not verify_only,'Extracted pinned source missing'
                data=bundle.read(member)
                assert len(data)==entry['bytes'] and hashlib.sha256(data).hexdigest()==entry['sha256']
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
            assert target.stat().st_size==entry['bytes'] and sha(target)==entry['sha256'],member
    print('CC0 BIRD INPUTS: exact archive and six members verified; embedded scripts disabled')

def candidate():
    preparation=read(LOCAL/'preparation.json')
    report=read(ROOT/'outputs/creatures/bird-trial/motion-validation.json')
    assert report['failures']==0 and report['asset_sha256']==preparation['asset_sha256']
    profile=read(ROOT/'scripts/bird-profile.json')
    profile['stats']={'original':{'bones':65,'height_m':.25,'clips':preparation['clips']}}
    profile['authored_replacements']={name:info['origin'] for name,info in preparation['clips'].items()}
    profile['pick_bounds']={'position':[value-.025 for value in report['envelope']['position']],
        'size':[value+.05 for value in report['envelope']['size']]}
    (LOCAL/'candidate.json').write_text(json.dumps(profile,indent=2)+'\n',encoding='utf-8')

def install():
    preparation=read(LOCAL/'preparation.json')
    assert sha(ROOT/'scripts/blender-prepare-bird.py')==preparation['recipe_sha256']
    candidate=read(LOCAL/'candidate.json')
    asset=resource(candidate['assets']['modern'])
    assert sha(asset)==preparation['asset_sha256']
    for name in ['motion-validation','presentation-validation']:
        report=read(ROOT/'outputs/creatures/bird-trial'/f'{name}.json')
        assert report['failures']==0 and report['checks']>100,f'{name} failed/incomplete'
        assert report['asset_sha256']==sha(asset) and report['import_sha256']==sha(Path(str(asset)+'.import'))
        assert report['recipe_sha256']==preparation['recipe_sha256']
        assert report['preparation_sha256']==sha(LOCAL/'preparation.json')
        for path,digest in report['runtime_sha256'].items():
            assert digest and sha(resource(path))==digest,f'Stale bird evidence: {path}'
        if name=='presentation-validation':
            assert report['candidate_sha256']==sha(LOCAL/'candidate.json'),'Candidate changed after rendered acceptance'
            assert report['partial_hue_mask_sha256']==sha(resource(candidate['partial_hue_mask']))
    PUBLIC.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(asset,PUBLIC/'small-bird.glb')
    shutil.copyfile(resource(candidate['partial_hue_mask']),PUBLIC/'feather-tint-mask.png')
    shutil.copyfile(LOCAL/'preparation.json',PUBLIC/'preparation.json')
    candidate.update(status='validated',assets={'modern':'res://Art/Creatures/Birds/small-bird.glb'},
        partial_hue_mask='res://Art/Creatures/Birds/feather-tint-mask.png')
    # Only this independently licensed record ships. Source-derived local
    # creature entries are never copied into the distributable manifest.
    index=PUBLIC.parent/'index.json'
    existing=read(index) if index.exists() else {'entries':[]}
    existing['entries']=[row for row in existing['entries'] if row['kind']!=candidate['kind']]+[candidate]
    index.write_text(json.dumps(existing,indent=2)+'\n',encoding='utf-8')
    (PUBLIC/'NOTICE.txt').write_text(
        'Yellow-billed shrike mesh, rig and original texture maps: pistachio / Al Stachio.\n'
        'Source: https://opengameart.org/content/bird-yellow-billed-shrike\n'
        'Source license: CC0-1.0, https://creativecommons.org/publicdomain/zero/1.0/\n'
        'Exact source archive/member hashes: preparation.json and scripts/bird-inputs.json.\n'
        'Britannia Reborn conversion and authored motions: GPL-3.0-or-later; see root LICENSE.\n'
        'Feather tint mask is the licensed translucency map, reused without pixel changes.\n'
        'No original Ultima Online mesh, texture or animation is included in this asset.\n',encoding='utf-8')
    print('CC0 BIRD INSTALLED: receipt-validated mesh, maps, authored motion and provenance')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-only',action='store_true');parser.add_argument('--install',action='store_true');parser.add_argument('--candidate',action='store_true')
    args=parser.parse_args();inputs(args.verify_only)
    if args.candidate:candidate()
    if args.install:install()
if __name__=='__main__':main()
