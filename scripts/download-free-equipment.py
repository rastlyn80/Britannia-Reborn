"""Download/hash-check the selected official CC0 clothing and skin data only."""
import argparse,hashlib,json,re,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'work/free-equipment'
PIN={'suits02_cc0.zip': {'url': 'https://files.makehumancommunity.org/asset_packs/suits02/suits02_cc0.zip', 'sha256': '437f4d7ab92b698c1fb1047e7d62b22c11f195b2473e936118661dc8e6b7eb7a', 'selected_members': {'clothes/donitz_monk_robe_hood/donitz_monk_robe_hood.mhclo': '5f32a69d26f68b9c5dd9076e9b6859c154291759726831def4bc5c7afc315aa7', 'clothes/donitz_monk_robe_hood/monks_robe_brown.mhmat': '605e05e538f3d2160d62724dd07bd736efda01c055bfcb4c4de13bd90214f4ce', 'clothes/donitz_monk_robe_hood/donitz_monk_robe_hood.thumb': '0dd5567b3d4160481476a1293ce61e10161913c6609288f005dfcff87fade869', 'clothes/donitz_monk_robe_hood/robe_brown__diffuse.png': '244f344a4ba574aa4e36b63919d36e5c6bb1ac6b7d0b92ef6815a709c5bc9bb9', 'clothes/donitz_monk_robe_hood/Monks_Hood.obj': '989f2632ccce50d4cf99973167ecc10e6f33911a60e8e378d50d8b30d06306fc', 'clothes/donitz_monk_robe_hood/robe__normal_gl.png': '0ec059f6732c37c234af409c4467eabe1c8865292fdac0755a653ea6f9110859', 'clothes/rehmanpolanski_viking_pants/rehmanpolanski_viking_pants.mhclo': '2afe050edefda93d4e47a58b31e6e65a14ac09e0d466d9debcacbe376f956c0f', 'clothes/rehmanpolanski_viking_pants/pantsviking.obj': '44644ac6aeec9cb56fbfd77225eaa8b02613b2587cd809fe6f3755bef7e2d709', 'clothes/rehmanpolanski_viking_pants/pantsviking.mhmat': 'a4e8f761f524b7a3f6d0aaa37ece5a88282e05c424071c018473bbc81922d7ee', 'clothes/rehmanpolanski_viking_pants/PantsViking.png': '15b5d55a6f6b8f6d42bda782aa2db93cb7d17c88e6a13fb1a52cbcbf6d4b34e6', 'clothes/rehmanpolanski_viking_pants/rehmanpolanski_viking_pants.thumb': '6704d38d19a3fd3358dd40837f96430cdee6c8fece3b9e23cf9bbdfe7e09b848', 'clothes/donitz_monk_robe/Monks_Robe.obj': '12ab7c180f724c1a50d3b2217d0d37ef03758ed387e22abb3933fe93269b90cc', 'clothes/donitz_monk_robe/monks_robe_brown.mhmat': '605e05e538f3d2160d62724dd07bd736efda01c055bfcb4c4de13bd90214f4ce', 'clothes/donitz_monk_robe/donitz_monk_robe.mhclo': '7f0cf2903c602bd817e8a3a38d4b6201313ab0c156702f9dcc3e440897b0a4c8', 'clothes/donitz_monk_robe/robe_brown__diffuse.png': '244f344a4ba574aa4e36b63919d36e5c6bb1ac6b7d0b92ef6815a709c5bc9bb9', 'clothes/donitz_monk_robe/donitz_monk_robe.thumb': '8f338fcec830c14436f1f360b4798de7908c217d7f5ad768a9b1cd3847cc3d92', 'clothes/donitz_monk_robe/robe__normal_gl.png': '0ec059f6732c37c234af409c4467eabe1c8865292fdac0755a653ea6f9110859', 'clothes/rehmanpolanski_viking_tunic/tunicviking.mhmat': '8b69e430954fe0df4ea832bdb60f3786244118e4ac2e539a782e32a38c51f3dd', 'clothes/rehmanpolanski_viking_tunic/rehmanpolanski_viking_tunic.thumb': '5146814cfe8e6555567a9833f439ce9e146a5b3f2d9d821e7895566a93de33f5', 'clothes/rehmanpolanski_viking_tunic/tunicviking.obj': '78c593d23151c4f9cd63481bd7f5101cae920623404bbf5f3daa01a5f2ea050b', 'clothes/rehmanpolanski_viking_tunic/TUNIC_Viking.png': '9fcb9e17fad6ec1a36e3a0e0562cac3ca0ea72208da617875eed9bf294d9f870', 'clothes/rehmanpolanski_viking_tunic/rehmanpolanski_viking_tunic.mhclo': '349b5b7b2abc44a7bd0b52ca99bd352e7d3b316cd4be5d539bbd9587462e801c', 'clothes/rehmanpolanski_viking_boots/BootsViking.png': '114622c571ff7249bbd25223f6563d174894c426afb6ab92d35551b712bf1413', 'clothes/rehmanpolanski_viking_boots/rehmanpolanski_viking_boots.mhclo': 'd864ac895a662031026615b5e042fb2160e63f432029576fa6faaf2ad692eb92', 'clothes/rehmanpolanski_viking_boots/bootsviking.mhmat': '48c23f652484411447b1c04a9c64f421331c5b02ce3697e023f9fc140bb3ca39', 'clothes/rehmanpolanski_viking_boots/rehmanpolanski_viking_boots.thumb': '8f8222d6c41f3aee8f0c7a9af01227e71857f9b7688ba00a0b69756f13e854b3', 'clothes/rehmanpolanski_viking_boots/bootsviking.obj': '9cc5a9cc4160ff2230144490244117eaddc4596152556304ca59d1129e4c196b'}, 'metadata_member': 'packs/suits02.json', 'metadata_sha256': '279ded8386876b89cedf62df8bdac33358b75942b07aef5b82f73a1235442711'}, 'skins02_cc0.zip': {'url': 'https://files.makehumancommunity.org/asset_packs/skins02/skins02_cc0.zip', 'sha256': '1613f1ef3afca53094511d26620ed7cf1d2dedc29ed3d384d60bdebe250698ae', 'selected_members': {'skins/mindfront_aksel_skin/mindfront_aksel_skin.mhmat': 'ed79cb17edbb5929dd83474a46f045df7d5f31d0b9c1156c87f563bd2bbbfab6', 'skins/mindfront_aksel_skin/Aksel_Skin_diffuse.png': '268ee6d1ea9665f8050d040c7b47971884428628021418ae52f68912859f5e60', 'skins/mindfront_aksel_skin/Aksel_Skin_NRM.png': '2bf3632a4bfb1631d9ae15568c7de5c7254c780e5168f1546827f32d50f5212d', 'skins/mindfront_aksel_skin/Aksel_Skin_SPEC.png': 'd34638826d48d6fdb632f3a18296999630edf2879e7301356dfa60e6d61808f7', 'skins/mindfront_aksel_skin/mindfront_aksel_skin.thumb': '52c48a768ecef782641285b8ef2e59828f09d441d42ed8593dceb350204b3b5d'}, 'metadata_member': 'packs/skins02.json', 'metadata_sha256': '35c4e7d05d882537b6312cbbc95830347eb547941248dbdb5f5595e6d9e1e705'}, 'base_obj': {'url': 'https://raw.githubusercontent.com/makehumancommunity/makehuman/3c701a8e52f09e69922e8b598d23be2d7dfc49e3/makehuman/data/3dobjs/base.obj', 'sha256': '8e761e6624b8f54536409135d1636da63b32486a90d4897f84e121d144f6fb4c', 'commit': '3c701a8e52f09e69922e8b598d23be2d7dfc49e3'}}

