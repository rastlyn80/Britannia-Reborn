"""Prepare the three original fey and demon champion candidates from pinned local inputs."""
import runpy
from pathlib import Path
import hashlib
import json
from shutil import copyfile
root = Path(__file__).resolve().parents[1]
base=root/'work/creatures/late-client-inputs'
source=base/'champions-fey-source'
p=runpy.run_path(str(root/'scripts/prepare-gazer-larva-source.py'))['pipeline']()
p.OUTPUT=(base/'champions-fey-preview').resolve()
members={f.relative_to(source).as_posix().lower():f for f in source.rglob('*') if f.is_file()}
manifest = json.loads(Path(__file__).with_name('fey-champion-inputs.json').read_text(encoding='utf-8'))
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
table_path = base/'model-table/Client/Models.txt'
assert sha(table_path) == manifest['model_table_sha256']
assert {key: sha(path) for key, path in members.items()} == manifest['files']
p.helper.audit.ARCHIVE_HASH = manifest['installer_sha256']
class Inputs:
    def read(self,name):
        return members[name].read_bytes()
hit_member = next(key for key in members if key.endswith('/ethereal_warriors_male_gethit.grn'))
hit = p.td.parse(members[hit_member].read_bytes(), animations_only=True, scene_root_names=True, scale_shear_tracks=True)
assert len(hit['bones']) == 41 and not hit['tracks']
del members[hit_member]
table=p.table_rows(table_path.read_bytes())
_,native=p.native_bodies()
recipes=p.reuse.RECIPES.copy()
target = root/'Viewer/local-art/creatures/fey_champions'
target.mkdir(parents=True, exist_ok=True)
res = 'res://local-art/creatures/fey_champions/'
models = []
constructors = {174: 'Semidar', 175: 'LordOaks', 176: 'Silvani'}
for family,kind,body in [('succubi','succubi_succubus',174),('ethereal','ethereal_warriors_male',175),('fey','fey_race_pixie',176)]:
    p.reuse.RECIPES={k:v for k,v in recipes.items() if k==kind}
    rows=[r for r in table if r['stem']!=kind or r['body']==body]
    row,=p.prepare(family,Inputs(),{k:k for k in members},rows,native,selected_kinds={kind})
    expected = 7 if body == 175 else 8
    assert row['status'] == 'prepared' and len(row['clip_sources']) == expected
    assert ('Hit' in row['authored_replacements']) == (body == 175)
    print(body,row['status'],row.get('blocker'),len(row.get('clip_sources',{})),row.get('authored_replacements'),flush=True)

    identity, = row['bodies']
    assert identity['body'] == body
    for native_source in identity['native_sources']:
        relative = native_source['path'].replace(chr(92), '/')
        assert sha(root/'Server/ModernUO'/relative) == native_source['sha256']
    row.update(family='fey_champions', native_constructor_hues={constructors[body]: 0},
               assets={}, asset_sha256={}, art_dependency_sha256={})
    if 'Cast2' in row['clip_sources']:
        row['classic_action_categories'] = {'12': 'Cast2'}
        row['new_action_categories'] = {'11': 'Cast2'}
    for variant in ('original', 'rounded', 'modern'):
        name = f'{kind}-{variant}.gltf'
        copyfile(p.OUTPUT/name, target/name)
        row['assets'][variant] = res + name
        row['asset_sha256'][variant] = sha(target/name)
    models.append(row)
pending = target/'preparation.pending'
pending.write_text(json.dumps({'models': models, 'input_manifest_sha256': sha(Path(__file__).with_name('fey-champion-inputs.json'))},
                              indent=2) + '\n', encoding='utf-8')
pending.replace(target/'preparation.json')
