"""Reproduce the private original Mummy trial; no activation or acceptance."""
import argparse
import hashlib
import importlib.util
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'work/third-dawn/late-source-research/uoaos-source'
WORK = ROOT/'work/creatures/mummies/source-preparation'
ART = ROOT/'Viewer/local-art/creatures'
MANIFEST = ROOT/'scripts/source-mummy-inputs.json'
KIND = 'walking_dead_mummy'
TOOLS = ['prepare-source-mummy.py','prepare-creatures.py','import-third-dawn.py',
         'third-dawn-subdivide.py','creature-source-reuse.py','creature-affine.py',
         'creature-source-repairs.py','creature-humanoid-actions.py',
         'prepare-distinct-mounts.py','audit-creature-sources.py']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inputs(cabinet_members=False):
    pins = json.loads(MANIFEST.read_text(encoding='utf-8'))
    cabs = SOURCE.parent/'uoaos-cabinets'
    for row in pins['cabinets']:
        path = cabs/Path(row['zip_member']).name
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256']
    folders = {'Models': 'client7.cab', 'Models/Monsters': 'client11.cab', 'Models/Maps': 'client10.cab'}
    seven = shutil.which('7z') or shutil.which('7zz') or 'C:/Program Files/7-Zip/7z.exe'
    for row in pins['files']:
        path = (SOURCE/row['path']).resolve()
        assert path.is_relative_to(SOURCE.resolve()) and path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], row['path']
        if cabinet_members:
            cabinet = cabs/folders[Path(row['path']).parent.as_posix()]
            # Inspect original cabinet contents in memory. No game executable runs.
            raw = subprocess.run([seven, 'e', '-so', str(cabinet), path.name], check=True, capture_output=True).stdout
            assert len(raw) == row['bytes'] and hashlib.sha256(raw).hexdigest() == row['sha256'], row['path']
    assert {r['native_class'] for r in pins['native_sources']} == {'Mummy', 'PestilentBandage'}
    for row in pins['native_sources']:
        assert row['body'] == 154 and sha(ROOT/'Server/ModernUO'/row['path']) == row['sha256']
    return pins

def prepare(cabinet_members=False):
    pins = inputs(cabinet_members)
    tools = {name:sha(ROOT/'scripts'/name) for name in TOOLS}
    spec = importlib.util.spec_from_file_location('mummy_pipeline', ROOT/'scripts/prepare-creatures.py')
    pipeline = importlib.util.module_from_spec(spec); spec.loader.exec_module(pipeline)
    WORK.mkdir(parents=True, exist_ok=True); pipeline.OUTPUT = WORK
    paths = {'uoaos/UOTD/'+r['path']: SOURCE/r['path'] for r in pins['files']}
    class OriginalInputs:
        def read(self, name):
            return paths[name].read_bytes()
    pipeline.reuse.RECIPES[KIND] = {'floor_sample_rate': 240, 'measure_motion_bounds': True}
    server_pin, native = pipeline.native_bodies()
    assert server_pin == pins['server_pin']
    rows = pipeline.prepare('walking', OriginalInputs(), {n.casefold(): n for n in paths},
                            pipeline.table_rows((SOURCE/'Models/models.txt').read_bytes()), native, selected_kinds={KIND})
    assert len(rows) == 1
    row = rows[0]
    assert row['status'] == 'prepared' and not row['rejected_source_clips']
    assert {r['body'] for r in row['bodies']} == {154}
    assert row['stats']['original']['source_points'] == 104 and row['stats']['original']['triangles'] == 200
    assert row['stats']['original']['bones'] == 33 and row['stats']['rounded']['triangles'] == 3200
    assert set(row['clip_sources']) == {'Idle','Walk','Run','Attack','Hit','Death','Fidget'}
    row['bodies'][0]['native_sources'] = pins['native_sources']
    row['pending_render_feature'] = 'Source pose/terrain/material/mask/corpse and separate native Mummy/PestilentBandage acceptance remain; no route enabled.'
    assets = {}
    for treatment in ['original','rounded','modern']:
        name = KIND+'-'+treatment+'.gltf'
        shutil.copyfile(WORK/name, ART/name); assets[name] = sha(ART/name)
    name = KIND+'-original-albedo.png'; shutil.copyfile(WORK/name, ART/name); assets[name] = sha(ART/name)
    report = dict(family='mummies', models=rows, server_pin=server_pin, source_url=pins['source_url'],
                  source_cabinets=pins['cabinets'], input_manifest_sha256=sha(MANIFEST),
                  source_tools_sha256=tools,
                  assets_sha256=assets, cabinet_members_verified=cabinet_members,
                  scope=pins['scope'], rights=pins['rights'])
    folder=ART/'mummies'; folder.mkdir(parents=True, exist_ok=True)
    assert tools == {name:sha(ROOT/'scripts'/name) for name in TOOLS}
    assert pins == inputs()
    (folder/'preparation.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
    print('MUMMY PREPARED: exact33-joint original, seven motions,200to3200triangles; two native constructors share154. No accepted coverage.')

def check_prepared():
    inputs()
    report = json.loads((ART/'mummies/preparation.json').read_text(encoding='utf-8'))
    assert report['input_manifest_sha256'] == sha(MANIFEST)
    assert report['cabinet_members_verified']
    assert set(report['source_tools_sha256']) == set(TOOLS)
    for name,digest in report['source_tools_sha256'].items():
        assert sha(ROOT/'scripts'/name) == digest, name
    for name,digest in report['assets_sha256'].items():
        assert Path(name).name == name and sha(ART/name) == digest, name
    assert len(report['models']) == 1
    row=report['models'][0]
    assert row['kind'] == KIND and row['pending_render_feature']
    assert set(row['clip_sources']) == {'Idle','Walk','Run','Attack','Hit','Death','Fidget'}
    assert not row['rejected_source_clips'] and {r['body'] for r in row['bodies']} == {154}
    assert row['stats']['original']['bones'] == 33 and row['stats']['rounded']['triangles'] == 3200
    print('MUMMY PREPARATION: actual cabinet members/exact inputs/reader/converter/derived assets checked. Source pose/render/terrain/hue/corpse/native acceptance remains.')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare',action='store_true'); parser.add_argument('--cabinet-members',action='store_true')
    parser.add_argument('--check-prepared',action='store_true')
    args=parser.parse_args()
    if args.prepare:
        prepare(args.cabinet_members)
    elif args.check_prepared:
        check_prepared()
    else:
        pins=inputs(args.cabinet_members)
        print('MUMMY INPUTS:',len(pins['files']),'exact original files,three cabinets,two native constructor sources; no activation')
