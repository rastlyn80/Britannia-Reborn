"""Extract pinned CC0, UV-compatible skin candidates without changing pixels."""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'work/free-human/makehuman_system_assets_cc0.zip'
OUT=ROOT/'Viewer/local-art/free-equipment'
EXPECTED='b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107'
PINS={
 'skins/young_caucasian_male2/young_lightskinned_male_diffuse2.png':'03efe1f6b0ae52429649dcefc9dcaef6058032f874a251169cc3e2ed473c3874',
 'skins/young_caucasian_male2/young_caucasian_male2.mhmat':'60022513803f7b68f30c4f91235b827ace9d36757dc07bdac157d58b7cbc226d',
 'skins/young_asian_male/young_lightskinned_male_diffuse3.png':'f50016a5507fc687dc8df06599c8ea48de950cd185de33a71cafc1319ddab4d5',
 'skins/young_asian_male/young_asian_male.mhmat':'9fdfc9863cd15d1359311435f2da7de3906f81d6eea549fba6bf14cd82ceb6a0',
 'skins/young_african_male/young_darkskinned_male_diffuse.png':'e3f0dbb634e4c68561338f0087f7a122444e84ec56df102212f1222aa12e4d50',
 'skins/young_african_male/young_african_male.mhmat':'11040111c4735028b473f8ce4bb6b0dc0515b7bf26ea815ead85f2c3cbdd7645',
 'skins/young_caucasian_female/young_caucasian_female.mhmat':'0bdea7786201f0b1132a24088336a97496ccdc54e9984db65d253a6a6d66f24f',
 'skins/young_caucasian_female/young_lightskinned_female_diffuse.png':'b2a6ac8cd4f9febdb447368e29c76cd68410bb66e46d9dcfa2d5f75126eea8fc',
 'skins/young_asian_female/young_asian_female.mhmat':'2baeded5fdfd31acc187e83b278f9c4e4cbb59a7ffedf50ebcffcc44e4eab220',
 'skins/young_asian_female/young_lightskinned_female_diffuse3.png':'1d82f782b7d2da732229633bd2d14754d873fff53cdb1d088977bcf67ae19dde',
 'skins/young_african_female/young_african_female.mhmat':'f7e0726cb1c4f1f3dd23e5143f2d91a7c69ddd782a8b1de153a36e1549028b5c',
 'skins/young_african_female/young_darkskinned_female_diffuse.png':'96aa4a96b247fc90d371587bb88e6ae3bfc77e83f5126f17e6bbb713aa200470'}
assert hashlib.sha256(PACK.read_bytes()).hexdigest()==EXPECTED,'Changed official source pack'
OUT.mkdir(exist_ok=True,parents=True)
with zipfile.ZipFile(PACK) as z:
 for name,pin in PINS.items():
  raw=z.read(name);assert hashlib.sha256(raw).hexdigest()==pin
  if name.endswith('.mhmat'):assert 'CC0' in raw.decode('utf-8')
  (OUT/name.rsplit('/',1)[-1]).write_bytes(raw)
evidence=dict(url='https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip',archive_sha256=EXPECTED,selected=PINS,licence='CC0-1.0; explicit declaration in each mhmat',pixels='unmodified',default='young_lightskinned_male_diffuse2.png',alternatives=['young_lightskinned_male_diffuse3.png','young_darkskinned_male_diffuse.png'])
evidence['female_presets']=['young_lightskinned_female_diffuse.png','young_lightskinned_female_diffuse3.png','young_darkskinned_female_diffuse.png']
(OUT/'natural-skin-provenance.json').write_text(json.dumps(evidence,indent=2))
print('Natural skin: twelve pinned source files, six CC0 declarations verified')
