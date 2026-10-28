"""Fetch/extract pinned licensed equipment and cosmetics. Never execute asset code."""
import argparse,hashlib,json,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'work/character-expansion'
PIN=json.loads((ROOT/'scripts/character-expansion-inputs.json').read_text())
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--verify-only',action='store_true');args=ap.parse_args()
 OUT.mkdir(parents=True,exist_ok=True)
 for name,info in PIN['archives'].items():
  path=ROOT/info['local'] if 'local' in info else OUT/(name+'_cc0.zip')
  if not path.exists() or sha(path.read_bytes())!=info['sha256']:
   if args.verify_only:raise RuntimeError('Missing or changed archive '+name)
   temp=path.with_suffix('.partial');temp.parent.mkdir(parents=True,exist_ok=True)
   with urllib.request.urlopen(urllib.request.Request(info['url'],headers={'User-Agent':'BritanniaReborn-AssetPreparation/1.0'}),timeout=90) as response,temp.open('wb') as f:
    while block:=response.read(1024*1024):f.write(block)
   assert sha(temp.read_bytes())==info['sha256'],'Changed archive '+name
   temp.replace(path)
  with zipfile.ZipFile(path) as z:
   for asset in PIN['assets'].values():
    if asset['pack']!=name:continue
    assert asset['license'] in ['CC0','CC-BY']
    if asset['license']=='CC-BY':assert asset.get('attribution'),'Missing required attribution'
    for member,pin in asset['files'].items():
     target=OUT/'assets'/member
     assert target.resolve().is_relative_to((OUT/'assets').resolve())
     raw=z.read(member);assert sha(raw)==pin,'Changed member '+member
     if args.verify_only:assert target.exists() and sha(target.read_bytes())==pin,'Missing extracted member '+member
     else:target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
 for name,info in PIN.get('material_inputs',{}).items():
  path=ROOT/name
  if not path.exists() and not args.verify_only and 'archive_url' in info:
   archive=OUT/('material-'+info['archive_sha256'][:16]+'.zip')
   if not archive.exists():
    request=urllib.request.Request(info['archive_url'],headers={'User-Agent':'BritanniaReborn-AssetPreparation/1.0'})
    with urllib.request.urlopen(request,timeout=90) as response:archive.write_bytes(response.read())
   assert sha(archive.read_bytes())==info['archive_sha256'],'Changed material archive'
   assert Path(info['archive_member']).suffix.lower() in ['.png','.jpg','.jpeg']
   assert path.resolve().is_relative_to(ROOT.resolve())
   with zipfile.ZipFile(archive) as z:
    raw=z.read(info['archive_member']);assert sha(raw)==info['sha256']
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
  assert path.exists() and sha(path.read_bytes())==info['sha256'],'Missing or changed material '+name
 print('CHARACTER EXPANSION:',len(PIN['assets']),'pinned licensed assets and material inputs verified')
if __name__=='__main__':main()
