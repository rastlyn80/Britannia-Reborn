"""Fetch the pinned CC0 MakeHuman export inputs; no downloaded code is executed."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'work/free-human'
PIN={'commit': '852e48f316b90a0937234886630e4fb4cdfd1f78', 'assets': {'base_body_anim.glb': {'url': 'https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/output/base_body_anim.glb', 'sha256': '0eb271d4adea12b7f6bb1d4d8f7398db702f9449479be559ab9f019b5ab30b0f', 'bytes': 8212156}, 'hair_short02.glb': {'url': 'https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/output/hair_short02.glb', 'sha256': 'eb341c197acf3948dac1f41f7722e9dad31018149541504a13ebcc8b6aa9d5aa', 'bytes': 1103288}, 'clothing_briefs.glb': {'url': 'https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/output/clothing_briefs.glb', 'sha256': 'e5cf944ff423acfdd11f1294c4dc4a87d875e2d6acb0b00747bd7cc37d2cfa21', 'bytes': 227604}, 'base_body.joints.json': {'url': 'https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/output/base_body.joints.json', 'sha256': '47c40fcaeb9f089f0f32ba781e2a0ac7d7a925a47b6db3c46102f0091a53a839', 'bytes': 45258}, 'asset_licenses.json': {'url': 'https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/output/asset_licenses.json', 'sha256': 'b18bbc7f45fe7c28bcf3b119f44f7b8425d3b4c871f99c694b181b5603f4758e', 'bytes': 7730}, 'hair.json': {'url': 'https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/output/hair.json', 'sha256': '8f54ea98cd039ce61ed15658d8a6c738253a454e23d2f3f9b7706f63bfbdc372', 'bytes': 2008}}, 'licence_notes_sha256': '18af8d071bcb1cab2260263991ad49c314dc616facf7f33b0ab19bee78d4ec13', 'system_pack': {'url': 'https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip', 'sha256': 'b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107', 'members': ['skins/young_caucasian_male/', 'skins/young_caucasian_male/young_lightskinned_male_diffuse.png', 'skins/young_caucasian_male/young_caucasian_male.thumb', 'skins/young_caucasian_male/young_caucasian_male.mhmat']}}


PIN['assets']['clothing_bra.glb']={'url':'https://raw.githubusercontent.com/kblood/CharacterCreator/852e48f316b90a0937234886630e4fb4cdfd1f78/output/clothing_bra.glb','sha256':'5f664e238312be3c4507f77f7e012b30731dbe0618c8e2941c350f516090fd5b','bytes':294820}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--verify-only',action='store_true');args=ap.parse_args()
 OUT.mkdir(parents=True,exist_ok=True)
 def fetch(url,path,expected=None):
  if path.exists() and (expected is None or digest(path)==expected):return
  if args.verify_only:raise RuntimeError('Missing or modified input: '+str(path))
  temp=path.with_suffix(path.suffix+'.partial')
  with urllib.request.urlopen(url,timeout=90) as response,temp.open('wb') as output:
   while block:=response.read(1024*1024):output.write(block)
  if expected and digest(temp)!=expected:raise RuntimeError('Download hash mismatch: '+str(path))
  temp.replace(path)
 for name,item in PIN['assets'].items():fetch(item['url'],OUT/name,item['sha256'])
 licence_url='https://raw.githubusercontent.com/kblood/CharacterCreator/'+PIN['commit']+'/LICENSE-NOTES.md'
 fetch(licence_url,OUT/'LICENSE-NOTES.md',PIN['licence_notes_sha256'])
 pack=PIN['system_pack'];archive=OUT/'makehuman_system_assets_cc0.zip';fetch(pack['url'],archive,pack['sha256'])
 skin=OUT/'male-skin';skin.mkdir(exist_ok=True)
 with zipfile.ZipFile(archive) as z:
  for name in pack['members']:
   if name.endswith(('.png','.mhmat','.meta')):
    data=z.read(name);target=skin/name.rsplit('/',1)[-1]
    if args.verify_only:
     if not target.exists() or target.read_bytes()!=data:raise RuntimeError('Male skin extraction differs')
    else:target.write_bytes(data)
 if not args.verify_only:
  (OUT/'source-commit.txt').write_text(PIN['commit'])
  (OUT/'download-manifest.json').write_text(json.dumps(dict(repository='https://github.com/kblood/CharacterCreator',commit=PIN['commit'],assets=PIN['assets'],licence='CC0-1.0 for exported assets; see LICENSE-NOTES.md'),indent=2))
  (OUT/'male-skin-source.json').write_text(json.dumps(pack,indent=2))
 print('FREE HUMAN INPUTS: pinned assets, licence notes and official male skin verified')
if __name__=='__main__':main()