def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--verify-only',action='store_true');args=ap.parse_args();OUT.mkdir(parents=True,exist_ok=True)
 def fetch(url,path,expected):
  if path.exists() and sha(path.read_bytes())==expected:return
  if args.verify_only:raise RuntimeError('Missing/modified input '+str(path))
  temp=path.with_suffix(path.suffix+'.partial')
  with urllib.request.urlopen(url,timeout=90) as response,temp.open('wb') as output:
   while block:=response.read(1024*1024):output.write(block)
  if sha(temp.read_bytes())!=expected:raise RuntimeError('Hash mismatch '+str(path))
  temp.replace(path)
 fetch(PIN['base_obj']['url'],OUT/'base.obj',PIN['base_obj']['sha256'])
 evidence={}
 for name in ['suits02_cc0.zip','skins02_cc0.zip']:
  info=PIN[name];path=OUT/name;fetch(info['url'],path,info['sha256'])
  with zipfile.ZipFile(path) as z:
   meta=z.read(info['metadata_member']);assert sha(meta)==info['metadata_sha256'];catalog=json.loads(meta)
   for member,expected in info['selected_members'].items():
    raw=z.read(member);assert sha(raw)==expected
    target=OUT/'assets'/member
    if not target.resolve().is_relative_to((OUT/'assets').resolve()):raise RuntimeError('Unsafe asset path')
    if args.verify_only:
     if not target.exists() or target.read_bytes()!=raw:raise RuntimeError('Extracted file differs '+member)
    else:target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    asset=member.split('/')[1];record=catalog[asset]
    assert record['license']=='CC0','Selected asset is not CC0'
    evidence[asset]=record
    if member.endswith('.mhclo') and not re.search(r'license\s*:?\s*CC0',raw[:700].decode('utf-8'),re.I):raise RuntimeError('Clothing header licence is missing')
   if not args.verify_only:(OUT/info['metadata_member'].rsplit('/',1)[-1]).write_bytes(meta)
 if not args.verify_only:
  (OUT/'download-manifest.json').write_text(json.dumps(PIN,indent=2));(OUT/'licence-evidence.json').write_text(json.dumps(evidence,indent=2))
 print('FREE EQUIPMENT INPUTS: all source hashes and six selected CC0 licence records verified')
if __name__=='__main__':main()
