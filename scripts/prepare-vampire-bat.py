"""Rebuild the recovered Vampire Bat with the flight parent folded into its root."""
import copy, hashlib, json, runpy
from shutil import copyfile
from pathlib import Path
root = Path(__file__).resolve().parents[1]
b = root/'work/creatures/late-client-inputs'
p=runpy.run_path(str(root/'scripts/prepare-gazer-larva-source.py'))['pipeline']()
p.OUTPUT=b.resolve()/'vampire-bat-preview'
source=b/'vampire-bat-source'
members={f.relative_to(source).as_posix().lower():f for f in source.rglob('*') if f.is_file()}
manifest_path = Path(__file__).with_name('vampire-bat-inputs.json')
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
table_path = b/'model-table/Client/Models.txt'
assert sha(table_path) == manifest['model_table_sha256']
assert {name: sha(path) for name, path in members.items()} == manifest['files']
p.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']

class Inputs:
 def read(self,name): return members[name].read_bytes()
original=p.helper.match_animation
def match(anim,body):
 leaves={f'bip01 {side} {part}0nub' for side in ('l','r') for part in ('finger','toe')}
 indices={i for i,bone in enumerate(body['bones']) if bone['name'] in leaves}
 assert len(indices)==4
 assert not any(i in indices and w>0 for point in body['weights'] for i,w in point)
 assert not any(bone['parent'] in indices for bone in body['bones'])
 retained=dict(body,bones=[bone for i,bone in enumerate(body['bones']) if i not in indices])
 if any(bone['name']=='dummy01' for bone in anim['bones']):
  anim=copy.deepcopy(anim)
  by_name={bone['name']:i for i,bone in enumerate(anim['bones'])}
  tracks={t['name']:t for t in anim['tracks']}
  parent=anim['bones'][by_name['dummy01']]
  root=anim['bones'][by_name['bip01']]
  assert anim['bones'][parent['parent']]['name']=='__root' and root['parent']==by_name['dummy01']
  for channel in ('translation','rotation'):
   values=tracks['dummy01'][channel]['values']
   assert all(min(max(abs(a-sign*b) for a,b in zip(v,parent[channel])) for sign in ((1,-1) if channel=='rotation' else (1,)))<1e-5 for v in values)
  identity=(1,0,0,0,1,0,0,0,1)
  assert all(max(abs(a-b) for a,b in zip(v,identity))<1e-5 for v in tracks['dummy01'].get('scale_shear',{}).get('values',[]))
  q=p.td.unit(parent['rotation'])
  def translate(v): return [a+b for a,b in zip(parent['translation'],p.td.rotate(q,v))]
  def rotate(v): return p.td.qmul(q,v)
  for channel,compose in [('translation',translate),('rotation',rotate)]:
   root[channel]=compose(root[channel])
   stream=tracks['bip01'][channel]
   stream['values']=[compose(v) for v in stream['values']]
  root['parent']=parent['parent']
  print('Flight: composed constant dummy01 into the weighted bip01 root',flush=True)
 return original(anim,retained)
p.helper.match_animation=match
table=p.table_rows(table_path.read_bytes())
_,native=p.native_bodies()
row,=p.prepare('vampire',Inputs(),{k:k for k in members},table,native)
if row['status'] != 'prepared':
    raise RuntimeError(f'Vampire Bat source conversion failed: {row.get("blocker")}')
identity, = row['bodies']
assert identity['body'] == 317 and row['stats']['original']['bones'] == 38
assert len(row['clip_sources']) == 9 and 'Fly' in row['clip_sources']
for native_source in identity['native_sources']:
    relative = native_source['path'].replace(chr(92), '/')
    assert sha(root/'Server/ModernUO'/relative) == native_source['sha256']
target = root/'Viewer/local-art/creatures/vampire_bat'
target.mkdir(parents=True, exist_ok=True)
res = 'res://local-art/creatures/vampire_bat/'
row.update(family='vampire_bat', movement_mode='ground_plane',
           native_constructor_hues={'VampireBat': 0, 'VampireBatFamiliar': 0},
           assets={}, asset_sha256={}, art_dependency_sha256={})
for variant in ('original', 'rounded', 'modern'):
    name = f'vampire_bat-{variant}.gltf'
    copyfile(p.OUTPUT/name, target/name)
    row['assets'][variant] = res + name
    row['asset_sha256'][variant] = sha(target/name)
pending = target/'preparation.pending'
pending.write_text(json.dumps({'models': [row], 'input_manifest_sha256': sha(manifest_path)},
                              indent=2) + '\n', encoding='utf-8')
pending.replace(target/'preparation.json')
print('Vampire Bat 317: 38-joint source mesh and nine recovered motions including Fly')
